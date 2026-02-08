---
name: pdl-validate
description: "PM validation gate for ideas — approves or rejects ideas for the product backlog with user story generation. Use this skill when you need to validate ideas, promote to backlog, run PM review on ideas, generate user stories, or override auto-deferred ideas."
---

# PDL Validate Skill

## Purpose

Submit an idea from `docs/product/_backlog/01_IDEAS.md` to a Product Manager agent for validation. On approval, generate a user story and add it to `docs/product/_backlog/02_USER_STORIES.md`. On rejection, update the idea status accordingly.

## Inputs

- **IDEA-NNN**: The identifier of the idea to validate (from user arguments)

## Workflow

### Step 1: Auto-Create Backlog Files

Check if `docs/product/_backlog/01_IDEAS.md` exists. If not, create it with the table header:

```markdown
# Ideas Backlog

| ID | Idea | Source | Date | Status | ICE Score |
|----|------|--------|------|--------|-----------|
```

Check if `docs/product/_backlog/02_USER_STORIES.md` exists. If not, create it with:

```markdown
# Product Backlog - User Stories

| Priority | Story ID | Story | ICE Score | Source | Status |
|----------|----------|-------|-----------|--------|--------|
```

### Step 2: Parse Input

Extract the IDEA-NNN identifier from user arguments. Validate the format matches `IDEA-` followed by a 3-digit number. If invalid or missing, display usage: `Usage: /pdl.validate IDEA-NNN`

### Step 3: Read and Find Idea

Read `docs/product/_backlog/01_IDEAS.md` and find the row matching the given IDEA-NNN.

**Error conditions** — display error and exit:
- Idea not found: `"Error: IDEA-{NNN} not found in 01_IDEAS.md"`
- Status is "Rejected": `"Error: IDEA-{NNN} has already been rejected by PM"`
- Status is "Validated": `"Error: IDEA-{NNN} has already been validated — see 02_USER_STORIES.md"`

### Step 4: Display Idea for Review

Show the idea details before launching PM review:

```
IDEA FOR PM VALIDATION

ID: IDEA-{NNN}
Idea: {description}
Source: {source}
Date: {date}
Status: {status}
ICE Score: {total} (I:{impact} C:{confidence} E:{effort})
Priority Tier: {tier}
Auto-Deferred: {Yes if status is Deferred, otherwise No}
```

### Step 5: Launch PM Validation

Use the Task tool with `product-manager` subagent_type to perform the PM review:

```
Review this idea for product backlog inclusion:

Idea: {idea_description}
ICE Score: {total} (I:{impact} C:{confidence} E:{effort})
Priority Tier: {tier}
Current Status: {status}
Auto-Deferred: {yes/no}

Evaluate:
1. Does this idea align with the product vision and roadmap?
2. Is the ICE scoring reasonable given the idea description?
3. Does this idea deliver meaningful user value?
4. Should this idea enter the product backlog as a user story?

If auto-deferred (score < 12), provide additional justification for why this idea
should or should not override the auto-defer gate.

Respond with:
STATUS: [APPROVED | REJECTED]
RATIONALE: [Your detailed reasoning — 2-4 sentences]
```

### Step 6: Handle Rejection

If PM returns **REJECTED**:

1. Update idea status to **"Rejected"** in `01_IDEAS.md` using Edit tool
2. Display the rejection:

```
PM VALIDATION: REJECTED

ID: IDEA-{NNN}
Idea: {description}
PM Rationale: {rationale}

The idea has been marked as Rejected in 01_IDEAS.md.
To re-submit: re-score with `/pdl.score IDEA-{NNN}` (this re-opens the idea), then run `/pdl.validate IDEA-{NNN}` again.
```

3. Exit the workflow.

### Step 7: Handle Approval — Generate User Story

If PM returns **APPROVED**:

#### 7a. Generate User Story

Transform the idea description into user story format:

```
"As a [persona], I want [action], so that [benefit]"
```

**Transformation rules**:
- **Persona**: Extract from the idea description if evident. Default to "Template Adopter" if no persona is specified or inferrable.
- **Action**: Extract the core action or capability from the idea description.
- **Benefit**: Infer the user benefit from the context and idea description.

#### 7b. Present for User Confirmation

Display the generated user story to the user and ask for confirmation:

```
GENERATED USER STORY

"As a {persona}, I want {action}, so that {benefit}."

Is this user story accurate? You can edit it before saving.
```

Use AskUserQuestion:
```
Options:
  - Accept: "Save this user story as-is"
  - Edit: "Let me modify the user story text"
```

If the user selects "Edit", accept their modified version. If they provide it via "Other", use their text.

#### 7c. Generate US-NNN ID

1. Read `docs/product/_backlog/02_USER_STORIES.md`
2. Parse the table to find all existing US-NNN identifiers
3. Find the highest NNN value
4. Increment by 1, zero-pad to 3 digits
5. If no existing entries, start at US-001

#### 7d. Determine Priority

Map ICE score to priority rank:
- P0 (25-30): Priority = 1
- P1 (18-24): Priority = 2
- P2 (12-17): Priority = 3
- Deferred (<12, PM override): Priority = 4

If other entries exist, assign the next available rank at the appropriate tier level.

### Step 8: Write Backlog Entries

#### 8a. Append to User Stories

Append a new row to `docs/product/_backlog/02_USER_STORIES.md`:

```
| {priority} | US-{NNN} | {user_story_text} | {ice_total} | IDEA-{NNN} | Ready for PRD |
```

#### 8b. Update Idea Status

Update the idea status in `01_IDEAS.md` from current status to **"Validated"** using Edit tool.

#### 8c. Document PM Override (if applicable)

If the idea was previously "Deferred" (auto-deferred with score < 12) and PM approved it:

After the user stories table in `02_USER_STORIES.md`, append a note:

```markdown

> **PM Override — US-{NNN}**: IDEA-{NNN} was auto-deferred (ICE score {total} < 12) but approved by PM. Rationale: {pm_rationale}
```

### Step 9: Report Result

```
PM VALIDATION: APPROVED

ID: IDEA-{NNN}
Idea: {description}
PM Rationale: {rationale}

User Story Created:
  ID: US-{NNN}
  Story: "{user_story_text}"
  Priority: {priority}
  Status: Ready for PRD

Idea status updated to "Validated" in 01_IDEAS.md.
User story added to 02_USER_STORIES.md.

Next: Run `/triad.prd {topic}` to create a PRD from this user story.
```

## ICE Scoring Reference

### Priority Tiers

| Score Range | Priority | Action |
|-------------|----------|--------|
| 25-30 | P0 (Critical) | Fast-track to development |
| 18-24 | P1 (High) | Queue for next sprint |
| 12-17 | P2 (Medium) | Consider when capacity allows |
| < 12 | Deferred | Auto-defer; requires PM override via `/pdl.validate` |

### Auto-Defer Gate

Ideas scoring below 12 are automatically deferred. This skill allows PM to override the auto-defer gate. When an override occurs, the PM rationale is documented alongside the user story.

## Edge Cases

- **IDEA-NNN not found**: Display error with the ID that was searched for
- **Already Rejected**: Cannot re-validate directly — user must re-score first with `/pdl.score` (which re-opens it), then run `/pdl.validate` again
- **Already Validated**: Cannot re-validate — user story already exists
- **PM timeout or error**: Report the error and suggest retrying
- **User edits story to empty string**: Re-prompt for user story text
- **Backlog files missing**: Auto-create with headers (Step 1)
- **PM approves auto-deferred idea**: Document override rationale in backlog

## Quality Checklist

- [ ] Backlog files auto-created if missing
- [ ] IDEA-NNN parsed, found, and eligible for validation
- [ ] PM agent invoked with idea details via Task tool
- [ ] Rejection: Status updated to Rejected in 01_IDEAS.md
- [ ] Approval: User story generated in proper format
- [ ] Approval: User story presented for user confirmation
- [ ] Approval: US-NNN ID generated correctly
- [ ] Approval: Row appended to 02_USER_STORIES.md
- [ ] Approval: Idea status updated to Validated in 01_IDEAS.md
- [ ] PM override documented if idea was auto-deferred
- [ ] Result reported with next step guidance
