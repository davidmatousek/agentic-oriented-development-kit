---
name: pdl-score
description: "Re-score an existing idea's ICE rating when circumstances change. Use this skill when you need to re-evaluate ideas, update ICE scores, change idea priority, or re-assess deferred ideas."
---

# PDL Re-Score Skill

## Purpose

Update an existing idea's ICE (Impact, Confidence, Effort) score in `docs/product/_backlog/01_IDEAS.md` when circumstances change, new information emerges, or priorities shift.

## Inputs

- **IDEA-NNN**: The identifier of the idea to re-score (from user arguments)

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

Extract the IDEA-NNN identifier from user arguments. Validate the format matches `IDEA-` followed by a 3-digit number. If invalid or missing, display usage: `Usage: /pdl.score IDEA-NNN`

### Step 3: Read Ideas Backlog

Read `docs/product/_backlog/01_IDEAS.md` and parse the table to find the row matching the given IDEA-NNN identifier.

If the idea is not found, display an error and exit:
```
Error: IDEA-{NNN} not found in 01_IDEAS.md
```

### Step 4: Display Current Scores

Show the existing idea details:

```
CURRENT SCORES — IDEA-{NNN}

Idea: {description}
Source: {source}
Date: {date}
Status: {status}

ICE Score: {total} (I:{impact} C:{confidence} E:{effort})
Priority Tier: {tier}
```

### Step 5: New ICE Scoring

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

### Step 6: Compute New ICE Total

```
New ICE Total = Impact + Confidence + Effort
Range: 3-30
```

### Step 7: Update Status

Apply status transitions based on threshold crossings:

- If current status is **"Deferred"** and new score >= 12: Set status to **"Scoring"**
- If current status is **"Scoring"** and new score < 12: Set status to **"Deferred"**
- If current status is **"Validated"**: **Preserve** status (already PM-approved, do not downgrade)
- If current status is **"Rejected"** and new score >= 12: Set status to **"Scoring"** (re-opens for re-validation via `/pdl.validate`)
- If current status is **"Rejected"** and new score < 12: Set status to **"Deferred"**

**Note**: Re-scoring a Rejected idea resets it for a fresh PM review. The PM previously rejected the idea, but re-scoring indicates changed circumstances that warrant re-evaluation. The user must still run `/pdl.validate` to get PM approval.

### Step 8: Update Row In Place

Use the Edit tool to replace the existing table row in `01_IDEAS.md` with updated values:
- New ICE score
- New status (if changed per Step 7)
- Current date (YYYY-MM-DD)
- All other fields remain unchanged

**Important**: Replace the existing row — do not append a new row.

### Step 9: Report Result

Display the comparison:

```
IDEA RE-SCORED

ID: IDEA-{NNN}
Idea: {description}

Previous: {old_total} (I:{old_i} C:{old_c} E:{old_e}) — {old_tier}
Updated:  {new_total} (I:{new_i} C:{new_c} E:{new_e}) — {new_tier}

{If tier changed: "Priority tier changed: {old_tier} → {new_tier}"}
{If status changed: "Status changed: {old_status} → {new_status}"}
{If status preserved: "Status preserved: {status}"}

Date updated: {YYYY-MM-DD}
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

Ideas scoring below 12 are automatically deferred. The PM can override this gate using `/pdl.validate IDEA-NNN`.

## Edge Cases

- **IDEA-NNN not found**: Display error with the ID that was searched for
- **Invalid ID format**: Display usage guidance
- **Validated status**: Preserve — PM has already approved, re-scoring only updates the numeric score
- **Rejected status**: Re-opens to Scoring (>= 12) or Deferred (< 12) — allows re-submission to PM via `/pdl.validate`
- **Custom ICE score outside 1-10**: Clamp to valid range (1 minimum, 10 maximum)
- **Score doesn't change**: Still update the date to record that a re-evaluation occurred

## Quality Checklist

- [ ] IDEA-NNN parsed and validated
- [ ] Idea found in 01_IDEAS.md
- [ ] Current scores displayed before re-scoring
- [ ] New ICE score computed correctly (additive I+C+E)
- [ ] Status updated based on threshold crossings (Validated preserved; Rejected re-opens)
- [ ] Row updated in place (not duplicated)
- [ ] Date updated to current date
- [ ] Old vs new comparison displayed
