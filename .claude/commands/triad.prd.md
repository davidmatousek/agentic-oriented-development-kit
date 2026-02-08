---
description: Create PRD with Triad governance (PM + Architect + Team-Lead sign-offs) - Streamlined v2
---

## User Input

```text
$ARGUMENTS
```

Consider user input before proceeding (if not empty).

## Overview

Wraps prd-create skill with automatic Triad triple sign-off.

**Flow**: Check vision docs → Validate topic → Classify type → Draft PRD → Reviews → Handle blockers → Inject frontmatter → Update INDEX

## Step 0: Check Product Vision (Optional)

Check if product vision documents exist:
- `docs/product/01_Product_Vision/product-vision.md`

**If vision docs DON'T exist** (first PRD for this project):
1. Use AskUserQuestion:
   - **Quick Vision**: Answer 3 questions to create vision docs (recommended for new projects)
   - **Skip**: Proceed directly to PRD creation (for experienced users)

2. If "Quick Vision" selected, run mini-workshop:

```
🎯 Quick Product Vision (3 questions)

Q1: What problem are you solving and for whom?
(1-2 sentences: the pain point and who experiences it)

Q2: What's your solution in one sentence?
(How your product solves the problem differently)

Q3: What are the 2-3 core features?
(Brief list of key capabilities)
```

3. Generate `docs/product/01_Product_Vision/product-vision.md` with their answers:
   - Mission statement (derived from Q1+Q2)
   - Problem statement (Q1)
   - Solution overview (Q2)
   - Core capabilities table (Q3)

**If vision docs exist**: Skip to Step 1

## Step 1: Validate Topic

1. Parse topic from `$ARGUMENTS` (kebab-case format)
2. If empty: Error "Usage: /triad.prd <topic>" and exit
3. Check `docs/product/02_PRD/` for existing PRD with same topic
4. If exists: Use AskUserQuestion with options: View existing, Create with suffix (v2), Abort

## Step 2: Classify PRD Type

Use AskUserQuestion to determine workflow type:

| Type | Examples | Workflow |
|------|----------|----------|
| Infrastructure | deployment, database, migration, CI/CD | Sequential (Architect baseline → PM draft → Team-Lead → Architect final) |
| Feature | UI, API, dashboard, user-facing | Parallel (PM draft → Architect + Team-Lead reviews in parallel) |

## Step 3: Draft PRD

**Infrastructure workflow**:
1. Launch architect agent for baseline technical assessment
2. Invoke prd-create skill with architect baseline context
3. Launch team-lead agent for timeline/feasibility review
4. Launch architect agent for final technical review

**Feature workflow**:
1. Invoke prd-create skill directly
2. Launch **two Task agents in parallel** (single message, two Task tool calls):

| Agent | subagent_type | Focus | Key Criteria |
|-------|---------------|-------|--------------|
| Architect | architect | Technical | Feasibility, architecture, scalability, security |
| Team-Lead | team-lead | Timeline | Realism, resources, dependencies, complexity |

**Prompt template for each**:
```
Review PRD draft for {FOCUS AREA}.

PRD Topic: {topic}
Draft Content: {prd_draft_content}

Provide sign-off:
STATUS: [APPROVED | APPROVED_WITH_CONCERNS | CHANGES_REQUESTED | BLOCKED]
NOTES: [Your detailed feedback]
```

## Step 4: Handle Review Results

**All APPROVED/APPROVED_WITH_CONCERNS**: → Proceed to Step 5

**Any CHANGES_REQUESTED**:
1. Display feedback from reviewers who requested changes
2. Use product-manager agent to update PRD addressing the feedback
3. Re-run reviews only for reviewers who requested changes
4. Loop until all approved or user aborts (max 5 iterations)

**Any BLOCKED**:
1. Display blocker with veto domain (Architect=technical, Team-Lead=timeline)
2. Use AskUserQuestion with options:
   - **Resolve**: Address issues and re-submit to blocked reviewer
   - **Override**: Provide justification (min 20 chars), mark as BLOCKED_OVERRIDDEN
   - **Abort**: Cancel PRD creation

## Step 5: Assign PRD Number

1. Scan `docs/product/02_PRD/` for `NNN-*.md` files
2. Extract max NNN, assign next_number = max + 1 (or 1 if empty)
3. Format: `{NNN}-{topic}-{YYYY-MM-DD}.md`

## Step 6: Write PRD with Frontmatter

1. Build YAML frontmatter with triad sign-offs:

```yaml
---
prd:
  number: {prd_number}
  topic: {topic}
  created: {YYYY-MM-DD}
  status: {Approved|In Review|Blocked|Draft}
  type: {infrastructure|feature}
triad:
  pm_signoff: {agent: product-manager, date: ..., status: ..., notes: ...}
  architect_signoff: {agent: architect, date: ..., status: ..., notes: ...}
  techlead_signoff: {agent: team-lead, date: ..., status: ..., notes: ...}
source:           # Optional — populated when PRD originates from PDL
  idea_id: null   # IDEA-NNN reference (from PDL backlog)
  story_id: null  # US-NNN reference (from PDL backlog)
---
```

2. Write to `docs/product/02_PRD/{filename}`

## Step 6b: Update PDL Backlog Status (if applicable)

After the PRD is written, if the frontmatter contains a non-null `source.story_id`:

1. Read `docs/product/_backlog/02_USER_STORIES.md`
2. Find the row matching the `source.story_id` (e.g., `US-001`)
3. Update the Status column from "Ready for PRD" to "In PRD"
4. If the story ID is not found in `02_USER_STORIES.md` (e.g., file was manually edited or story ID is incorrect), skip gracefully with a warning: `"Warning: {story_id} not found in 02_USER_STORIES.md — status not updated"`
5. If `02_USER_STORIES.md` does not exist, skip silently (PDL is optional)

## Step 7: Update INDEX.md

1. Read `docs/product/02_PRD/INDEX.md`
2. Add new row to Active PRDs table with status symbols: ✓=APPROVED, ⚠=CONCERNS, 🔄=CHANGES, ⛔=BLOCKED, ⚠⚡=OVERRIDDEN
3. Update "Last Updated" date
4. Write updated INDEX.md

## Step 8: Report Completion

Display summary:
```
✅ PRD CREATION COMPLETE

PRD: {prd_number} - {topic}
Type: {workflow_type}
Status: {overall_status}
File: docs/product/02_PRD/{filename}

Triple Sign-offs:
- PM: {pm_status}
- Architect: {architect_status}
- Team-Lead: {techlead_status}

Next: /triad.specify
```

## Quality Checklist

- [ ] Topic validated (no duplicates or user-approved suffix)
- [ ] Workflow type classified (infrastructure or feature)
- [ ] PRD drafted via prd-create skill
- [ ] Reviews executed (sequential for infra, parallel for feature)
- [ ] Blockers handled (resolved, overridden, or aborted)
- [ ] PRD number assigned sequentially
- [ ] Frontmatter injected with all three sign-offs
- [ ] INDEX.md updated with new row
- [ ] Completion summary displayed
