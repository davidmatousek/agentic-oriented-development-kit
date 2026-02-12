# ADR-003: Heuristic Token Estimation for Budget Tracking

**Status**: Accepted
**Date**: 2026-02-11
**Deciders**: Architect
**Feature**: 032 (Real-time Token Budget Tracking)

---

## Context

The `/aod.run` orchestrator (Feature 022) chains 5 SDLC stages in a single session. Feature 030 reduced persistent context consumption by ~78%, but the orchestrator still has no visibility into cumulative token usage during a run. When total consumption approaches the 200K-token context window limit, the agent experiences degraded performance or context overflow with no advance warning.

To make informed decisions about context loading (e.g., skipping non-essential reference files, recommending a session resume), the orchestrator needs a running estimate of tokens consumed. However, the Claude Code agent framework does not expose actual token counts to skills or bash scripts.

**Constraints**:
- No API access to actual token counts from within skill execution
- Estimation must run in Bash 3.2 (macOS default) with `jq`
- Must add negligible overhead (< 10ms per call)
- Must err on the side of overestimation (triggering adaptive mode early is safer than triggering late)
- Must be backward compatible with pre-032 state files

---

## Decision

We will use a **character-count-based heuristic** to estimate token consumption, implemented as `aod_state_estimate_tokens` in `.aod/scripts/bash/run-state.sh`.

The formula:

```
estimated_tokens = (character_count * 3) / 8
```

This is equivalent to approximately 1 token per 2.67 characters, which represents the `chars/4` baseline (the commonly cited ~4 chars/token average for English text) multiplied by a **1.5x safety multiplier**. The safety multiplier accounts for:
- Tool call framing overhead (~10%)
- Unmeasured system prompt contributions (~15%)
- General safety margin (~25%)

The estimation is performed using integer arithmetic only (no floating point), ensuring Bash 3.2 compatibility.

Budget tracking is stored in a `token_budget` object within `run-state.json`:
- `usable_budget`: 120,000 tokens (60% of 200K window, reserving 40% for untracked consumption)
- `threshold_percent`: 80% (adaptive mode activates when estimated total reaches 80% of usable budget, i.e., ~96K estimated tokens)
- `adaptive_mode`: Boolean flag toggled when threshold is crossed

When adaptive mode activates, the orchestrator:
1. Skips non-essential reference file loads (entry-modes.md after initial routing, dry-run.md, error-recovery.md)
2. Never skips must-load files (governance.md at governance gates)
3. Displays an `[adaptive]` indicator in the stage map
4. Recommends session resume when estimated budget is insufficient for the next stage

---

## Rationale

**Reasons**:
1. **Only viable approach**: Without API-level token count access, character-based heuristics are the only option available within the skill execution environment.
2. **Intentional overestimation**: The 1.5x safety multiplier ensures adaptive mode triggers conservatively. False positives (unnecessary adaptive mode) are harmless -- the orchestrator skips optional content. False negatives (missing the threshold) risk context overflow.
3. **Zero additional dependencies**: Uses only `wc -c` and shell arithmetic. No new tools or libraries required.
4. **Integer arithmetic**: `(chars * 3) / 8` avoids floating-point operations, which are not reliably available in Bash 3.2 without `bc` or `awk`.
5. **Configurable threshold**: The 80% threshold and 120K usable budget are stored in the state file and can be tuned per-project without code changes.
6. **Additive and backward compatible**: The `token_budget` object is optional. All 4 new functions check for its existence and degrade gracefully (return defaults) when it is absent.

---

## Alternatives Considered

### Alternative 1: No Estimation (Status Quo)

**Pros**:
- Zero implementation effort
- No risk of inaccurate estimates

**Cons**:
- No visibility into context consumption
- Context overflows are undetectable until they happen
- No ability to make adaptive loading decisions

**Why Not Chosen**: Feature 030 demonstrated that context is a finite, valuable resource. Operating blind on consumption is not sustainable as orchestration complexity grows.

### Alternative 2: Exact Token Counting via External Tokenizer

**Pros**:
- Accurate token counts
- No need for safety multipliers

**Cons**:
- Requires a tokenizer binary (tiktoken, cl100k_base) as a new dependency
- Tokenizer must be installed on user machines (violates local-first simplicity)
- Tokenizer model may not match the actual model used by Claude
- Significant latency compared to character counting

**Why Not Chosen**: Adds a non-trivial dependency for marginal accuracy improvement. The heuristic with safety multiplier provides sufficient accuracy for stage-level budget decisions.

### Alternative 3: Character-Based Estimation Without Safety Multiplier

**Pros**:
- Simpler formula (chars / 4)
- Closer to "true" average token size

**Cons**:
- Underestimates actual consumption due to untracked overhead (system prompts, tool framing)
- Adaptive mode triggers too late, potentially after context degradation has begun

**Why Not Chosen**: Underestimation is the dangerous direction for a budget tracker. The 1.5x multiplier costs nothing in false-positive scenarios (adaptive mode is non-destructive) but prevents costly false negatives.

### Alternative 4: Per-Reference-File-Load Budget Updates

**Pros**:
- Higher granularity; budget reflects intra-stage consumption in real time

**Cons**:
- Approximately doubles state file I/O (one write per reference load instead of per stage boundary)
- Reference file loads already take ~100ms; adding a state write doubles the overhead
- Stage-boundary granularity is sufficient for the primary use case (deciding whether to start the next stage)

**Why Not Chosen**: Checkpoint batching at stage boundaries provides the right granularity/overhead trade-off. Intra-stage precision does not change the stage-level decisions the orchestrator makes.

---

## Consequences

### Positive
- Orchestrator has running visibility into estimated context consumption
- Adaptive mode prevents context overflow by reducing non-essential loads
- Proactive resume recommendations let users save progress before degradation
- Token budget data (stage_estimates, prior_sessions) provides post-run analysis capability
- All changes are backward compatible; pre-032 state files work without modification

### Negative
- Estimates are inherently imprecise; actual token counts may differ by 20-40%
- Safety multiplier may trigger adaptive mode prematurely in short runs
- `prior_sessions` array grows over time (mitigated by keeping only last 3 entries)
- Four new functions increase `run-state.sh` surface area

### Mitigation
- Threshold and usable_budget are configurable in the state file for per-project tuning
- Adaptive mode only skips files classified as "Skippable" -- must-load files are never affected
- `prior_sessions` pruning to last 3 entries prevents unbounded growth
- All new functions follow established patterns (compound helpers, graceful field-existence checks)

---

## Related Decisions

- ADR-001: Atomic State Persistence (token_budget writes use the same write-then-rename pattern)
- ADR-002: Prompt Segmentation (created the reference file classification that adaptive mode acts on)
- Bash 3.2 compatibility constraint (integer arithmetic requirement, see KB Entry 6)

---

## References

- `.aod/scripts/bash/run-state.sh` -- Implementation (functions: `aod_state_estimate_tokens`, `aod_state_update_budget`, `aod_state_get_budget_summary`, `aod_state_check_adaptive`)
- `.claude/skills/~aod-run/SKILL.md` -- Orchestrator skill (stage map display, checkpoint logic, adaptive mode)
- `specs/032-real-time-token/plan.md` -- Feature 032 implementation plan
- `specs/032-real-time-token/spec.md` -- Feature 032 specification
