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
- [Append-Only Logging with Graceful Failure](#pattern-append-only-logging)
- [Circuit-Breaker Churn Detection](#pattern-circuit-breaker-churn-detection)
- [Subshell Isolation for Strict Shell Options](#pattern-subshell-isolation-for-strict-shell-options)
- [`set +e` / `set -e` Bracket for rc-Capture Under Strict Shell](#pattern-set-e-bracket-for-rc-capture-under-strict-shell)
- [Directory Allow-List with CI Snapshot Coverage](#pattern-directory-allow-list-with-ci-snapshot-coverage)

### Template Patterns (AOD Kit)
- [Template Variable Expansion](#pattern-template-variable-expansion)

### Skill Patterns (AOD Kit)
- [On-Demand Reference File Segmentation](#pattern-on-demand-reference-file-segmentation)
- [Compound State Helpers](#pattern-compound-state-helpers)
- [Governance Result Caching](#pattern-governance-result-caching)
- [Read-Only Dry-Run Preview](#pattern-read-only-dry-run-preview)
- [Dual-Surface Injection](#pattern-dual-surface-injection)
- [Minimal-Return Subagent](#pattern-minimal-return-subagent)
- [Governed Skill Phase Loop](#pattern-governed-skill-phase-loop)
- [Anti-Rationalization Tables — Behavioral Primer for Agent-Loaded Files](#pattern-anti-rationalization-tables-behavioral-primer)

### Command Patterns (AOD Kit)
- [Orchestrator-Awareness Guard](#pattern-orchestrator-awareness-guard)
- [Non-Fatal Observability Wrapper](#pattern-non-fatal-observability-wrapper)
- [Built-in Skill Invocation from a Command](#pattern-built-in-skill-invocation-from-a-command)
- [Deterministic Authorization (No LLM in Authorization Path)](#pattern-deterministic-authorization)
- [Three-Channel Halt Protocol](#pattern-three-channel-halt-protocol)

### Design System Patterns (AOD Kit)
- [Layered Design Context Discovery](#pattern-layered-design-context-discovery)
- [Brand Identity Override](#pattern-brand-identity-override)
- [Grep-Based Build Quality Gate](#pattern-grep-based-build-quality-gate)

### Stack Pack Architecture Patterns (AOD Kit)
- [Two-Level Architecture (Build-Time / Run-Time)](#pattern-two-level-architecture)
- [Convention Contract (STACK.md)](#pattern-convention-contract)
- [Declarative Test Contract with Stable Exit-Code Taxonomy](#pattern-declarative-test-contract)

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

**Added**: Feature 030 (Context Efficiency of /aod.run)

#### Problem
New features need to extend the orchestrator state file (`run-state.json`) with additional data objects (e.g., `governance_cache` in Feature 030). However, existing state files created by earlier features do not contain these new fields. Requiring a schema migration or version bump would break backward compatibility and force users to recreate state files.

#### Solution
Every function that reads a new state field checks whether that field exists before accessing it. If the field is absent, the function returns a safe default value and exits cleanly (return 0). Functions that write to a new field first check for the parent object's existence and skip the write if it is absent. This makes the new state object purely opt-in: it is created only when a new orchestration is initialized with the feature enabled.

The key rules:
1. **Read functions**: Check for field existence; return a default if absent
2. **Write functions**: Check for parent object existence; return 0 (success) if absent
3. **Initialization**: New state object is included in the initial state template for new runs
4. **No migration**: Existing state files from prior features continue to work without modification

#### Example
```bash
# From .aod/scripts/bash/run-state.sh

aod_state_update_optional_field() {
    # ... (args: field_name, value)
    local state
    state=$(aod_state_read) || return 1

    # Check if the optional field exists; skip gracefully if absent (backward compat)
    local has_field
    has_field=$(echo "$state" | jq -r "if .$field_name then \"yes\" else \"no\" end")
    if [[ "$has_field" != "yes" ]]; then
        return 0  # Pre-feature state file — no field present, no error
    fi

    # Proceed with update only if the field exists
    state=$(echo "$state" | jq --arg val "$value" \
        ".$field_name = \$val")
    aod_state_write "$state"
}

aod_state_get_governance_cache() {
    # Returns defaults when governance_cache is absent
    echo "$state" | jq -r '
        if .governance_cache then
            .governance_cache
        else
            null
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
- [Compound State Helpers](#pattern-compound-state-helpers) -- state summary helpers follow the same pipe-delimited extraction approach
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
  SKILL.md                     # Core loop (~620 lines, always loaded)
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

**Added**: Feature 038 (Universal Session State Tracking)

#### Problem
Standalone lifecycle commands (`/aod.define`, `/aod.spec`, etc.) need to write state to `.aod/run-state.json`. However, the orchestrator (`/aod.run`) already manages state when it invokes these same commands as sub-stages. If a standalone command writes state entries while an active orchestrator is managing the state file, the two writers conflict -- potentially corrupting orchestrator loop context.

#### Solution
Before performing any state writes, each standalone command checks whether an active orchestrator owns the state file. The detection uses an implicit heuristic: read the `updated_at` timestamp and current stage status from the state file; if any stage is `in_progress` AND `updated_at` is within 5 minutes of the current time, an orchestrator is presumed active. In that case, the command skips state writes and defers to the orchestrator.

This avoids introducing new flags or environment variables. The 5-minute window is chosen because orchestrator loop iterations typically complete within seconds; a stale `updated_at` beyond 5 minutes indicates an abandoned or crashed orchestration rather than an active one.

The key rules:
1. **Check state existence**: If no state file exists, create one (standalone initialization)
2. **Check orchestrator recency**: Read `updated_at` and stage status; skip if active
3. **Validate feature ID**: Compare branch-derived feature ID against state's `feature_id`; prompt user on mismatch
4. **Proceed or skip**: Write state only in standalone mode

#### Example
```
# From .claude/commands/aod.define.md

1. Check state file:
   bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_exists && echo "exists" || echo "none"'
   - "none" -> create state (step 3)
   - "exists" -> check orchestrator (step 2)

2. Detect active orchestrator:
   aod_state_get_loop_context  -> "plan|spec|in_progress"
   aod_state_get ".updated_at" -> "2026-02-12T10:05:00Z"
   - If stage is in_progress AND updated_at < 5 min ago -> SKIP state writes
   - Otherwise -> standalone mode, continue

3. Create state file (standalone only):
   aod_state_init "{feature_id}" "{feature_name}" "Entity 1"
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
- [Additive Optional State Fields](#pattern-additive-optional-state-fields) -- state fields follow the same backward-compatible schema extension
- [Graceful CLI Degradation](#pattern-graceful-cli-degradation) -- state operations degrade gracefully (non-fatal) similar to CLI fallbacks
- [Compound State Helpers](#pattern-compound-state-helpers) -- `aod_state_get_loop_context` used for orchestrator detection

---

### Pattern: Non-Fatal Observability Wrapper

**Added**: Feature 038 (Universal Session State Tracking)

#### Problem
Observability and state tracking are secondary concerns -- they must never block the primary skill execution. However, initialization sequences involve multiple steps (state existence check, orchestrator detection, feature ID validation, state creation) that can each fail for various reasons (missing `jq`, corrupted state file, permission errors). Wrapping every individual call in error handling is verbose and error-prone.

#### Solution
Encapsulate the entire observability initialization and completion sequences in clearly demarcated "Non-Fatal" blocks. Every shell command within these blocks uses `|| true` or equivalent error suppression. The block boundary is documented in the command file with an explicit contract: "If any step fails, log the error and continue -- observability is non-fatal."

The completion block follows the same pattern: write state, read summary, and append to output. If any step fails, the observability line is simply omitted from the completion message.

#### Example
```
# Pre-execution block (from command files)
## State Tracking (Non-Fatal)
1. Check state file ...
2. Detect active orchestrator ...
3. Create state file ...
If any step fails, log the error and continue to Step 1.

# Post-execution block (from command files, completion section)
### State Tracking (Non-Fatal)
1. Write state update:
   bash -c '... || true'
2. Read summary:
   bash -c '... || echo "fallback"'
3. If any step fails, omit the observability line.
```

#### When to Use
- Secondary telemetry or observability features that must not impact primary functionality
- Operations where partial success is acceptable (some observability data is better than none)
- Features added to existing stable commands where failure isolation is critical

#### When NOT to Use
- Core functionality where failures must be surfaced and handled
- Operations where partial state is worse than no state (use transactions instead)
- When error details are needed for debugging (non-fatal suppresses error context)

#### Related Patterns
- [Orchestrator-Awareness Guard](#pattern-orchestrator-awareness-guard) -- the non-fatal wrapper contains the orchestrator guard as one of its steps
- [Graceful CLI Degradation](#pattern-graceful-cli-degradation) -- both patterns prioritize continued operation over error reporting
- [Additive Optional State Fields](#pattern-additive-optional-state-fields) -- state read/write functions already handle missing fields gracefully

---

### Pattern: Append-Only Logging with Graceful Failure

**Added**: Feature 049 (Simple Logging Utility)

#### Problem
Scripts need to record timestamped execution events for debugging and auditing, but logging must not interfere with the primary operation if file writes fail (permission denied, disk full, etc.). Additionally, log configuration must be flexible (custom path via environment variable) without requiring code changes.

#### Solution
Implement a logging function that:
1. **Appends to a file** (not atomic, acceptable for logs) using `>>` operator
2. **Prepends ISO 8601 UTC timestamps** for temporal sorting and cross-system consistency
3. **Auto-creates directories** before first write (implicit initialization)
4. **Fails gracefully**: captures write errors, emits a warning to stderr, and returns non-zero exit code without exiting the calling script
5. **Accepts configuration** via environment variable (`AOD_LOG_FILE`) with a sensible default

#### Example
```bash
# From .aod/scripts/bash/logging.sh (Feature 049)

# Default log file path (can be overridden via environment variable)
AOD_LOG_FILE="${AOD_LOG_FILE:-.aod/logs/aod.log}"

# Log a timestamped message to the log file
# Usage: aod_log "message"
# Returns: 0 on success, 1 on failure
aod_log() {
    local message="$1"
    local timestamp

    # Generate ISO 8601 UTC timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Ensure log directory exists
    mkdir -p "$(dirname "$AOD_LOG_FILE")" 2>/dev/null || {
        echo "[aod] Warning: Cannot create log directory" >&2
        return 1
    }

    # Append formatted log entry to file
    echo "$timestamp $message" >> "$AOD_LOG_FILE" 2>/dev/null || {
        echo "[aod] Warning: Cannot write to log file" >&2
        return 1
    }

    return 0
}
```

**Usage in other scripts**:
```bash
# Source the logging utility
source .aod/scripts/bash/logging.sh

# Log a message (will use default path .aod/logs/aod.log)
aod_log "Stage started"

# Log with custom path (set environment variable)
AOD_LOG_FILE=/tmp/custom.log aod_log "Custom path message"

# Caller continues even if logging fails
aod_log "This might fail" || echo "Warning: logging failed"
```

**Log format**:
```
2026-02-13T10:30:00Z Stage started
2026-02-13T10:30:01Z Discover stage complete
2026-02-13T10:30:15Z Define stage started
```

#### When to Use
- Any script that needs diagnostic output for later review without blocking execution
- Lifecycle commands where logging is secondary to primary functionality
- Situations where log files may be on read-only or space-constrained filesystems
- Multi-step processes where you want to track progress independent of return codes

#### When NOT to Use
- Critical alerts that must be delivered (use stderr/exit for critical errors)
- High-frequency logging where append overhead matters (logs only at stage boundaries, not per-call)
- Systems requiring guaranteed atomic writes or concurrent write safety (append mode is best-effort only)
- Requirements for structured logging (JSON, tags, log levels) -- this is plain-text only

#### Implementation Guarantees
- **No hard failure**: Write errors emit a stderr warning but never crash the caller
- **Cross-platform**: Works on macOS and Linux with standard shell utilities (`date`, `mkdir`, `echo`)
- **Portable configuration**: Environment variable override allows scripts to be used unchanged in different contexts
- **Self-healing**: Auto-creates parent directories before first write, no manual initialization needed

#### Related Patterns
- [Graceful CLI Degradation](#pattern-graceful-cli-degradation) -- logging gracefully degrades similar to optional CLI tools
- [Function Library Sourcing](#pattern-function-library-sourcing) -- logging.sh is a function library meant to be sourced by other scripts

---

### Pattern: Circuit-Breaker Churn Detection

**Added**: Feature 054 (Parallel Execution Hardening)
**ADR**: [ADR-006](../02_ADRs/ADR-006-non-fatal-observability-operations.md)

#### Problem
When an operation fails repeatedly with the same error, the orchestrator may enter a "churn loop" -- retrying the same failing operation until context is exhausted. Observed: 17+ minutes of retries before hard failure, wasting substantial tokens and user time.

#### Solution
Implement a circuit-breaker pattern that tracks consecutive failures by error signature. After 3 identical failures, the circuit-breaker "opens" and triggers a diagnostic pause with a message to the user. The circuit-breaker resets when:
- An operation succeeds (proves the issue is resolved)
- The error signature changes (indicates a different problem)
- A new session starts (fresh context, worth retrying)

#### Example

The governance circuit breaker in `governance.md` tracks consecutive `gate_rejections`. When 3 identical failures occur, it escalates to the user rather than retrying.

```json
{
  "gate_rejections": [
    { "stage": "plan", "substage": "spec", "reviewer": "product-manager", "attempt": 1 },
    { "stage": "plan", "substage": "spec", "reviewer": "product-manager", "attempt": 2 },
    { "stage": "plan", "substage": "spec", "reviewer": "product-manager", "attempt": 3 }
  ]
}
```

When 3 rejections accumulate for the same gate, the circuit breaker fires and escalates to the user.

#### When to Use
- Operations that can fail repeatedly with the same root cause
- Long-running orchestrations where churn wastes significant resources
- Any retry logic where detecting futile retries provides value

#### When NOT to Use
- Operations expected to fail before succeeding (e.g., polling for async completion)
- When different failures are related (consider aggregating to a single signature)
- Single-shot operations without retry logic

#### Error Signature Design

The error signature is `operation_name:error_type` (e.g., `governance_review:timeout`). Choosing the right granularity is important:

- **Too specific**: Every failure looks different, circuit-breaker never triggers
- **Too general**: Unrelated failures accumulate, false positives occur

Good signatures group failures by root cause, not surface symptoms.

#### Related Patterns
- [Non-Fatal Observability Wrapper](#pattern-non-fatal-observability-wrapper) -- circuit-breaker functions are non-fatal
- [Graceful CLI Degradation](#pattern-graceful-cli-degradation) -- circuit-breaker degrades to "closed" on read errors

---

### Pattern: Dual-Surface Injection

**Added**: Feature 058 (Stack Packs)
**ADR**: [ADR-007](../02_ADRs/ADR-007-stack-pack-dual-surface-injection.md)

#### Problem
Stack packs need to inject technology-specific context into AI agents at two distinct points with different loading semantics: (1) broad coding rules that all agents should follow, auto-loaded via `.claude/rules/` discovery at session start; and (2) role-specific persona supplements that only specialized/hybrid agents should load, on-demand during task execution. A single injection surface would either over-load all agents with role-specific details (wasting context tokens) or under-serve specialized agents with only generic rules.

#### Solution
Inject pack content through two independent surfaces with different loading triggers:

**Surface 1 -- Rules injection** (auto-loaded, all agents): On activation, copy `.md` files from `stacks/{pack}/rules/` to `.claude/rules/stack/` and generate a `persona-loader.md` directive. These files are discovered by Claude Code's standard rules loading mechanism and apply to every agent in the session.

**Surface 2 -- Persona injection** (on-demand, specialized/hybrid agents only): During `/aod.build`, the build command reads `.aod/stack-active.json` to determine the active pack, then augments dispatched agent prompts with instructions to read `stacks/{pack}/agents/{agent-name}.md`. Core agents (product-manager, architect, team-lead, orchestrator, web-researcher) are never augmented.

Files are **copied** (not symlinked) from pack source to the rules directory for cross-platform safety and source immutability. Activation state is tracked in `.aod/stack-active.json` (JSON, consistent with `run-state.json` pattern).

#### Example
```
# Activation flow (/aod.stack use nextjs-supabase)

# Surface 1: Copy rules to auto-discovery location
stacks/nextjs-supabase/rules/conventions.md  -->  .claude/rules/stack/conventions.md
stacks/nextjs-supabase/rules/security.md     -->  .claude/rules/stack/security.md
(generated)                                  -->  .claude/rules/stack/persona-loader.md

# Surface 2: State file enables build-time persona injection
.aod/stack-active.json = {"pack": "nextjs-supabase", "activated_at": "2026-02-27T14:30:00Z", "version": "1.0"}

# During /aod.build, when dispatching frontend-developer:
#   1. Read .aod/stack-active.json -> pack = "nextjs-supabase"
#   2. Agent is "specialized" tier -> inject persona read instruction
#   3. Agent reads stacks/nextjs-supabase/agents/frontend-developer.md
#   4. Agent applies stack-specific conventions from supplement

# During /aod.build, when dispatching product-manager:
#   1. Agent is "core" tier -> no persona injection
#   2. Rules from .claude/rules/stack/ still apply (auto-loaded)
```

```
# Deactivation flow (/aod.stack remove)
rm .claude/rules/stack/conventions.md
rm .claude/rules/stack/security.md
rm .claude/rules/stack/persona-loader.md
rm .aod/stack-active.json
# Pack source files in stacks/ are untouched
# Previously scaffolded project files are untouched
```

#### When to Use
- Injecting context into agents at multiple points with different loading semantics (auto-loaded vs. on-demand)
- When different agent roles need different subsets of injected content
- Plugin/pack systems where activation must be reversible without side effects on source files
- Context-budget-constrained environments where selective loading is necessary

#### When NOT to Use
- Single-surface injection is sufficient (all agents need the same content)
- Content is small enough that loading everything everywhere fits within context budget
- When symlinks are acceptable (single-platform, no immutability requirement)

#### Related Patterns
- [On-Demand Reference File Segmentation](#pattern-on-demand-reference-file-segmentation) -- persona supplements use the same principle of loading content only when needed
- [Additive Optional State Fields](#pattern-additive-optional-state-fields) -- `stack-active.json` follows the same JSON state pattern, and the system gracefully handles its absence
- [Graceful CLI Degradation](#pattern-graceful-cli-degradation) -- inconsistent state detection in `/aod.stack` commands follows the same degrade-gracefully philosophy

---

### Pattern: Subshell Isolation for Strict Shell Options

**Added**: Feature 062 (Auto-Create GitHub Projects Board During Init)

#### Problem
Scripts that use `set -e` (errexit) will abort if any command returns a non-zero exit code. When such a script sources a function library and calls a function that may fail (e.g., a network-dependent GitHub API call), the failure propagates through the `source` chain and terminates the parent script -- even when the caller intends to handle the failure gracefully with `|| true`.

The core issue is that `set -e` propagates into sourced files and their function calls. A `source lib.sh && some_function` expression inherits the parent's `set -e` context, so any internal failure within `some_function` causes the parent to exit before the `|| true` guard can execute.

#### Solution
Wrap the source-and-call sequence in `bash -c '...'`, which spawns a child process with a fresh shell environment. The child process does NOT inherit `set -e` from the parent. The parent captures the child's exit code and output, then handles failure with `|| true` or conditional logic.

This creates a clean boundary: the parent script keeps its strict error handling for its own operations, while the sourced library functions execute without `set -e` interference.

#### Example
```bash
# From scripts/init.sh (Feature 062)
# Parent script has: set -e

# CORRECT: Subshell isolation — set -e does NOT propagate into the child
board_output=$(bash -c 'source .aod/scripts/bash/github-lifecycle.sh && aod_gh_setup_board' 2>&1) || true

# WRONG: Direct source — set -e propagates, any internal failure kills init.sh
source .aod/scripts/bash/github-lifecycle.sh
aod_gh_setup_board || true  # Too late — set -e already killed the script

# WRONG: Subshell syntax — ( ) inherits set -e from parent
board_output=$(source .aod/scripts/bash/github-lifecycle.sh && aod_gh_setup_board 2>&1) || true
```

The key distinction is between `bash -c '...'` (new process, clean environment) and `$(...)` or `( )` (subshell that inherits shell options from the parent).

#### When to Use
- Calling function libraries from scripts that use `set -e`
- Isolating non-critical operations (board creation, telemetry) from critical init flows
- Any scenario where a sourced function may fail and the caller must continue

#### When NOT to Use
- Scripts without `set -e` (no isolation needed, direct source is fine)
- When you need the sourced functions to share variables with the parent (child process has separate scope)
- Critical operations where failure SHOULD abort the parent script

#### Related Patterns
- [Function Library Sourcing](#pattern-function-library-sourcing) -- the standard pattern for calling library functions; subshell isolation is the variant for `set -e` contexts
- [Graceful CLI Degradation](#pattern-graceful-cli-degradation) -- the outer pattern that skips non-critical operations; subshell isolation is the mechanism that makes graceful degradation safe under `set -e`
- [Non-Fatal Observability Wrapper](#pattern-non-fatal-observability-wrapper) -- both patterns ensure secondary operations cannot block primary execution
- [`set +e` / `set -e` Bracket for rc-Capture Under Strict Shell](#pattern-set-e-bracket-for-rc-capture-under-strict-shell) -- the in-process counterpart; subshell isolation handles cross-process boundaries (`bash -c`), the bracket pattern handles same-process command substitution

---

### Pattern: `set +e` / `set -e` Bracket for rc-Capture Under Strict Shell

**Added**: Feature 132 (Fix `scripts/update.sh` Silent Exit 5)
**Hardened**: Feature 134 (FR-017 enforcement across two new helper modules — `bootstrap.sh`, `check-placeholders.sh`)
**Precedent**: `scripts/check-manifest-coverage.sh:115-118` (Feature 129)

#### Problem

A script running under `set -euo pipefail` cannot reliably capture a non-zero return code from a helper invoked via command substitution. The pattern most authors reach for first looks correct but is broken on bash 3.2:

```bash
set -euo pipefail
local result
result=$(some_helper "$arg")
local rc=$?            # NEVER reached: set -e aborted the parent on the helper's non-zero exit
if [ "$rc" -eq 5 ]; then
    handle_specific_drift_case
fi
```

The intuitive "fix" with `|| true` does not work either — it clobbers `$?` to zero before the rc-capture line:

```bash
result=$(some_helper "$arg") || true
local rc=$?            # Always 0 — `|| true` already swallowed the real exit code
```

This anti-pattern caused Feature 132's silent-exit-5 bug: the error-collector branch at `scripts/update.sh:929-934` was unreachable because `set -e` aborted the parent before `local cat_rc=$?` could capture the helper's return code. Adopters saw a bare exit 5 with zero stdout/stderr — the architectural intent (a typed diagnostic listing uncategorized files) was never executed.

#### Solution

Bracket the command substitution with `set +e` ... `set -e`. This temporarily disables errexit across exactly the substitution where rc-capture matters, then immediately restores strict mode:

```bash
set +e
result=$(some_helper "$arg")
local rc=$?
set -e
if [ "$rc" -eq 5 ]; then
    handle_specific_drift_case
elif [ "$rc" -eq 1 ]; then
    handle_helper_internal_error
fi
```

Three properties make this the canonical kit pattern:
1. **`$?` is preserved** — bash does not abort between the substitution and the rc-capture line.
2. **Scope is minimal** — strict mode is off for exactly the assignment, on for everything else.
3. **Bash 3.2 compatible** — no associative arrays, no process substitution, no errtrap. Works identically on macOS `/bin/bash` 3.2.57 and Ubuntu CI bash 5.x.

#### Example

```bash
# .aod/scripts/bash/bootstrap.sh (Feature 134, FR-017)
# Parent has: set -euo pipefail

set +e
upstream_dir=$(aod_template_fetch_upstream "$canonical_url" "$staging_root")
local fetch_rc=$?
set -e

if [ "$fetch_rc" -ne 0 ]; then
    echo "ERROR: upstream fetch failed (rc=$fetch_rc)" >&2
    return "$fetch_rc"
fi

# .aod/scripts/bash/check-placeholders.sh (Feature 134, FR-017)
set +e
findings=$(scan_files "$scope")
local scan_rc=$?
set -e

if [ "$scan_rc" -eq 0 ] && [ -n "$findings" ]; then
    emit_findings "$findings"
    emit_migration_table
    exit 13     # placeholder drift (non-colliding allocation, ADR-013 additive philosophy)
fi
```

#### When to Use

- Every command substitution where you intend to branch on a typed exit code from a helper that may legitimately return non-zero (e.g., "drift detected" = exit 5; "helper not found" = exit 1).
- Any helper-call site under `set -euo pipefail` where a typed diagnostic must follow a specific exit code (otherwise the diagnostic is unreachable).
- Helper-call chains in adopter-facing CLIs where a silent abort would corrupt the operator's mental model of what failed.

**Enforcement boundary**: F134's FR-017 makes this a recurring requirement — every helper call site in `.aod/scripts/bash/bootstrap.sh` and `.aod/scripts/bash/check-placeholders.sh` MUST use the bracket. Plan-phase grep audit (`grep -rn` for `aod_template_*` invocations under `set -e` parents) is the regression gate.

#### When NOT to Use

- Scripts without `set -e` — the bracket is a no-op there; just capture `$?` directly.
- Helper calls where any non-zero exit is a hard fatal (and you want bash to abort) — strict mode is the right behavior; rc-capture is unnecessary.
- Loop bodies where the typed-rc branching is not needed inside the iteration — restoring `set -e` after the loop body is sufficient (avoid bracket-per-iteration when one outer bracket suffices).

#### Related Patterns

- [Subshell Isolation for Strict Shell Options](#pattern-subshell-isolation-for-strict-shell-options) — handles cross-process boundaries via `bash -c`. The rc-capture bracket is the in-process counterpart for same-shell command substitution. Use the bracket when you need the helper's variables in the parent's scope; use subshell isolation when the helper invokes other strict scripts and `set -e` would cascade through `source`.
- [Graceful CLI Degradation](#pattern-graceful-cli-degradation) — the bracket is what makes typed exit-code degradation expressible under strict mode (drift → exit 13 vs. helper failure → exit 1 vs. clean → exit 0).
- [Function Library Sourcing](#pattern-function-library-sourcing) — the standard call pattern; the bracket is the wrapper that lets sourced functions return typed non-zero codes without aborting the parent.

---

### Pattern: Built-in Skill Invocation from a Command

**Added**: Feature 065 (Add /simplify Command to AOD Process)
**ADR**: [ADR-008](../02_ADRs/ADR-008-opt-out-flag-for-default-quality-gates.md)

#### Problem
A command workflow needs to invoke a built-in platform skill (one that is not a custom `.claude/skills/` file, but a first-party capability like `/simplify`) as a named step. Two sub-problems arise:

1. **Discoverability**: The skill is invisible in the command file -- there is no file path to reference, only a slash-command name. Readers of the command file cannot tell what the skill does without knowing the platform.
2. **Opt-out**: Some execution contexts make the built-in step inappropriate (e.g., methodology-only repos with no source code to simplify, CI runs that must be deterministic). A blanket invocation with no escape hatch forces all users to accept the step.

#### Solution
Reference the built-in skill by its slash-command name in the command file's step list, with a parenthetical that describes what it does. Gate the step behind an opt-out flag (e.g., `--no-simplify`) that is checked before the step executes. The flag default is **on** (quality gate runs unless explicitly skipped), preserving the quality intent while providing a documented escape hatch.

The opt-out flag must be:
1. Declared in the command's flag-parsing section near the top of the file
2. Checked immediately before the step that invokes the skill
3. Documented in the command reference and in CLAUDE.md

The step text uses the Skill tool (not Bash) to invoke the built-in, since built-ins are agent capabilities, not shell commands.

#### Example
```markdown
# In .claude/commands/aod.build.md

## Flags
- `--no-design-check`: Skip the Design Quality Gate step (Step 6)
- `--no-security`: Skip the Security Scan step (Step 7)
- `--no-simplify`: Skip the Code Simplification step (Step 8)

## Steps

...

### Step 6: Design Quality Gate (skip if --no-design-check)
Run grep-based checks on changed UI files for banned fonts, arbitrary spacing,
shadow count, and reduced-motion support.
- If `--no-design-check` flag is present: skip this step, write design-check.md "Skipped" entry
- Otherwise: Run 4 automated checks on changed CSS/JSX/TSX/HTML files

### Step 7: Security Scan (skip if --no-security)
Invoke the /security skill to analyze changed code files and manifests for
OWASP Top 10 vulnerabilities and known CVE patterns.
- If `--no-security` flag is present: skip this step, write security-scan.md "Skipped" entry
- Otherwise: Use the Skill tool to invoke `security` on changed files

### Step 8: Code Simplification (skip if --no-simplify)
Invoke the /simplify skill to reduce complexity and improve readability of
any files modified during this build session.
- If `--no-simplify` flag is present: skip this step entirely, log "Simplification skipped (--no-simplify)"
- Otherwise: Use the Skill tool to invoke `/simplify` on changed files
```

```markdown
# In CLAUDE.md commands section
/aod.build [--no-security] [--no-design-check] [--no-simplify]  # Execute with auto architect checkpoints; --no-design-check skips Design Quality Gate (Step 6); --no-security skips Security Scan (Step 7); --no-simplify skips Code Simplification (Step 8)
```

#### When to Use
- Integrating a platform built-in (e.g., `/simplify`, `/lint`, `/format`) as a named workflow step
- When the built-in is appropriate by default but not universally (methodology repos, CI-only runs)
- When you want the quality gate to be explicit in the command file so reviewers understand the workflow

#### When NOT to Use
- Built-ins that are always appropriate with no valid reason to skip (just invoke unconditionally)
- Built-ins that are rarely appropriate (make the step opt-in with a `--with-X` flag instead)
- Custom skills in `.claude/skills/` (use On-Demand Reference File Segmentation pattern instead)

#### Related Patterns
- [On-Demand Reference File Segmentation](#pattern-on-demand-reference-file-segmentation) -- applies to custom skill files; this pattern applies to platform built-ins
- [Read-Only Dry-Run Preview](#pattern-read-only-dry-run-preview) -- `--dry-run` and `--no-simplify` follow the same flag-gating convention for skipping steps

---

### Pattern: Template Variable Expansion

**Added**: Feature 061 (init.sh Personalize All Template Files)
**ADR**: [ADR-009](../02_ADRs/ADR-009-template-variable-expansion-scope.md)

#### Problem
Template files shipped with the kit contain the kit's own name ("Agentic Oriented Development Kit") as hardcoded text. When an adopter runs `make init`, these files are not personalized, so all user-facing documentation still shows the kit name instead of the adopter's project name. This causes confusion and requires manual find-and-replace by adopters.

#### Solution
Use the `{{PROJECT_NAME}}` double-brace placeholder wherever the project name should appear in a template file. `scripts/init.sh` already performs a `sed` substitution pass over template files during `make init`, replacing `{{PROJECT_NAME}}` with the adopter's actual project name. No new code or infrastructure is needed -- add the placeholder to the file content and the init script handles the rest.

The convention aligns with other template variables in the kit (`{{CURRENT_DATE}}`, `{{TEMPLATE_VARIABLES}}`, etc.) and is consistent with the pre-existing usage in `.aod/memory/constitution.md`.

#### Files Using This Pattern
| File | Placeholder Locations |
|------|-----------------------|
| `CLAUDE.md` | File header, project structure comment |
| `README.md` | Title, description, header references |
| `.claude/README.md` | Title, overview |
| `.claude/agents/_README.md` | Title, overview |
| `.claude/rules/commands.md` | Overview line |
| `.claude/rules/context-loading.md` | Overview line |
| `.claude/rules/deployment.md` | Overview line |
| `.claude/rules/git-workflow.md` | Overview line |
| `.claude/rules/governance.md` | Overview line |
| `.claude/rules/scope.md` | Title, description lines |
| `docs/product/02_PRD/INDEX.md` | Header |
| `.aod/memory/constitution.md` | Pre-existing usage |

#### When to Use
- Any template file that would display "Agentic Oriented Development Kit" to an adopter after `make init`
- Headers, titles, and overview lines in files that adopters will read, share, or modify
- New `.claude/rules/*.md` or `.claude/agents/*.md` files added to the kit

#### When NOT to Use
- Internal implementation files that adopters never read directly (e.g., shell scripts, JSON state files)
- Comments in script files where the kit name is intentional (e.g., attribution headers)
- Files that are NOT processed by `scripts/init.sh` -- check `init.sh` to confirm a file is in scope before adding the placeholder

#### Checklist for New Template Files
When adding a new user-facing template file to the kit:
1. Identify every occurrence of "Agentic Oriented Development Kit" or its abbreviation
2. Replace with `{{PROJECT_NAME}}`
3. Verify the file is included in the `scripts/init.sh` substitution loop
4. Test with `make init` on a fresh clone to confirm replacement occurs

#### Related Patterns
- None -- this is a content convention, not a runtime pattern

---

### Pattern: Two-Level Architecture

**Added**: Feature 064 (Knowledge System Stack Pack)

#### Problem
Knowledge-intensive domains (resume writing, publishing, education, consulting) need AI-orchestrated workflows to produce quality outputs. A naive approach treats orchestration design and content production as a single activity, leading to non-reusable one-off generation, no quality framework, and re-running the full SDLC for every output.

#### Solution
Separate the system into two distinct operational levels with different lifecycles:

**Build-time (AOD lifecycle)**: Use `/aod.define` through `/aod.deliver` to design and construct the orchestration itself -- commands, agent personas, content architecture, quality rubric, and context loading configuration. The product of build-time is a working orchestration system.

**Run-time (domain orchestration)**: Use the commands built during build-time (e.g., `/new`, `/draft`, `/review`, `/export`) to produce domain outputs -- tailored resumes, edited chapters, lesson plans, consulting deliverables. The product of run-time is domain content.

The rule: AOD commands design the system. Product commands operate the system. Never use AOD commands as run-time product commands. Never build product commands that duplicate AOD lifecycle functions.

#### Example
```
# BUILD-TIME: Constructing the orchestration (AOD lifecycle)
/aod.define "resume builder"    # Define command inventory, audience, content domains
/aod.spec                       # Specify commands, agents, content architecture
/aod.project-plan               # Plan orchestration: command flow, context loading
/aod.tasks                      # Break down into: command files, agent personas, templates
/aod.build                      # Author commands, build agents, configure context loading
/aod.deliver                    # Validate end-to-end orchestration

# RUN-TIME: Operating the built system (product commands)
/new senior-resume              # Initialize output instance from master content
/draft --preset formal-exec     # Generate draft using voice + style + context
/review                         # Evaluate against scoring rubric
/export pdf                     # Format for delivery
```

#### When to Use
- Stack packs targeting content-intensive or knowledge-management domains
- Any system where the orchestration layer is itself the product (not application code)
- Domains where quality is measured by rubric scoring rather than test suites

#### When NOT to Use
- Traditional software stack packs (e.g., nextjs-supabase) where build-time produces application code directly
- Simple automation scripts with no reusable orchestration layer

#### Related Patterns
- [Dual-Surface Injection](#pattern-dual-surface-injection) -- mechanism for loading pack conventions into agents
- [Command-per-Workflow](#pattern-orchestrator-awareness-guard) -- each user workflow maps to one command (documented in `stacks/knowledge-system/STACK.md`)

---

### Pattern: Minimal-Return Subagent

**Added**: Feature 073 (Minimal-Return Architecture for Subagent Context Optimization)
**ADR**: [ADR-010](../02_ADRs/ADR-010-minimal-return-architecture.md)

#### Problem

Subagents invoked for governance reviews (Triad reviewers, code reviewers) return their complete findings inline to the calling orchestrator. A thorough review runs 500-2,000 tokens per return. A full Triad review cycle (3 reviewers) therefore consumes 1,500-6,000 tokens in the main context before any implementation work can proceed. In long-running orchestrations with 10+ delegations, this overhead exhausts the context window within 30-60 minutes -- well before the Build stage.

The core tension: governance reviews are valuable because they are thorough. Truncating returns would lose the rationale, specific concerns, and recommendations that make reviews actionable. The problem is not what the subagent produces, but where it lives.

#### Solution

Decouple the subagent's work product from its return to the main context using **file-based offloading**:

1. The subagent writes its complete findings to `.aod/results/{agent-name}.md` before returning
2. The subagent returns only a brief status summary to the main context: STATUS + ITEMS count + DETAILS file path, capped at 10 lines
3. The main agent reads the results file on-demand when it needs to act on specific findings (e.g., when CHANGES_REQUESTED)
4. Results files use overwrite semantics -- each invocation replaces the prior file, keeping only the current review

The approach has two enforcement layers:
- **Project-wide**: A "Subagent Return Policy" section in CLAUDE.md establishes the convention for all agents
- **Agent-level**: A "Return Format (STRICT)" section in each agent prompt specifies exact format and line limits

The `.aod/results/` directory is gitignored as ephemeral session-scoped artifacts.

#### Example

```markdown
# In .claude/agents/architect.md

## Return Format (STRICT)

When invoked as a **subagent** (via the Agent tool), you MUST:

1. Write your full review to `.aod/results/architect.md` (overwrite, do not append)
2. Return to the caller ONLY the following format:

```
STATUS: [APPROVED | APPROVED_WITH_CONCERNS | CHANGES_REQUESTED | BLOCKED]
ITEMS: [N findings/concerns]
DETAILS: .aod/results/architect.md
```

Maximum return: 10 lines. Do NOT include review rationale, specific concerns,
recommendations, code snippets, or file contents in the return.

This restriction applies ONLY when invoked as a subagent. When invoked directly
by the user, provide full output.
```

```
# Results file written by architect: .aod/results/architect.md
STATUS: CHANGES_REQUESTED
ITEMS: 3

## Finding 1: Missing rate limiting on public endpoints (BLOCKING)
[Full rationale, code references, recommendations ...]

## Finding 2: ...
```

```
# Return to main orchestrator (from architect subagent) — ~8 lines, ~80 tokens
STATUS: CHANGES_REQUESTED
ITEMS: 3
DETAILS: .aod/results/architect.md
```

#### When to Use

- Subagents that produce review or audit outputs (Triad reviewers, code reviewers, security analysts)
- Long-running orchestrations where cumulative subagent return overhead threatens context budget
- Any agent invoked multiple times per session where return content repeats similar structure
- Multi-reviewer workflows where the main agent must aggregate results but act on each individually

#### When NOT to Use

- Agents invoked for debugging or diagnostic work where the diagnostic output IS the deliverable (return the content inline)
- Simple status-check subagents where the return is already minimal (< 5 lines)
- Agents invoked directly by the user (not as a subagent) -- the return format restriction does not apply
- Single-shot orchestrations where context budget is not a concern

#### Implementation Notes

- The `{agent-name}.md` filename convention ensures each agent type has a stable, known path (e.g., `product-manager.md`, `architect.md`, `team-lead.md`)
- If two instances of the same agent type run in parallel, the last write wins (overwrite semantics -- acceptable given sequential Triad reviews)
- If the results directory does not exist, the subagent creates it before writing (self-healing initialization)
- Non-compliance degrades gracefully: a verbose return is larger than intended but does not break the workflow

#### Token Savings Reference

| Scenario | Before | After | Reduction |
|----------|--------|-------|-----------|
| Single reviewer return | 500-2,000 tokens | ~80 tokens | ~95% |
| Full Triad cycle (3 reviewers) | 1,500-6,000 tokens | <600 tokens | ~90% |
| Full `/aod.run` lifecycle (10+ delegations) | Context exhausted ~30-60 min | 90+ min sustained | 2-3x session length |

#### Related Patterns

- [On-Demand Reference File Segmentation](#pattern-on-demand-reference-file-segmentation) -- same principle of deferring content to disk until needed; applied to skill files rather than subagent returns
- [Governance Result Caching](#pattern-governance-result-caching) -- complements this pattern by caching governance verdicts; minimal returns reduce what needs to be cached
- [Non-Fatal Observability Wrapper](#pattern-non-fatal-observability-wrapper) -- non-compliance in return format degrades gracefully, never blocks governance

---

### Pattern: Governed Skill Phase Loop

**Added**: Feature 071 (One-Shot Bug Fix Command — `/aod.bugfix`)
**Skill**: `.claude/skills/~aod-bugfix/SKILL.md`

#### Problem

A skill needs to execute a multi-phase workflow where: (1) phases must be announced so the user knows progress without having to infer it from output; (2) at least one phase applies irreversible mutations (file edits) that require explicit user consent before proceeding; (3) secondary phases (knowledge base operations) are valuable but must not abort the primary loop if they fail; and (4) a user-reviewable artifact must be generated and approved before being persisted.

A linear sequence of instructions with no phase structure, no confirmation gate, and no non-fatal boundary handling produces a skill that silently edits files, suppresses KB failures as errors, and leaves users uncertain about progress.

#### Solution

Structure the SKILL.md as a sequence of explicitly numbered and announced phases. Each phase follows this contract:

1. **Entry announcement**: Print `[Phase N] <name>...` before executing the phase body
2. **Mutation gate**: Before any file write or code change, present a fix plan (affected files + nature of change + confidence level) and wait for explicit user confirmation. Do NOT proceed if the user declines.
3. **Non-fatal secondary phases**: Phases that perform optional enhancements (KB lookup, KB write, external reads) use non-fatal handling: announce failure, continue to next phase. The primary loop must complete regardless of secondary phase outcomes.
4. **Artifact review gate**: When a phase generates a user-facing artifact (e.g., KB entry draft), display it before writing. Allow inline editing. Write only after re-confirmation.
5. **Completion summary**: At loop end, emit a structured summary: root cause identified, files changed, verification status, artifact location (or "skipped").

#### Phase Structure (from `/aod.bugfix`)

```
Phase 0   — Input Acknowledgment & Context Summary (always runs)
Phase 0b  — KB Pre-Check (non-fatal; skips on failure, proceeds to Phase 1)
Phase 1   — Root Cause Analysis (5 Whys methodology; states root cause in plain language)
Phase 2   — Fix Plan + Confirmation Gate (BLOCKING: must receive explicit confirm before Phase 3)
Phase 3   — Implementation (applies ONLY the changes described in Phase 2)
Phase 3b  — Commit Prompt (non-blocking advisory)
Phase 4   — Verification (best-effort; SKIPPED is valid if no test commands available)
Phase 5   — KB Entry Review Gate (non-fatal; show draft → review → write after confirm)

[Completion Summary]
```

#### Key Invariants

- Phase 3 MUST NOT execute unless Phase 2 received explicit user confirmation
- Phase 3 MUST report exactly which files were edited if it fails mid-execution (no silent partial state)
- Phase 0b failure MUST NOT prevent Phase 1 from starting
- Phase 5 failure MUST NOT mark the loop as failed (KB write is non-fatal per ADR-006)
- Secondary phases (0b, 5) are always announced, never silently skipped

#### When to Use

- Skills that perform multi-step workflows with at least one irreversible mutation step
- Workflows where KB or knowledge document operations are secondary (valuable but not critical path)
- Developer-facing skills where progress transparency reduces cognitive load
- Any skill following the diagnose → plan → implement → verify → document lifecycle shape

#### When NOT to Use

- Simple single-step skills where phase structure adds no navigational value
- Skills with no mutation phases (no confirmation gate needed)
- Background or non-interactive skills where user confirmation gates are inappropriate

#### Related Patterns

- [Non-Fatal Observability Wrapper](#pattern-non-fatal-observability-wrapper) — the same non-fatal principle applied to bash observability functions; this pattern applies it to AI skill phase boundaries
- [On-Demand Reference File Segmentation](#pattern-on-demand-reference-file-segmentation) — for skills exceeding ~500 lines, combine with this pattern to split conditionally-needed phase content into on-demand reference files

---

### Pattern: Convention Contract

**Added**: Feature 058 (Stack Packs), validated across Features 064 and 078

#### Problem

Stack packs need to communicate technology conventions, coding rules, and architectural constraints to AI agents in a predictable format. Without a standardized contract, each pack would define conventions differently -- some as prose, some as rules files, some embedded in agent prompts -- making it impossible for the stack activation skill to load conventions consistently. Agents would not know where to find the authoritative source for "how to write code in this stack."

#### Solution

Define a `STACK.md` file as the required convention contract for every stack pack. The file follows a fixed structure with a budget cap (500 lines max) to prevent context bloat:

1. **Header block**: Pack metadata (target audience, stack versions, use case, deployment, philosophy) in a standardized format that the activation skill can parse
2. **Architecture Pattern section**: Layered architecture with explicit ALWAYS/NEVER rules per layer (routes, services, models, schemas, etc.)
3. **Conventions sections**: Backend conventions, frontend conventions, API communication patterns, testing requirements, security rules -- each with concrete examples
4. **Validation checklist**: A checklist agents can evaluate code against to verify convention compliance

The contract is loaded into every agent invocation when the pack is active (via the dual-surface injection mechanism). Agents treat STACK.md as authoritative for technology-specific decisions.

#### Example
```
stacks/fastapi-react/STACK.md (354 lines):
  Header        → Target, Stack, Use Case, Deployment, Philosophy
  Architecture  → Backend (layered: routes → services → ORM)
                → Database (SQLAlchemy 2.0 async + asyncpg)
                → Frontend (React SPA with TanStack Query)
  Conventions   → Backend (Pydantic schemas, dependency injection)
                → Frontend (TypeScript strict, component patterns)
  Security      → CORS, auth, SQL injection prevention
  Testing       → pytest-asyncio, httpx, Vitest + RTL
  Validation    → 15-item compliance checklist
```

#### When to Use
- Every stack pack must include a STACK.md (it is the only required file in a pack)
- When defining technology conventions that agents must follow during code generation
- When multiple agent personas need a shared authoritative source for coding rules

#### When NOT to Use
- For runtime configuration (use `defaults.env` or scaffold config files instead)
- For agent persona definitions (use `agents/*.md` persona supplements instead)
- For rules that apply regardless of stack (use `.claude/rules/*.md` instead)

#### Related Patterns
- [Dual-Surface Injection](#pattern-dual-surface-injection) -- mechanism that loads STACK.md into agent context at activation time
- [Two-Level Architecture](#pattern-two-level-architecture) -- knowledge-system packs use STACK.md to define both build-time and run-time conventions
- [Declarative Test Contract with Stable Exit-Code Taxonomy](#pattern-declarative-test-contract) -- layered on top of this pattern; adds a machine-readable contract block inside STACK.md Section 7 for test-runner declarations

---

### Pattern: Declarative Test Contract with Stable Exit-Code Taxonomy

**Added**: Feature 130 (Stack Pack Test Contract)
**ADR**: [ADR-012](../02_ADRs/ADR-012-stack-pack-test-contract.md)
**Delivered**: 2026-04-21 (PR #141)

#### Problem

A kit-level skill (`/aod.deliver` Step 9) needs to invoke pack-specific test commands (unit, integration, E2E) but has no reliable way to discover what those commands are. Filesystem heuristics (probe for `playwright.config.*`, detect `package.json` dependencies, look for `pytest.ini`, etc.) lock the skill into whichever runners it can detect, create branches that bloat the skill prose, and silently conflate "this pack has no E2E layer" with "the heuristic failed to detect the E2E runner." New runners require skill edits. Pack authors have no explicit way to opt out with a tracked reason.

Additionally: any schema change needs PR-time enforcement so contract drift is caught on the upstream kit, not at adopter delivery time.

#### Solution

Declare a small, versioned contract in a fixed location inside each pack's `STACK.md`, validate it with a bash-3.2 lint emitting a **stable exit-code taxonomy**, and consume it from the skill via **exit-code branching** rather than string parsing or filesystem probing.

**Three mechanisms compose**:

1. **Machine-parseable block inside human-readable doc**: Use HTML sentinel comments (`<!-- BEGIN: foo -->` / `<!-- END: foo -->`) to bracket a fenced YAML block. HTML comments survive Markdown prettifiers; `awk` range match extracts the block regardless of fence reflow.
2. **Minimal schema with XOR for mutual-exclusion states**: Required-field + XOR-between-two-alternatives makes three semantic states distinguishable (have-it, explicitly-don't, forgot-to-declare). Unknown keys trigger a distinct error so typos surface immediately.
3. **Stable exit-code taxonomy**: Consumer scripts branch on numeric codes, not string parsing. Codes are frozen forever — adding new codes is permitted; repurposing is not. Multi-violation runs emit all errors to stderr in compiler-diagnostic format and exit with the numerically lowest applicable code.

PR-time enforcement runs the same lint in CI (`bash:3.2` Docker container for parity with local macOS). Stderr output follows the `<file>:<line>: <SEVERITY>: <message>` format supported by the GitHub Actions annotator for inline PR comments.

#### Example

```yaml
# stacks/<pack>/STACK.md Section 7 — the contract block

<!-- BEGIN: aod-test-contract -->
```yaml
test_command: "npm run test"
e2e_command: "npx playwright test"   # XOR with e2e_opt_out
# OR, for packs without an E2E layer:
# e2e_opt_out: "No E2E layer yet — tracked in #138"
```
<!-- END: aod-test-contract -->
```

```bash
# Consumer script (/aod.deliver Step 9a) — exit-code branching

bash .aod/scripts/bash/stack-contract-lint.sh "stacks/${PACK}/STACK.md"
case $? in
  0)
    # VALID — extract TEST_COMMAND / E2E_COMMAND / E2E_OPT_OUT and proceed
    ;;
  2|3|4|1)
    # Schema error / runtime error → e2e_validation.status = "error"
    ;;
  5)
    # MISSING_BLOCK — grace-period implicit opt-out (one release)
    # Post-grace, treat as error
    ;;
esac
```

```
# Lint stderr on a multi-violation file (pack missing test_command AND using a typo):
[aod-stack-contract] stacks/my-pack/STACK.md:312: ERROR: test_command is required
See: docs/stacks/TEST_COMMAND_CONTRACT.md#test-command
[aod-stack-contract] stacks/my-pack/STACK.md:314: ERROR: unknown key 'e2e_comand' — did you mean 'e2e_command'?
See: docs/stacks/TEST_COMMAND_CONTRACT.md#allowed-keys

# Exit code: 2 (lowest of 2 and 4)
```

#### Required Elements

1. **Author-facing surface**: Fenced YAML block bracketed by HTML sentinel comments inside an existing human-readable document (contract co-located with prose, no new files).
2. **Minimal schema**: One required field + XOR-between-two-alternatives (distinguish have-it / explicitly-don't / forgot). Unknown-key check prevents silent typos.
3. **Stable exit-code taxonomy**: Numeric codes with documented stability guarantee. Range-based branching in consumers (e.g., "any code in 2–4 is a schema error").
4. **Compiler-diagnostic stderr format**: `<file>:<line>: <SEVERITY>: <message>` for GitHub Actions annotator parity.
5. **Multi-violation resolution rule**: Single-pass reporting with numerically-lowest exit code. Consumers branch on ranges; all violations visible in CI logs.
6. **Bash-3.2 compatibility**: No JSON parsing in the hot path; no external tools beyond POSIX `awk`, `grep`, `sed`.
7. **CI enforcement**: `bash:3.2` Docker container mirrors local shell; path filters scope the workflow; SHA-pinned `actions/checkout`; `permissions: contents: read`; `concurrency.cancel-in-progress: true`.
8. **Grace-period discipline** (if backward compat matters): One-release grace as unconditional prose-level branching in the consumer — no runtime feature flag, no version detection. Removal is a one-line diff in a tracked spin-out issue.

#### When to Use

- Kit invariants that must be declared per-pack (testing surface, deployment target, security requirements, supported runtimes)
- Consumer scripts running in bash 3.2 environments (macOS `/bin/bash`)
- Schemas simple enough to express in ≤5 keys with a single XOR rule (if the schema needs nested structures, tuple types, or conditional-requirement logic, upgrade to JSON + `jq` or structured tools)
- Cases where "absence" and "explicit opt-out" must be distinguishable
- Any kit-level invariant that should fail PR-time, not delivery-time

#### When NOT to Use

- Complex schemas with nested objects, arrays of structures, or conditional field dependencies (use JSON Schema + `jq` validation instead)
- Cases where consumers have `jq` available and richer error detail is valuable
- Runtime configuration that changes per-session (this pattern is for static declarations in version-controlled files)
- When no backward-compat burden exists (a hard-flip may be simpler than tracking a grace period)

#### Related Patterns

- [Convention Contract (STACK.md)](#pattern-convention-contract) — this pattern layers a machine-readable contract on top of the prose contract established there
- [Atomic File Write](#pattern-atomic-file-write) — the contract block is static (no runtime state), but `.aod/stack-active.json` which Step 9a reads follows the same atomic-write pattern
- [Non-Fatal Observability Wrapper](#pattern-non-fatal-observability-wrapper) — contract lint errors are non-fatal under the default delivery gate (ADR-006); `--require-tests` flips to hard
- [Directory Allow-List with CI Snapshot Coverage](#pattern-directory-allow-list-with-ci-snapshot-coverage) — same `bash:3.2` Docker CI shell pattern; same GitHub Actions annotator format

---

### Pattern: Layered Design Context Discovery

**Added**: Feature 097 (Design Capabilities Enhancement)
**Rule file**: `.claude/rules/design-context-loader.md`

#### Problem

UI-generating agents need design context (fonts, colors, spacing, aesthetic direction) before writing any visual code. Without a structured discovery process, agents either generate output using banned defaults (Inter font, solid white backgrounds) or load partial context that conflicts with project-specific brand requirements. The challenge is compounded by multiple context sources (brand identity files, archetypes, scaffold tokens, core rules) that may overlap or conflict.

#### Solution

Define a mandatory 5-step discovery sequence that all UI-generating agents execute before writing any HTML, CSS, JSX, TSX, or visual component code. The sequence has a strict precedence order -- when values conflict between sources, higher-precedence sources win:

1. **Brand Identity** (highest): Read `brands/*/brand.md` and `tokens.css`
2. **Archetype**: Load active archetype from `.claude/design/archetypes/`
3. **Stack Pack Tokens**: Load scaffold CSS with `@theme` definitions
4. **Core Rules**: Read `.claude/rules/design-quality.md` and stack-specific supplements
5. **Aesthetic Philosophy**: Answer 4 questions (visual mood, typeface pairing, color temperature, visual density) before writing code

Core rules (layer 4) always apply as minimum standards regardless of higher-layer overrides. The Aesthetic Philosophy step ensures agents articulate design intent rather than picking defaults.

#### Precedence Table

```
brand identity  >  archetype  >  scaffold tokens  >  core rules
(explicit client)  (aesthetic)   (stack baseline)   (minimum standard)
```

#### Example
```
# Agent discovery sequence (before generating any UI code):

# Step 1: Check for brand identity
Read brands/acme-corp/brand.md       # Mood: professional, Font: IBM Plex Sans
Read brands/acme-corp/tokens.css     # --color-primary: oklch(0.45 0.15 250)
Read brands/acme-corp/anti-patterns.md  # No gradients, no rounded corners > 8px

# Step 2: Check for active archetype
# Brand overrides archetype -- skip conflicting values, use archetype
# for any undefined properties (e.g., motion style, shadow depth)

# Step 3: Load stack tokens
Read stacks/nextjs-supabase/scaffold/app/globals.css  # @theme baseline

# Step 4: Load design quality rules (always applies)
Read .claude/rules/design-quality.md

# Step 5: Document Aesthetic Philosophy as code comment
/* Aesthetic: professional | IBM Plex Sans + Geist Mono | cool | balanced */
```

#### When to Use
- Any task that generates or modifies UI components (HTML, CSS, JSX, TSX)
- When multiple design context sources exist in the repository
- Setting up a new project where design direction must be established before code

#### When NOT to Use
- Backend-only tasks, documentation, CLI tools, configuration files
- Projects with a single simple CSS file and no brand or archetype requirements

#### Related Patterns
- [Dual-Surface Injection](#pattern-dual-surface-injection) -- stack pack design supplements are loaded via the same injection mechanism
- [Convention Contract (STACK.md)](#pattern-convention-contract) -- stack-level design conventions are defined in STACK.md; this pattern governs how they are discovered and prioritized
- [Built-in Skill Invocation from a Command](#pattern-built-in-skill-invocation-from-a-command) -- the design quality gate in the build pipeline uses the same opt-out flag convention

---

### Pattern: Brand Identity Override

**Added**: Feature 097 (Design Capabilities Enhancement)
**Example**: `brands/_example/`

#### Problem

Projects need to express a unique visual identity that goes beyond generic design tokens. An archetype provides a starting aesthetic direction, but real-world projects have specific brand colors, forbidden patterns, logo usage rules, and reference imagery that archetypes cannot anticipate. Without a structured brand identity convention, agents either ignore project-specific requirements or require ad-hoc prompting for every UI task.

#### Solution

Define a `brands/{name}/` directory convention with a fixed file structure:

| File | Required | Purpose |
|------|----------|---------|
| `brand.md` | Yes | Brand narrative: mood, voice, visual language, do/don't rules |
| `tokens.css` | Yes | CSS custom properties defining the brand's color, typography, and spacing tokens |
| `anti-patterns.md` | No | Explicit list of things to avoid (specific colors, patterns, layouts) |
| `reference/` | No | Directory of reference images, screenshots, or mood board assets |

Brand identity has the highest precedence in the design context discovery sequence. When `brand.md` specifies a font, it overrides the archetype's font. When `tokens.css` defines `--color-primary`, it overrides scaffold defaults.

The `_example` brand ships as a template that adopters copy and customize. The underscore prefix signals it is a template, not an active brand.

#### Example
```
brands/
  _example/          # Template brand (copy to create your own)
    brand.md         # Brand narrative, mood, typography choices
    tokens.css       # CSS custom properties: --color-primary, --font-heading, etc.
    anti-patterns.md # "Never use: gradients, rounded corners > 8px, emoji in headings"
    reference/       # Logo files, mood board screenshots
  acme-corp/         # Adopter's actual brand
    brand.md
    tokens.css

# Agent behavior when brand exists:
# 1. Read brand.md -> extract mood, font choices, color direction
# 2. Read tokens.css -> load exact token values
# 3. Read anti-patterns.md -> load constraints
# 4. Apply brand values, falling back to archetype/scaffold for undefined properties
```

#### When to Use
- Projects with an established visual brand that agents must respect
- Multi-brand projects where different products share the same codebase
- When adopters need a structured way to communicate design requirements to agents

#### When NOT to Use
- Early-stage projects where brand identity has not been defined (use archetypes instead)
- Non-visual projects (CLI tools, APIs, backend services)
- When design tokens are managed entirely by an external design system (e.g., Figma tokens plugin)

#### Related Patterns
- [Layered Design Context Discovery](#pattern-layered-design-context-discovery) -- brand identity is the highest-precedence layer in the discovery sequence
- [Convention Contract (STACK.md)](#pattern-convention-contract) -- similar "fixed file structure" approach applied to stack conventions; this pattern applies it to visual brand identity

---

### Pattern: Grep-Based Build Quality Gate

**Added**: Feature 097 (Design Capabilities Enhancement)
**ADR**: [ADR-011](../02_ADRs/ADR-011-multi-flag-opt-out-and-step-insertion-pattern.md)

#### Problem

Design quality standards (banned fonts, spacing rules, shadow limits) are codified in rule files that agents read at generation time, but agents do not always comply -- they may fall back to defaults under context pressure, or a human developer may edit UI files without loading the design rules. There is no automated detection layer to catch regressions before code reaches a pull request.

#### Solution

Add a detection layer as a numbered step in the `/aod.build` pipeline (Step 6: Design Quality Gate) that runs grep-based checks on UI files changed on the feature branch. The gate uses simple `grep` / `git diff` commands rather than a dedicated linting tool, keeping the dependency footprint at zero.

The gate runs 4 checks:

| Check | Method | Pass Criteria |
|-------|--------|---------------|
| Font compliance | Grep for banned font names as primary declarations | Zero occurrences |
| Spacing compliance | Grep for arbitrary Tailwind values (`[Npx]`, `[Nrem]`) | Zero occurrences |
| Shadow count | Count distinct `--shadow-*` custom property definitions | 5 or fewer levels |
| Reduced motion | Grep for `motion-safe:` / `motion-reduce:` / `prefers-reduced-motion` | Present if animations exist |

The gate follows the multi-flag opt-out pattern (ADR-011): it runs by default and can be skipped with `--no-design-check`. It only executes when UI files (`.css`, `.jsx`, `.tsx`, `.html`) are present in the branch diff, avoiding false triggers on backend-only changes.

Results flow to a user decision point: Pass (proceed), Findings (fix / acknowledge / abort).

#### Example
```
# In aod.build Step 6:

# Pre-check: any UI files changed?
git diff --name-only main...HEAD | grep -E '\.(css|jsx|tsx|html)$'
# No matches -> skip gate, proceed to Step 7

# Check 1: Font compliance
git diff main...HEAD -- '*.css' '*.jsx' '*.tsx' | grep -iE \
  'font-family:.*\b(Inter|Roboto|Arial|Open Sans|Lato)\b'
# Any match -> finding

# Check 2: Spacing compliance
git diff main...HEAD -- '*.css' '*.jsx' '*.tsx' | grep -E \
  '\[[0-9]+(px|rem)\]'
# Any match -> finding

# Check 3: Shadow count
grep -roh -- '--shadow-[a-z]*' changed_files | sort -u | wc -l
# > 5 -> finding

# Check 4: Reduced motion
grep -rl 'transition\|animation\|@keyframes' changed_files | while read f; do
  grep -l 'motion-safe\|motion-reduce\|prefers-reduced-motion' "$f" || echo "$f: missing"
done
```

#### When to Use
- Build pipelines that need lightweight design quality enforcement without external tooling
- Projects using the AOD design system (design-quality.md rules, archetypes, brand identity)
- When a zero-dependency detection layer is preferred over a full CSS linter

#### When NOT to Use
- Projects using dedicated design linting tools (Stylelint with design token plugins, etc.)
- Backend-only projects with no UI files
- When the build pipeline already has a comprehensive CSS/design validation step

#### Related Patterns
- [Built-in Skill Invocation from a Command](#pattern-built-in-skill-invocation-from-a-command) -- the design quality gate follows the same opt-out flag convention (`--no-design-check`) documented in this pattern
- [Layered Design Context Discovery](#pattern-layered-design-context-discovery) -- the prevention layer (context loading) complements this detection layer; together they form a two-layer enforcement strategy

---

### Pattern: Directory Allow-List with CI Snapshot Coverage

**Added**: Feature 128 (Directory-Based Extraction Manifest)

#### Problem

A hand-curated per-file manifest that gates what ships from a private source repo to a public template has three compounding failure modes:

1. **Silent omission** — a new agent file added to `.claude/agents/` is not registered in the manifest, so it never ships. Downstream adopters never see the improvement; the bug only surfaces during a cutover sync months later.
2. **Silent inclusion** — a new private PRD (e.g., `docs/product/02_PRD/128-feature.md`) is placed in a directory the maintainer later decides to wildcard-ship. Private content leaks to the public template without maintainer awareness.
3. **Manifest rot** — every feature ships with a three-line manifest edit that the PM-reviewer cannot meaningfully validate against the actual diff. Over time, the manifest accumulates stale entries for files that no longer exist, and reviewers stop scrutinizing it.

Inline heredocs for content-reset templates compound (3) — a refactor regression can silently overwrite the wrong destination with stale inline content because the heredoc body is not reviewable as a standalone artifact in a PR diff.

#### Solution

Replace the hand-curated per-file manifest with three composable mechanisms:

1. **Directory allow-list** — `MANIFEST_DIRS` (top-level directory paths whose contents auto-ship) plus `MANIFEST_ROOT_FILES` (explicit root-level file allow-list). Additions to an already-allow-listed directory require zero manifest edit.
2. **Externalized content-reset templates** — move inline heredocs into standalone files under a template directory (`scripts/reset-templates/`). Register each reset target as a `<destination>:<template-source>` pair. Missing template path halts the pipeline before any destination is written.
3. **CI classification snapshot** — commit a sorted text file (`extract-classification.txt`) recording every git-tracked file's classification (`SHIP`, `EXCL-by-override`, `EXCL-by-construction`). A CI workflow runs a validator (`scripts/check-extract-coverage.sh`) on every PR that computes live classifications from `git ls-files` and diffs against the committed snapshot. Any divergence (new file added, file reclassified) blocks the PR with a compiler-diagnostic error (`extract-classification.txt:N: <message>`). Maintainer remediation: regenerate the snapshot, review the diff, commit as an explicit acknowledgement.

Wrap the whole pipeline in a **five-layer defense bundle** (binary acceptance — any absent layer → unsafe to ship):

| Layer | Mechanism | Failure Mode |
|-------|-----------|--------------|
| (1) Allow-list | `MANIFEST_DIRS` + `MANIFEST_ROOT_FILES` — pre-extract | Non-allow-listed paths never shipped |
| (2) Residual placeholder scan | Post-copy scan for `{{[A-Z_]+}}` markers in shipped files | Compiler-diagnostic stderr + exit 1 |
| (3) Deny-list regex scan | Post-copy scan against inline `DENY_LIST_PATTERNS` (project markers + maintainer-username pattern, LICENSE excluded) | Compiler-diagnostic stderr + exit 1 |
| (4) Safe-path assert | Reject `..`, absolute, `~`, `.`, and symlink entries for all template references | Exit 1 within 1 s, no destination written |
| (5) Fail-loud template existence | Missing content-reset template halts before any destination write | Exit 1 within 1 s (SC-010) |

The CI snapshot check provides an additional independent gate — Layer (4) in spatial sense (it runs outside the extraction pipeline, in CI) — so the five-layer in-pipeline bundle cannot silently degrade between maintainer workstation runs.

#### Example

Manifest declarations in `scripts/extract.sh`:

```bash
MANIFEST_DIRS=(
    ".aod/scripts"
    ".aod/templates"
    ".claude"
    "brands"
    "docs/architecture"
    "docs/core_principles"
    "docs/devops"
    "docs/guides"
    "docs/product"
    "docs/standards"
    "docs/testing"
    "stacks"
)

MANIFEST_ROOT_FILES=(
    ".env.example"
    ".extractignore"
    ".gitattributes"
    ".gitignore"
    "CHANGELOG.md"
    "CLAUDE.md"
    "CONTRIBUTING.md"
    "LICENSE"
    "MIGRATION.md"
    "Makefile"
    "README.md"
)

CONTENT_RESET_FILES=(
    "docs/INSTITUTIONAL_KNOWLEDGE.md:scripts/reset-templates/IK.md"
    "docs/product/02_PRD/INDEX.md:scripts/reset-templates/PRD_INDEX.md"
)

DENY_LIST_PATTERNS=(
    # Project markers, maintainer-username pattern, etc.
)
```

Classification snapshot (`scripts/extract-classification.txt`):

```
EXCL-by-construction  .aod/archive/some-old-feature.md
EXCL-by-construction  .aod/closures/feature-100.md
EXCL-by-override      docs/product/02_PRD/128-directory-based-extraction-manifest-2026-04-20.md
SHIP                  .claude/agents/architect.md
SHIP                  CHANGELOG.md
SHIP                  CLAUDE.md
SHIP                  docs/standards/DEFINITION_OF_DONE.md
```

CI workflow (`.github/workflows/extract-coverage.yml`, SHA-pinned `actions/checkout`, `permissions: contents: read`, `concurrency.cancel-in-progress: true`):

```yaml
jobs:
  check-extract-coverage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA>  # SHA-pinned
      - name: Validate extraction coverage (bash 3.2)
        run: docker run --rm -v "$PWD:/w" -w /w bash:3.2 scripts/check-extract-coverage.sh
```

Maintainer remediation loop (<5 min target):

```bash
make extract-classify                         # regenerate snapshot
git diff scripts/extract-classification.txt   # review every change
git add scripts/extract-classification.txt    # explicit acknowledgement
git commit -m "chore: refresh extract-classification.txt for <reason>"
```

#### When to Use

- Pipelines that gate what ships from a private source to a public surface (templates, docs, SDKs)
- Any scenario where "adding a new file" is the common operation and "re-curating an allow-list" is the rare operation
- When a reviewer needs an auditable, diffable snapshot of what the pipeline will do
- When the cost of a private-data leak is high enough to warrant a bundle of independent defenses

#### When NOT to Use

- Simple one-shot builds with no gating requirement (no private data to protect)
- Pipelines where every shipped file already corresponds to a build artifact that must be explicitly named (no "auto-ship" semantic)
- Small repos (<50 tracked files) where a per-file manifest is not a review burden
- Short-lived projects where the CI gate overhead outweighs the drift-detection benefit

#### Files Using This Pattern

| File | Role |
|------|------|
| `scripts/extract.sh` | Manifest engine — declares `MANIFEST_DIRS`, `MANIFEST_ROOT_FILES`, `CONTENT_RESET_FILES`, `DENY_LIST_PATTERNS`; implements the 5-layer defense pipeline |
| `scripts/check-extract-coverage.sh` | Bash 3.2 validator — computes live classifications, diffs against snapshot |
| `scripts/extract-classification.txt` | Committed sorted snapshot |
| `scripts/reset-templates/IK.md` | Externalized content-reset template body |
| `scripts/reset-templates/PRD_INDEX.md` | Externalized content-reset template body |
| `.github/workflows/extract-coverage.yml` | CI gate — runs validator in `bash:3.2` Docker step |
| `.extractignore` | Subtractive overlay — gitignore-style globs, no negation (FR-033) |
| `Makefile` (`extract-check`, `extract-classify` targets) | Local validator + snapshot regenerator |

#### Related Patterns

- [Atomic File Write (Write-Then-Rename)](#pattern-atomic-file-write) — the snapshot regenerator writes atomically to avoid mid-write corruption
- [Grep-Based Build Quality Gate](#pattern-grep-based-build-quality-gate) — similar "detection layer in CI" philosophy, applied to design quality; both favor zero-dependency shell validators over dedicated linting tools
- [Read-Only Dry-Run Preview](#pattern-read-only-dry-run-preview) — `extract.sh --dry-run` and `/aod.sync-upstream --dry-run` follow the same preview-before-write discipline

---

### Pattern: Deterministic Authorization (No LLM in Authorization Path)

**Added**: Feature 139 (Delivery Means Verified, Not Documented)
**ADR**: [ADR-013](../02_ADRs/ADR-013-delivery-verification-first.md)
**Delivered**: 2026-04-23 (PR #149)

#### Problem

A bounded auto-fix loop wants to repair failing tests by applying small, mechanical diffs proposed by an LLM agent (e.g., a tester in `mode: heal`). The moment the **authorization** decision ("should I apply this diff?") routes through an LLM, retry pressure and prompt-injection-from-test-output can coax the loop into accepting progressively weaker diffs — deleting assertions, adding `.skip`, inflating timeouts to bypass flakes, or commenting out whole scenarios — until the suite "passes." A self-healing gate that can weaken its own verification is indistinguishable from a broken gate.

The core risk: any stochastic input in the authorization path means the same adversarial diff could be allowed on Tuesday and rejected on Wednesday. There is no stable invariant to test against, so fixture-based regression coverage samples a distribution rather than asserting a property.

#### Solution

Split **proposal** from **authorization**. Let an LLM propose diffs; force authorization through a **closed set of deterministic rules** operating on the unified diff as text, with fixture-verified invariants.

Three composable mechanisms:

1. **Closed rule set on the diff** — a small, static list of rules (ideally ≤ 10) expressed as regex-level checks over the hunks. Rules target adversarial patterns: no assertion deletion, no scenario skipping, no timeout inflation beyond a capped multiplier, no file paths outside an allow-list, no whole-scenario removal.
2. **Fixture-verified invariant** — ship ≥ N positive fixtures (legitimate diffs that MUST be allowed) and ≥ N negative fixtures (adversarial diffs that MUST be rejected). The test harness asserts 100% agreement between the rule evaluator and the expected verdict. The invariant: **identical input diff → identical verdict, every time.**
3. **Escalation on rejection, not retry-within-scope** — when a proposed diff is rejected, the loop escalates (e.g., opens a draft PR with a review label) rather than re-prompting the LLM for "a different fix." This prevents the LLM from searching diff-space for a rule-bypassing variation.

A parallel enforcement tripwire keeps escalated artifacts out of the automation path. In the 139 implementation, `grep -r 'gh pr merge' .claude/skills/` asserts at CI time that no skill can auto-merge a PR labeled `e2e-heal`; the authorization boundary and the merge boundary are independently enforced.

#### Example

From `.aod/scripts/bash/scope-guard.sh` (Feature 139 — 5-rule closed set):

```bash
# Rule R1: test-paths-only — every changed file must match test_paths allow-list
# Rule R2: no-deletion — no hunk removes an assert/expect/cy.should/test.expect
# Rule R3: timeout-multiplier — numeric timeout increases capped at 2x existing
# Rule R4: no-skip — no .skip/.only/@ignore/xit/xdescribe/pytest.mark.skip added
# Rule R5: no-scenario-removal — no whole Given/When/Then or test(...) block deleted

evaluate_scope_guard() {
  local diff_file="$1"
  local test_paths="$2"

  # Each rule returns "ALLOWED" or "REJECTED:<reason>"
  check_rule_r1_test_paths "$diff_file" "$test_paths" || return 1
  check_rule_r2_no_deletion "$diff_file" || return 1
  check_rule_r3_timeout_multiplier "$diff_file" || return 1
  check_rule_r4_no_skip "$diff_file" || return 1
  check_rule_r5_no_scenario_removal "$diff_file" || return 1

  echo "ALLOWED"
}
```

Fixture-verified invariant from `tests/unit/scope-guard.test.sh`:

```bash
# 10 positive fixtures — legitimate heal diffs MUST be allowed
for fixture in tests/fixtures/scope-guard/positive/*.diff; do
  result=$(evaluate_scope_guard "$fixture" "tests/**/*.spec.ts")
  assert_equals "ALLOWED" "$result" "positive fixture $(basename $fixture)"
done

# 10 negative fixtures — adversarial diffs MUST be rejected
for fixture in tests/fixtures/scope-guard/negative/*.diff; do
  result=$(evaluate_scope_guard "$fixture" "tests/**/*.spec.ts")
  assert_match "^REJECTED:" "$result" "negative fixture $(basename $fixture)"
done
```

#### When to Use

- Auto-fix / auto-heal / auto-remediation loops that must not silently degrade the verification they are healing
- Any agentic loop where the same input should produce the same authorization decision across runs
- Security-sensitive approval paths (access grants, code signing, deployment authorization) where the authorization surface must be auditable in ≤ 200 lines
- Loops running under retry pressure where an LLM judge could be worn down into successive concessions

#### When NOT to Use

- Open-ended creative tasks (proposal-only flows, content generation, design exploration) where "authorization" is really "selection" and a rule-based approach would be too restrictive
- Judgment calls with unbounded adversarial surface (subjective code review, style assessment) where enumerating static rules is impractical
- One-shot flows with no retry mechanism — the adversarial surface from retry pressure is what motivates determinism

#### Related Patterns

- [Append-Only Logging with Graceful Failure](#pattern-append-only-logging) — every authorization decision (allow/reject + reason) can be logged via the same line-atomic JSONL pattern
- [Non-Fatal Observability Wrapper](#pattern-non-fatal-observability-wrapper) — observability around authorization is non-fatal; the decision itself is transactional
- [Subshell Isolation for Strict Shell Options](#pattern-subshell-isolation-for-strict-shell-options) — rule functions can run under `set -euo pipefail` in subshells to fail fast on malformed diffs without aborting the parent loop

---

### Pattern: Three-Channel Halt Protocol

**Added**: Feature 139 (Delivery Means Verified, Not Documented)
**ADR**: [ADR-013](../02_ADRs/ADR-013-delivery-verification-first.md)
**Delivered**: 2026-04-23 (PR #149)

#### Problem

A long-running orchestration (wave batch, CI pipeline, multi-feature delivery loop) needs to detect a downstream halt — a hard stop where human review is required before proceeding. Different orchestration surfaces observe different signals:

- A shell-wrapper orchestrator branches on **exit codes**.
- A GitHub Actions wrapper reads **structured state files**.
- A terminal-tailing supervisor greps **stdout lines**.

If the halting skill emits only one signal, orchestrators built on other surfaces either miss halts silently (the most damaging outcome — a next-wave feature launches despite a blocking review) or have to fabricate fragile post-hoc detection (document scraping, PR-state polling, log mining).

A single-channel signal also degrades poorly. If the one channel is the file and the disk is full, the halt is lost entirely.

#### Solution

Emit halts through **three independent channels simultaneously**, each observable via different infrastructure, with a **core invariant** that survives partial degradation:

| Channel | Surface | Format | Orchestrator Consumer |
|---------|---------|--------|----------------------|
| **1. stdout** | Terminal / CI log | Fixed-regex line: `^Halted — .* requires human review$` | `awk` / `grep` tailing |
| **2. File** | Filesystem state dir | Atomic write-then-rename JSON (schema-validated) | `jq` parse after invocation |
| **3. Exit code** | Process exit | Additive numeric code in a reserved decade (e.g., 10 for HALT_FOR_REVIEW) | Bash `case` block on `$?` |

**Core invariant**: a non-zero exit code always accompanies halt. Channels 1 and 2 can degrade (terminal lost, disk full, `jq` absent) without breaking the invariant. Orchestrators that check only the exit code can always branch correctly, even when the richer channels are unavailable.

**Graceful degradation** (borrowing the non-fatal observability pattern): if Channel 2 cannot be written (`.aod/state/` unwritable, `jq` missing), emit a stderr notice and continue with Channels 1 + 3. On disk-full, the halt may devolve to generic exit code 1 (runtime error) instead of the structured halt code — orchestrators see a generic failure, escalate accordingly, and no halt is silently lost.

**Exit code policy**: reserve a decade (10-19, 20-29, …) per-skill so codes never collide across the kit. Adding new codes within a decade is permitted; repurposing existing codes is forbidden. Orchestrators branch on **ranges** (`case` arms over `10|11|12`), not exact equality, so adding code 13 in a future release costs one `case` arm and no reader changes.

#### Example

From `.aod/scripts/bash/halt-signal.sh` (Feature 139):

```bash
emit_halt_signal() {
  local feature="$1"
  local heal_pr_url="$2"
  local reason="$3"

  # Channel 1: stdout (fixed regex, awk-parseable)
  printf 'Halted — heal-PR %s requires human review\n' "$heal_pr_url"

  # Channel 2: file (atomic write-then-rename, jq-parseable)
  # Graceful degradation — if this fails, Channels 1+3 still fire
  local state_dir=".aod/state"
  local halt_file="${state_dir}/deliver-${feature}.halt.json"
  local tmp_file="${halt_file}.tmp"

  if mkdir -p "$state_dir" 2>/dev/null; then
    if jq -c -n \
      --arg ts "$(date -u +%FT%TZ)" \
      --arg feature "$feature" \
      --arg url "$heal_pr_url" \
      --arg reason "$reason" \
      '{timestamp: $ts, feature: $feature, heal_pr_url: $url, reason: $reason, recovery_status: "awaiting_review"}' \
      > "$tmp_file" 2>/dev/null && mv "$tmp_file" "$halt_file" 2>/dev/null; then
      : # halt file written successfully
    else
      printf '[halt-signal] Channel 2 degraded: halt record could not be written\n' >&2
    fi
  fi

  # Channel 3: exit code (the last-line invariant)
  exit 10  # HALT_FOR_REVIEW
}
```

Orchestrator branching (any channel works):

```bash
# Preferred: exit code + file pair
/aod.deliver --autonomous
result=$?
if [ "$result" -eq 10 ]; then
  heal_pr=$(jq -r '.heal_pr_url' ".aod/state/deliver-${NNN}.halt.json" 2>/dev/null || echo "unknown")
  dispatch_to_review_queue "$heal_pr"
fi

# Fallback: stdout tailing
/aod.deliver --autonomous 2>&1 | awk '/^Halted — heal-PR .* requires human review$/ {print; exit 0}'

# Minimal: exit code only
/aod.deliver --autonomous
case $? in
  0)       echo "delivered" ;;
  10|11|12) handle_halt ;;
  *)       handle_generic_failure ;;
esac
```

#### Required Elements

1. **Three independent surfaces**: stdout line, atomic state file, exit code — each observable without the others
2. **Stable stdout line format**: fixed regex, no template variables in the signal token, anchored with `^` and `$`
3. **Atomic file write**: write-then-rename via `mv` so readers never see a partial JSON
4. **Schema-validated file content**: strict JSON (jq-parseable), documented in a versioned contract so orchestrators can migrate
5. **Reserved exit-code decade**: additive, range-based branching, no repurposing, gap-left between decades for natural expansion
6. **Core invariant**: non-zero exit code always accompanies halt; Channels 1 & 2 may degrade without breaking this
7. **Graceful degradation path**: Channel 2 write failures are logged to stderr (non-fatal) and do not abort the halt — Channel 1 + Channel 3 carry the signal

#### When to Use

- Long-running orchestrations that call out to gate-style skills (delivery, deployment, security review) where a halt means "stop the wave, wait for human review"
- Any skill consumed by heterogeneous orchestrators (CLI, CI wrapper, terminal supervisor) where single-channel signaling would force orchestrator-specific adaptation
- Scenarios where a missed halt is strictly worse than a redundant halt (integrity-critical gates, compliance workflows, release pipelines)

#### When NOT to Use

- Interactive-only skills where the human operator is always observing the terminal — stdout alone suffices
- Skills that never halt (transparent data transforms, pure query tools) — the machinery has no payload
- Environments where exit codes cannot be controlled (embedded interpreters that squash sub-process codes) — the core invariant cannot hold and the pattern degrades to best-effort

#### Related Patterns

- [Atomic File Write (Write-Then-Rename)](#pattern-atomic-file-write) — Channel 2's halt-record write uses this pattern; readers never see partial state
- [Non-Fatal Observability Wrapper](#pattern-non-fatal-observability-wrapper) — Channel 2 write failures follow the non-fatal semantics (stderr notice, continue)
- [Append-Only Logging with Graceful Failure](#pattern-append-only-logging) — same graceful-failure philosophy applied to audit logs
- [Declarative Test Contract with Stable Exit-Code Taxonomy](#pattern-declarative-test-contract) — establishes the exit-code stability guarantee and range-based branching discipline that this pattern extends

---

### Pattern: Anti-Rationalization Tables — Behavioral Primer for Agent-Loaded Files

**Added**: Feature 158 (Anti-Rationalization Tables for AOD Command/Skill Files)
**Source**: Adapted from [addyosmani/agent-skills `docs/skill-anatomy.md`](https://github.com/addyosmani/agent-skills/blob/main/docs/skill-anatomy.md)

#### Problem

Agent-invoked governance flows (AOD commands and skills) are prose primers loaded fresh on every `/<command>` invocation. The agent reads top-to-bottom and constructs an execution plan. Mid-flow, when context pressure rises or a step looks tedious, the agent can rationalize a shortcut — "I already validated this in the prior step," "the adopter probably wants me to skip the architect review," "the test suite is flaky, I'll mark them all skipped." These shortcuts are not visible in the trace until they cause a downstream failure (an empty artifact, a missing gate, a surprising delivery report). Reviewer audit becomes "did the agent reconstruct the ideal flow?" rather than "do any of these specific behaviors appear?" — which does not scale beyond personal session memory.

The core tension: governance flows need to be readable enough that an agent grasps them, but readability alone is not a behavioral defense. A list of "do this, then this" is silent on the narratives the agent might construct to do something else.

#### Solution

Add two new H2 sections to every agent-loaded governance file — `## Common Rationalizations` (2-column markdown table) and `## Red Flags` (markdown bullet list) — that prime the agent at invocation time with file-specific shortcut narratives and concrete consequences, plus an observable-behavior checklist for reviewer audit.

The Rationalizations table pairs a first-person quoted shortcut narrative (column 1) with a concrete-consequence rebuttal (column 2). The agent reads both columns at load time. When mid-flow it considers the shortcut, the loaded primer already named it and named what would actually fail. The Red Flags list is for reviewers — externally-observable behaviors they can mechanically scan a trace against, no agent-mind-reading required.

The pattern works because **the rebuttal is loaded before the temptation arises**. Agents do not read prose linearly under pressure; they re-scan for relevant fragments. A rationalization labelled in the loaded file becomes pattern-matchable when the agent considers the same shortcut later.

Two additional content rules emerge:

1. **Concrete consequences only, no appeal-to-authority**. Reality columns must cite a gate name, file path, exit code, downstream command, step number, or named artifact — not "the docs say…" or "best practice is…". Authority phrases collapse under context pressure; concrete consequences do not.
2. **Layer split** (commands host invocation-level rationalizations: flags, modes, routing, arguments; skills host execution-level rationalizations: steps, gates, sign-offs, artifacts). Mixing layers creates verbatim duplicates that erode the primer's specificity. The split is enforced by a post-bundle dedupe pass.

#### Example

A command file (invocation-level — `.claude/commands/aod.spec.md`):

```markdown
## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll fill in the [NEEDS CLARIFICATION] markers later" | Markers fail validation at /aod.spec Step 3.4 Quality Validation (.claude/commands/aod.spec.md:177); spec is not ready if any remain. Resolve now or run /aod.clarify. |
| "I already know what to build, the spec is just paperwork" | Without a PM-signed spec, /aod.project-plan refuses to run; you'll re-author the spec under deadline pressure. |

## Red Flags

- Agent generates spec content without reading the source PRD frontmatter.
- Agent leaves [NEEDS CLARIFICATION] markers in the spec and proceeds to /aod.project-plan anyway.
- Agent fabricates Acceptance Criteria without Given/When/Then structure.
```

A peer skill file (execution-level — `.claude/skills/~aod-spec/SKILL.md`) hosts complementary execution-level Rationalizations (e.g., "the spec already has these sections, I don't need to validate") — never verbatim duplicates of the command-layer entries.

#### Verification (POSIX-portable forward-CI contract)

The pattern ships with a **stable forward-contract** so any future Phase 2 CI gate is cheap to add. Two POSIX-portable checks per section work on BSD grep (macOS), GNU grep (Linux/CI), and BusyBox without requiring PCRE / `-P` / `-z`:

```bash
# Coverage: every in-scope file contains the H2 header on its own line
grep -L "^## Common Rationalizations$" <files>   # expect empty output
grep -L "^## Red Flags$" <files>                  # expect empty output

# Anchor: every H2 header is followed by exactly one blank line
awk '/^## Common Rationalizations$/ { getline n; if (n != "") print FILENAME ": no anchor" }' <file>
awk '/^## Red Flags$/ { getline n; if (n != "") print FILENAME ": no anchor" }' <file>
```

The grep `-L` flag (lists files lacking the pattern) plus a 4-line `awk` one-liner cover the entire format contract. No PCRE multi-line lookups, no `-z` null-byte mode, no compiled regex tooling. F158's plan-phase architectural decision (AD-003) explicitly rejected `grep -Pzo` because BSD grep on macOS does not support `-P` — the original spec-phase draft would have failed silently for macOS adopters running the audit locally.

#### Authoring discipline (lessons from F158 build)

The bundle's 4-5.5 hour single-author session surfaced **three drift instances** caught by the layered defense:

| Drift | Caught by | Mitigation that worked |
|---|---|---|
| 35 voice-cap MINOR violations (Reality > 25 words) on 11 command files | Architect spot-check at commands→skills boundary (FR-009 / AD-007) | Strategy A semicolon-pivot at offending cells; D-001 rows preserved verbatim |
| 1 verbatim cross-file Rationalization duplicate | FR-007 dedupe one-liner (`sort \| uniq -d` over extracted quotes) | Skill-side specialized; command-side preserved per layer split |
| 4 banned-phrase ("best practice") occurrences | Wave 6 banned-phrase grep | Reworded to bypass literal grep while preserving citation power |

The lesson: a **single-author bundle of similar content always drifts**. The mitigation is layered — per-file pre-commit grep self-check + boundary-line architect spot-check + bundle-level grep audits — not any single check on its own. Plan upgraded the citation-drift base rate from Medium → High after observing one drift instance per governance phase; build confirmed the High rate.

#### When to Use

- Agent-invoked governance flows where the loaded prose IS the behavioral spec — AOD commands, skills, agent personas.
- Files large enough (200+ lines) that mid-flow context pressure could realistically lead the agent to construct a shortcut narrative.
- Domains with concrete consequences (named gates, exit codes, file paths) that can be cited without invoking authority.
- Bundles ≥10 files where reviewer audit benefits from a shared observable-behavior checklist.

#### When NOT to Use

- Persona definition files (`.claude/agents/*.md`) — they describe *who* the agent is, not *what flow* it executes; rationalizations have no procedural anchor.
- Pure reference docs (`docs/architecture/`, `docs/standards/`) — readers consult these on demand; they are not loaded into an agent's working context for execution.
- Files with no concrete-consequence citations available — if every Reality column would have to say "best practice is…", the file is too abstract for the pattern to deliver value.
- Internal tooling scripts — bash scripts, `.aod/scripts/bash/*.sh` — the runtime is execution, not interpretation; rationalization narratives have no semantic foothold there.
- Stack-pack-specific or adopter-application files — F158 deliberately scopes to the 18 AOD-internal governance files; expanding beyond is a separate PRD per F158 Out of Scope.

#### Related Patterns

- [Grep-Based Build Quality Gate](#pattern-grep-based-build-quality-gate) — the forward-CI contract follows the same zero-dependency-grep-detection philosophy; if a Phase 2 CI gate ships for F158, it slots into the build pipeline using this pattern's structure.
- [Minimal-Return Subagent](#pattern-minimal-return-subagent) — the architect spot-check (FR-009 / AD-007) at the commands→skills boundary uses minimal-return semantics so the spot-check itself does not bloat the build context.
- [Governed Skill Phase Loop](#pattern-governed-skill-phase-loop) — the sequential single-author execution constraint (FR-006 / AD-001) is a phase-loop variant: zero parallel waves on file-edit tasks for content-cohesion preservation.

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
