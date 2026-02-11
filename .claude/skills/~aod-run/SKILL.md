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

| Section | Purpose |
|---------|---------|
| [Step 1: Route by Mode](#step-1-route-by-mode) | Entry point routing |
| [Step 2: Core State Machine Loop](#step-2-core-state-machine-loop) | Central orchestration logic |
| [Plan Substage Tracking](#plan-substage-tracking) | Spec → project_plan → tasks |
| [Stage Skill Mapping](#stage-skill-mapping) | Stage-to-skill invocation table |
| [Post-Stage Context Extraction](#post-stage-context-extraction) | Artifact discovery after each stage |
| [Governance Gate Detection](#governance-gate-detection) | Reading approval/rejection from frontmatter |
| [Governance Tier](#governance-tier) | Light/Standard/Full gate rules |
| [New Idea Entry](#new-idea-entry) | `idea` mode handler |
| [Issue Entry](#issue-entry) | `issue` mode handler |
| [Resume Entry](#resume-entry) | `resume` mode handler |
| [Status Entry](#status-entry) | `status` mode handler (read-only) |
| [Stage Map Display](#stage-map-display) | Visual progress indicators |
| [Transition Messages](#transition-messages) | Stage transition headers |
| [GitHub Integration](#github-integration) | Label updates after stage completion |
| [Error Logging](#error-logging) | Error/event capture in state file |
| [Rejection Handling](#rejection-handling) | CHANGES_REQUESTED flow |
| [Retry Tracking](#retry-tracking) | Gate rejection history |
| [Max-Retry Circuit Breaker](#max-retry-circuit-breaker) | 3-attempt threshold |
| [Blocked Handling](#blocked-handling) | BLOCKED flow with override option |
| [Corrupted State File Handling](#corrupted-state-file-handling) | Recovery from corrupt state |
| [Lifecycle Already Complete Detection](#lifecycle-already-complete-detection) | Guard against restarting |
| [Lifecycle Complete](#lifecycle-complete) | Completion summary and archival |

## Execution

When this skill is invoked, the command file passes a parsed mode and arguments:

```
Mode: {idea | issue | resume | status}
Issue: {number or "none"}
Idea: {text or "none"}
```

### Step 1: Route by Mode

Read the mode from the invocation context and route to the appropriate handler:

| Mode | Handler | Description |
|------|---------|-------------|
| `idea` | [New Idea Entry](#new-idea-entry) | Create initial state, start at Discover |
| `issue` | [Issue Entry](#issue-entry) | Read GitHub Issue, create/load state, resume |
| `resume` | [Resume Entry](#resume-entry) | Load state file, validate, continue |
| `status` | [Status Entry](#status-entry) | Read-only display, then exit |

After the entry handler sets up state, all modes (except `status`) converge to the **Core Loop**.

### Step 2: Core State Machine Loop

This is the central orchestration logic. It runs after any entry handler has established or loaded state.

**Loop algorithm**:

1. **Read state**: Use Bash to read `.aod/run-state.json` via `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_read'`
2. **Check completion**: If all 5 stages show `status: "completed"`, go to [Lifecycle Complete](#lifecycle-complete)
3. **Determine next stage**: Read `current_stage` from state. If its status is `"completed"`, advance to the next stage in sequence: `discover` → `define` → `plan` → `build` → `deliver`
4. **Handle Plan substages**: If `current_stage` is `plan`, read `current_substage` and cycle through `spec` → `project_plan` → `tasks`. Only advance past Plan when all 3 substages complete.
5. **Write pre-stage checkpoint**: Update state with `current_stage` status = `"in_progress"` and current timestamp. Write atomically via `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_write '"'"'<json>'"'"''`
6. **Display stage map**: Show current progress (see [Stage Map Display](#stage-map-display))
7. **Display transition message**: Show formatted header for the stage about to execute (see [Transition Messages](#transition-messages))
8. **Invoke stage skill**: Use the Skill tool to invoke the appropriate stage skill (see [Stage Skill Mapping](#stage-skill-mapping)). Pass required context (idea text, issue number, artifact paths from prior stages).
9. **Detect governance result**: After the skill returns, read the produced artifact's YAML frontmatter to check governance gate status (see [Governance Gate Detection](#governance-gate-detection)). Apply tier-specific rules (see [Governance Tier](#governance-tier)).
10. **Handle result**:
    - **APPROVED / APPROVED_WITH_CONCERNS**: Mark stage completed in state, record artifacts, write checkpoint, continue loop
    - **CHANGES_REQUESTED**: Record rejection via [Retry Tracking](#retry-tracking), check [Max-Retry Circuit Breaker](#max-retry-circuit-breaker), then offer options via [Rejection Handling](#rejection-handling)
    - **BLOCKED**: Record rejection via [Retry Tracking](#retry-tracking), display blocker and offer options via [Blocked Handling](#blocked-handling)
    - **No governance gate for this stage/tier**: Mark completed, continue
11. **Write post-stage checkpoint**: Update state with completion status, artifacts, governance results, timestamp
12. **Update GitHub Issue label**: If `gh` available, update stage label (see [GitHub Integration](#github-integration))
13. **Loop**: Return to step 1

**Stage sequence**: `discover` → `define` → `plan` (spec → project_plan → tasks) → `build` → `deliver`

**Exit conditions**:
- All stages completed → display lifecycle summary
- BLOCKED with no resolution → save state, exit
- User chooses to pause → save state, exit
- Context overflow → user resumes with `--resume` in new session

### Plan Substage Tracking

The Plan stage contains 3 substages executed in strict sequence. The orchestrator tracks each substage independently and only advances past Plan when all 3 are complete.

**Substage sequence**: `spec` → `project_plan` → `tasks`

**Algorithm** (detailed expansion of Core Loop step 4):

1. **When entering Plan stage**: If `current_substage` is null, set it to `spec` (first substage). Update state: `stages.plan.status = "in_progress"`, `stages.plan.started_at = {now}`, `current_substage = "spec"`.

2. **Determine active substage**: Read `current_substage` from state. Check the substage's status in `stages.plan.substages.{substage}.status`:
   - If `"completed"`: Advance to next substage in sequence
   - If `"pending"` or `"in_progress"`: This is the active substage to execute

3. **Substage advancement logic**:
   - `spec` completed → set `current_substage = "project_plan"`, set `stages.plan.substages.project_plan.status = "in_progress"`
   - `project_plan` completed → set `current_substage = "tasks"`, set `stages.plan.substages.tasks.status = "in_progress"`
   - `tasks` completed → set `current_substage = null`, mark overall Plan stage as `"completed"`, set `stages.plan.completed_at = {now}`

4. **Write substage checkpoint**: After each substage transition, write state atomically. This ensures that if the session dies between substages, the orchestrator can resume at the correct substage.

5. **Skill invocation per substage**:
   - `spec` substage → invoke `aod.spec` skill
   - `project_plan` substage → invoke `aod.project-plan` skill
   - `tasks` substage → invoke `aod.tasks` skill

6. **Governance per substage**: Each substage has its own governance gate (see [Governance Gate Detection](#governance-gate-detection)). The orchestrator checks the substage's artifact frontmatter after each skill invocation:
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
4. Proceed to [Lifecycle Complete](#lifecycle-complete)

### Governance Gate Detection

After each stage skill returns, detect the governance gate result by reading the produced artifact's YAML frontmatter. The orchestrator does NOT re-implement governance — it reads the results that stage skills already produced.

**Detection algorithm**:

1. **Identify the artifact to check** based on the completed stage:

   | Stage | Artifact Path | Required Sign-offs |
   |-------|--------------|-------------------|
   | Discover | (no artifact — Discover approval is implicit in ICE score + PM validation) | None (approval is part of the discover flow) |
   | Define | `docs/product/02_PRD/{NNN}-*.md` | PM + Architect + Team-Lead (Triad review) |
   | Plan: spec | `specs/{NNN}-*/spec.md` | PM (`triad.pm_signoff.status`) |
   | Plan: project_plan | `specs/{NNN}-*/plan.md` | PM + Architect (`triad.pm_signoff.status`, `triad.architect_signoff.status`) |
   | Plan: tasks | `specs/{NNN}-*/tasks.md` | PM + Architect + Team-Lead (all three `triad.*.status` fields) |
   | Build | (no single artifact — Build approval via Architect checkpoints within `aod.build`) | None (checkpoints handled internally) |
   | Deliver | (no artifact — Deliver approval via DoD validation within `aod.deliver`) | None (DoD handled internally) |

2. **Read the artifact file** using the Read tool. Extract the YAML frontmatter between `---` delimiters.

3. **Parse sign-off statuses**: For each required sign-off field, extract the `status` value from the `triad:` block.

4. **Evaluate gate result**:

   - **All required sign-offs are APPROVED or APPROVED_WITH_CONCERNS**: Gate PASSED
   - **Any sign-off is BLOCKED_OVERRIDDEN**: Gate PASSED (override was user-authorized)
   - **Any sign-off is CHANGES_REQUESTED**: Gate REJECTED — record which reviewer requested changes and their notes
   - **Any sign-off is BLOCKED**: Gate BLOCKED — record which reviewer blocked and their notes
   - **Sign-off field is null or missing**: Stage skill did not complete governance — treat as still in progress

5. **Record governance result in state**: Update the stage's `governance` object with each reviewer's status and date. Add entries to `gate_rejections` array if rejected.

**Recognized approval statuses**: `APPROVED`, `APPROVED_WITH_CONCERNS`, `BLOCKED_OVERRIDDEN`
**Recognized rejection statuses**: `CHANGES_REQUESTED`
**Recognized blocker statuses**: `BLOCKED`

**Re-grounding**: After reading governance results (which may contain variable-length reviewer feedback), re-read this SKILL.md section before continuing the loop to prevent template drift (per KB Entry 9).

### Governance Tier

The orchestrator reads the governance tier from the project constitution to determine which gates are active. This follows the same pattern as `~aod-plan`.

**How to read the tier**:

1. Read `.aod/memory/constitution.md`
2. Look for the `## Governance Tiers` section, then find the YAML configuration block:
   ```yaml
   governance:
     tier: standard
   ```
3. Extract the `tier:` value. Valid values: `light`, `standard`, `full`
4. If the section is not found, the `governance:` key is missing, or the value is not recognized: **default to `standard`**

**Tier-specific gate rules**:

| Tier | Discover Gate | Define Gate | Plan: spec Gate | Plan: project_plan Gate | Plan: tasks Gate | Build Gate | Deliver Gate |
|------|---------------|-------------|-----------------|------------------------|-----------------|------------|--------------|
| **Light** | SKIP | SKIP | SKIP (PM sign-off not required) | Check dual sign-off | Check triple sign-off | Internal (aod.build) | Internal (aod.deliver) |
| **Standard** | Check (implicit in discover flow) | Check Triad review | Check PM sign-off | Check dual sign-off | Check triple sign-off | Internal (aod.build) | Internal (aod.deliver) |
| **Full** | Check | Check | Check PM sign-off (separate) | Check dual sign-off | Check triple sign-off | Internal (aod.build) | Internal (aod.deliver) |

**Gate skip behavior** (Light tier):
- When a gate is marked SKIP, the orchestrator marks the stage as completed without checking frontmatter sign-offs
- The stage skill is still invoked (stages are never skipped — only gates are)
- Display: `"Note: Light governance tier — {gate_name} gate skipped."`

**Governance floor (FR-026)**: Triple sign-off on `tasks.md` MUST be enforced regardless of tier. This is the non-negotiable governance floor. Even in Light tier, the orchestrator checks that `tasks.md` has PM + Architect + Team-Lead sign-offs before allowing Build to proceed.

**When to read the tier**:
- At orchestration startup (initial or resume)
- Store in state as `governance_tier`
- On resume, re-read from constitution (tier may have changed mid-orchestration — apply new tier going forward, do not re-evaluate already-completed gates)

**Mid-orchestration tier change handling**:

When the governance tier changes between sessions (detected at Resume Entry step 10), the orchestrator applies these rules:

1. **Read new tier**: Extract `tier:` from constitution on every resume
2. **Compare with stored tier**: Check `governance_tier` in state file against the newly-read value
3. **If changed**:
   - Update `governance_tier` in state to the new value
   - Display: `"Note: Governance tier changed from {old_tier} to {new_tier}. New tier applied going forward."`
   - **Do NOT re-evaluate already-completed gates**: Stages that already passed governance review keep their status. The new tier only affects gates for stages that have not yet been evaluated.
   - **Example**: If Discover and Define passed under `standard` tier, then the user switches to `light` tier mid-orchestration — Discover and Define keep their approval status. The Light tier's gate-skip rules only apply to pending stages (Plan:spec gate would now be skipped instead of requiring PM sign-off).
4. **Governance floor preserved**: The triple sign-off on `tasks.md` is always enforced regardless of tier change (FR-026). Changing from `standard` to `light` cannot bypass the tasks.md triple sign-off.

### New Idea Entry

When mode is `idea`, the orchestrator creates a fresh orchestration from a raw idea description.

**Algorithm**:

1. **Check for existing state file**: Use Bash to run `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_exists && echo "exists" || echo "none"'`
   - If state file exists: Display warning: `"A state file already exists for a previous orchestration. Use --resume to continue it, or delete .aod/run-state.json to start fresh."` Then STOP (do not overwrite).

2. **Read governance tier**: Read `.aod/memory/constitution.md`, extract `governance:` → `tier:` value. Default to `standard` if not found.

3. **Generate feature metadata**:
   - `feature_name`: Convert idea text to kebab-case (lowercase, spaces to hyphens, strip non-alphanumeric except hyphens, truncate to 50 chars)
   - `feature_id`: Will be assigned after Discover stage creates a GitHub Issue (set to `"000"` initially)
   - `branch`: Will be set after Discover stage determines the branch name (set to `"pending"` initially)
   - `github_issue`: null initially (assigned by Discover stage)
   - `idea`: The full idea text as provided by the user

4. **Create initial state JSON**: Build the state object following Entity 1 schema:

```json
{
  "version": "1.0",
  "feature_id": "000",
  "feature_name": "{kebab-case-idea}",
  "github_issue": null,
  "idea": "{full idea text}",
  "branch": "pending",
  "started_at": "{current ISO 8601 timestamp}",
  "updated_at": "{current ISO 8601 timestamp}",
  "governance_tier": "{tier from constitution}",
  "current_stage": "discover",
  "current_substage": null,
  "session_count": 1,
  "intervention_count": 0,
  "stages": {
    "discover": { "status": "pending", "started_at": null, "completed_at": null, "artifacts": [], "governance": null, "substages": null, "error": null },
    "define": { "status": "pending", "started_at": null, "completed_at": null, "artifacts": [], "governance": null, "substages": null, "error": null },
    "plan": { "status": "pending", "started_at": null, "completed_at": null, "artifacts": [], "governance": null, "substages": { "spec": { "status": "pending", "artifacts": [] }, "project_plan": { "status": "pending", "artifacts": [] }, "tasks": { "status": "pending", "artifacts": [] } }, "error": null },
    "build": { "status": "pending", "started_at": null, "completed_at": null, "artifacts": [], "governance": null, "substages": null, "error": null },
    "deliver": { "status": "pending", "started_at": null, "completed_at": null, "artifacts": [], "governance": null, "substages": null, "error": null }
  },
  "error_log": [],
  "gate_rejections": []
}
```

5. **Write state to disk**: Use Bash to create the state file via `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_create '"'"'{json}'"'"''` (using the constructed JSON).

6. **Display initial status**:
```
AOD ORCHESTRATOR — New Lifecycle
================================
Idea: {idea text}
Governance Tier: {tier}
Starting Stage: Discover

Stage Map:
  [>] Discover  [ ] Define  [ ] Plan  [ ] Build  [ ] Deliver
```

7. **Proceed to Core Loop**: Fall through to Step 2 (Core State Machine Loop) to begin executing the Discover stage.

### Issue Entry

When mode is `issue`, the orchestrator reads an existing GitHub Issue to determine the current lifecycle stage and creates (or loads) state accordingly.

**Algorithm**:

1. **Parse issue number**: Extract the numeric issue number from the input (strip `#` prefix if present).

2. **Check for existing state file**: Use Bash to run `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_exists && echo "exists" || echo "none"'`
   - If state file exists: Check if it matches this issue number (see [State File Detection for Existing Features](#state-file-detection-for-existing-features))
   - If state file does not exist: Continue to step 3

3. **Read GitHub Issue**: Use Bash to fetch issue data:
   ```
   gh issue view {NNN} --json number,title,labels
   ```
   - Extract `number`, `title`, and `labels` array
   - If `gh` is unavailable or fails: fall back to [GitHub Graceful Degradation](#github-graceful-degradation)

4. **Extract stage label**: Search the labels array for a label matching `stage:*`:
   - `stage:discover` → current stage is `discover`
   - `stage:define` → current stage is `define`
   - `stage:plan` → current stage is `plan`
   - `stage:build` → current stage is `build`
   - `stage:deliver` → current stage is `deliver`
   - `stage:done` → lifecycle already complete (display summary and exit)
   - No `stage:*` label found → default to `discover` (assume fresh issue)

5. **Infer completed stages**: Based on the detected stage label, mark all prior stages as `completed`:

   | Detected Label | Completed Stages | Starting Stage |
   |---------------|-----------------|----------------|
   | `stage:discover` | (none) | discover |
   | `stage:define` | discover | define |
   | `stage:plan` | discover, define | plan |
   | `stage:build` | discover, define, plan | build |
   | `stage:deliver` | discover, define, plan, build | deliver |
   | `stage:done` | all | (lifecycle complete) |

6. **Discover existing artifacts**: Scan disk for artifacts from completed stages (see [Artifact Discovery](#artifact-discovery)).

7. **Read governance tier**: Read `.aod/memory/constitution.md`, extract `governance:` → `tier:` value. Default to `standard` if not found.

8. **Generate feature metadata**:
   - `feature_id`: Zero-pad the issue number to 3 digits (e.g., `42` → `"042"`)
   - `feature_name`: Convert issue title to kebab-case (lowercase, spaces to hyphens, strip non-alphanumeric except hyphens, truncate to 50 chars)
   - `branch`: `{feature_id}-{feature_name}` (e.g., `"042-add-dark-mode-toggle"`)
   - `github_issue`: The issue number
   - `idea`: The issue title

9. **Create initial state JSON**: Build the state object following Entity 1 schema, with completed stages pre-filled:

```json
{
  "version": "1.0",
  "feature_id": "{NNN}",
  "feature_name": "{kebab-case-title}",
  "github_issue": {issue_number},
  "idea": "{issue title}",
  "branch": "{feature_id}-{feature_name}",
  "started_at": "{current ISO 8601 timestamp}",
  "updated_at": "{current ISO 8601 timestamp}",
  "governance_tier": "{tier}",
  "current_stage": "{detected starting stage}",
  "current_substage": null,
  "session_count": 1,
  "intervention_count": 0,
  "stages": {
    "discover": { "status": "{completed or pending}", "started_at": null, "completed_at": "{if completed: now, else: null}", "artifacts": ["{discovered artifacts}"], "governance": null, "substages": null, "error": null },
    "define": { "status": "{completed or pending}", ... },
    "plan": { "status": "{completed or pending}", ..., "substages": { "spec": {...}, "project_plan": {...}, "tasks": {...} } },
    "build": { "status": "pending", ... },
    "deliver": { "status": "pending", ... }
  },
  "error_log": [],
  "gate_rejections": []
}
```

   For completed stages: set `status: "completed"`, populate `artifacts` from disk scan, set timestamps to current time (exact original times are not available).

   For the Plan stage when it's marked completed: also mark all 3 substages (`spec`, `project_plan`, `tasks`) as `completed` with their discovered artifacts.

10. **Write state to disk**: Use Bash to create the state file via `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_create '"'"'{json}'"'"''`

11. **Ensure correct branch**: Check current git branch. If not on the expected feature branch, switch to it:
    - If branch exists: `git checkout {branch}`
    - If branch does not exist: `git checkout -b {branch}`

12. **Display initial status**:
```
AOD ORCHESTRATOR — Resume from Issue #{NNN}
=============================================
Feature: {feature_name} (#{github_issue})
Branch: {branch}
Governance Tier: {tier}
Detected Stage: {stage label}
Starting Stage: {starting_stage}

Completed: {list of completed stage names}
Artifacts Found: {count}

Stage Map:
  {markers per stage}
```

13. **Proceed to Core Loop**: Fall through to Step 2 (Core State Machine Loop) to begin executing the starting stage.

### Artifact Discovery

When resuming from a GitHub Issue, the orchestrator scans the disk for existing artifacts to populate the state file. This ensures context from prior stages is available to subsequent stages.

**Scan algorithm**:

1. **Determine feature ID**: Zero-pad the issue number to 3 digits (e.g., `42` → `"042"`).

2. **Scan for each artifact type**:

   | Artifact | Glob Pattern | Stage |
   |----------|-------------|-------|
   | PRD | `docs/product/02_PRD/{NNN}-*.md` | define |
   | Spec | `specs/{NNN}-*/spec.md` | plan (spec substage) |
   | Plan | `specs/{NNN}-*/plan.md` | plan (project_plan substage) |
   | Tasks | `specs/{NNN}-*/tasks.md` | plan (tasks substage) |
   | Agent Assignments | `specs/{NNN}-*/agent-assignments.md` | plan (tasks substage) |
   | Research | `specs/{NNN}-*/research.md` | plan (pre-spec research) |

3. **Use Glob tool** for each pattern. Record found paths in the corresponding stage's `artifacts` array.

4. **Cross-validate**: If a stage is inferred as completed (from the GitHub label) but its expected artifact is not found on disk, log a warning:
   ```
   WARNING: Stage {stage} inferred as complete from GitHub label, but artifact not found: {expected pattern}
   ```
   Still mark the stage as completed (trust the GitHub label as authoritative), but note the missing artifact.

5. **Plan substage inference**: If Plan stage is marked completed, check which Plan artifacts exist:
   - spec.md found → mark `spec` substage as completed
   - plan.md found → mark `project_plan` substage as completed
   - tasks.md found → mark `tasks` substage as completed
   - If some Plan substage artifacts are missing but the overall Plan stage label says complete, warn but trust the label.

### State File Detection for Existing Features

When an issue number is provided and a state file already exists, the orchestrator checks whether the existing state file belongs to this feature.

**Algorithm**:

1. **Read existing state file**: Use Bash to run `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_get .github_issue'`

2. **Compare issue numbers**:
   - If the state file's `github_issue` matches the provided issue number: offer to resume from the state file instead of re-inferring from GitHub label
     - Use AskUserQuestion: "A state file already exists for Issue #{NNN}. Resume from state file (recommended) or re-infer from GitHub Issue label?"
     - Options: "Resume from state file" (recommended), "Re-infer from GitHub"
     - If user chooses resume: switch to `--resume` flow (see [Resume Entry](#resume-entry))
     - If user chooses re-infer: delete existing state file, continue with issue entry flow from step 3
   - If the state file's `github_issue` does NOT match: warn about conflict
     - Use AskUserQuestion: "A state file exists for a different feature (Issue #{existing}). What would you like to do?"
     - Options: "Switch to Issue #{NNN} (archive current state)", "Cancel"
     - If switch: archive current state to `specs/{existing_NNN}-*/run-state.json`, then continue with issue entry
     - If cancel: exit

### GitHub Graceful Degradation

When the `gh` CLI is unavailable or fails, the orchestrator falls back to artifact-only detection.

**Degradation levels**:

| Level | Condition | Detection Method | Behavior |
|-------|-----------|-----------------|----------|
| 1 | `gh` not installed | `command -v gh` fails | Fall back to artifact-only scan |
| 2 | `gh` not authenticated | `gh auth status` fails | Fall back to artifact-only scan |
| 3 | Issue not found | `gh issue view` returns error | Warn user, offer to create issue or proceed without |

**Artifact-only fallback** (Levels 1 and 2):

1. Display warning: `"GitHub CLI unavailable. Falling back to artifact-only detection."`
2. Skip the `gh issue view` call
3. Use the provided issue number to construct the feature ID (zero-pad to 3 digits)
4. Scan disk for artifacts using the [Artifact Discovery](#artifact-discovery) algorithm
5. Infer the current stage from the highest-level artifact found:
   - tasks.md found → infer `build` (Plan complete)
   - plan.md found → infer `plan` (project_plan substage complete, check for tasks)
   - spec.md found → infer `plan` (spec substage complete, check for plan)
   - PRD found → infer `plan` (Define complete, start at Plan:spec)
   - No artifacts → infer `discover` (start from beginning)
6. Ask user to confirm the inferred stage: "Based on artifacts found, the current stage appears to be {stage}. Is this correct?"
   - Options: "Yes, continue from {stage}", "No, let me specify"
   - If user specifies: accept their input as the starting stage

**Level 3 fallback** (Issue not found):

1. Display warning: `"GitHub Issue #{NNN} not found."`
2. Use AskUserQuestion: "Issue #{NNN} was not found on GitHub. What would you like to do?"
   - Options: "Scan artifacts and proceed without issue", "Cancel"
   - If proceed: use artifact-only fallback (same as Level 1/2)
   - If cancel: exit

### Resume Entry

When mode is `resume`, the orchestrator reads the persisted state file from disk, validates it, and continues from the last completed stage boundary.

**Algorithm**:

1. **Check for state file**: Use Bash to run `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_exists && echo "exists" || echo "none"'`
   - If state file does NOT exist: Display error and guidance:
     ```
     ERROR: No orchestration state file found at .aod/run-state.json

     To start a new orchestration:
       /aod.run "your feature idea"
       /aod.run #NNN  (from existing GitHub Issue)

     A state file is created automatically when you start orchestration.
     ```
     Then STOP (exit without proceeding).

2. **Read and validate state file**: Use Bash to run `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_validate'`
   - If validation fails (non-zero exit): the state file is corrupt or has an unrecognized schema. Route to [Corrupted State File Handling](#corrupted-state-file-handling) — archive the corrupt file and offer recovery options.

3. **Read full state**: Use Bash to run `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_read'`. Parse the JSON to extract:
   - `feature_id`, `feature_name`, `github_issue`, `branch`
   - `current_stage`, `current_substage`
   - `session_count`
   - `started_at`, `updated_at`
   - All stage statuses from `stages` map

4. **Increment session count**: Calculate `new_session_count = session_count + 1`. Update state:
   ```
   bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_set ".session_count" "{new_session_count}"'
   ```

5. **Validate schema version**: Check that `version` is `"1.0"`. If not recognized, warn but attempt to continue (forward-compatible).

6. **Check lifecycle-already-complete**: Check if all 5 stages show `status: "completed"` (see [Lifecycle Already Complete Detection](#lifecycle-already-complete-detection)). If complete, display summary and STOP — do NOT proceed to the Core Loop or restart any stages.

7. **Run artifact consistency validation**: For each stage marked as `completed` in the state, verify its recorded artifacts exist on disk (see [Artifact Consistency Validation](#artifact-consistency-validation)).

8. **Run stale state detection**: Check if the state file is stale (see [Stale State Detection](#stale-state-detection)). If stale, ask user confirmation before proceeding.

9. **Run GitHub label validation**: If `gh` is available, verify the GitHub Issue's `stage:*` label matches `current_stage` in the state file (see [GitHub Label Validation on Resume](#github-label-validation-on-resume)).

10. **Re-read governance tier**: Read `.aod/memory/constitution.md`, extract `governance:` → `tier:` value. Default to `standard` if not found. Update state if tier has changed:
    ```
    bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_set ".governance_tier" "{tier}"'
    ```
    If tier changed from previous value, display: `"Note: Governance tier changed from {old} to {new}. New tier applied going forward."`

11. **Ensure correct branch**: Check current git branch. If not on the expected feature branch:
    - If branch exists: `git checkout {branch}`
    - If branch does not exist: warn user: `"Expected branch {branch} not found. Currently on {current_branch}."`
    - Use AskUserQuestion: "Feature branch {branch} not found. Continue on current branch or create it?"
      - Options: "Continue on {current_branch}", "Create {branch}"

12. **Display resume status**:
```
AOD ORCHESTRATOR — Resuming
============================
Feature: {feature_name} (#{github_issue})
Branch: {branch}
Session: {new_session_count} (previous: {old_session_count})
Governance Tier: {tier}
Current Stage: {current_stage}{substage_detail}
Last Updated: {updated_at}

Completed Stages: {list of completed stage names}
Pending Stages: {list of pending stage names}

Stage Map:
  {markers per stage}
```

13. **Proceed to Core Loop**: Fall through to Step 2 (Core State Machine Loop). The current stage from the state file determines where execution resumes. If a stage is `in_progress`, re-execute it from its beginning (idempotent restart). If a stage is `completed`, advance to the next pending stage.

### Artifact Consistency Validation

When resuming, verify that artifacts recorded in the state file for completed stages actually exist on disk. This catches cases where artifacts were manually deleted or moved between sessions.

**Algorithm** (called by Resume Entry step 7):

1. **Iterate completed stages**: For each stage in the `stages` map where `status == "completed"`:

2. **Check recorded artifacts**: Read the `artifacts` array for that stage. For each artifact path in the array:
   - Use Glob to check if the file exists at that path
   - If the path contains a wildcard (e.g., `specs/022-*/spec.md`), use Glob to resolve it
   - Record whether each artifact was found or missing

3. **Check Plan substage artifacts**: If the Plan stage is completed, also check each substage (`spec`, `project_plan`, `tasks`) and their `artifacts` arrays using the same logic.

4. **Build inconsistency report**: Collect all missing artifacts into a list:

   ```
   Artifact Consistency Check:
     [OK] specs/022-full-lifecycle-orchestrator/spec.md
     [OK] specs/022-full-lifecycle-orchestrator/plan.md
     [MISSING] specs/022-full-lifecycle-orchestrator/tasks.md
   ```

5. **Handle results**:

   - **All artifacts found**: Display `"Artifact consistency check: PASSED ({count} artifacts verified)"` and continue.

   - **Some artifacts missing**: Display the inconsistency report and use AskUserQuestion:
     - Question: "Some artifacts for completed stages are missing from disk. How would you like to proceed?"
     - Options:
       - "Accept current state (skip missing artifacts)" — Continue with resume, trusting the state file. Missing artifacts may cause issues in subsequent stages.
       - "Re-run affected stages" — For each stage with missing artifacts, reset its status to `"pending"` in the state file. The orchestrator will re-execute those stages.
     - If user chooses to accept: log a warning in state `error_log` and continue
     - If user chooses to re-run: update state for affected stages, write atomically, then continue to Core Loop (which will re-execute from the earliest incomplete stage)

6. **Write any state changes**: If stages were reset, write the updated state atomically via `run-state.sh`.

### Stale State Detection

Detect when the state file has not been updated for more than 7 days. This catches situations where a developer started an orchestration, left it for a while, and is now resuming with potentially outdated context.

**Algorithm** (called by Resume Entry step 8):

1. **Check staleness**: Use Bash to run `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_is_stale && echo "STALE" || echo "FRESH"'`
   - The `aod_state_is_stale` function compares `updated_at` against current time with a 7-day (604800 second) threshold
   - Exit code 0 = stale, exit code 1 = fresh, exit code 2 = error (no timestamp)

2. **Handle results**:

   - **FRESH**: No action needed. Continue with resume flow.

   - **STALE**: Read the `updated_at` timestamp from state. Calculate the age in days. Display a staleness warning:
     ```
     WARNING: Orchestration state is {N} days old (last updated: {updated_at}).

     This may indicate:
       - The feature was paused and context has changed
       - Artifacts may have been modified outside the orchestrator
       - GitHub Issue labels may be out of sync

     Current stage: {current_stage}
     Feature: {feature_name} (#{github_issue})
     ```

     Use AskUserQuestion:
     - Question: "The orchestration state is {N} days old. Do you want to continue from where you left off?"
     - Options:
       - "Yes, resume from {current_stage}" — Continue with resume flow as normal
       - "No, start fresh" — Archive the current state file to `specs/{NNN}-*/run-state.json`, delete `.aod/run-state.json`, and display guidance for starting a new orchestration. Then STOP.

   - **ERROR**: Display `"WARNING: Could not determine state file age (missing updated_at timestamp). Proceeding with caution."` Continue with resume flow.

3. **No state modification**: This check is read-only. It does not modify the state file. The session count increment has already been written by the Resume Entry step 4.

### GitHub Label Validation on Resume

When resuming with a GitHub Issue number in state, verify that the issue's `stage:*` label matches the `current_stage` recorded in the state file. This catches cases where someone manually moved the issue label or another process updated it.

**Algorithm** (called by Resume Entry step 8):

1. **Check prerequisites**:
   - Read `github_issue` from state. If null, skip this check entirely (no GitHub Issue to validate against).
   - Check if `gh` CLI is available: `command -v gh >/dev/null 2>&1`. If not available, skip with message: `"GitHub CLI unavailable. Skipping label validation."` and continue.
   - Check if `gh` is authenticated: `gh auth status >/dev/null 2>&1`. If not authenticated, skip with message: `"GitHub CLI not authenticated. Skipping label validation."` and continue.

2. **Read GitHub Issue label**: Use Bash to fetch the issue's labels:
   ```
   gh issue view {github_issue} --json labels --jq '.labels[].name' 2>/dev/null
   ```
   - Search the output for a line matching `stage:*`
   - Extract the stage name (e.g., `stage:build` → `build`)
   - If no `stage:*` label found: skip validation with message: `"No stage label found on Issue #{github_issue}. Skipping label validation."`

3. **Compare with state file**: Compare the GitHub label's stage with `current_stage` from the state file.

4. **Handle results**:

   - **Match**: Display `"GitHub label validation: PASSED (Issue #{github_issue} label matches state: stage:{current_stage})"` and continue.

   - **Mismatch**: Display the discrepancy:
     ```
     WARNING: GitHub Issue label does not match orchestration state.

       State file: current_stage = {current_stage}
       GitHub Issue #{github_issue}: label = stage:{github_label_stage}

     This may indicate:
       - Someone manually updated the issue label
       - Another process advanced the lifecycle
       - The state file is from a different session
     ```

     Use AskUserQuestion:
     - Question: "The state file says '{current_stage}' but GitHub says 'stage:{github_label_stage}'. Which source of truth should we use?"
     - Options:
       - "Use state file ({current_stage})" — Trust the local state file. Update the GitHub label to match: `bash -c 'source .aod/scripts/bash/github-lifecycle.sh && aod_gh_update_stage {github_issue} {current_stage}'`
       - "Use GitHub label ({github_label_stage})" — Trust GitHub. Update the state file: reset stages as needed (mark stages before the GitHub label as completed, reset the current and later stages). This is similar to the Issue Entry flow's stage inference logic. Write updated state atomically.

   - **Error reading GitHub**: If `gh issue view` fails for any reason, skip with message: `"Could not read Issue #{github_issue}. Skipping label validation."` and continue.

5. **Write any state changes**: If the user chose to trust GitHub, write the updated state atomically via `run-state.sh`. If a GitHub label was updated, the `github-lifecycle.sh` function handles that.

### Status Entry

When mode is `status`, the orchestrator displays the current orchestration state in read-only mode, then exits. It MUST NOT modify the state file or any artifacts.

**Algorithm**:

1. **Parse optional issue number**: Check if an issue number was provided along with `--status` (e.g., `--status #NNN`). If yes, store it as `status_issue_number`.

2. **Check for state file**: Use Bash to run `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_exists && echo "exists" || echo "none"'`

   - If state file exists: proceed to step 3 (display from state file)
   - If state file does NOT exist AND `status_issue_number` is set: proceed to [Status Fallback (No State File)](#status-fallback-no-state-file)
   - If state file does NOT exist AND no issue number: display message and exit:
     ```
     No active orchestration found.

     To check status of a specific issue:
       /aod.run --status #NNN

     To start a new orchestration:
       /aod.run "your feature idea"
       /aod.run #NNN
     ```
     Then STOP (exit without proceeding).

3. **Read state file** (read-only): Use Bash to run `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_read'`. Parse the JSON to extract all fields.

4. **Build stage map**: For each stage, determine its display marker using the same logic as [Stage Map Display](#stage-map-display):
   - `completed` → `[x]`, `in_progress` → `[>]`, `pending` → `[ ]`, `failed` → `[!]`
   - For Plan stage: append substage in parentheses if in progress

5. **Determine next action**: Based on `current_stage` and its status:
   - If `in_progress`: "Continue {stage_name}" (or "Continue Plan: {substage}" for Plan)
   - If `completed` and next stage exists: "Start {next_stage_name}"
   - If all completed: "Lifecycle complete — run /aod.deliver"
   - If `failed`: "Retry {stage_name} (resolve blocker first)"

6. **Display status report**:

```
AOD ORCHESTRATOR — Status
==========================
Feature: {feature_name} (#{github_issue})
Branch: {branch}
Governance Tier: {governance_tier}
Session Count: {session_count}
Last Updated: {updated_at}

Stage Map:
  {stage markers}

Current Stage: {current_stage}{substage_detail}
Status: {current_stage_status}
Next Action: {next_action}

Completed: {list of completed stage names, or "none"}
Pending: {list of pending stage names, or "none"}

Governance Gates:
  {for each stage with governance: stage — reviewer: status}

Rejections: {gate_rejections count} total ({intervention_count} interventions)
```

7. **Exit**: STOP immediately after display. Do NOT modify state, invoke any skills, or enter the Core Loop.

### Status Fallback (No State File)

When `--status` is invoked with an issue number but no state file exists, infer status from GitHub Issue labels and on-disk artifacts.

**Algorithm**:

1. **Check GitHub CLI availability**: Run `command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1`
   - If `gh` is available and authenticated: proceed to step 2
   - If `gh` is unavailable or not authenticated:
     - Display: `"GitHub CLI unavailable. Falling back to artifact-only detection."`
     - Skip to step 3 (artifact-only scan)

2. **Read GitHub Issue**: Use Bash to fetch issue data:
   ```
   gh issue view {NNN} --json number,title,labels
   ```
   - Extract `number`, `title`, and `labels` array
   - Search labels for `stage:*` to determine current stage
   - If issue not found: display `"Issue #{NNN} not found on GitHub."` and STOP

3. **Scan on-disk artifacts**: Use the same Artifact Discovery logic (zero-pad issue number, scan for PRD/spec/plan/tasks using Glob).

4. **Infer stage from artifacts** (if GitHub label not available):
   - tasks.md found → infer `build` (Plan complete)
   - plan.md found → infer `plan` (project_plan substage)
   - spec.md found → infer `plan` (spec substage)
   - PRD found → infer `plan` (Define complete)
   - No artifacts → infer `discover`

5. **Display inferred status**:

```
AOD ORCHESTRATOR — Inferred Status (no state file)
====================================================
Issue: #{NNN} — {title or "unknown"}
Detected Stage: {stage from label or artifact inference}
Source: {GitHub label | artifact scan}

Artifacts Found:
  {list of found artifact paths, or "none"}

Note: No state file exists for this feature.
      This status is inferred from {source}. To start orchestration:
        /aod.run #{NNN}
```

6. **Exit**: STOP immediately. Do NOT create a state file or modify anything.

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

After Plan completes, Build in progress:
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

2. **Map stage to number and detail**: Use the lookup table below to determine the stage number (`N`), display name (`STAGE_NAME`), and substage detail (if applicable):

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

   For non-Plan stages (no substage detail):
   ```
   --- STAGE {N}: {STAGE_NAME} ---
   ```

   For Plan substages (substage detail present):
   ```
   --- STAGE 3: PLAN ({substage detail}) ---
   ```

4. **Output immediately**: Display the transition header before invoking the stage skill. This gives the user clear visibility into which stage is about to execute.

**Examples**:
```
--- STAGE 1: DISCOVER ---
--- STAGE 2: DEFINE ---
--- STAGE 3: PLAN (sub-stage 1/3: Feature Specification) ---
--- STAGE 3: PLAN (sub-stage 2/3: Architecture Plan) ---
--- STAGE 3: PLAN (sub-stage 3/3: Task Breakdown) ---
--- STAGE 4: BUILD ---
--- STAGE 5: DELIVER ---
```

### GitHub Integration

After each stage completes successfully (governance gate passed), update the GitHub Issue's `stage:*` label to reflect the new current stage. This keeps the GitHub Issue board in sync with the orchestration state (FR-023).

**Algorithm** (called by Core Loop step 12, after post-stage checkpoint is written):

1. **Check prerequisites**:
   - Read `github_issue` from state. If null (no GitHub Issue for this feature), skip entirely.
   - Check if `gh` CLI is available: `command -v gh >/dev/null 2>&1`. If not, skip silently.
   - Check if `gh` is authenticated: `gh auth status >/dev/null 2>&1`. If not, skip silently.

2. **Determine the new stage label**: Map the newly-completed stage to the next stage in the sequence, since the label should reflect where the feature currently is:

   | Completed Stage | Completed Substage | New Label |
   |-----------------|-------------------|-----------|
   | discover | — | `stage:define` (moving to Define) |
   | define | — | `stage:plan` (moving to Plan) |
   | plan | spec | `stage:plan` (still in Plan, next substage) |
   | plan | project_plan | `stage:plan` (still in Plan, next substage) |
   | plan | tasks | `stage:build` (moving to Build) |
   | build | — | `stage:deliver` (moving to Deliver) |
   | deliver | — | `stage:done` (lifecycle complete) |

   **Note**: Plan substage completions (spec, project_plan) do not change the label — the issue stays at `stage:plan` until all 3 substages complete. Only the final substage (tasks) triggers a label change to `stage:build`.

3. **Update the label**: Use the `github-lifecycle.sh` function:
   ```
   bash -c 'source .aod/scripts/bash/github-lifecycle.sh && aod_gh_update_stage {github_issue} {new_stage}'
   ```
   Where `{new_stage}` is the stage name from the label (e.g., `define`, `plan`, `build`, `deliver`, `done`).

4. **Handle failures gracefully**: If the label update fails for any reason (network error, rate limit, permission issue), log a warning but do NOT halt orchestration. The label update is non-blocking.
   - Display: `"Note: GitHub label update skipped ({reason}). Orchestration continues."`

5. **Backlog refresh**: After updating the label, optionally refresh the backlog:
   ```
   bash .aod/scripts/bash/backlog-regenerate.sh 2>/dev/null || true
   ```
   This is fire-and-forget — failure does not affect orchestration.

---

### Error Logging

Capture stage errors and significant events in the state file's `error_log` array for debugging and auditability. Error entries follow Entity 4 schema.

**Algorithm** (called whenever an error or significant event occurs during orchestration):

1. **Build error entry** following Entity 4 schema:

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
   - **Stage skill failure**: When a Skill tool invocation produces an error or unexpected output. Log the stage name, error type, and a summary of what went wrong.
   - **Governance gate rejection**: Already tracked in `gate_rejections`, but also log a summary entry in `error_log` for easy scanning. Include the reviewer name and brief reason.
   - **Circuit breaker activation**: When max retries are reached. Include the reviewer, stage, and attempt count.
   - **User abort**: When the user chooses to abort. Include the reason (BLOCKED gate, manual decision).
   - **Artifact inconsistency**: When resume validation detects missing artifacts. Include the artifact path and stage.
   - **State corruption**: When the state file fails validation. Include the validation error details.
   - **GitHub errors**: When `gh` CLI operations fail. Include the operation and error message.

5. **Error entries are append-only**: Never remove or modify existing error log entries. The log provides a chronological audit trail of all issues encountered during orchestration.

6. **Display in status**: The `--status` command includes the error count. Users can inspect `.aod/run-state.json` directly for full error details.

---

### Rejection Handling

When a governance gate returns CHANGES_REQUESTED, the orchestrator displays the rejection details and offers the user options to address or pause.

**Algorithm** (called by Core Loop step 10 when result is CHANGES_REQUESTED):

1. **Extract rejection details**: From the artifact's YAML frontmatter, identify which reviewer(s) returned CHANGES_REQUESTED. Collect:
   - `reviewer`: The reviewer agent name (e.g., `product-manager`, `architect`, `team-lead`)
   - `status`: `CHANGES_REQUESTED`
   - `notes`: The reviewer's feedback/required changes
   - `stage`: The current stage name
   - `substage`: The current substage (for Plan stages) or null

2. **Display rejection information**:

```
GOVERNANCE GATE — CHANGES REQUESTED
====================================
Stage: {stage}{substage_detail}
Reviewer: {reviewer}
Attempt: {attempt_number} of 3

Feedback:
  {reviewer notes/required changes}

The reviewer has requested changes before this stage can be approved.
```

3. **Offer options**: Use AskUserQuestion to present choices:
   - Question: "How would you like to proceed?"
   - Options:
     - "Address now" — Continue in this session. The orchestrator will re-invoke the stage skill to address the changes, then re-submit for governance review.
     - "Pause orchestration" — Save current state (including the rejection) and exit gracefully. The user can resume later with `--resume`.

4. **Handle user choice**:

   - **"Address now"**:
     1. Increment `intervention_count` in state (user is manually intervening)
     2. Write updated state atomically
     3. Re-invoke the stage skill via Skill tool (same skill, same arguments as the original invocation)
     4. After skill returns, re-check governance gate result (return to Core Loop step 9)
     5. If approved: continue with normal completion flow
     6. If rejected again: return to this Rejection Handling flow (loop)

   - **"Pause orchestration"**:
     1. Record the rejection in state (see [Retry Tracking](#retry-tracking))
     2. Write state with the current stage still `in_progress` and the rejection recorded
     3. Display pause message:
        ```
        Orchestration paused. State saved to .aod/run-state.json

        To resume later:
          /aod.run --resume

        The orchestrator will continue from the {stage} stage.
        ```
     4. STOP (exit without continuing the loop)

### Retry Tracking

Every governance gate rejection is recorded in the state's `gate_rejections` array for auditability and circuit breaker logic. This section is referenced by Rejection Handling step 4 ("Address now" path) and Pause path.

**Algorithm** (called whenever a governance gate returns CHANGES_REQUESTED or BLOCKED):

1. **Build rejection entry** following Entity 5 schema:

```json
{
  "timestamp": "{current ISO 8601 timestamp}",
  "stage": "{current_stage}",
  "substage": "{current_substage or null}",
  "reviewer": "{reviewer agent name}",
  "status": "{CHANGES_REQUESTED or BLOCKED}",
  "attempt": {attempt_number},
  "feedback": "{reviewer notes/feedback}"
}
```

2. **Calculate attempt number**: Count existing entries in `gate_rejections` that match the same `stage` + `substage` + `reviewer` combination, then add 1. This gives the sequential attempt number for this specific gate.

3. **Append to state**: Add the rejection entry to the `gate_rejections` array:
   ```
   bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_append ".gate_rejections" '"'"'{rejection_json}'"'"''
   ```

4. **Update intervention count**: When the user chooses "Address now" in the Rejection Handling flow, increment `intervention_count`:
   ```
   bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_set ".intervention_count" "{new_count}"'
   ```
   This tracks how many times the user manually intervened at governance gates (for SC-003 metric: "80% of orchestrations complete without manual intervention beyond governance gate decisions").

5. **Update stage governance record**: Also update the stage's `governance` object in state to reflect the latest reviewer status:
   ```
   bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_set ".stages.{stage}.governance.{reviewer_field}" '"'"'{"status":"{status}","date":"{date}","notes":"{notes}"}'"'"''
   ```
   Where `{reviewer_field}` maps:
   - `product-manager` → `pm_signoff`
   - `architect` → `architect_signoff`
   - `team-lead` → `techlead_signoff`

6. **Write state atomically**: All state updates are written atomically via `run-state.sh` helpers.

**Retry flow**: After recording the rejection, if the user chose "Address now", the Rejection Handling flow re-invokes the stage skill. After the skill completes, governance is re-checked. If approved, the rejection history remains in `gate_rejections` as an audit trail. If rejected again, a new entry is appended and the attempt number increments.

### Max-Retry Circuit Breaker

After 3 consecutive rejections on the same governance gate, the orchestrator stops automatic retries and asks the user to intervene manually. This prevents infinite rejection loops where the AI agent cannot satisfy a reviewer's requirements.

**Algorithm** (called by Rejection Handling before offering "Address now"):

1. **Count consecutive rejections**: Query the `gate_rejections` array for entries matching the current `stage` + `substage` + `reviewer` combination. Count how many consecutive entries exist (i.e., entries with sequential `attempt` numbers without an intervening approval).

2. **Check threshold**: If the count is >= 3:

   - **Do NOT offer "Address now"**. Instead, display the circuit breaker message:

   ```
   CIRCUIT BREAKER — Max retries reached
   ======================================
   Stage: {stage}{substage_detail}
   Reviewer: {reviewer}
   Consecutive Rejections: {count}

   The same governance gate has been rejected {count} times.
   Automatic retries are paused to prevent an infinite loop.

   Rejection history:
     Attempt 1: {feedback_summary}
     Attempt 2: {feedback_summary}
     Attempt 3: {feedback_summary}

   Please review the feedback above and make manual changes
   before resuming orchestration.
   ```

   - Use AskUserQuestion:
     - Question: "Max retries reached on this governance gate. How would you like to proceed?"
     - Options:
       - "Pause and fix manually" — Save state with the stage marked as `failed`, exit. User fixes the artifact offline and resumes with `--resume`.
       - "Override and continue" — User takes responsibility. Mark the gate as `BLOCKED_OVERRIDDEN` in state, record the override in `gate_rejections` with a note that the user overrode after max retries, and advance to the next stage.

   - **Handle "Pause and fix manually"**:
     1. Update stage status to `"failed"` in state
     2. Record an error in `error_log`:
        ```json
        {
          "timestamp": "{now}",
          "stage": "{stage}",
          "type": "circuit_breaker",
          "message": "Max retries (3) reached on {reviewer} review for {stage}. Manual intervention required.",
          "recoverable": true
        }
        ```
     3. Write state atomically
     4. Display resume guidance and STOP

   - **Handle "Override and continue"**:
     1. Increment `intervention_count`
     2. Update the stage's governance record to show `BLOCKED_OVERRIDDEN` for the reviewer
     3. Append an override entry to `gate_rejections`:
        ```json
        {
          "timestamp": "{now}",
          "stage": "{stage}",
          "substage": "{substage or null}",
          "reviewer": "{reviewer}",
          "status": "BLOCKED_OVERRIDDEN",
          "attempt": {count + 1},
          "feedback": "User override after {count} consecutive rejections."
        }
        ```
     4. Write state atomically
     5. Mark stage as completed and continue the Core Loop

3. **If count < 3**: The circuit breaker does not fire. Return to Rejection Handling, which offers the normal "Address now" / "Pause orchestration" options.

### Blocked Handling

When a governance gate returns BLOCKED, it represents a critical blocker that a reviewer has identified. The orchestrator displays the blocker details and offers the user three options: resolve, override, or abort.

**Algorithm** (called by Core Loop step 10 when result is BLOCKED):

1. **Extract blocker details**: From the artifact's YAML frontmatter, identify which reviewer(s) returned BLOCKED. Collect:
   - `reviewer`: The reviewer agent name
   - `status`: `BLOCKED`
   - `notes`: The reviewer's blocker description and veto reason
   - `stage`: The current stage name
   - `substage`: The current substage or null

2. **Record the rejection**: Use [Retry Tracking](#retry-tracking) to record this BLOCKED result in `gate_rejections`.

3. **Display blocker information**:

```
GOVERNANCE GATE — BLOCKED
==========================
Stage: {stage}{substage_detail}
Reviewer: {reviewer}

Blocker:
  {reviewer notes/blocker description}

A reviewer has identified a critical issue that prevents this stage
from being approved. This is a hard block, not a request for changes.
```

4. **Offer options**: Use AskUserQuestion to present choices:
   - Question: "A governance gate has been blocked. How would you like to proceed?"
   - Options:
     - "Resolve and re-submit" — Address the blocker in this session. The orchestrator will re-invoke the stage skill, then re-submit for governance review.
     - "Override with justification" — Provide a written justification for overriding the blocker. The gate will be marked `BLOCKED_OVERRIDDEN` and orchestration will continue. Use this only when the blocker is understood and accepted.
     - "Abort orchestration" — Cancel the orchestration entirely. State is saved but the stage is marked as `failed`.

5. **Handle user choice**:

   - **"Resolve and re-submit"**:
     1. Increment `intervention_count`
     2. Write updated state
     3. Re-invoke the stage skill via Skill tool
     4. After skill returns, re-check governance gate (return to Core Loop step 9)
     5. If now approved: continue normally
     6. If blocked again: return to this Blocked Handling flow
     7. **Note**: The max-retry circuit breaker also applies to BLOCKED results. After 3 consecutive BLOCKED results on the same gate, the circuit breaker fires.

   - **"Override with justification"**:
     1. The user's justification is captured from the AskUserQuestion response (they provide it via the "Other" free-text option or it's implied by selecting Override)
     2. Increment `intervention_count`
     3. Update the stage's governance record to show `BLOCKED_OVERRIDDEN`:
        ```json
        {
          "status": "BLOCKED_OVERRIDDEN",
          "date": "{today}",
          "notes": "User override: {justification}"
        }
        ```
     4. Append override entry to `gate_rejections`:
        ```json
        {
          "timestamp": "{now}",
          "stage": "{stage}",
          "substage": "{substage or null}",
          "reviewer": "{reviewer}",
          "status": "BLOCKED_OVERRIDDEN",
          "attempt": {attempt_number},
          "feedback": "User override: {justification}"
        }
        ```
     5. Write state atomically
     6. Mark stage governance as passed and continue the Core Loop

   - **"Abort orchestration"**:
     1. Update stage status to `"failed"` in state
     2. Record an error in `error_log`:
        ```json
        {
          "timestamp": "{now}",
          "stage": "{stage}",
          "type": "user_abort",
          "message": "User aborted orchestration due to BLOCKED governance gate ({reviewer}).",
          "recoverable": true
        }
        ```
     3. Write state atomically
     4. Display abort message:
        ```
        Orchestration aborted. State saved to .aod/run-state.json

        The {stage} stage is marked as failed.

        To restart this stage later:
          /aod.run --resume

        The orchestrator will retry the {stage} stage from the beginning.
        ```
     5. STOP (exit without continuing)

### Corrupted State File Handling

When the state file fails validation (JSON parse error, missing required fields, or unrecognized schema version), the orchestrator archives the corrupt file and offers recovery options.

**Algorithm** (called by Resume Entry step 2 when `aod_state_validate` returns non-zero):

1. **Archive the corrupt file**: Generate a timestamped backup name and copy the corrupt file:
   ```
   bash -c 'cp .aod/run-state.json ".aod/run-state.json.corrupt.$(date +%Y%m%d%H%M%S)"'
   ```

2. **Display corruption details**:

   ```
   ERROR: Corrupted state file detected
   ======================================
   File: .aod/run-state.json
   Archive: .aod/run-state.json.corrupt.{timestamp}

   Validation errors:
     {error details from aod_state_validate stderr}

   The corrupted file has been archived for inspection.
   ```

3. **Attempt artifact-based recovery**: Scan disk for existing artifacts to determine what stage the feature was in:
   - Use the same [Artifact Discovery](#artifact-discovery) algorithm to find PRD, spec, plan, tasks
   - Infer the current lifecycle stage from found artifacts (same logic as GitHub Graceful Degradation Level 1/2 artifact inference)

4. **Offer recovery options**: Use AskUserQuestion:
   - Question: "State file is corrupted. How would you like to recover?"
   - Options:
     - "Start fresh from artifacts" — Create a new state file based on discovered artifacts (infer completed stages from what exists on disk). Delete the corrupt `.aod/run-state.json` and create a fresh one. Then proceed to the Core Loop from the inferred stage.
     - "Start completely fresh" — Delete the corrupt state file entirely. Display guidance: `"Run /aod.run 'idea' or /aod.run #NNN to begin a new orchestration."` Then STOP.

5. **Handle "Start fresh from artifacts"**:
   1. Determine feature ID from the current branch name (extract NNN from `NNN-feature-name` pattern)
   2. If branch doesn't match the pattern, ask user for the feature number
   3. Run Artifact Discovery with that feature ID
   4. Infer completed stages from found artifacts
   5. Build a new state file (same as Issue Entry step 9 logic) with discovered artifacts
   6. Read governance tier from constitution
   7. Write the new state file atomically
   8. Display: `"Recovery complete. New state created from {N} artifacts found on disk."`
   9. Proceed to the Core Loop

6. **Handle "Start completely fresh"**:
   1. Delete `.aod/run-state.json`
   2. Display guidance for starting a new orchestration
   3. STOP

---

### Lifecycle Already Complete Detection

Guard clause that prevents restarting an already-completed lifecycle. This is checked at:
- Resume Entry step 6 (before artifact validation and other resume checks)
- Core Loop step 2 (as part of the main loop)
- Issue Entry step 4 (when `stage:done` label is detected)

**Algorithm**:

1. **Read stage statuses**: Check the `status` field for all 5 stages (`discover`, `define`, `plan`, `build`, `deliver`) in the state file.

2. **Check if all completed**: If all 5 stages have `status: "completed"`:

   - Display the lifecycle completion summary (same as [Lifecycle Complete](#lifecycle-complete)), then STOP. Do NOT proceed to the Core Loop, restart any stages, or invoke any skills.

   ```
   AOD ORCHESTRATOR — Lifecycle Already Complete
   ===============================================
   Feature: {feature_name} (#{github_issue})
   Branch: {branch}

   All 5 lifecycle stages have already been completed.

   Stage Map:
     [x] Discover  [x] Define  [x] Plan  [x] Build  [x] Deliver

   To start a new feature:
     /aod.run "your new idea"
     /aod.run #NNN

   To view the delivery summary:
     /aod.run --status
   ```

   Then STOP immediately.

3. **If not all completed**: Continue with the normal flow (resume validation, core loop, etc.).

---

### Lifecycle Complete

When all 5 stages show `status: "completed"` (checked at Core Loop step 2), display the lifecycle completion summary and archive the state file.

**Algorithm**:

1. **Read final state**: Read `.aod/run-state.json` for all completion data.

2. **Calculate metrics**:
   - `session_count`: Read directly from state
   - `governance_gates_passed`: Count stages where `governance` object is non-null and contains at least one sign-off with APPROVED or APPROVED_WITH_CONCERNS status. Include Plan substages individually.
   - `total_governance_gates`: Count stages that had governance checks (based on tier rules)
   - `total_rejections`: Length of `gate_rejections` array
   - `intervention_count`: Read directly from state
   - `duration`: Calculate from `started_at` to `updated_at` (display as "X days" or "X hours")
   - `artifacts`: Collect all non-empty `artifacts` arrays from each stage and Plan substages

3. **Display completion summary**:

```
AOD ORCHESTRATOR — Lifecycle Complete
=====================================
Feature: {feature_name} (#{github_issue})
Branch: {branch}
Duration: {session_count} session(s), {duration}
Stages: 5/5 complete
Governance Gates: {governance_gates_passed}/{total_governance_gates} passed
Rejections: {total_rejections} total ({intervention_count} manual interventions)

Stage Map:
  [x] Discover  [x] Define  [x] Plan  [x] Build  [x] Deliver

Artifacts:
  - {artifact_path_1}
  - {artifact_path_2}
  - ...

Next: /aod.deliver FEATURE: {feature_id} - {feature_name}
```

4. **Archive state file**: Copy the state file to the specs directory for permanent record:
   ```
   bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_archive "specs/{NNN}-{feature_name}/run-state.json"'
   ```
   Where `{NNN}` is the `feature_id` and `{feature_name}` is from state.

5. **Do NOT delete the active state file**: Keep `.aod/run-state.json` in place so `--status` can still read it and the lifecycle-already-complete detection works on subsequent invocations.

6. **Exit**: The orchestrator's work is complete. The user can proceed with `/aod.deliver` if it wasn't already the final stage, or review the archived state.
