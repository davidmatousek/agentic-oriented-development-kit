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

Next: /aod.tasks
```

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
