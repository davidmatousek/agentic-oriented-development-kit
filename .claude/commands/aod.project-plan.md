---
description: Create implementation plan with dual sign-off (PM + Architect) - Streamlined v2
---

## User Input

```text
$ARGUMENTS
```

Consider user input before proceeding (if not empty).

## Overview

Self-contained implementation planning command with automatic PM + Architect dual sign-off.

**Flow**: Validate spec → Setup & load context → Generate plan (phases 0-1) → Dual review (parallel) → Handle blockers → Inject frontmatter

## Step 1: Validate Prerequisites

1. Get branch: `git branch --show-current` → must match `NNN-*` pattern
2. Find spec: `specs/{NNN}-*/spec.md` → must exist
3. Parse frontmatter: Verify `triad.pm_signoff.status` is APPROVED (or APPROVED_WITH_CONCERNS/BLOCKED_OVERRIDDEN)
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

## Step 2: Generate Plan

### 2a: Setup

1. Run `.aod/scripts/bash/setup-plan.sh --json` from repo root and parse JSON for FEATURE_SPEC, IMPL_PLAN, SPECS_DIR, BRANCH. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

### 2b: Load Context

1. Read FEATURE_SPEC and `.aod/memory/constitution.md`
2. Load IMPL_PLAN template (already copied by setup script)

### 2c: Execute Plan Workflow

Follow the structure in IMPL_PLAN template to:
- Fill Technical Context (mark unknowns as "NEEDS CLARIFICATION")
- Fill Constitution Check section from constitution
- Evaluate gates (ERROR if violations unjustified)
- Phase 0: Generate research.md (resolve all NEEDS CLARIFICATION)
- Phase 1: Generate data-model.md, contracts/, quickstart.md
- Phase 1: Update agent context by running the agent script
- Re-evaluate Constitution Check post-design

### Phase 0: Outline & Research

1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION → research task
   - For each dependency → best practices task
   - For each integration → patterns task

2. **Generate and dispatch research agents**:
   ```
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

### Phase 1: Design & Contracts

**Prerequisites:** `research.md` complete

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Generate API contracts** from functional requirements:
   - For each user action → endpoint
   - Use standard REST/GraphQL patterns
   - Output OpenAPI/GraphQL schema to `/contracts/`

3. **Agent context update**:
   - Run `.aod/scripts/bash/update-agent-context.sh claude`
   - These scripts detect which AI agent is in use
   - Update the appropriate agent-specific context file
   - Add only new technology from current plan
   - Preserve manual additions between markers

**Output**: data-model.md, /contracts/*, quickstart.md, agent-specific file

### 2d: Verify Plan Created

1. Verify `plan.md` was created at `specs/{NNN}-*/plan.md`
2. If not created: Error and exit

## Step 3: Dual Sign-off (Parallel)

Launch **two Task agents in parallel** (single message, two Task tool calls):

| Agent | subagent_type | Focus | Key Criteria |
|-------|---------------|-------|--------------|
| PM | product-manager | Product alignment | Spec requirements covered, user stories, acceptance criteria, no scope creep |
| Architect | architect | Technical | Architecture sound, technology appropriate, security addressed, scalable |

**Prompt template for each** (customize focus area):
```
Review plan.md at {plan_path} for {FOCUS AREA}.

Read the file, then provide sign-off:

STATUS: [APPROVED | APPROVED_WITH_CONCERNS | CHANGES_REQUESTED | BLOCKED]
NOTES: [Your detailed feedback]
```

**Parse responses**: Extract STATUS and NOTES from each agent's output.

## Step 4: Handle Review Results

**All APPROVED/APPROVED_WITH_CONCERNS**: → Proceed to Step 5

**Any CHANGES_REQUESTED**:
1. Display feedback from reviewers who requested changes
2. Use architect agent to update plan addressing the feedback
3. Re-run reviews only for reviewers who requested changes
4. Loop until all approved or user aborts

**Any BLOCKED**:
1. Display blocker with veto domain (PM=product scope, Architect=technical)
2. Use AskUserQuestion with options:
   - **Resolve**: Address issues and re-submit to blocked reviewer
   - **Override**: Provide justification (min 20 chars), mark as BLOCKED_OVERRIDDEN
   - **Abort**: Cancel plan creation

## Step 5: Inject Frontmatter

Add YAML frontmatter to plan.md (prepend to existing content):

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
  techlead_signoff: null  # Added by /aod.tasks
---
```

## Step 6: GitHub Lifecycle Update

After plan creation, regenerate BACKLOG.md to reflect current state:

1. Run `.aod/scripts/bash/backlog-regenerate.sh` to refresh BACKLOG.md
2. If `gh` is unavailable, skip silently (graceful degradation)

## Step 7: Report Completion

**Re-ground before output**: Re-read the template below exactly. Do not paraphrase or substitute reviewer recommendations for the `Next:` line — it must always be `/aod.plan PLAN: {feature_number} - {feature_name}`.

Display summary including branch, IMPL_PLAN path, and generated artifacts:
```
IMPLEMENTATION PLAN COMPLETE

Feature: {feature_number}
Spec: {spec_path}
Plan: {plan_path}
Artifacts: research.md, data-model.md, contracts/, quickstart.md

Dual Sign-offs:
- PM: {pm_status}
- Architect: {architect_status}

Next: /aod.plan PLAN: {feature_number} - {feature_name}
```

### Budget Tracking (Non-Fatal)

1. Read calibrated estimate: `PLAN_EST=$(bash -c 'source .aod/scripts/bash/performance-registry.sh 2>/dev/null && aod_registry_get_default per_stage_estimates.plan || echo 5000')`
2. Write post-estimate: `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_exists && aod_state_update_budget "plan" "post" "{PLAN_EST}" || true'`
3. Read summary: `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_exists && aod_state_get_budget_summary || echo "0|0|0|false"'` — returns `estimated_total|usable_budget|threshold_percent|adaptive_mode`
3. Parse the pipe-delimited result. Calculate `utilization = (estimated_total * 100) / usable_budget`.
4. If `estimated_total > 0`, append to the completion output: `(~{utilization}% budget used)`
5. If any step fails, omit the budget line — do not display errors.

## Key Rules

- Use absolute paths
- ERROR on gate failures or unresolved clarifications
- Command ends after Phase 1 planning and dual sign-off

## Quality Checklist

- [ ] Spec has approved PM sign-off
- [ ] plan.md created with full plan generation workflow
- [ ] Phase 0 research.md generated
- [ ] Phase 1 design artifacts generated
- [ ] Agent context updated
- [ ] Dual review executed in parallel
- [ ] Blockers handled (resolved, overridden, or aborted)
- [ ] Frontmatter injected with PM + Architect sign-offs
- [ ] Completion summary displayed
