---
name: aod-discover
description: "Unified discovery skill with 3 entry points: /aod.discover (full flow: capture + score + validate), /aod.idea (capture + score only), /aod.validate (PM validation for existing idea). Use this skill when you need to capture ideas, run discovery, validate ideas with PM, generate user stories, log feature requests, or add items to the ideas backlog."
---

# AOD Discover Skill

## Purpose

Unified discovery skill for the AOD Lifecycle's **Discover** stage. Handles idea capture, ICE scoring, evidence gathering, and PM validation with 3 entry points:

- **`/aod.discover`** — Full flow: capture idea + ICE score + evidence + PM validation + user story
- **`/aod.idea`** — Capture only: capture idea + ICE score + evidence (no PM validation)
- **`/aod.validate`** — Validate only: submit existing idea for PM review + user story generation

## Entry Point Detection

Determine the entry point from the invoking command:
- If invoked via `/aod.discover` → run **Full Flow** (Steps 1-8)
- If invoked via `/aod.idea` → run **Capture Only** (Steps 1-5)
- If invoked via `/aod.validate` → run **Validate Only** (Steps 6-8)

---

## Shared: Backlog Initialization

**Run at the start of every entry point.**

Check if `docs/product/_backlog/01_IDEAS.md` exists. If not, create it:

```markdown
# Ideas Backlog

| ID | Idea | Source | Date | Status | ICE Score |
|----|------|--------|------|--------|-----------|
```

Check if `docs/product/_backlog/02_USER_STORIES.md` exists. If not, create it:

```markdown
# Product Backlog - User Stories

| Priority | Story ID | Story | ICE Score | Source | Status |
|----------|----------|-------|-----------|--------|--------|
```

---

## Step 1: Parse Input (Capture + Full Flow)

Extract the idea description from user arguments. If no description is provided, ask the user to describe their idea.

## Step 2: Generate IDEA-NNN ID

1. Read `docs/product/_backlog/01_IDEAS.md`
2. Parse the table to find all existing IDEA-NNN identifiers
3. Find the highest NNN value
4. Increment by 1, zero-pad to 3 digits
5. If no existing entries, start at IDEA-001

## Step 3: Capture Source and ICE Score

### Source

Use AskUserQuestion to determine the idea source:

```
Question: "Where did this idea come from?"
Options:
  - Brainstorm: "Generated during a brainstorming or planning session"
  - Customer Feedback: "Reported by a customer or based on user research"
  - Team Idea: "Suggested by a team member during development"
  - User Request: "Directly requested by a user or stakeholder"
```

### ICE Scoring

Present each ICE dimension using AskUserQuestion:

#### Impact — "How much value does this deliver to users?"

```
Options:
  - High (9): "Transformative — significant user value"
  - Medium (6): "Solid improvement — meaningful but incremental"
  - Low (3): "Minor enhancement — small quality-of-life fix"
```

Allow "Other" for custom numeric values (1-10).

#### Confidence — "How sure are we this will succeed?"

```
Options:
  - High (9): "Proven pattern — strong evidence it will work"
  - Medium (6): "Some unknowns — reasonable confidence with gaps"
  - Low (3): "Speculative — significant uncertainty"
```

Allow "Other" for custom numeric values (1-10).

#### Effort (Ease of Implementation) — "How easy is this to build?"

```
Options:
  - High (9): "Days of work — straightforward implementation"
  - Medium (6): "Weeks of work — moderate complexity"
  - Low (3): "Months of work — significant engineering effort"
```

Allow "Other" for custom numeric values (1-10).

**Compute**: ICE Total = Impact + Confidence + Effort (range 3-30)

## Step 4: Evidence Prompt (Capture + Full Flow)

After ICE scoring, prompt the user for evidence supporting this idea.

Use AskUserQuestion:

```
Question: "Who has this problem, and how do you know?"
Header: "Evidence"
Options:
  - Customer Feedback: "Based on direct customer reports, support tickets, or user research"
  - Team Observation: "Noticed by the team during development, testing, or internal usage"
  - Analytics Data: "Supported by usage metrics, error rates, or behavioral analytics"
  - User Request: "Explicitly requested by a user, stakeholder, or partner"
```

Allow "Other" for free-text evidence statements.

**Store the response** as the `evidence` field. This value is used in:
- Step 5b: GitHub Issue body (`## Evidence` section)
- Step 6: PM validation (evidence quality evaluation)
- BACKLOG.md Discover section (Evidence column)

**If the user selects a predefined category**: Store as `"{Category}: {any additional detail}"` if they provide detail, or just `"{Category}"` if not.

**If the user provides free text via "Other"**: Store the full text as-is.

## Step 5: Apply Auto-Defer Gate

Determine status based on ICE total:

- **Total < 12**: Set status to **"Deferred"** (auto-deferred)
- **Total >= 12**: Set status to **"Scoring"**

Append a new row to `docs/product/_backlog/01_IDEAS.md`:

```
| IDEA-{NNN} | {idea_description} | {source} | {YYYY-MM-DD} | {status} | {total} (I:{impact} C:{confidence} E:{effort}) |
```

**If auto-deferred AND entry point is Full Flow (`/aod.discover`)**:
- Flow **STOPS** here. Do not proceed to PM validation.
- Display result with guidance:

```
IDEA CAPTURED — AUTO-DEFERRED

ID: IDEA-{NNN}
Idea: {description}
Source: {source}
Evidence: {evidence}
ICE Score: {total} (I:{impact} C:{confidence} E:{effort})
Priority Tier: Deferred
Status: Deferred

This idea was auto-deferred (score < 12).
To request PM override: `/aod.validate IDEA-{NNN}`
To re-score with new information: `/aod.score IDEA-{NNN}`
```

**If auto-deferred AND entry point is Capture Only (`/aod.idea`)**: Display same result, exit.

**If NOT auto-deferred AND entry point is Capture Only (`/aod.idea`)**: Display result and exit:

```
IDEA CAPTURED

ID: IDEA-{NNN}
Idea: {description}
Source: {source}
Evidence: {evidence}
Date: {YYYY-MM-DD}
ICE Score: {total} (I:{impact} C:{confidence} E:{effort})
Priority Tier: {tier}
Status: Scoring

Next: Run `/aod.validate IDEA-{NNN}` to submit for PM review, or continue capturing ideas with `/aod.idea`.
```

**If NOT auto-deferred AND entry point is Full Flow (`/aod.discover`)**: Continue to Step 5a.

## Step 5a: GitHub Issue Creation (All Entry Points)

After capturing the idea to `01_IDEAS.md`, create a GitHub Issue for lifecycle tracking:

1. Build the issue body using the structured format from `github-lifecycle.sh`:
   ```markdown
   # [IDEA-{NNN}] {idea_description}

   ## ICE Score
   Impact: {impact}, Confidence: {confidence}, Effort: {effort} = **{total}**

   ## Evidence
   {evidence}

   ## Metadata
   - Source: {source}
   - Priority: {priority_tier}
   - Date: {YYYY-MM-DD}
   - Status: {status}
   ```

2. Call `aod_gh_create_issue` (from `.aod/scripts/bash/github-lifecycle.sh`):
   - Title: `[IDEA-{NNN}] {idea_description}`
   - Body: structured markdown above
   - Stage: `discover`
   - Idea ID: `IDEA-{NNN}` (for duplicate detection)

3. If `gh` is unavailable, skip silently (graceful degradation).

## Step 5b: Regenerate BACKLOG.md

After GitHub Issue creation, run `.aod/scripts/bash/backlog-regenerate.sh` to update the backlog snapshot. If `gh` is unavailable, skip silently.

## Step 5c: Check Governance Tier (Full Flow only)

Before proceeding to PM validation in the Full Flow (`/aod.discover`), check the governance tier:

1. Read `.aod/memory/constitution.md`
2. Find the governance tier configuration (`governance:` → `tier:` value)
3. Valid values: `light`, `standard`, `full`. Default: `standard`

**If tier is `light`**:
- PM validation is **optional** — skip Steps 6-7 in the Full Flow
- Display note: "Note: Light governance tier — PM validation skipped. Run `/aod.validate IDEA-{NNN}` to manually request PM review."
- Proceed directly to Step 8 (Write entries) with status remaining "Scoring" (not "Validated")
- The user can still manually invoke `/aod.validate IDEA-{NNN}` at any time

**If tier is `standard` or `full`**: Continue to Step 6 as normal.

**Note**: The `/aod.validate` entry point always runs PM validation regardless of tier — it is an explicit user request for PM review.

## Step 6: PM Validation (Validate + Full Flow)

### For `/aod.validate` entry point: Parse and find idea

Extract the IDEA-NNN identifier from user arguments. Validate format matches `IDEA-` followed by a 3-digit number. If invalid or missing, display: `Usage: /aod.validate IDEA-NNN`

Read `docs/product/_backlog/01_IDEAS.md` and find the matching row.

**Error conditions**:
- Idea not found: `"Error: IDEA-{NNN} not found in 01_IDEAS.md"`
- Status is "Rejected": `"Error: IDEA-{NNN} has already been rejected by PM. Re-score with /aod.score first."`
- Status is "Validated": `"Error: IDEA-{NNN} has already been validated — see 02_USER_STORIES.md"`

Display idea for review:

```
IDEA FOR PM VALIDATION

ID: IDEA-{NNN}
Idea: {description}
Source: {source}
Evidence: {evidence}
Date: {date}
Status: {status}
ICE Score: {total} (I:{impact} C:{confidence} E:{effort})
Priority Tier: {tier}
Auto-Deferred: {Yes if status is Deferred, otherwise No}
```

### Launch PM Review

Use the Task tool with `product-manager` subagent_type:

```
Review this idea for product backlog inclusion:

Idea: {idea_description}
ICE Score: {total} (I:{impact} C:{confidence} E:{effort})
Priority Tier: {tier}
Current Status: {status}
Auto-Deferred: {yes/no}
Evidence: {evidence}

Evaluate:
1. Does this idea align with the product vision and roadmap?
2. Is the ICE scoring reasonable given the idea description?
3. Does this idea deliver meaningful user value?
4. Should this idea enter the product backlog as a user story?
5. Is the evidence sufficient to justify pursuing this idea? Evaluate the quality and
   specificity of the evidence provided.

If evidence is empty or "No evidence provided", flag this:
"No evidence provided — recommend gathering evidence before proceeding."
You may still approve if the idea has strong merit despite missing evidence, but note
the evidence gap in your rationale.

If auto-deferred (score < 12), provide additional justification for why this idea
should or should not override the auto-defer gate.

Respond with:
STATUS: [APPROVED | REJECTED]
EVIDENCE_QUALITY: [Strong | Adequate | Weak | Missing]
RATIONALE: [Your detailed reasoning — 2-4 sentences]
```

### Handle Rejection

If PM returns **REJECTED**:
1. Update idea status to **"Rejected"** in `01_IDEAS.md` using Edit tool
2. Display rejection and exit:

```
PM VALIDATION: REJECTED

ID: IDEA-{NNN}
Idea: {description}
PM Rationale: {rationale}

The idea has been marked as Rejected in 01_IDEAS.md.
To re-submit: re-score with `/aod.score IDEA-{NNN}`, then run `/aod.validate IDEA-{NNN}` again.
```

### Handle Approval

If PM returns **APPROVED**: Continue to Step 7.

## Step 7: User Story Generation

1. **Generate user story**: Transform idea into "As a [persona], I want [action], so that [benefit]" format.
   - Default persona: "Template Adopter" if not evident from idea.
2. **Present for confirmation**: Use AskUserQuestion:
   ```
   Options:
     - Accept: "Save this user story as-is"
     - Edit: "Let me modify the user story text"
   ```
3. **Generate US-NNN ID**: Read `02_USER_STORIES.md`, find highest US-NNN, increment by 1 (pad to 3 digits). Start at US-001 if empty.
4. **Determine priority**: Map ICE score to priority rank:
   - P0 (25-30): Priority = 1
   - P1 (18-24): Priority = 2
   - P2 (12-17): Priority = 3
   - Deferred (<12, PM override): Priority = 4

## Step 8: Write Backlog Entries and Report

### Write entries

1. Append row to `docs/product/_backlog/02_USER_STORIES.md`:
   ```
   | {priority} | US-{NNN} | {user_story_text} | {ice_total} | IDEA-{NNN} | Ready for PRD |
   ```
2. Update idea status to **"Validated"** in `01_IDEAS.md`.
3. If idea was auto-deferred (status was "Deferred") and PM approved, append PM override note after the user stories table:
   ```markdown

   > **PM Override — US-{NNN}**: IDEA-{NNN} was auto-deferred (ICE score {total} < 12) but approved by PM. Rationale: {pm_rationale}
   ```

### Report result

**For `/aod.validate` entry point**:
```
PM VALIDATION: APPROVED

ID: IDEA-{NNN}
Idea: {description}
Evidence Quality: {evidence_quality}
PM Rationale: {rationale}

User Story Created:
  ID: US-{NNN}
  Story: "{user_story_text}"
  Priority: {priority}
  Status: Ready for PRD

Idea status updated to "Validated" in 01_IDEAS.md.
User story added to 02_USER_STORIES.md.

Next: Run `/aod.define {topic}` to create a PRD from this user story.
```

**For `/aod.discover` entry point (full flow)**:
```
AOD DISCOVERY COMPLETE

Idea Captured:
  ID: IDEA-{NNN}
  Description: {description}
  Source: {source}
  Evidence: {evidence}

ICE Scoring:
  Score: {total} (I:{impact} C:{confidence} E:{effort})
  Priority Tier: {tier}

PM Validation: APPROVED
  Evidence Quality: {evidence_quality}
  Rationale: {rationale}

User Story Created:
  ID: US-{NNN}
  Story: "{user_story_text}"
  Priority: {priority}
  Status: Ready for PRD

Next: Run `/aod.define {topic}` to create a PRD from this user story.
```

---

## ICE Scoring Reference

### Quick-Assessment Anchors

| Dimension | High (9) | Medium (6) | Low (3) |
|-----------|----------|------------|---------|
| **Impact** | Transformative | Solid improvement | Minor enhancement |
| **Confidence** | Proven pattern | Some unknowns | Speculative |
| **Effort (Ease)** | Days of work | Weeks of work | Months of work |

### Priority Tiers

| Score Range | Priority | Action |
|-------------|----------|--------|
| 25-30 | P0 (Critical) | Fast-track to development |
| 18-24 | P1 (High) | Queue for next sprint |
| 12-17 | P2 (Medium) | Consider when capacity allows |
| < 12 | Deferred | Auto-defer; requires PM override via `/aod.validate` |

### Auto-Defer Gate

Ideas scoring below 12 are automatically deferred. In the full flow (`/aod.discover`), the flow stops and no PM validation occurs. Use `/aod.validate IDEA-NNN` to request PM override for deferred ideas.

---

## Edge Cases

- **Empty table**: Start ID at IDEA-001
- **No description provided**: Prompt user for idea description
- **Custom ICE score outside 1-10**: Clamp to valid range (1 minimum, 10 maximum)
- **Backlog files missing**: Auto-create with headers (Backlog Initialization)
- **Duplicate idea text**: Allow it — the IDEA-NNN ID is the unique identifier
- **IDEA-NNN not found** (validate): Display error with the ID that was searched for
- **Already Rejected** (validate): Cannot re-validate directly — user must re-score first with `/aod.score`
- **Already Validated** (validate): Cannot re-validate — user story already exists
- **PM timeout or error**: Report the error and suggest retrying
- **User edits story to empty string**: Re-prompt for user story text
- **PM approves auto-deferred idea**: Document override rationale in backlog
- **Auto-deferred in full flow**: Flow stops — no PM validation, no user story

## Quality Checklist

- [ ] Backlog files auto-created if missing
- [ ] Entry point correctly detected (discover/idea/validate)
- [ ] IDEA-NNN ID generated correctly (sequential, zero-padded)
- [ ] Source captured from user selection
- [ ] Evidence prompted after ICE scoring (predefined categories + free text)
- [ ] Evidence included in GitHub Issue body and display outputs
- [ ] ICE score computed correctly (additive I+C+E)
- [ ] Auto-defer gate applied (< 12 = Deferred, flow stops in full flow)
- [ ] Governance tier read from constitution (light/standard/full, default: standard)
- [ ] Light tier: PM validation skipped in full flow, with note to user
- [ ] PM validation includes evidence quality evaluation (Strong/Adequate/Weak/Missing)
- [ ] PM validation invoked via Task tool (product-manager subagent)
- [ ] Rejection: Status updated, flow exits
- [ ] Approval: User story generated in proper format
- [ ] User story presented for confirmation
- [ ] US-NNN ID generated and row appended to 02_USER_STORIES.md
- [ ] Idea status updated to Validated on approval
- [ ] PM override documented if idea was auto-deferred
- [ ] Result reported with next step guidance
