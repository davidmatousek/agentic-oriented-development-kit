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

### Skill Patterns (AOD Kit)
- [On-Demand Reference File Segmentation](#pattern-on-demand-reference-file-segmentation)
- [Compound State Helpers](#pattern-compound-state-helpers)
- [Governance Result Caching](#pattern-governance-result-caching)
- [Read-Only Dry-Run Preview](#pattern-read-only-dry-run-preview)
- [Dual-Surface Injection](#pattern-dual-surface-injection)

### Command Patterns (AOD Kit)
- [Orchestrator-Awareness Guard](#pattern-orchestrator-awareness-guard)
- [Non-Fatal Observability Wrapper](#pattern-non-fatal-observability-wrapper)
- [Built-in Skill Invocation from a Command](#pattern-built-in-skill-invocation-from-a-command)

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
- `--no-simplify`: Skip the code simplification step (Step 6)

## Steps

...

### Step 6: Code Simplification (skip if --no-simplify)
Invoke the /simplify skill to reduce complexity and improve readability of
any files modified during this build session.
- If `--no-simplify` flag is present: skip this step entirely, log "Simplification skipped (--no-simplify)"
- Otherwise: Use the Skill tool to invoke `/simplify` on changed files
```

```markdown
# In CLAUDE.md commands section
/aod.build [--no-simplify]  # Execute with auto architect checkpoints; --no-simplify skips code simplification step
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
