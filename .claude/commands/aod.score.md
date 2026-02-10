---
description: Re-score an existing idea's ICE rating when circumstances change
---

## User Input

```text
$ARGUMENTS
```

Consider user input before proceeding (if not empty).

## Overview

Updates an existing idea's ICE score when circumstances change, new information emerges, or priorities shift.

**Source of truth**: GitHub Issues. Reads and updates the idea's GitHub Issue body.

**Flow**: Parse IDEA-NNN → Find GitHub Issue → Display current scores → New ICE scoring → Update status → Update GitHub Issue → Regenerate BACKLOG.md → Report comparison

## Step 1: Validate Input

1. Parse IDEA-NNN identifier from `$ARGUMENTS`
2. Validate format: Must match `IDEA-` followed by a number (e.g., `IDEA-001`)
3. If invalid or missing: Display usage `Usage: /aod.score IDEA-NNN`

## Step 2: Execute Re-Scoring

Follow the workflow defined in the ~aod-score skill (`.claude/skills/~aod-score/SKILL.md`):

1. Find GitHub Issue: `source .aod/scripts/bash/github-lifecycle.sh && aod_gh_find_issue "[IDEA-NNN]"`
2. Read issue body to extract current ICE scores and status
3. Display current ICE scores and status
4. Present new ICE scoring via AskUserQuestion (Impact, Confidence, Effort — each H9/M6/L3 or custom 1-10)
5. Compute new total, apply status transitions (threshold crossings, Validated preserved, Rejected re-opens)
6. Update GitHub Issue body with new scores and status
7. Add re-score comment to issue
8. Regenerate BACKLOG.md via `.aod/scripts/bash/backlog-regenerate.sh`
9. Report old vs new comparison with tier change if applicable

## Quality Checklist

- [ ] IDEA-NNN format validated
- [ ] GitHub Issue found for the idea
- [ ] Current scores displayed
- [ ] New ICE score computed correctly
- [ ] Status transitions applied correctly
- [ ] GitHub Issue updated (body + comment)
- [ ] BACKLOG.md regenerated
- [ ] Comparison reported
