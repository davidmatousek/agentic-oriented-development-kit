---
description: Capture a new feature idea with ICE scoring into the Ideas Backlog
---

## User Input

```text
$ARGUMENTS
```

Consider user input before proceeding (if not empty).

## Overview

Captures a raw feature idea, scores it with ICE (Impact, Confidence, Effort), and creates a GitHub Issue for lifecycle tracking.

**Source of truth**: GitHub Issues with `stage:*` labels. BACKLOG.md is auto-generated.

**Flow**: Parse idea → Generate ID from GitHub Issues → Capture source → ICE scoring → Evidence → Auto-defer gate → Create GitHub Issue → Regenerate BACKLOG.md → Report result

## Step 1: Validate Input

1. Parse idea description from `$ARGUMENTS`
2. If empty: Ask the user to describe their idea before proceeding

## Step 2: Execute Idea Capture

Follow the workflow defined in the ~aod-discover skill (`.claude/skills/~aod-discover/SKILL.md`):

1. Generate IDEA-NNN ID (search existing GitHub Issues for highest `[IDEA-NNN]`, increment)
2. Capture source via AskUserQuestion (Brainstorm / Customer Feedback / Team Idea / User Request)
3. ICE scoring via AskUserQuestion (Impact, Confidence, Effort — each H9/M6/L3 or custom 1-10)
4. Evidence prompt via AskUserQuestion
5. Compute ICE total, apply auto-defer gate (< 12 = Deferred, >= 12 = Scoring)
6. Create GitHub Issue with structured body and `stage:discover` label
7. Regenerate BACKLOG.md via `.aod/scripts/bash/backlog-regenerate.sh`
8. Report result with ID, ICE breakdown, priority tier, and next step guidance

## Quality Checklist

- [ ] Idea description captured from user
- [ ] IDEA-NNN ID generated correctly from GitHub Issues
- [ ] Source captured from user selection
- [ ] Evidence captured from user
- [ ] ICE score computed and auto-defer gate applied
- [ ] GitHub Issue created with structured body and `stage:discover` label
- [ ] BACKLOG.md regenerated
- [ ] Result reported with next step guidance
