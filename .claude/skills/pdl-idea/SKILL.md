---
name: pdl-idea
description: "Capture a raw feature idea with ICE scoring into the Ideas Backlog. Use this skill when you need to capture ideas, log feature requests, record brainstorm output, or add items to the ideas backlog with ICE prioritization scoring."
---

# PDL Idea Capture Skill

## Purpose

Capture a new feature idea with ICE (Impact, Confidence, Effort) scoring and append it to the Ideas Backlog at `docs/product/_backlog/01_IDEAS.md`.

## Inputs

- **Idea description**: Natural language description of the feature idea (from user arguments)

## Workflow

### Step 1: Auto-Create Backlog Files

Check if `docs/product/_backlog/01_IDEAS.md` exists. If not, create it with the table header:

```markdown
# Ideas Backlog

| ID | Idea | Source | Date | Status | ICE Score |
|----|------|--------|------|--------|-----------|
```

Also check if `docs/product/_backlog/02_USER_STORIES.md` exists. If not, create it with:

```markdown
# Product Backlog - User Stories

| Priority | Story ID | Story | ICE Score | Source | Status |
|----------|----------|-------|-----------|--------|--------|
```

### Step 2: Parse Input

Extract the idea description from user arguments. If no description is provided, ask the user to describe their idea.

### Step 3: Generate IDEA-NNN ID

1. Read `docs/product/_backlog/01_IDEAS.md`
2. Parse the table to find all existing IDEA-NNN identifiers
3. Find the highest NNN value
4. Increment by 1, zero-pad to 3 digits
5. If no existing entries, start at IDEA-001

### Step 4: Capture Source

Use AskUserQuestion to determine the idea source:

```
Question: "Where did this idea come from?"
Options:
  - Brainstorm: "Generated during a brainstorming or planning session"
  - Customer Feedback: "Reported by a customer or based on user research"
  - Team Idea: "Suggested by a team member during development"
  - User Request: "Directly requested by a user or stakeholder"
```

### Step 5: ICE Scoring

Present the ICE scoring quick-assessment table using AskUserQuestion. Ask each dimension separately:

#### Impact — "How much value does this deliver to users?"

```
Options:
  - High (9): "Transformative — significant user value"
  - Medium (6): "Solid improvement — meaningful but incremental"
  - Low (3): "Minor enhancement — small quality-of-life fix"
```

Allow the user to select "Other" to provide a custom numeric value (1-10).

#### Confidence — "How sure are we this will succeed?"

```
Options:
  - High (9): "Proven pattern — strong evidence it will work"
  - Medium (6): "Some unknowns — reasonable confidence with gaps"
  - Low (3): "Speculative — significant uncertainty"
```

Allow the user to select "Other" to provide a custom numeric value (1-10).

#### Effort (Ease of Implementation) — "How easy is this to build?"

```
Options:
  - High (9): "Days of work — straightforward implementation"
  - Medium (6): "Weeks of work — moderate complexity"
  - Low (3): "Months of work — significant engineering effort"
```

Allow the user to select "Other" to provide a custom numeric value (1-10).

### Step 6: Compute ICE Total

```
ICE Total = Impact + Confidence + Effort
Range: 3-30
```

### Step 7: Apply Auto-Defer Gate

Determine the status based on the ICE total:

- **Total < 12**: Set status to **"Deferred"** (auto-deferred — requires PM override via `/pdl.validate` to proceed)
- **Total >= 12**: Set status to **"Scoring"**

### Step 8: Append to Ideas Backlog

Append a new row to the table in `docs/product/_backlog/01_IDEAS.md`:

```
| IDEA-{NNN} | {idea_description} | {source} | {YYYY-MM-DD} | {status} | {total} (I:{impact} C:{confidence} E:{effort}) |
```

Use the Edit tool to append the row after the last existing table row (or after the header separator if the table is empty).

### Step 9: Report Result

Display the result to the user:

```
IDEA CAPTURED

ID: IDEA-{NNN}
Idea: {description}
Source: {source}
Date: {YYYY-MM-DD}

ICE Score: {total} (I:{impact} C:{confidence} E:{effort})
Priority Tier: {tier}
Status: {status}

{If Deferred: "This idea was auto-deferred (score < 12). Use `/pdl.validate IDEA-{NNN}` to request PM override."}
{If Scoring: "Next: Run `/pdl.validate IDEA-{NNN}` to submit for PM review, or continue capturing ideas with `/pdl.idea`."}
```

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
| < 12 | Deferred | Auto-defer; requires PM override via `/pdl.validate` |

### Auto-Defer Gate

Ideas scoring below 12 are automatically deferred. This threshold catches ideas where all three dimensions score poorly (e.g., Low/Low/Low = 9). The PM can override this gate using `/pdl.validate IDEA-NNN`.

## Edge Cases

- **Empty table**: Start ID at IDEA-001
- **No description provided**: Prompt user for idea description before proceeding
- **Custom ICE score outside 1-10**: Clamp to valid range (1 minimum, 10 maximum)
- **Backlog files missing**: Auto-create with headers (Step 1)
- **Duplicate idea text**: Allow it — different ideas may have similar descriptions; the ID is the unique identifier

## Quality Checklist

- [ ] Backlog files auto-created if missing
- [ ] IDEA-NNN ID generated correctly (sequential, zero-padded)
- [ ] Source captured from user selection
- [ ] ICE score computed correctly (additive I+C+E)
- [ ] Auto-defer gate applied (< 12 = Deferred)
- [ ] Row appended to 01_IDEAS.md with all fields
- [ ] Result reported with ICE breakdown and priority tier
