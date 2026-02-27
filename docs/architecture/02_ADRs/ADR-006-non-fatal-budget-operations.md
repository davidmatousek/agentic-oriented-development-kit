# ADR-006: Non-Fatal Error Handling for Budget Operations

**Status**: Accepted
**Date**: 2026-02-14
**Deciders**: Architect, Feature 054 Implementation Team
**Feature**: 054 - Parallel Execution Budget Hardening

---

## Context

Feature 054 introduces six new functions to `run-state.sh` for parallel execution budget tracking and circuit-breaker churn detection:

- `aod_state_set_parallel_context(agent_count)` - Set parallel execution mode with multiplier
- `aod_state_get_parallel_multiplier()` - Retrieve current budget multiplier (1.0/1.5/3.0)
- `aod_state_clear_parallel_context()` - Reset parallel context after operation
- `aod_state_record_failure(op, error)` - Record operation failure for circuit-breaker
- `aod_state_check_circuit_breaker()` - Check if circuit-breaker is tripped (3+ consecutive failures)
- `aod_state_reset_circuit_breaker()` - Reset circuit-breaker state

These functions enhance budget tracking accuracy for parallel Triad reviews (3 agents consuming ~90K tokens) and detect churn loops (repeated failures with identical error signatures).

**The key constraint**: Budget hardening is an enhancement layer, not a critical path. Any failure in these functions must never block the primary skill execution. If `jq` is unavailable, the state file is corrupted, or a write fails, the skill must continue normally with conservative defaults.

---

## Decision

We will implement all Feature 054 budget operations with **comprehensive non-fatal error handling** using three techniques:

1. **Function-level wrapping**: Entire function body wrapped in `{ ... } 2>/dev/null || true`
2. **Fallback return values**: Every function returns a safe default on any error
3. **Early exit on missing prerequisites**: Functions return 0 (success) when state file lacks required fields

---

## Rationale

### Why Non-Fatal?

**Budget tracking is observational, not transactional.** Unlike state writes that affect orchestration flow (e.g., `current_stage`), budget multipliers and circuit-breaker status are purely informational. An incorrect estimate (1.0x instead of 3.0x) may cause a late auto-pause, but won't corrupt the workflow. A blocked skill due to `jq` missing would be worse than an imprecise budget estimate.

**Prior art in the codebase**: Feature 038 established the "Non-Fatal Budget Wrapper" pattern for standalone commands. Feature 054 extends this pattern to the underlying bash functions themselves, making non-fatality intrinsic rather than caller-dependent.

**Graceful degradation hierarchy**:
1. Best case: Parallel multiplier accurately applied (3.0x for 3-agent review)
2. Degraded case: Fallback to 1.0x multiplier, possible late auto-pause
3. Worst case: Budget operations silently fail, skill executes normally without tracking

### Design Choices

**Choice 1: Wrap entire function body, not individual statements**

```bash
# CHOSEN: Single wrapper
aod_state_set_parallel_context() {
    {
        # ... all logic ...
    } 2>/dev/null || true
    return 0
}

# REJECTED: Per-statement handling
aod_state_set_parallel_context() {
    aod_state_check_jq || return 0  # Would need this on every call
    state=$(aod_state_read) || return 0
    # ... 10+ more statements each needing || return 0
}
```

**Rationale**: Single wrapper is more maintainable and guarantees non-fatality regardless of future changes to function internals.

**Choice 2: Return fallback values from stdout, not error codes**

```bash
aod_state_get_parallel_multiplier() {
    { ... } 2>/dev/null || echo "1.0"  # Fallback to stdout
    return 0  # Always success
}
```

**Rationale**: Callers use `$(aod_state_get_parallel_multiplier)` for value capture. A non-zero exit code would be ignored; a missing stdout value would cause downstream errors. Explicit fallback ensures callers always receive usable data.

**Choice 3: Validate input defensively, don't trust callers**

```bash
_aod_calc_multiplier() {
    local agent_count="$1"

    # Invalid input -> warning + fallback
    if ! [[ "$agent_count" =~ ^[0-9]+$ ]]; then
        echo "[aod] WARNING: Invalid agent_count, defaulting to 1.0" >&2
        echo "1.0"
        return 0
    fi

    # Negative/zero -> warning + fallback
    if [[ "$agent_count" -le 0 ]]; then
        echo "[aod] WARNING: agent_count must be positive, defaulting to 1.0" >&2
        echo "1.0"
        return 0
    fi
    # ...
}
```

**Rationale**: Budget functions are called from skill code during governance gates. A typo or calculation error in the skill should not cascade into a hard failure.

---

## Alternatives Considered

### Alternative 1: Strict Error Handling with Caller Guards

Make budget functions fail loudly, require callers to wrap in `|| true`.

**Pros**:
- Clearer debugging: Errors are visible
- Forces callers to acknowledge budget operations can fail

**Cons**:
- Every caller must remember to add guards
- Violates "non-fatal by design" principle established in Feature 038
- Skills would need to duplicate error-suppression logic

**Why Not Chosen**: Shifts complexity to callers; historical evidence shows callers forget guards and cause production failures.

### Alternative 2: Conditional Execution Based on Prerequisites

Check for `jq` and state file existence before each operation; skip silently if missing.

**Pros**:
- Explicit skip logic is documentable
- No reliance on shell error suppression

**Cons**:
- Doesn't handle mid-function failures (e.g., `jq` crashes, disk full)
- Duplicates prerequisite checks across 6 functions

**Why Not Chosen**: Partial solution; full-function wrapping is more robust.

### Alternative 3: Feature Flag to Enable/Disable Budget Hardening

Allow users to disable Feature 054 entirely via environment variable.

**Pros**:
- Clean opt-out for users experiencing issues
- Clear documentation of what's enabled/disabled

**Cons**:
- Adds configuration complexity
- Budget hardening should "just work" without user intervention
- Users would need to know the flag exists to use it

**Why Not Chosen**: Non-fatal design makes feature flags unnecessary; broken operations degrade gracefully.

---

## Consequences

### Positive

- Budget operations can never block skill execution
- No new dependencies (relies on existing `jq` with fallback)
- Consistent with established non-fatal patterns (Features 038, 042, 049)
- Callers don't need to understand budget internals
- Backward compatible: Existing code ignores new state fields

### Negative

- Errors are silently suppressed; debugging requires enabling verbose mode
- Incorrect multipliers may cause suboptimal auto-pause timing
- Circuit-breaker may fail to detect churn if state writes fail

### Mitigation

- **Diagnostic logging**: Circuit-breaker logs churn detection to `error_log` array before pausing
- **Warning messages**: Invalid inputs emit warnings to stderr before falling back
- **Explicit fallbacks**: All functions document their fallback values in comments

---

## Implementation Notes

### Multiplier Logic

```
Agent Count    Multiplier    Rationale
-----------    ----------    ---------
1              1.0x          Solo execution, no scaling needed
2              1.5x          Light parallelism (PM + Architect review)
3+             3.0x          Full Triad review, capped at maximum
```

### Circuit-Breaker State Schema

```json
{
  "circuit_breaker": {
    "status": "closed",           // "open" after 3+ identical failures
    "failure_count": 0,           // Resets on success or signature change
    "last_error_signature": null, // "operation:error_type" pattern
    "last_failure_at": null       // ISO8601 timestamp
  }
}
```

### Error Signature Comparison

Circuit-breaker compares `operation_name:error_type` strings. If consecutive failures have different signatures, the counter resets (transient, unrelated issues). Only identical signatures accumulate toward the 3-failure threshold.

---

## Related Decisions

- ADR-003: Heuristic Token Estimation (establishes token budget schema)
- ADR-004: Performance Registry (establishes calibrated budget defaults)
- Pattern: Non-Fatal Budget Wrapper (Feature 038)
- Pattern: Graceful CLI Degradation (Feature 022)

---

## References

- Feature 054 Spec: `specs/054-parallel-execution-budget-hardening/spec.md`
- Implementation: `.aod/scripts/bash/run-state.sh` (lines 682-969)
- Prior pattern: `docs/architecture/03_patterns/README.md#pattern-non-fatal-budget-wrapper`
