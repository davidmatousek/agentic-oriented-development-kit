---
description: Re-score an existing idea's ICE rating when circumstances change
---

## User Input

```text
$ARGUMENTS
```

Consider user input before proceeding (if not empty).

## Overview

Updates an existing idea's ICE score in the Ideas Backlog when circumstances change, new information emerges, or priorities shift.

**Flow**: Parse IDEA-NNN → Find idea → Display current scores → New ICE scoring → Update status → Update row → Report comparison

## Step 1: Validate Input

1. Parse IDEA-NNN identifier from `$ARGUMENTS`
2. Validate format: Must match `IDEA-` followed by a 3-digit number (e.g., `IDEA-001`)
3. If invalid or missing: Display usage `Usage: /pdl.score IDEA-NNN`

## Step 2: Execute Re-Scoring

Follow the workflow defined in the pdl-score skill (`.claude/skills/pdl-score/SKILL.md`):

1. Auto-create backlog files if missing (FR-7)
2. Read `docs/product/_backlog/01_IDEAS.md` and find the matching row
3. Display current ICE scores and status
4. Present new ICE scoring via AskUserQuestion (Impact, Confidence, Effort — each H9/M6/L3 or custom 1-10)
5. Compute new total, apply status transitions (threshold crossings, Validated preserved, Rejected re-opens)
6. Update row in place in `01_IDEAS.md` with new score, status, and date
7. Report old vs new comparison with tier change if applicable

## Quality Checklist

- [ ] IDEA-NNN format validated
- [ ] Idea found in 01_IDEAS.md
- [ ] Current scores displayed
- [ ] New ICE score computed correctly
- [ ] Status transitions applied correctly
- [ ] Row updated in place (not duplicated)
- [ ] Comparison reported
