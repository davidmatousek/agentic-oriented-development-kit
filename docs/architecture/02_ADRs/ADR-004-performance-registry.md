# ADR-004: Performance Registry for Self-Calibrating Budget Tracking

**Status**: Accepted
**Date**: 2026-02-12
**Decision Maker**: Architect
**Feature**: 042-self-calibrating-governance

## Context

The budget tracking system introduced in Feature 032 (ADR-003) uses hardcoded defaults that do not reflect real-world performance:

- **Hardcoded usable_budget**: 120,000 tokens (orchestrated) / 60,000 tokens (standalone)
- **Hardcoded per-stage estimates**: 5,000 tokens for all stages
- **Hardcoded safety multiplier**: 1.5x

Empirical data from completed features shows these defaults are inaccurate:
- Feature 034 (cross-session-budget-history): 106,000 total estimated tokens across 2 sessions
- Feature 038 (universal-session-budget-tracking): 117,000 total estimated tokens across 3 sessions
- Actual per-stage consumption varies significantly: define/plan stages consume 15,000-20,000 tokens, while discover/deliver stages consume 8,000-13,000 tokens

**The Open Feedback Loop**: Budget tracking captures actual consumption data (pre/post estimates per stage) but never feeds this data back to improve future estimates. Each new feature starts with the same hardcoded defaults, ignoring accumulated historical performance.

**Impact of Inaccurate Estimates**:
1. **Resume recommendations fire at wrong times**: With 5,000 default stage estimates, the system recommends pausing when 15,000 tokens remain, but stages actually cost 15,000-20,000 tokens
2. **Wasted sessions**: Users pause too early or too late based on inaccurate projections
3. **Poor planning confidence**: Orchestrator cannot reliably predict whether remaining budget is sufficient for upcoming stages

The estimation gap (actual/estimated ratio of ~2.5x as documented in spec SC-007) persists indefinitely without calibration.

## Decision

We will implement a file-based **Performance Registry** to close the feedback loop between budget tracking (capture) and budget estimation (consumption).

### Implementation Approach

1. **Registry Location**: `.aod/memory/performance-registry.json`
   - Follows local-first principle (no external dependencies)
   - Colocated with other memory files (constitution.md)

2. **Shell Library**: `.aod/scripts/bash/performance-registry.sh` with 5 functions:
   - `aod_registry_exists` - Check if registry file exists
   - `aod_registry_read` - Read full registry JSON
   - `aod_registry_get_default` - Read single value with dot-path, fallback on error
   - `aod_registry_append_feature` - Extract from run-state, append to features[]
   - `aod_registry_recalculate` - Recompute calibrated_defaults from features[]

3. **Recency-Windowed Approach**: Maximum 5 features in `features[]` array with FIFO rotation
   - Recent features are more predictive than old features
   - Bounded storage prevents unbounded growth
   - 5 features provides sufficient sample size while remaining responsive to workflow changes

4. **Auto-Population**: Registry is populated automatically during `/aod.deliver` when `run-state.json` contains `token_budget` data with at least one stage having `post > 0`
   - No manual intervention required
   - Calibration improves passively with each feature delivery

5. **Non-Fatal Failure Mode**: All consumers fall back to hardcoded defaults on any failure
   - Registry corruption returns fallback values silently
   - Missing jq returns fallback values
   - Missing registry file returns fallback values
   - No blocking errors in critical paths

6. **Integer Arithmetic**: Recalculation uses integer operations only per ADR-003 Bash 3.2 compatibility constraint
   - Formula: `(sum * 1) / count` with floor rounding
   - No floating-point operations in shell

7. **Seed Data**: Registry ships pre-populated with data from Features 034 and 038 to mitigate cold start

### Registry Schema (v1.0)

```json
{
  "version": "1.0",
  "updated_at": "ISO-8601 timestamp",
  "calibrated_defaults": {
    "usable_budget": 60000,
    "safety_multiplier": 1.5,
    "per_stage_estimates": {
      "discover": 10000,
      "define": 20000,
      "plan": 20000,
      "build": 13000,
      "deliver": 11500
    }
  },
  "features": [
    {
      "feature_id": "034",
      "feature_name": "cross-session-budget-history",
      "completed_at": "2026-02-12T03:30:00Z",
      "session_count": 2,
      "total_estimated_tokens": 106000,
      "stage_actuals": { ... }
    }
  ]
}
```

## Alternatives Considered

### Alternative 1: Auto-Tuning Thresholds in Real-Time

**Description**: Dynamically adjust estimates during a single orchestration run based on observed consumption.

**Pros**:
- Immediate adaptation
- No persistent storage required

**Cons**:
- Unpredictable behavior within a session
- Insufficient data points (single run) for reliable calibration
- Creates non-deterministic orchestrator behavior
- Hard to debug when estimates change mid-run

**Why Not Chosen**: Real-time auto-tuning introduces complexity and unpredictability. Cross-feature calibration provides stable, predictable estimates based on sufficient data.

### Alternative 2: Database-Backed Registry

**Description**: Store performance data in SQLite or similar embedded database.

**Pros**:
- Structured queries
- Built-in data integrity
- Scalable to large datasets

**Cons**:
- Violates local-first principle (adds sqlite dependency)
- Overkill for 5-feature window
- Complicates deployment and portability
- Shell integration requires additional tooling

**Why Not Chosen**: JSON file with jq provides sufficient capability for the bounded dataset. Adding a database introduces unnecessary dependency for a 5-entry cache.

### Alternative 3: Per-Session Auto-Adjustment

**Description**: Adjust estimates after each session based on that session's performance.

**Pros**:
- Faster calibration feedback
- Session-level granularity

**Cons**:
- Single session provides noisy data
- Session boundaries are arbitrary (user-driven)
- Multi-session features would over-weight individual sessions
- Estimate oscillation between sessions

**Why Not Chosen**: Feature delivery is the natural calibration boundary. A complete feature provides stable, representative data across all stages. Session-level adjustment would create noisy, unstable estimates.

### Alternative 4: No Calibration (Keep Hardcoded Defaults)

**Description**: Accept the current hardcoded defaults as "good enough."

**Pros**:
- Zero implementation effort
- No new failure modes
- Simplicity

**Cons**:
- Perpetuates inaccurate estimates indefinitely
- Resume recommendations remain unreliable
- Estimation gap (~2.5x) never closes
- Wastes the data already being captured

**Why Not Chosen**: Feature 032/034/038 built a complete budget tracking infrastructure. Leaving the feedback loop open wastes this investment and perpetuates poor user experience with resume recommendations.

## Consequences

### Positive

1. **Calibration improves with each feature delivery**: Every completed feature contributes to more accurate estimates for future features
2. **Cold start mitigated**: Seed data from Features 034 and 038 provides reasonable defaults from first use
3. **Non-fatal failures preserve existing behavior**: Registry problems never block orchestration; fallback to hardcoded defaults maintains backward compatibility
4. **Transparent feedback in delivery reports**: Users see "Performance Registry Updated" section showing calibration effect
5. **Resume recommendations become reliable**: Calibrated per-stage estimates (10K-20K) replace inaccurate defaults (5K)
6. **Estimation gap closes over time**: As calibration accumulates, actual/estimated ratio should decrease from ~2.5x toward 1.5x
7. **Zero manual intervention**: Calibration is fully automatic via `/aod.deliver` integration

### Negative

1. **5-feature cap may miss patterns in very large projects**: Projects with many features may have early features rotated out before patterns stabilize
2. **Single-person workflow data may not generalize to teams**: Registry calibrated by one developer may not reflect another developer's consumption patterns
3. **Integer arithmetic limits precision**: Per-stage estimates rounded to nearest integer may lose precision for very small values
4. **jq dependency**: Registry operations require jq; systems without jq receive fallback behavior
5. **FIFO rotation loses historical context**: Oldest features are discarded, potentially losing valuable outlier data

### Mitigation

- 5-feature window can be increased in future versions if needed (schema versioned)
- Team environments can seed registry with team-representative data
- Integer precision is sufficient for 4-5 digit token counts (5,000-100,000 range)
- jq is already required by run-state.sh; no new dependency introduced
- Outlier data (very large or very small features) is intentionally dampened by averaging

## References

- PRD: `docs/product/02_PRD/042-self-calibrating-governance-performance-registry-2026-02-12.md`
- Spec: `specs/042-self-calibrating-governance/spec.md`
- ADR-003: `docs/architecture/02_ADRs/ADR-003-heuristic-token-estimation.md`
- run-state.sh: `.aod/scripts/bash/run-state.sh`
