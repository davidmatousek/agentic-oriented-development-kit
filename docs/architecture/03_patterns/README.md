# Design Patterns - {{PROJECT_NAME}}

**Last Updated**: {{CURRENT_DATE}}
**Owner**: Architect

---

## Overview

This directory documents reusable design patterns for {{PROJECT_NAME}}.

---

## Pattern Categories

### API Patterns
- Request/response patterns
- Error handling
- Authentication/authorization
- Rate limiting
- Pagination

### Database Patterns
- Query optimization
- Indexing strategies
- Migration patterns
- Concurrency control
- Caching strategies

### Frontend Patterns
- Component composition
- State management
- Data fetching
- Error boundaries
- Performance optimization

### Testing Patterns
- Unit test structure
- Integration test patterns
- E2E test patterns
- Mocking strategies

### Shell Script Patterns (AOD Kit)
- [Atomic File Write (Write-Then-Rename)](#pattern-atomic-file-write)
- [Function Library Sourcing](#pattern-function-library-sourcing)
- [Graceful CLI Degradation](#pattern-graceful-cli-degradation)
- [Additive Optional State Fields](#pattern-additive-optional-state-fields)

### Skill Patterns (AOD Kit)
- [On-Demand Reference File Segmentation](#pattern-on-demand-reference-file-segmentation)
- [Compound State Helpers](#pattern-compound-state-helpers)
- [Governance Result Caching](#pattern-governance-result-caching)
- [Read-Only Dry-Run Preview](#pattern-read-only-dry-run-preview)

### Command Patterns (AOD Kit)
- [Orchestrator-Awareness Guard](#pattern-orchestrator-awareness-guard)
- [Non-Fatal Budget Wrapper](#pattern-non-fatal-budget-wrapper)

---

## Documented Patterns

### Pattern: Atomic File Write

**Added**: Feature 022 (Full Lifecycle Orchestrator)
**ADR**: [ADR-001](../02_ADRs/ADR-001-atomic-state-persistence.md)

#### Problem
Writing JSON state to disk risks corruption if the process crashes mid-write. Readers may see partial JSON, breaking the orchestrator's ability to resume.

#### Solution
Write to a temporary file first, then atomically rename it to the target path. On POSIX systems, `mv` within the same filesystem is atomic.

#### Example
```bash
# From .aod/scripts/bash/run-state.sh
AOD_STATE_FILE=".aod/run-state.json"
AOD_STATE_TMP=".aod/run-state.json.tmp"

aod_state_write() {
    local json="$1"
    # Validate JSON before writing
    echo "$json" | jq . > "$AOD_STATE_TMP" || { rm -f "$AOD_STATE_TMP"; return 1; }
    # Atomic rename
    mv "$AOD_STATE_TMP" "$AOD_STATE_FILE"
}
```

#### When to Use
- Writing state/config files that must survive crashes
- Any file where partial writes would corrupt consumers
- Single-writer scenarios (no concurrent access needed)

#### When NOT to Use
- Multi-writer concurrent scenarios (use file locking or a database)
- Append-only logs (just append, no need for atomicity on the whole file)

---

### Pattern: Function Library Sourcing

**Added**: Pre-Feature 022, documented during Feature 022

#### Problem
Bash scripts that define functions are invoked as standalone executables (`bash script.sh arg`), but the functions are never called -- only defined.

#### Solution
Source the library file before calling its functions. Use `bash -c 'source lib.sh && function_name args'`.

#### Example
```bash
# CORRECT: source then call
bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_read'
bash -c 'source .aod/scripts/bash/github-lifecycle.sh && aod_gh_update_stage 22 plan'

# WRONG: functions defined but never called
bash .aod/scripts/bash/run-state.sh aod_state_read
```

**Exception**: `backlog-regenerate.sh` is a standalone script (not a function library):
```bash
bash .aod/scripts/bash/backlog-regenerate.sh
```

#### When to Use
- All `.aod/scripts/bash/*.sh` function libraries
- Any Bash file that exports functions rather than running a main block

#### When NOT to Use
- Standalone scripts with a `main` block or top-level logic

---

### Pattern: Graceful CLI Degradation

**Added**: Feature 022 (Full Lifecycle Orchestrator)

#### Problem
The orchestrator depends on `gh` CLI for GitHub Issue label management, but `gh` may not be installed, authenticated, or the network may be unavailable. Hard-failing would block the entire lifecycle.

#### Solution
Check CLI availability before use, and fall back to artifact-only detection when the CLI is unavailable. Non-critical operations (label updates, backlog refresh) are fire-and-forget.

#### Example
```bash
# Check availability, skip silently if missing
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    gh issue view "$NNN" --json labels
else
    echo "GitHub CLI unavailable. Falling back to artifact-only detection."
    # Infer stage from on-disk artifacts instead
fi

# Fire-and-forget for non-critical operations
bash .aod/scripts/bash/backlog-regenerate.sh 2>/dev/null || true
```

#### When to Use
- External CLI tools that may not be installed (gh, jq, docker)
- Network-dependent operations where offline mode should still work
- Non-critical side effects (label updates, notifications)

#### When NOT to Use
- Core dependencies that the feature cannot function without (e.g., `jq` for JSON state)

---

### Pattern: Additive Optional State Fields

**Added**: Feature 032 (Real-time Token Budget Tracking)
**ADR**: [ADR-003](../02_ADRs/ADR-003-heuristic-token-estimation.md)

#### Problem
New features need to extend the orchestrator state file (`run-state.json`) with additional data objects (e.g., `governance_cache` in Feature 030, `token_budget` in Feature 032). However, existing state files created by earlier features do not contain these new fields. Requiring a schema migration or version bump would break backward compatibility and force users to recreate state files.

#### Solution
Every function that reads a new state field checks whether that field exists before accessing it. If the field is absent, the function returns a safe default value and exits cleanly (return 0). Functions that write to a new field first check for the parent object's existence and skip the write if it is absent. This makes the new state object purely opt-in: it is created only when a new orchestration is initialized with the feature enabled.

The key rules:
1. **Read functions**: Check for field existence; return a default if absent
2. **Write functions**: Check for parent object existence; return 0 (success) if absent
3. **Initialization**: New state object is included in the initial state template for new runs
4. **No migration**: Existing state files from prior features continue to work without modification

#### Example
```bash
# From .aod/scripts/bash/run-state.sh (Feature 032)

aod_state_update_budget() {
    # ... (args: stage, checkpoint, tokens)
    local state
    state=$(aod_state_read) || return 1

    # Check if token_budget exists; skip gracefully if absent (backward compat)
    local has_budget
    has_budget=$(echo "$state" | jq -r 'if .token_budget then "yes" else "no" end')
    if [[ "$has_budget" != "yes" ]]; then
        return 0  # Pre-032 state file — no budget tracking, no error
    fi

    # Proceed with update only if the field exists
    state=$(echo "$state" | jq --argjson tok "$tokens" \
        '.token_budget.estimated_total = (.token_budget.estimated_total + $tok)')
    aod_state_write "$state"
}

aod_state_get_budget_summary() {
    # Returns defaults when token_budget is absent
    echo "$state" | jq -r '
        if .token_budget then
            [(.token_budget.estimated_total // 0),
             (.token_budget.usable_budget // 120000),
             (.token_budget.threshold_percent // 80),
             (.token_budget.adaptive_mode // false)] | map(tostring) | join("|")
        else
            "0|120000|80|false"
        end'
}
```

#### When to Use
- Adding new top-level objects to a shared JSON state file across feature releases
- Any schema extension where existing consumers must not break
- When a feature is opt-in and should not require manual state file migration
- State files managed by multiple features at different version levels

#### When NOT to Use
- Breaking changes where the old schema is fundamentally incompatible (use schema version bump)
- Fields that are required for core functionality (missing field = hard failure is correct behavior)
- When the number of optional fields grows large enough to warrant a formal migration system

#### Related Patterns
- [Atomic File Write](#pattern-atomic-file-write) -- all state writes (including optional field updates) use write-then-rename
- [Compound State Helpers](#pattern-compound-state-helpers) -- budget summary helpers follow the same pipe-delimited extraction approach
- [Governance Result Caching](#pattern-governance-result-caching) -- `governance_cache` was the first use of this pattern (Feature 030)

---

### Pattern: On-Demand Reference File Segmentation

**Added**: Feature 030 (Context Efficiency of /aod.run)
**ADR**: [ADR-002](../02_ADRs/ADR-002-prompt-segmentation.md)

#### Problem
A monolithic SKILL.md file loads its entire content into the agent's context window at invocation, even when large sections are only needed conditionally (e.g., governance rules at stage boundaries, error recovery on failure). This wastes context tokens that could be used for implementation work.

#### Solution
Split the monolithic skill file into a compact core (~400-500 lines) containing the always-needed execution loop, plus co-located reference files loaded via the Read tool only when their content is needed. Each branch point in the core file includes a MANDATORY Read instruction that loads the relevant reference file before proceeding.

A Navigation table in the core file maps every conditionally-needed section to its reference file, making the structure discoverable.

#### Example
```
# Directory structure
.claude/skills/~aod-run/
  SKILL.md                     # Core loop (~405 lines, always loaded)
  references/
    governance.md              # Loaded at governance gates
    entry-modes.md             # Loaded once per entry mode
    dry-run.md                 # Loaded only with --dry-run
    error-recovery.md          # Loaded on error/completion

# In SKILL.md — branch point with MANDATORY Read instruction
**MANDATORY**: You MUST use the Read tool to load `references/governance.md`
before proceeding with governance gate detection. Do NOT rely on memory of
prior governance content. If the file cannot be read, display an error and STOP.
```

#### When to Use
- Skill files exceeding ~500 lines where content divides into always-needed vs. conditionally-needed
- Skills with distinct operational modes (e.g., normal vs. dry-run vs. error recovery)
- When context window pressure limits the agent's ability to perform downstream work

#### When NOT to Use
- Skills under ~500 lines where the entire content is routinely needed
- Content that is heavily cross-referenced (splitting creates circular Read dependencies)
- When Read tool latency is unacceptable for the use case

#### Related Patterns
- [Compound State Helpers](#pattern-compound-state-helpers) -- reduces state read tokens within the segmented core
- [Governance Result Caching](#pattern-governance-result-caching) -- reduces how often governance.md needs to be loaded

---

### Pattern: Compound State Helpers

**Added**: Feature 030 (Context Efficiency of /aod.run)

#### Problem
Reading the full JSON state file into context at every loop iteration consumes ~315 tokens per read. In a lifecycle with ~15 state reads before the Build stage, this totals ~4,725 tokens for state management alone. Most reads only need 2-3 fields.

#### Solution
Provide compound Bash helper functions that read the JSON once internally, extract multiple fields via a single `jq` query, and return only a pipe-delimited string of the extracted values. The full JSON never enters the agent's context.

#### Example
```bash
# From .aod/scripts/bash/run-state.sh

# Generic multi-field extraction
# Returns: "plan|spec|standard"
aod_state_get_multi ".current_stage" ".current_substage" ".governance_tier"

# Purpose-specific helper for the Core Loop
# Returns: "plan|spec|in_progress"
aod_state_get_loop_context

# Usage in the orchestrator Core Loop (step 1):
# Instead of: state=$(aod_state_read)  → ~315 tokens
# Use:        context=$(aod_state_get_loop_context)  → ~5 tokens
```

#### When to Use
- State files read repeatedly in a loop where only a few fields are needed per iteration
- Any scenario where the full state is large but the consumer needs a small subset
- When cumulative token savings across multiple reads justify adding helper functions

#### When NOT to Use
- One-time reads where the full state is needed (initialization, validation)
- State files small enough that full reads are negligible (~50 tokens or less)

#### Related Patterns
- [Atomic File Write](#pattern-atomic-file-write) -- compound helpers use the same atomic read/write infrastructure
- [On-Demand Reference File Segmentation](#pattern-on-demand-reference-file-segmentation) -- both patterns reduce context consumption

---

### Pattern: Governance Result Caching

**Added**: Feature 030 (Context Efficiency of /aod.run)

#### Problem
Checking governance approval status requires reading full artifact files (spec.md, plan.md, tasks.md) and parsing their YAML frontmatter. Each artifact read consumes ~500 tokens. Governance is checked at stage boundaries and during resume validation, leading to ~3,000 tokens of redundant reads when verdicts have not changed.

#### Solution
Cache governance verdicts (status, date, summary) in the state file under a `governance_cache` object, keyed by artifact and reviewer. On subsequent governance checks, read the cached verdict (~11 tokens) instead of re-reading the artifact (~500 tokens). Invalidate the cache when an artifact is regenerated after a CHANGES_REQUESTED verdict.

#### Example
```bash
# From .aod/scripts/bash/run-state.sh

# Cache a verdict after a governance review completes
aod_state_cache_governance "spec" "pm" "APPROVED" "PM approved spec"

# Check cache before reading artifact (returns "APPROVED|2026-02-11|summary" or "null")
aod_state_get_governance_cache "spec" "pm"

# Invalidate cache when artifact is regenerated
aod_state_clear_governance_cache "spec"
```

```json
{
  "governance_cache": {
    "spec": {
      "pm": {
        "status": "APPROVED",
        "date": "2026-02-11T14:30:00Z",
        "summary": "PM approved spec"
      }
    }
  }
}
```

#### When to Use
- Governance or approval checks that are read frequently but change rarely
- Any expensive read operation whose result is deterministic until the source is modified
- Multi-gate workflows where the same verdict is checked at multiple points

#### When NOT to Use
- When the source artifact changes frequently (cache churn exceeds read savings)
- When governance rules require always-fresh reads (e.g., compliance audits)
- Single-check scenarios where caching adds complexity without savings

#### Related Patterns
- [On-Demand Reference File Segmentation](#pattern-on-demand-reference-file-segmentation) -- cache hits avoid loading governance.md entirely
- [Compound State Helpers](#pattern-compound-state-helpers) -- cache reads use the same incremental extraction approach

---

### Pattern: Read-Only Dry-Run Preview

**Added**: Feature 027 (Orchestrator Dry-Run Mode)

#### Problem
Skills and commands that perform multi-step mutations (writing state files, creating branches, updating GitHub labels, invoking sub-skills) are difficult to reason about before execution. Users cannot predict what the orchestrator will do -- which stages will execute, which will be skipped, and what governance gates will trigger -- without actually running it and potentially creating irreversible side effects.

#### Solution
Add a `--dry-run` flag that reuses the existing detection and classification logic but suppresses all write operations. The pattern has four phases:

1. **Detect**: Run the same read-only detection steps as the normal mode (read state files, query GitHub, scan artifacts on disk)
2. **Classify**: Build the planned execution sequence, governance gate predictions, and artifact predictions using the detected state
3. **Display**: Render a structured preview showing what would happen for each stage
4. **Exit**: Stop immediately without entering the execution loop

The key insight is that detection logic is already separated from mutation logic in well-structured skills. Dry-run reuses detection verbatim and replaces mutation with display.

#### Example
```
# Skill routing (pseudocode from SKILL.md)
if DryRun == true:
    # Phase 1: Detect (reuse existing detection steps, read-only)
    run_detection_phase(mode, suppress_writes=true)

    # Phase 2: Classify
    execution_plan = classify_stages(detected_state)
    gate_predictions = predict_governance_gates(execution_plan, tier)
    artifact_predictions = predict_artifacts(execution_plan, feature_id)

    # Phase 3: Display
    render_preview(execution_plan, gate_predictions, artifact_predictions)

    # Phase 4: Exit -- do NOT enter Core Loop
    EXIT
```

Mutations explicitly suppressed during dry-run:
- No state file writes (`.aod/run-state.json`)
- No git branch creation or switching
- No GitHub label updates
- No sub-skill invocations
- No backlog regeneration

#### When to Use
- Commands or skills with multi-step side effects where users need confidence before committing
- Orchestrators that chain multiple sub-commands with governance gates
- Any workflow where the execution plan depends on detected state (existing artifacts, labels, prior progress)

#### When NOT to Use
- Simple commands with a single, obvious action (e.g., "read this file")
- Commands that are already read-only (e.g., `--status`)
- When the detection phase itself has significant side effects that cannot be separated from mutations

#### Related Patterns
- [Graceful CLI Degradation](#pattern-graceful-cli-degradation) -- dry-run inherits the same `gh` fallback behavior during detection

---

### Pattern: Orchestrator-Awareness Guard

**Added**: Feature 038 (Universal Session Budget Tracking)

#### Problem
Standalone lifecycle commands (`/aod.define`, `/aod.spec`, etc.) need to track their own session budget by writing pre/post estimates to `.aod/run-state.json`. However, the orchestrator (`/aod.run`) already manages budget tracking when it invokes these same commands as sub-stages. If a standalone command writes budget entries while an active orchestrator is managing the state file, the two writers conflict -- double-counting token estimates and potentially corrupting orchestrator loop context.

#### Solution
Before performing any budget writes, each standalone command checks whether an active orchestrator owns the state file. The detection uses an implicit heuristic: read the `updated_at` timestamp and current stage status from the state file; if any stage is `in_progress` AND `updated_at` is within 5 minutes of the current time, an orchestrator is presumed active. In that case, the command skips all budget tracking and defers to the orchestrator.

This avoids introducing new flags or environment variables. The 5-minute window is chosen because orchestrator loop iterations typically complete within seconds; a stale `updated_at` beyond 5 minutes indicates an abandoned or crashed orchestration rather than an active one.

The key rules:
1. **Check state existence**: If no state file exists, create one (standalone initialization)
2. **Check orchestrator recency**: Read `updated_at` and stage status; skip if active
3. **Validate feature ID**: Compare branch-derived feature ID against state's `feature_id`; prompt user on mismatch
4. **Proceed or skip**: Write budget estimates only in standalone mode

#### Example
```
# From .claude/commands/aod.define.md (Step 0b)

1. Check state file:
   bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_exists && echo "exists" || echo "none"'
   - "none" -> create state (step 3)
   - "exists" -> check orchestrator (step 2)

2. Detect active orchestrator:
   aod_state_get_loop_context  -> "plan|spec|in_progress"
   aod_state_get ".updated_at" -> "2026-02-12T10:05:00Z"
   - If stage is in_progress AND updated_at < 5 min ago -> SKIP budget tracking
   - Otherwise -> standalone mode, continue

3. Create state file (standalone only):
   aod_state_init "{feature_id}" "{feature_name}" "Entity 1"

4. Write pre-estimate:
   aod_state_update_budget "{stage}" "pre" "5000"
```

#### When to Use
- Commands that can run both standalone and as sub-stages of an orchestrator
- Any writer that shares a state file with a long-running coordinator process
- Scenarios where an implicit ownership heuristic (recency) is sufficient

#### When NOT to Use
- Commands that are always standalone (no orchestrator coordination)
- When explicit ownership (lock files, PID checks) is required for correctness
- High-frequency concurrent writers where a 5-minute heuristic is too coarse

#### Related Patterns
- [Additive Optional State Fields](#pattern-additive-optional-state-fields) -- budget fields follow the same backward-compatible schema extension
- [Graceful CLI Degradation](#pattern-graceful-cli-degradation) -- budget operations degrade gracefully (non-fatal) similar to CLI fallbacks
- [Compound State Helpers](#pattern-compound-state-helpers) -- `aod_state_get_loop_context` used for orchestrator detection

---

### Pattern: Non-Fatal Budget Wrapper

**Added**: Feature 038 (Universal Session Budget Tracking)

#### Problem
Budget tracking is a secondary concern -- it must never block the primary skill execution. However, the budget initialization sequence involves multiple steps (state existence check, orchestrator detection, feature ID validation, state creation, budget write) that can each fail for various reasons (missing `jq`, corrupted state file, permission errors). Wrapping every individual call in error handling is verbose and error-prone.

#### Solution
Encapsulate the entire budget initialization sequence (pre-estimate) and the completion sequence (post-estimate + utilization display) in clearly demarcated "Non-Fatal" blocks. Every shell command within these blocks uses `|| true` or equivalent error suppression. The block boundary is documented in the command file with an explicit contract: "If any step fails, log the error and continue -- budget tracking is non-fatal."

The completion block follows the same pattern: write post-estimate, read budget summary, calculate utilization percentage, and append to output. If any step fails, the budget line is simply omitted from the completion message.

#### Example
```
# Pre-execution block (from command files, Step 0b/1b)
## Budget Tracking (Non-Fatal)
1. Check state file ...
2. Detect active orchestrator ...
3. Create state file ...
4. Write pre-estimate: aod_state_update_budget "define" "pre" "5000"
If any step fails, log the error and continue to Step 1.

# Post-execution block (from command files, completion section)
### Budget Tracking (Non-Fatal)
1. Write post-estimate:
   bash -c '... && aod_state_update_budget "define" "post" "5000" || true'
2. Read summary:
   bash -c '... && aod_state_get_budget_summary || echo "0|0|0|false"'
3. Calculate utilization = (estimated_total * 100) / usable_budget
4. If estimated_total > 0, append: (~N% budget used)
5. If any step fails, omit the budget line.
```

#### When to Use
- Secondary telemetry or observability features that must not impact primary functionality
- Operations where partial success is acceptable (some budget data is better than none)
- Features added to existing stable commands where failure isolation is critical

#### When NOT to Use
- Core functionality where failures must be surfaced and handled
- Operations where partial state is worse than no state (use transactions instead)
- When error details are needed for debugging (non-fatal suppresses error context)

#### Related Patterns
- [Orchestrator-Awareness Guard](#pattern-orchestrator-awareness-guard) -- the non-fatal wrapper contains the orchestrator guard as one of its steps
- [Graceful CLI Degradation](#pattern-graceful-cli-degradation) -- both patterns prioritize continued operation over error reporting
- [Additive Optional State Fields](#pattern-additive-optional-state-fields) -- budget read/write functions already handle missing fields gracefully

---

## Pattern Template

```markdown
# Pattern: [Pattern Name]

## Problem
[What problem does this pattern solve?]

## Solution
[How does the pattern solve it?]

## Example
```[language]
[Code example]
```

## When to Use
- [Scenario 1]
- [Scenario 2]

## When NOT to Use
- [Anti-pattern scenario]

## Related Patterns
- [Link to related patterns]
```

---

**Template Instructions**: Create pattern documents as you establish conventions. Organize by category (api-patterns/, db-patterns/, etc.).
