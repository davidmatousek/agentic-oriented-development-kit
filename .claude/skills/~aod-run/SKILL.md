---
name: ~aod-run
description: Full lifecycle orchestrator that chains all 5 AOD stages (Discover, Define, Plan, Build, Deliver) with disk-persisted state for session resilience and governance gates at every boundary. Use this skill when you need to run the full lifecycle, orchestrate stages, resume orchestration, or check orchestration status.
---

# Full Lifecycle Orchestrator Skill

## Purpose

Single-command lifecycle orchestrator that chains all 5 AOD stages autonomously, pausing at governance gates for Triad sign-offs and persisting state to disk for session resilience.

**Entry Points**:
- Raw idea: `"description"` → start at Discover
- Issue number: `#NNN` or `NNN` → resume from issue's current stage
- Resume: `--resume` → continue from last state checkpoint
- Status: `--status` / `--status #NNN` → read-only display

**State File**: `.aod/run-state.json` (atomic write-then-rename via `run-state.sh`)

## Navigation

| Section | Purpose | Location |
|---------|---------|----------|
| [Step 1: Route by Mode](#step-1-route-by-mode) | Entry point routing | This file |
| [Step 2: Core State Machine Loop](#step-2-core-state-machine-loop) | Central orchestration logic | This file |
| [Plan Substage Tracking](#plan-substage-tracking) | Spec → project_plan → tasks | This file |
| [Stage Skill Mapping](#stage-skill-mapping) | Stage-to-skill invocation table | This file |
| [Post-Stage Context Extraction](#post-stage-context-extraction) | Artifact discovery after each stage | This file |
| [Stage Map Display](#stage-map-display) | Visual progress indicators | This file |
| [Transition Messages](#transition-messages) | Stage transition headers | This file |
| [GitHub Integration](#github-integration) | Label updates after stage completion | This file |
| [Error Logging](#error-logging) | Error/event capture in state file | This file |
| Governance Gate Detection | Reading approval/rejection from frontmatter | `references/governance.md` |
| Governance Tier | Light/Standard/Full gate rules | `references/governance.md` |
| Rejection / Retry / Circuit Breaker / Blocked | Governance result handling | `references/governance.md` |
| New Idea / Issue / Resume / Status Entry | Mode-specific handlers | `references/entry-modes.md` |
| Dry-Run Entry | `--dry-run` preview handler (read-only) | `references/dry-run.md` |
| Corrupted State / Lifecycle Complete | Error and completion handlers | `references/error-recovery.md` |

## Execution

When this skill is invoked, the command file passes a parsed mode and arguments:

```
Mode: {idea | issue | resume | status}
Issue: {number or "none"}
Idea: {text or "none"}
DryRun: {true or false}
```

### Step 1: Route by Mode

Read the mode and DryRun flag from the invocation context. Route to the appropriate handler:

**DryRun + Status check (first)**: If `DryRun == true` AND `Mode == status`, display `"Note: --status is already read-only. --dry-run flag ignored."` and route to Status Entry as normal.

**DryRun check (second)**: If `DryRun == true` (and Mode is NOT `status`):

**MANDATORY**: You MUST use the Read tool to load `references/dry-run.md` before proceeding with dry-run handling. Do NOT rely on memory of prior dry-run content. If the file cannot be read, display an error and STOP.

Follow the Dry-Run Entry instructions from that file. The Dry-Run Entry handler will perform read-only detection and display a preview, then exit without entering the Core Loop.

**Mode routing (if DryRun is false)**:

**MANDATORY**: You MUST use the Read tool to load `references/entry-modes.md` before proceeding with any entry mode handler. Do NOT rely on memory of prior entry mode content. If the file cannot be read, display an error and STOP.

| Mode | Handler | Description |
|------|---------|-------------|
| `idea` | New Idea Entry (in entry-modes.md) | Create initial state, start at Discover |
| `issue` | Issue Entry (in entry-modes.md) | Read GitHub Issue, create/load state, resume |
| `resume` | Resume Entry (in entry-modes.md) | Load state file, validate, continue |
| `status` | Status Entry (in entry-modes.md) | Read-only display, then exit |

After the entry handler sets up state, all modes (except `status`) converge to the **Core Loop**.

### Step 2: Core State Machine Loop

This is the central orchestration logic. It runs after any entry handler has established or loaded state.

**Loop algorithm**:

1. **Read loop context**: Use Bash to read loop context via `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_get_loop_context'` — returns `{stage}|{substage}|{stage_status}` (e.g., `plan|spec|in_progress`). Parse the pipe-delimited result. **Do NOT use `aod_state_read` here** — the compound helper extracts only the 3 fields needed for routing.
2. **Check completion**: If stage_status from step 1 indicates all stages may be complete, verify by checking all 5 stage statuses via `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_get_multi ".stages.discover.status" ".stages.define.status" ".stages.plan.status" ".stages.build.status" ".stages.deliver.status"'`. If all show `completed`, **MANDATORY**: You MUST use the Read tool to load `references/error-recovery.md`, then follow the Lifecycle Complete instructions. Do NOT rely on memory of prior error-recovery content. If the file cannot be read, display an error and STOP.
3. **Determine next stage**: Use the `current_stage` and `stage_status` from step 1. If status is `"completed"`, advance to the next stage in sequence: `discover` → `define` → `plan` → `build` → `deliver`
4. **Handle Plan substages**: If `current_stage` is `plan`, use the `substage` from step 1 and cycle through `spec` → `project_plan` → `tasks`. Only advance past Plan when all 3 substages complete. **When advancing between substages, apply context boundary** (see Plan Substage Tracking step 3a) to clear previous substage content and retain only approval metadata.
5. **Write pre-stage checkpoint**: Update state with `current_stage` status = `"in_progress"` and current timestamp. Write atomically via `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_write '"'"'<json>'"'"''`.
6. **Display stage map**: Show current progress (see [Stage Map Display](#stage-map-display))
7. **Display transition message**: Show formatted header for the stage about to execute (see [Transition Messages](#transition-messages))
8. **Invoke stage skill**: Use the Skill tool to invoke the appropriate stage skill (see [Stage Skill Mapping](#stage-skill-mapping)). Pass required context (idea text, issue number, artifact paths from prior stages).
9. **Detect governance result**: After the skill returns, first check the governance cache via `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_get_governance_cache "{artifact}" "{reviewer}"'`. If the cache returns a verdict (not `"null"`), use the cached result. If the cache returns `"null"`, **MANDATORY**: You MUST use the Read tool to load `references/governance.md` before proceeding with governance gate detection. Do NOT rely on memory of prior governance content. If the file cannot be read, display an error and STOP. Follow the Governance Gate Detection and Governance Tier instructions from that file. Apply tier-specific rules.

   **Serialized Triad Reviews (Feature 047)**: When a governance gate requires multiple reviewers (e.g., plan.md requires PM + Architect, tasks.md requires PM + Architect + Team-Lead), execute reviews **sequentially** instead of in parallel:

   1. **Sequential execution order**: PM review first, then Architect review, then Team-Lead review (if applicable)
   2. **Context clearing between reviewers**: After each reviewer completes, **MANDATORY**: Re-read `references/governance.md` to clear reviewer context and prevent template drift (per KB Entry 9).
   3. **Cache each verdict**: After each individual reviewer completes, cache their verdict via `aod_state_cache_governance` before invoking the next reviewer
   4. **Early termination on rejection**: If any reviewer returns CHANGES_REQUESTED or BLOCKED, stop the review sequence immediately — do not invoke remaining reviewers. Handle the rejection per step 10.
   5. **All reviewers use same checklists and criteria**: The only change is execution order (sequential vs. parallel). Same reviewers, same review prompts, same approval criteria.

   **Wall-clock trade-off**: Sequential execution adds ~15-20 seconds per review cycle compared to parallel execution. This trade-off is documented in ADR-005 and is acceptable per PRD priority stack (Quality > Few Pauses > Speed).
10. **Handle result**:
    - **APPROVED / APPROVED_WITH_CONCERNS**: Mark stage completed in state, record artifacts, write checkpoint, continue loop
    - **CHANGES_REQUESTED**: Follow the Rejection Handling instructions in `references/governance.md` (re-read if not already loaded). This includes Retry Tracking and Max-Retry Circuit Breaker checks.
    - **BLOCKED**: Follow the Blocked Handling instructions in `references/governance.md` (re-read if not already loaded).
    - **No governance gate for this stage/tier**: Mark completed, continue
11. **Write post-stage checkpoint**: Update state with completion status, artifacts, governance results, timestamp. Write atomically via `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_write '"'"'<json>'"'"''`.
12. **Update GitHub Issue label**: If `gh` available, update stage label (see [GitHub Integration](#github-integration))
13. **Loop**: Return to step 1

**Re-grounding after governance reviews**: After any governance review produces variable-length output (reviewer feedback, rejection details, override justifications), **MANDATORY**: Re-read `references/governance.md` before continuing the loop to prevent template drift (per KB Entry 9). This replaces the pre-segmentation pattern of re-reading the full SKILL.md.

**Re-grounding in serialized reviews**: When executing serialized Triad reviews (Feature 047), the re-grounding instruction applies **after each individual reviewer** in the sequence, not just at the end. After PM review output, re-read `references/governance.md` before invoking Architect. After Architect review output, re-read `references/governance.md` before invoking Team-Lead (if applicable). This ensures each reviewer starts with clean context.

**Re-grounding after lifecycle complete display**: After displaying lifecycle completion or lifecycle-already-complete output, **MANDATORY**: Re-read `references/error-recovery.md` to ensure the completion template is followed exactly.

**Stage sequence**: `discover` → `define` → `plan` (spec → project_plan → tasks) → `build` → `deliver`

**Exit conditions**:
- All stages completed → display lifecycle summary
- BLOCKED with no resolution → save state, exit
- User chooses to pause → save state, exit
- Session ends → user resumes with `--resume` in new session

### Plan Substage Tracking

The Plan stage contains 3 substages executed in strict sequence. The orchestrator tracks each substage independently and only advances past Plan when all 3 are complete.

**Substage sequence**: `spec` → `project_plan` → `tasks`

**Algorithm** (detailed expansion of Core Loop step 4):

1. **When entering Plan stage**: If `current_substage` is null, set it to `spec` (first substage). Update state: `stages.plan.status = "in_progress"`, `stages.plan.started_at = {now}`, `current_substage = "spec"`.

2. **Determine active substage**: Read `current_substage` from state. Check the substage's status in `stages.plan.substages.{substage}.status`:
   - If `"completed"`: Advance to next substage in sequence
   - If `"pending"` or `"in_progress"`: This is the active substage to execute

3. **Substage advancement logic**:
   - `spec` completed → set `current_substage = "project_plan"`, set `stages.plan.substages.project_plan.status = "in_progress"`. **Apply context boundary** (see step 3a).
   - `project_plan` completed → set `current_substage = "tasks"`, set `stages.plan.substages.tasks.status = "in_progress"`. **Apply context boundary** (see step 3a).
   - `tasks` completed → set `current_substage = null`, mark overall Plan stage as `"completed"`, set `stages.plan.completed_at = {now}`

3a. **Context boundary at substage transitions** (FR-013, FR-014, FR-015, FR-016):

   When advancing from one substage to the next (spec → project_plan, or project_plan → tasks), apply a context boundary to prevent context accumulation:

   **Step 1 - Display boundary message**:
   ```
   [Context boundary] Clearing {previous_substage} context
   ```
   Where `{previous_substage}` is `spec` or `project_plan`.

   **Step 2 - Extract and retain only approval metadata**:
   From the completed substage, retain only:
   - `status`: The approval status (e.g., "APPROVED")
   - `artifact_path`: Path to the artifact (e.g., `specs/{NNN}-*/spec.md`)
   - `feature_id`: The 3-digit feature ID (e.g., "047")

   These values are already persisted in `run-state.json` under `stages.plan.substages.{substage}` and do not require re-extraction.

   **Step 3 - Clear previous substage full content**:
   The previous substage's artifact content (spec.md or plan.md full text) is NOT carried forward. The next substage skill will read its own required context fresh.

   **Step 4 - On-demand re-read available**:
   If the next substage explicitly needs details from a prior artifact, it can re-read the artifact using the path stored in metadata. This is NOT automatic — the substage skill must explicitly invoke the Read tool with the artifact path from `stages.plan.substages.{prior_substage}.artifacts`.

   **Example boundary output**:
   ```
   [Context boundary] Clearing spec context
   Retained metadata: {status: "APPROVED", artifact_path: "specs/047-*/spec.md", feature_id: "047"}
   ```

4. **Write substage checkpoint**: After each substage transition, write state atomically. This ensures that if the session dies between substages, the orchestrator can resume at the correct substage.

5. **Skill invocation per substage**:
   - `spec` substage → invoke `aod.spec` skill
   - `project_plan` substage → invoke `aod.project-plan` skill
   - `tasks` substage → invoke `aod.tasks` skill

6. **Governance per substage**: Each substage has its own governance gate. First check the governance cache via `aod_state_get_governance_cache` (see Core Loop step 9). If the cache returns `"null"`, fall back to reading the substage's artifact frontmatter (load `references/governance.md` for the detection algorithm):
   - `spec`: Check `specs/{NNN}-*/spec.md` for PM sign-off
   - `project_plan`: Check `specs/{NNN}-*/plan.md` for PM + Architect sign-off
   - `tasks`: Check `specs/{NNN}-*/tasks.md` for PM + Architect + Team-Lead sign-off

7. **Display**: When displaying the stage map during Plan, show the active substage:
   ```
   [>] Plan (spec)       — spec substage in progress
   [>] Plan (plan)       — project_plan substage in progress
   [>] Plan (tasks)      — tasks substage in progress
   ```

### Stage Skill Mapping

Each lifecycle stage maps to an existing AOD skill invoked via the Skill tool. The orchestrator delegates all stage work — it never re-implements stage logic.

| Stage | Substage | Skill to Invoke | Skill Tool Name | Arguments to Pass |
|-------|----------|----------------|-----------------|-------------------|
| Discover | — | Discovery flow | `aod.discover` | Idea text (for new ideas) or issue context |
| Define | — | PRD creation | `aod.define` | Feature topic/title from idea or issue |
| Plan | spec | Specification | `aod.spec` | (reads spec context from branch) |
| Plan | project_plan | Architecture plan | `aod.project-plan` | (reads spec from branch) |
| Plan | tasks | Task breakdown | `aod.tasks` | (reads plan from branch) |
| Build | — | Implementation | `aod.build` | (reads tasks from branch) |
| Deliver | — | Delivery retrospective | `aod.deliver` | Feature number and name |

**Invocation pattern**: Use the Skill tool with `skill: "{skill_name}"` and pass arguments as `args: "{arguments}"`.

**Context passing between stages** (FR-012):
- After **Discover** completes: extract GitHub Issue number from discovery output; store in state as `github_issue`
- After **Define** completes: PRD path is at `docs/product/02_PRD/{NNN}-*.md`; store in state artifacts
- After **Plan:spec** completes: spec path is at `specs/{NNN}-*/spec.md`; store in state artifacts
- After **Plan:project_plan** completes: plan path is at `specs/{NNN}-*/plan.md`; store in state artifacts
- After **Plan:tasks** completes: tasks path is at `specs/{NNN}-*/tasks.md`; store in state artifacts
- After **Build** completes: implementation files tracked via tasks.md `[X]` markers
- After **Deliver** completes: delivery summary and metrics captured

**Argument formatting per stage**:

- **Discover**: `args: "{idea_text}"` — pass the raw idea description
- **Define**: `args: "{feature_title}"` — pass the feature title/topic for PRD creation
- **Plan stages**: no args needed — skills read context from current branch's spec directory
- **Build**: no args needed — reads tasks.md from branch
- **Deliver**: `args: "FEATURE: {NNN} - {feature_name}"` — pass feature number and name

### Post-Stage Context Extraction

After each stage skill returns, the orchestrator extracts context from the produced artifacts and updates the state file. This ensures subsequent stages receive the correct inputs.

**After Discover completes**:

1. The Discover skill creates a GitHub Issue and outputs the issue number. Read the orchestration output to find the issue number.
2. Use Bash to scan for new GitHub Issues: `gh issue list --label "stage:discover" --json number,title --limit 5` (if `gh` available)
3. Update state fields:
   - `github_issue`: Set to the issue number
   - `feature_id`: Zero-pad the issue number to 3 digits (e.g., `22` → `"022"`)
   - `branch`: Set to `{feature_id}-{feature_name}` (e.g., `"022-add-dark-mode-toggle"`)
4. Create the feature branch if not already on it: `git checkout -b {branch}` (or confirm current branch matches)
5. Record artifacts: Add the GitHub Issue URL to `stages.discover.artifacts`
6. Write updated state atomically

**After Define completes**:

1. Use Glob to find the PRD: `docs/product/02_PRD/{NNN}-*.md` where NNN is `feature_id`
2. Record artifacts: Add the PRD path to `stages.define.artifacts`
3. Write updated state atomically

**After Plan:spec completes**:

1. Use Glob to find the spec: `specs/{NNN}-*/spec.md`
2. Record artifacts: Add the spec path to `stages.plan.substages.spec.artifacts`
3. Write updated state atomically

**After Plan:project_plan completes**:

1. Use Glob to find the plan: `specs/{NNN}-*/plan.md`
2. Record artifacts: Add the plan path to `stages.plan.substages.project_plan.artifacts`
3. Write updated state atomically

**After Plan:tasks completes**:

1. Use Glob to find tasks and assignments: `specs/{NNN}-*/tasks.md`, `specs/{NNN}-*/agent-assignments.md`
2. Record artifacts: Add paths to `stages.plan.substages.tasks.artifacts`
3. Mark overall Plan stage as completed
4. Write updated state atomically

**After Build completes**:

1. The build stage produces implementation files tracked via tasks.md `[X]` markers
2. Record artifacts: Add `"tasks.md (all tasks completed)"` to `stages.build.artifacts`
3. Write updated state atomically

**After Deliver completes**:

1. The deliver stage produces a delivery summary and may update GitHub Issue to `stage:done`
2. Record artifacts: Add `"delivery complete"` to `stages.deliver.artifacts`
3. Write updated state atomically
4. **MANDATORY**: You MUST use the Read tool to load `references/error-recovery.md`, then follow the Lifecycle Complete instructions. If the file cannot be read, display an error and STOP.

### Stage Map Display

Display the stage map after each stage transition to show progress. This is referenced by Core Loop step 6.

**Algorithm**:

1. Read state from `.aod/run-state.json`
2. For each stage in sequence (`discover`, `define`, `plan`, `build`, `deliver`), determine its display marker:
   - `status == "completed"` → `[x]`
   - `status == "in_progress"` → `[>]`
   - `status == "pending"` → `[ ]`
   - `status == "failed"` → `[!]`
3. For the Plan stage, append the active substage in parentheses if in progress:
   - If `current_substage == "spec"` → `Plan (spec)`
   - If `current_substage == "project_plan"` → `Plan (plan)`
   - If `current_substage == "tasks"` → `Plan (tasks)`
   - If Plan is completed → `Plan`
4. Display the formatted stage map:

```
Stage Map:
  {marker} Discover  {marker} Define  {marker} Plan{substage}  {marker} Build  {marker} Deliver
```

**Examples**:

Starting a new lifecycle:
```
Stage Map:
  [>] Discover  [ ] Define  [ ] Plan  [ ] Build  [ ] Deliver
```

After Discover and Define complete, Plan:spec in progress:
```
Stage Map:
  [x] Discover  [x] Define  [>] Plan (spec)  [ ] Build  [ ] Deliver
```

Mid-lifecycle with Build in progress:
```
Stage Map:
  [x] Discover  [x] Define  [x] Plan  [>] Build  [ ] Deliver
```

All stages complete:
```
Stage Map:
  [x] Discover  [x] Define  [x] Plan  [x] Build  [x] Deliver
```

### Transition Messages

Display a formatted transition header before each stage begins executing. This is referenced by Core Loop step 7.

**Algorithm** (called by Core Loop step 7, before each stage skill invocation):

1. **Read current state**: Get `current_stage` and `current_substage` from state.

2. **Map stage to number and detail**: Use the lookup table below:

   | `current_stage` | `current_substage` | N | STAGE_NAME | Substage Detail |
   |-----------------|-------------------|---|------------|----------------|
   | `discover` | null | 1 | DISCOVER | — |
   | `define` | null | 2 | DEFINE | — |
   | `plan` | `spec` | 3 | PLAN | sub-stage 1/3: Feature Specification |
   | `plan` | `project_plan` | 3 | PLAN | sub-stage 2/3: Architecture Plan |
   | `plan` | `tasks` | 3 | PLAN | sub-stage 3/3: Task Breakdown |
   | `build` | null | 4 | BUILD | — |
   | `deliver` | null | 5 | DELIVER | — |

3. **Format and display**:

   For non-Plan stages:
   ```
   --- STAGE {N}: {STAGE_NAME} ---
   ```

   For Plan substages:
   ```
   --- STAGE 3: PLAN ({substage detail}) ---
   ```

**Examples**:
```
--- STAGE 1: DISCOVER ---
--- STAGE 3: PLAN (sub-stage 1/3: Feature Specification) ---
--- STAGE 4: BUILD ---
```

### GitHub Integration

After each stage completes successfully (governance gate passed), update the GitHub Issue's `stage:*` label to reflect the new current stage. This keeps the GitHub Issue board in sync with the orchestration state (FR-023).

**Algorithm** (called by Core Loop step 12, after post-stage checkpoint):

1. **Check prerequisites**:
   - Read `github_issue` from state. If null (no GitHub Issue for this feature), skip entirely.
   - Check if `gh` CLI is available: `command -v gh >/dev/null 2>&1`. If not, skip silently.
   - Check if `gh` is authenticated: `gh auth status >/dev/null 2>&1`. If not, skip silently.

2. **Determine the new stage label**: Map the newly-completed stage to the next stage in the sequence:

   | Completed Stage | Completed Substage | New Label |
   |-----------------|-------------------|-----------|
   | discover | — | `stage:define` |
   | define | — | `stage:plan` |
   | plan | spec | `stage:plan` (still in Plan) |
   | plan | project_plan | `stage:plan` (still in Plan) |
   | plan | tasks | `stage:build` |
   | build | — | `stage:deliver` |
   | deliver | — | `stage:done` |

   **Note**: Plan substage completions (spec, project_plan) do not change the label — the issue stays at `stage:plan` until all 3 substages complete.

3. **Update the label**: Use the `github-lifecycle.sh` function:
   ```
   bash -c 'source .aod/scripts/bash/github-lifecycle.sh && aod_gh_update_stage {github_issue} {new_stage}'
   ```

4. **Handle failures gracefully**: If the label update fails, log a warning but do NOT halt orchestration.
   - Display: `"Note: GitHub label update skipped ({reason}). Orchestration continues."`

5. **Backlog refresh**: After updating the label:
   ```
   bash .aod/scripts/bash/backlog-regenerate.sh 2>/dev/null || true
   ```
   This is fire-and-forget — failure does not affect orchestration.

### Error Logging

Capture stage errors and significant events in the state file's `error_log` array for debugging and auditability. Error entries follow Entity 4 schema.

**Algorithm** (called whenever an error or significant event occurs during orchestration):

1. **Build error entry**:

```json
{
  "timestamp": "{current ISO 8601 timestamp}",
  "stage": "{current_stage}",
  "type": "{error_type}",
  "message": "{descriptive error message}",
  "recoverable": true
}
```

2. **Error types** (standardized values for `type` field):

   | Type | When Used | Recoverable |
   |------|-----------|-------------|
   | `stage_error` | A stage skill invocation fails or returns an error | true |
   | `governance_rejection` | A governance gate returns CHANGES_REQUESTED | true |
   | `governance_blocked` | A governance gate returns BLOCKED | true |
   | `circuit_breaker` | Max retries (3) reached on a governance gate | true |
   | `user_abort` | User chose to abort orchestration | true |
   | `artifact_missing` | Artifact recorded in state not found on disk | true |
   | `state_corruption` | State file failed validation | true |
   | `github_error` | GitHub CLI operation failed | true |
   | `skill_invocation_error` | Skill tool invocation returned unexpected result | true |

3. **Append to state**: Use the `aod_state_append` function:
   ```
   bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_append ".error_log" '"'"'{"timestamp":"...","stage":"...","type":"...","message":"...","recoverable":true}'"'"''
   ```

4. **When to log errors**:
   - **Stage skill failure**: When a Skill tool invocation produces an error or unexpected output
   - **Governance gate rejection**: Also tracked in `gate_rejections`, log summary in `error_log`
   - **Circuit breaker activation**: When max retries are reached
   - **User abort**: When the user chooses to abort
   - **Artifact inconsistency**: When resume validation detects missing artifacts
   - **State corruption**: When the state file fails validation
   - **GitHub errors**: When `gh` CLI operations fail

5. **Error entries are append-only**: Never remove or modify existing error log entries. The log provides a chronological audit trail.
