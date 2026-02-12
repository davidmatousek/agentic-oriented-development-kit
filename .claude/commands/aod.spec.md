---
description: Create feature specification with automatic PM sign-off - Streamlined v2
---

## User Input

```text
$ARGUMENTS
```

Consider user input before proceeding (if not empty).

## Overview

Creates a feature specification with automatic PM sign-off (Constitution Principle VIII: Product-Spec Alignment). Generates spec.md inline with research grounding and governance review.

**Flow**: Validate PRD → **Research** → Generate spec (inline) → PM review → Handle blockers → Inject frontmatter

## Step 1: Validate Prerequisites

1. Get branch: `git branch --show-current` → must match `NNN-*` pattern
2. Find PRD: `docs/product/02_PRD/{NNN}-*.md` → must exist
3. Parse frontmatter: Verify all Triad sign-offs are APPROVED (or APPROVED_WITH_CONCERNS/BLOCKED_OVERRIDDEN)
4. If validation fails: Show error with required workflow order and exit
5. **GitHub Lifecycle Update (early)**: If a GitHub Issue exists for this feature, update its stage label to `stage:plan` using `aod_gh_update_stage` from `.aod/scripts/bash/github-lifecycle.sh`. This moves the issue to the Plan column on the Projects board at the *start* of specification work. Run `.aod/scripts/bash/backlog-regenerate.sh` to refresh BACKLOG.md. If `gh` is unavailable, skip silently (graceful degradation).

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

## Step 2: Research Phase

Before generating the specification, conduct research to ground the spec in reality. Run these **in parallel** using Task agents:

| Research Area | Agent/Tool | What to Find | Output |
|---------------|------------|--------------|--------|
| Knowledge Base | kb-query skill | Similar patterns, lessons learned, past bug fixes | Relevant KB entries |
| Codebase | Explore agent | Existing implementations, naming conventions, utilities | Similar features, patterns |
| Architecture | Read tool | Relevant architecture docs, constraints, dependencies | Technical constraints |
| Web Research | WebSearch tool | Industry best practices, existing solutions, common patterns | External references |

**Parallel Execution**: Launch all four research tasks simultaneously to minimize time.

**Research Prompt Template** (for Explore agent):
```
Research the codebase for the feature: {prd_title}

Find:
1. Similar features already implemented (patterns to follow)
2. Relevant utilities, helpers, or shared components
3. Naming conventions used for similar functionality
4. Any existing code that this feature might extend or integrate with

PRD context: {prd_path}
```

**Web Research Queries** (derive from PRD):
- "{feature_type} best practices {year}"
- "{feature_type} implementation patterns"
- "common {feature_type} user experience patterns"

**Output**: Create `specs/{NNN}-*/research.md` with findings:

```markdown
# Research Summary: {feature_name}

## Knowledge Base Findings
- [List relevant KB entries with links]
- Key lessons: ...

## Codebase Analysis
- Similar features: [list with file paths]
- Patterns to follow: ...
- Utilities to reuse: ...

## Architecture Constraints
- Relevant docs: [list with links]
- Key constraints: ...
- Dependencies: ...

## Industry Research
- Best practices: ...
- Common patterns: ...
- References: [links]

## Recommendations for Spec
- [Bullet points of what to include/avoid based on research]
```

**Pass research.md to Step 3** for use as context during spec generation.

## Step 3: Generate Specification (Inline)

The text the user typed after the command **is** the feature description. Do not ask the user to repeat it unless they provided an empty command.

### 3.1 Setup

1. **Check for Approved PRD** (PRD → Spec Traceability):
   - Search `docs/product/02_PRD/` for a PRD matching the feature description
   - Look for status "Approved" or "In Progress" in the PRD registry (INDEX.md)
   - If found, extract the PRD number (e.g., `006` from `006-phase-production-launch`)
   - **Use `--number N` flag** with the PRD number:
     ```bash
     .aod/scripts/bash/create-new-feature.sh --json --number N "$ARGUMENTS"
     ```
   - If no PRD found, warn user:
     ```
     ⚠️ Warning: No approved PRD found for this feature.
     Per Constitution v1.4.0: "No spec.md without an approved PRD"
     Recommended: Create PRD first with /aod.define <topic>
     Continue without PRD? (y/n)
     ```

2. Run the script `.aod/scripts/bash/create-new-feature.sh --json [--number N] "$ARGUMENTS"` from repo root and parse its JSON output for BRANCH_NAME and SPEC_FILE. All file paths must be absolute.
   **IMPORTANT** You must only ever run this script once. The JSON is provided in the terminal as output - always refer to it to get the actual content you're looking for. For single quotes in args, use: `"I'm Groot"`.

3. Load `.aod/templates/spec-template.md` to understand required sections.

### 3.2 Execution Flow

1. Parse user description from Input
   If empty: ERROR "No feature description provided"
2. Extract key concepts from description
   Identify: actors, actions, data, constraints
3. For unclear aspects:
   - Make informed guesses based on context, industry standards, and research.md findings
   - Only mark with [NEEDS CLARIFICATION: specific question] if:
     - The choice significantly impacts feature scope or user experience
     - Multiple reasonable interpretations exist with different implications
     - No reasonable default exists
   - **LIMIT: Maximum 3 [NEEDS CLARIFICATION] markers total**
   - Prioritize clarifications by impact: scope > security/privacy > user experience > technical details
4. Fill User Scenarios & Testing section
   If no clear user flow: ERROR "Cannot determine user scenarios"
5. Generate Functional Requirements
   Each requirement must be testable
   Use reasonable defaults for unspecified details (document assumptions in Assumptions section)
6. Define Success Criteria
   Create measurable, technology-agnostic outcomes
   Include both quantitative metrics and qualitative measures
   Each criterion must be verifiable without implementation details
7. Identify Key Entities (if data involved)
8. Return: SUCCESS (spec ready for review)

### 3.3 Write Specification

Write the specification to SPEC_FILE using the template structure, replacing placeholders with concrete details derived from the feature description (arguments) while preserving section order and headings.

### 3.4 Quality Validation

After writing the initial spec, validate against quality criteria:

a. **Create Spec Quality Checklist**: Generate a checklist file at `FEATURE_DIR/checklists/requirements.md`:

   ```markdown
   # Specification Quality Checklist: [FEATURE NAME]

   **Purpose**: Validate specification completeness and quality
   **Created**: [DATE]
   **Feature**: [Link to spec.md]

   ## Content Quality
   - [ ] No implementation details (languages, frameworks, APIs)
   - [ ] Focused on user value and business needs
   - [ ] Written for non-technical stakeholders
   - [ ] All mandatory sections completed

   ## Requirement Completeness
   - [ ] No [NEEDS CLARIFICATION] markers remain
   - [ ] Requirements are testable and unambiguous
   - [ ] Success criteria are measurable
   - [ ] Success criteria are technology-agnostic
   - [ ] All acceptance scenarios are defined
   - [ ] Edge cases are identified
   - [ ] Scope is clearly bounded
   - [ ] Dependencies and assumptions identified

   ## Feature Readiness
   - [ ] All functional requirements have clear acceptance criteria
   - [ ] User scenarios cover primary flows
   - [ ] Feature meets measurable outcomes defined in Success Criteria
   - [ ] No implementation details leak into specification

   ## Notes
   - Items marked incomplete require spec updates before `/aod.clarify` or `/aod.project-plan`
   ```

b. **Run Validation Check**: Review the spec against each checklist item

c. **Handle Validation Results**:
   - **If all items pass**: Mark checklist complete and proceed
   - **If items fail**: List failing items, update spec, re-validate (max 3 iterations)
   - **If [NEEDS CLARIFICATION] markers remain**: Present up to 3 clarification questions in table format, wait for user response, update spec

d. **Update Checklist** with current pass/fail status

### 3.5 Verify and Report

1. Verify `spec.md` was created at `specs/{NNN}-*/spec.md`
2. If not created: Error and exit

**Guidelines**:
- Focus on **WHAT** users need and **WHY**
- Avoid HOW to implement (no tech stack, APIs, code structure)
- Written for business stakeholders, not developers
- DO NOT create any checklists embedded in the spec
- Make informed guesses using context and industry standards
- Document assumptions in the Assumptions section
- Think like a tester: every requirement should be testable and unambiguous

**NOTE:** The script creates and checks out the new branch and initializes the spec file before writing.

## Step 4: PM Sign-off

Launch **one Task agent** for PM review:

| Agent | subagent_type | Focus | Key Criteria |
|-------|---------------|-------|--------------|
| PM | product-manager | Product alignment | PRD requirements covered, user stories, success criteria, no scope creep |

**Prompt template**:
```
Review spec.md at {spec_path} against PRD at {prd_path}.

Evaluate:
- Alignment with PRD requirements and scope
- Completeness (all PRD requirements addressed)
- User story coverage
- Success criteria clarity

Provide sign-off:
STATUS: [APPROVED | APPROVED_WITH_CONCERNS | CHANGES_REQUESTED | BLOCKED]
NOTES: [Your detailed feedback]
```

**Parse response**: Extract STATUS and NOTES from agent output.

## Step 5: Handle Review Results

**APPROVED/APPROVED_WITH_CONCERNS**: → Proceed to Step 6

**CHANGES_REQUESTED**:
1. Display PM feedback
2. Notify: "Update spec.md and re-run /aod.spec"
3. Still inject frontmatter with CHANGES_REQUESTED status

**BLOCKED**:
1. Display blocker with veto domain (PM=product scope)
2. Use AskUserQuestion with options:
   - **Resolve**: Address issues and re-run /aod.spec
   - **Override**: Provide justification (min 20 chars), mark as BLOCKED_OVERRIDDEN
   - **Abort**: Exit workflow

## Step 6: Inject Frontmatter

Add YAML frontmatter to spec.md (prepend to existing content):

```yaml
---
prd_reference: {prd_path}
triad:
  pm_signoff:
    agent: product-manager
    date: {YYYY-MM-DD}
    status: {pm_status}
    notes: "{pm_notes}"
  architect_signoff: null  # Added by /aod.project-plan
  techlead_signoff: null   # Added by /aod.tasks
---
```

## Step 7: Report Completion

**Re-ground before output**: Re-read the template below exactly. Do not paraphrase or substitute reviewer recommendations for the `Next:` line — it must always be `/aod.plan SPEC: {feature_number} - {feature_name}`.

Display summary:
```
SPECIFICATION CREATION COMPLETE

Feature: {feature_number}
PRD: {prd_path}
Spec: {spec_path}

PM Sign-off: {pm_status}

Next: /aod.plan SPEC: {feature_number} - {feature_name}
```

### Budget Tracking (Non-Fatal)

1. Read calibrated estimate: `PLAN_EST=$(bash -c 'source .aod/scripts/bash/performance-registry.sh 2>/dev/null && aod_registry_get_default per_stage_estimates.plan || echo 5000')`
2. Write post-estimate: `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_exists && aod_state_update_budget "plan" "post" "{PLAN_EST}" || true'`
3. Read summary: `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_exists && aod_state_get_budget_summary || echo "0|0|0|false"'` — returns `estimated_total|usable_budget|threshold_percent|adaptive_mode`
3. Parse the pipe-delimited result. Calculate `utilization = (estimated_total * 100) / usable_budget`.
4. If `estimated_total > 0`, append to the completion output: `(~{utilization}% budget used)`
5. If any step fails, omit the budget line — do not display errors.

## Quality Checklist

- [ ] Branch matches NNN-* pattern
- [ ] PRD exists with approved Triad sign-offs
- [ ] Research phase completed (KB, codebase, architecture, web)
- [ ] research.md created with findings
- [ ] spec.md created with inline generation (informed by research)
- [ ] Spec quality validation passed
- [ ] PM review completed
- [ ] Blockers handled (resolved, overridden, or aborted)
- [ ] Frontmatter injected with PM sign-off
- [ ] Completion summary displayed
