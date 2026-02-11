---
description: Create PRD with Triad governance (PM + Architect + Team-Lead sign-offs) - Streamlined v2
---

## User Input

```text
$ARGUMENTS
```

Consider user input before proceeding (if not empty).

## Overview

Wraps ~aod-define skill with automatic Triad triple sign-off.

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
2. If empty: Error "Usage: /aod.define <topic>" and exit
3. Check `docs/product/02_PRD/` for existing PRD with same topic
4. If exists: Use AskUserQuestion with options: View existing, Create with suffix (v2), Abort
5. **GitHub Lifecycle Update (early)**: Move the feature's GitHub Issue to `stage:define` at the *start* of PRD creation. Detection order (use first match):
   1. If `$ARGUMENTS` contains a numeric value (`#NNN` or bare `NNN`), look up the GitHub Issue directly: `source .aod/scripts/bash/github-lifecycle.sh && aod_gh_find_issue NNN`
   2. Search GitHub Issues by topic title: `source .aod/scripts/bash/github-lifecycle.sh && aod_gh_find_issue "TOPIC_TITLE"`
   3. Legacy fallback: Extract `[IDEA-NNN]` or `[RETRO-NNN]` tag from `$ARGUMENTS` and search: `source .aod/scripts/bash/github-lifecycle.sh && aod_gh_find_issue "[TAG]"`
   Once the issue number is found, run: `source .aod/scripts/bash/github-lifecycle.sh && aod_gh_update_stage ISSUE_NUMBER define`
   Then regenerate BACKLOG.md: `.aod/scripts/bash/backlog-regenerate.sh`
   **Issue-Required Gate**: If no issue is found after all detection methods:
   1. Use `AskUserQuestion` with three options:
      - **Auto-create Issue** (Recommended): Run `gh issue create --title "TOPIC" --label "stage:define"` to create a new Issue automatically. Use the returned Issue number as the PRD number.
      - **Provide Issue number**: User enters an existing GitHub Issue number manually. Validate it exists via `gh issue view NNN` before proceeding.
      - **Abort**: Cancel PRD creation cleanly with message "PRD creation requires a backing GitHub Issue. Create one at your repo's Issues page and re-run /aod.define."
   2. If `gh` CLI is unavailable and user cannot provide a number, abort with guidance: "The `gh` CLI is not available. Please create a GitHub Issue manually and re-run `/aod.define <topic> #NNN`."
   3. Store the resolved Issue number for use in Steps 5 and 6.

## Step 2: Classify PRD Type

Use AskUserQuestion to determine workflow type:

| Type | Examples | Workflow |
|------|----------|----------|
| Infrastructure | deployment, database, migration, CI/CD | Sequential (Architect baseline → PM draft → Team-Lead → Architect final) |
| Feature | UI, API, dashboard, user-facing | Parallel (PM draft → Architect + Team-Lead reviews in parallel) |

## Step 3: Draft PRD

**Infrastructure workflow**:
1. Launch architect agent for baseline technical assessment
2. Invoke ~aod-define skill with architect baseline context
3. Launch team-lead agent for timeline/feasibility review
4. Launch architect agent for final technical review

**Feature workflow**:
1. Invoke ~aod-define skill directly
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

1. Use the GitHub Issue number (resolved in Step 1) as the PRD number
2. Zero-pad to 3 digits (e.g., Issue #25 → 025)
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
source:           # Automatically populated from GitHub Issue
  idea_id: null   # Always equals prd.number (GitHub Issue number)
  story_id: null  # Deprecated — user stories now stored in GitHub Issue body
---
```

2. Write to `docs/product/02_PRD/{filename}`

## Step 6b: Regenerate BACKLOG.md

After the PRD is written, regenerate BACKLOG.md to reflect the stage transition:
Run `.aod/scripts/bash/backlog-regenerate.sh`. If `gh` is unavailable, skip silently.

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

Next: /aod.plan PRD: {prd_number} - {topic}
```

## Step 10: Quality Checklist

- [ ] Topic validated (no duplicates or user-approved suffix)
- [ ] Workflow type classified (infrastructure or feature)
- [ ] PRD drafted via ~aod-define skill
- [ ] Reviews executed (sequential for infra, parallel for feature)
- [ ] Blockers handled (resolved, overridden, or aborted)
- [ ] PRD number matches GitHub Issue number
- [ ] Frontmatter injected with all three sign-offs
- [ ] INDEX.md updated with new row
- [ ] Completion summary displayed
