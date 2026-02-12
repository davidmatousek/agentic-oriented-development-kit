---
description: Generate tasks with triple sign-off (PM + Architect + Team-Lead) - Streamlined v2
---

## User Input

```text
$ARGUMENTS
```

Consider user input before proceeding (if not empty).

## Overview

Generate an actionable, dependency-ordered tasks.md with automatic Triad triple sign-off governance.

**Flow**: Validate plan → Generate tasks → Triple review (parallel) → Handle blockers → Inject frontmatter → Generate assignments

## Step 1: Validate Prerequisites

1. Get branch: `git branch --show-current` → must match `NNN-*` pattern
2. Find plan: `specs/{NNN}-*/plan.md` → must exist
3. Parse frontmatter: Verify `triad.pm_signoff.status` and `triad.architect_signoff.status` are APPROVED (or APPROVED_WITH_CONCERNS/BLOCKED_OVERRIDDEN)
4. If validation fails: Show error with required workflow order and exit

## Step 1b: Budget Tracking (Non-Fatal)

Initialize session budget tracking. All budget operations are wrapped in error-swallowing guards — failures here never block skill execution.

1. **Check state file**: `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_exists && echo "exists" || echo "none"'`
   - If "none" → step 3 (create state)
   - If "exists" → step 2 (check orchestrator)

2. **Detect active orchestrator**: Run `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_get_loop_context'` (returns `stage|substage|status`) and `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_get ".updated_at"'`.
   - If any stage is `in_progress` AND `updated_at` is within 5 minutes of now → **skip all budget tracking** (orchestrator is active, it handles budget). Proceed to Step 2.
   - Otherwise → standalone mode, continue to step 2b.

2b. **Validate feature ID match**: Extract feature ID from branch: `BRANCH=$(git branch --show-current) && echo "$BRANCH" | sed 's/^\([0-9]\{3\}\).*/\1/'`. Compare with state's `feature_id` via `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_get ".feature_id"'`.
   - Match → step 4
   - No match → Use AskUserQuestion: "A state file exists for feature {state_feature_id} but you're on branch {branch}. Archive old state and create new?" Options: "Archive and create new", "Keep existing state". If archive: copy `.aod/run-state.json` to `specs/{old_feature_id}-*/run-state.json`, then proceed to step 3. If keep: proceed to step 4.

3. **Read calibrated defaults from registry**: Query the performance registry for calibrated budget values:
   ```
   USABLE_BUDGET=$(bash -c 'source .aod/scripts/bash/performance-registry.sh 2>/dev/null && aod_registry_get_default usable_budget || echo 60000')
   SAFETY_MULT=$(bash -c 'source .aod/scripts/bash/performance-registry.sh 2>/dev/null && aod_registry_get_default safety_multiplier || echo 1.5')
   PLAN_EST=$(bash -c 'source .aod/scripts/bash/performance-registry.sh 2>/dev/null && aod_registry_get_default per_stage_estimates.plan || echo 5000')
   ```

4. **Create state file**: Extract feature ID from branch (`NNN` from `NNN-*` pattern; default `"000"` if no match). Extract feature name from branch (everything after `NNN-`). Create state via:
   ```
   bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_create '"'"'{"version":"1.0","feature_id":"{NNN}","feature_name":"{name}","github_issue":null,"idea":"","branch":"{branch}","started_at":"{now}","updated_at":"{now}","governance_tier":"standard","current_stage":"plan","current_substage":null,"session_count":1,"intervention_count":0,"stages":{"discover":{"status":"pending","started_at":null,"completed_at":null,"artifacts":[],"governance":null,"substages":null,"error":null},"define":{"status":"pending","started_at":null,"completed_at":null,"artifacts":[],"governance":null,"substages":null,"error":null},"plan":{"status":"pending","started_at":null,"completed_at":null,"artifacts":[],"governance":null,"substages":{"spec":{"status":"pending","artifacts":[]},"project_plan":{"status":"pending","artifacts":[]},"tasks":{"status":"pending","artifacts":[]}},"error":null},"build":{"status":"pending","started_at":null,"completed_at":null,"artifacts":[],"governance":null,"substages":null,"error":null},"deliver":{"status":"pending","started_at":null,"completed_at":null,"artifacts":[],"governance":null,"substages":null,"error":null}},"token_budget":{"window_total":200000,"usable_budget":{USABLE_BUDGET},"safety_multiplier":{SAFETY_MULT},"estimated_total":0,"stage_estimates":{"discover":{"pre":0,"post":0},"define":{"pre":0,"post":0},"plan":{"pre":0,"post":0},"build":{"pre":0,"post":0},"deliver":{"pre":0,"post":0}},"threshold_percent":80,"adaptive_mode":false,"last_checkpoint":null,"prior_sessions":[]},"error_log":[],"gate_rejections":[]}'"'"''
   ```

5. **Write pre-estimate**: `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_update_budget "plan" "pre" "{PLAN_EST}"'`

If any step fails, log the error and continue to Step 2 — budget tracking is non-fatal.

## Step 2: Generate Tasks

### 2a. Setup

1. Run `.aod/scripts/bash/check-prerequisites.sh --json` from repo root and parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

### 2b. Load Design Documents

Read from FEATURE_DIR:
- **Required**: plan.md (tech stack, libraries, structure), spec.md (user stories with priorities)
- **Optional**: data-model.md (entities), contracts/ (API endpoints), research.md (decisions), quickstart.md (test scenarios)
- Note: Not all projects have all documents. Generate tasks based on what's available.

### 2c. Execute Task Generation Workflow

1. Load plan.md and extract tech stack, libraries, project structure
2. Load spec.md and extract user stories with their priorities (P1, P2, P3, etc.)
3. If data-model.md exists: Extract entities and map to user stories
4. If contracts/ exists: Map endpoints to user stories
5. If research.md exists: Extract decisions for setup tasks
6. Generate tasks organized by user story (see Task Generation Rules below)
7. Generate dependency graph showing user story completion order
8. Create parallel execution examples per user story
9. Validate task completeness (each user story has all needed tasks, independently testable)

### 2d. Generate tasks.md

Use `.aod/templates/tasks-template.md` as structure, fill with:
- Correct feature name from plan.md
- Phase 1: Setup tasks (project initialization)
- Phase 2: Foundational tasks (blocking prerequisites for all user stories)
- Phase 3+: One phase per user story (in priority order from spec.md)
- Each phase includes: story goal, independent test criteria, tests (if requested), implementation tasks
- Final Phase: Polish & cross-cutting concerns
- All tasks must follow the strict checklist format (see Task Generation Rules below)
- Clear file paths for each task
- Dependencies section showing story completion order
- Parallel execution examples per story
- Implementation strategy section (MVP first, incremental delivery)

### 2e. Verify Output

1. Verify `tasks.md` was created at `specs/{NNN}-*/tasks.md`
2. If not created: Error and exit
3. Output summary: total task count, task count per user story, parallel opportunities, independent test criteria, suggested MVP scope
4. Format validation: Confirm ALL tasks follow the checklist format (checkbox, ID, labels, file paths)

The tasks.md should be immediately executable - each task must be specific enough that an LLM can complete it without additional context.

Context for task generation: $ARGUMENTS

## Task Generation Rules

**CRITICAL**: Tasks MUST be organized by user story to enable independent implementation and testing.

**Tests are OPTIONAL**: Only generate test tasks if explicitly requested in the feature specification or if user requests TDD approach.

### Checklist Format (REQUIRED)

Every task MUST strictly follow this format:

```text
- [ ] [TaskID] [P?] [Story?] Description with file path
```

**Format Components**:

1. **Checkbox**: ALWAYS start with `- [ ]` (markdown checkbox)
2. **Task ID**: Sequential number (T001, T002, T003...) in execution order
3. **[P] marker**: Include ONLY if task is parallelizable (different files, no dependencies on incomplete tasks)
4. **[Story] label**: REQUIRED for user story phase tasks only
   - Format: [US1], [US2], [US3], etc. (maps to user stories from spec.md)
   - Setup phase: NO story label
   - Foundational phase: NO story label
   - User Story phases: MUST have story label
   - Polish phase: NO story label
5. **Description**: Clear action with exact file path

**Examples**:

- CORRECT: `- [ ] T001 Create project structure per implementation plan`
- CORRECT: `- [ ] T005 [P] Implement authentication middleware in src/middleware/auth.py`
- CORRECT: `- [ ] T012 [P] [US1] Create User model in src/models/user.py`
- CORRECT: `- [ ] T014 [US1] Implement UserService in src/services/user_service.py`
- WRONG: `- [ ] Create User model` (missing ID and Story label)
- WRONG: `T001 [US1] Create model` (missing checkbox)
- WRONG: `- [ ] [US1] Create User model` (missing Task ID)
- WRONG: `- [ ] T001 [US1] Create model` (missing file path)

### Task Organization

1. **From User Stories (spec.md)** - PRIMARY ORGANIZATION:
   - Each user story (P1, P2, P3...) gets its own phase
   - Map all related components to their story:
     - Models needed for that story
     - Services needed for that story
     - Endpoints/UI needed for that story
     - If tests requested: Tests specific to that story
   - Mark story dependencies (most stories should be independent)

2. **From Contracts**:
   - Map each contract/endpoint to the user story it serves
   - If tests requested: Each contract gets a contract test task [P] before implementation in that story's phase

3. **From Data Model**:
   - Map each entity to the user story(ies) that need it
   - If entity serves multiple stories: Put in earliest story or Setup phase
   - Relationships map to service layer tasks in appropriate story phase

4. **From Setup/Infrastructure**:
   - Shared infrastructure goes in Setup phase (Phase 1)
   - Foundational/blocking tasks go in Foundational phase (Phase 2)
   - Story-specific setup goes within that story's phase

### Phase Structure

- **Phase 1**: Setup (project initialization)
- **Phase 2**: Foundational (blocking prerequisites - MUST complete before user stories)
- **Phase 3+**: User Stories in priority order (P1, P2, P3...)
  - Within each story: Tests (if requested) → Models → Services → Endpoints → Integration
  - Each phase should be a complete, independently testable increment
- **Final Phase**: Polish & Cross-Cutting Concerns

## Step 3: Triple Sign-off (Parallel)

Launch **three Task agents in parallel** (single message, three Task tool calls):

| Agent | subagent_type | Focus | Key Criteria |
|-------|---------------|-------|--------------|
| PM | product-manager | Product scope | User stories covered, no scope creep, FRs addressed |
| Architect | architect | Technical | Dependencies ordered, parallel opportunities, patterns maintained |
| Team-Lead | team-lead | Timeline | Granularity appropriate, critical path identified, parallelization maximized |

**Prompt template for each** (customize focus area):
```
Review tasks.md at {tasks_path} for {FOCUS AREA}.

Read the file, then provide sign-off:

STATUS: [APPROVED | APPROVED_WITH_CONCERNS | CHANGES_REQUESTED | BLOCKED]
NOTES: [Your detailed feedback]
```

**Parse responses**: Extract STATUS and NOTES from each agent's output.

## Step 4: Handle Review Results

**All APPROVED/APPROVED_WITH_CONCERNS**: Proceed to Step 5

**Any CHANGES_REQUESTED**:
1. Display feedback from reviewers who requested changes
2. Use architect agent to update tasks addressing the feedback
3. Re-run reviews only for reviewers who requested changes
4. Loop until all approved or user aborts

**Any BLOCKED**:
1. Display blocker with veto domain (PM=scope, Architect=technical, Team-Lead=timeline)
2. Use AskUserQuestion with options:
   - **Resolve**: Address issues and re-submit to blocked reviewer
   - **Override**: Provide justification, mark as BLOCKED_OVERRIDDEN
   - **Abort**: Cancel task generation

**Multiple BLOCKED (cross-domain conflict)**:
1. Display all blockers with their domains
2. Use AskUserQuestion for executive decision:
   - **Product priority**: Override non-PM blocks
   - **Technical priority**: Override non-Architect blocks
   - **Schedule priority**: Override non-Team-Lead blocks
   - **Revise all**: Return to planning phase
   - **Abort**: Cancel

## Step 5: Inject Frontmatter

Add YAML frontmatter to tasks.md (prepend to existing content):

```yaml
---
triad:
  pm_signoff:
    agent: product-manager
    date: {YYYY-MM-DD}
    status: {pm_status}
    notes: "{pm_notes}"
  architect_signoff:
    agent: architect
    date: {YYYY-MM-DD}
    status: {architect_status}
    notes: "{architect_notes}"
  techlead_signoff:
    agent: team-lead
    date: {YYYY-MM-DD}
    status: {techlead_status}
    notes: "{techlead_notes}"
---
```

## Step 6: Generate Agent Assignments

Invoke team-lead agent to create `agent-assignments.md`.

**Reference**: Use [Agent Registry](.claude/agents/) for task-to-agent mapping.

**Output includes**:
- Agent Assignment Matrix (task to agent mapping based on Agent Registry)
- Parallel Execution Waves (grouped by dependencies)
- Quality Gates between waves
- Time estimates per wave

Save to `specs/{NNN}-*/agent-assignments.md`

## Step 7: Report Completion

**Re-ground before output**: Re-read the template below exactly. Do not paraphrase or substitute reviewer recommendations for the `Next:` line — it must always be `/aod.build FEATURE: {feature_number} - {feature_name}`.

Display summary:
```
TASK BREAKDOWN COMPLETE

Feature: {feature_number}
Tasks: {tasks_path}
Assignments: {assignments_path}

Triple Sign-offs:
- PM: {pm_status}
- Architect: {architect_status}
- Team-Lead: {techlead_status}

Next: /aod.build FEATURE: {feature_number} - {feature_name}
```

### Budget Tracking (Non-Fatal)

1. Read calibrated estimate: `PLAN_EST=$(bash -c 'source .aod/scripts/bash/performance-registry.sh 2>/dev/null && aod_registry_get_default per_stage_estimates.plan || echo 5000')`
2. Write post-estimate: `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_exists && aod_state_update_budget "plan" "post" "{PLAN_EST}" || true'`
3. Read summary: `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_exists && aod_state_get_budget_summary || echo "0|0|0|false"'` — returns `estimated_total|usable_budget|threshold_percent|adaptive_mode`
3. Parse the pipe-delimited result. Calculate `utilization = (estimated_total * 100) / usable_budget`.
4. If `estimated_total > 0`, append to the completion output: `(~{utilization}% budget used)`
5. If any step fails, omit the budget line — do not display errors.

## Quality Checklist

- [ ] Plan has dual sign-offs (PM + Architect)
- [ ] tasks.md generated with full task generation workflow
- [ ] Triple review executed in parallel
- [ ] Blockers handled (resolved, overridden, or aborted)
- [ ] Frontmatter injected with all three sign-offs
- [ ] agent-assignments.md generated
- [ ] Completion summary displayed
