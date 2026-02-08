---
description: Capture a new feature idea with ICE scoring into the Ideas Backlog
---

## User Input

```text
$ARGUMENTS
```

Consider user input before proceeding (if not empty).

## Overview

Captures a raw feature idea, scores it with ICE (Impact, Confidence, Effort), and appends it to the Ideas Backlog.

**Flow**: Parse idea → Auto-create backlog files → Generate ID → Capture source → ICE scoring → Auto-defer gate → Append to backlog → Report result

## Step 1: Validate Input

1. Parse idea description from `$ARGUMENTS`
2. If empty: Ask the user to describe their idea before proceeding

## Step 2: Execute Idea Capture

Follow the workflow defined in the pdl-idea skill (`.claude/skills/pdl-idea/SKILL.md`):

1. Auto-create backlog files if missing (FR-7)
2. Generate IDEA-NNN ID (read table, find highest, increment)
3. Capture source via AskUserQuestion (Brainstorm / Customer Feedback / Team Idea / User Request)
4. ICE scoring via AskUserQuestion (Impact, Confidence, Effort — each H9/M6/L3 or custom 1-10)
5. Compute ICE total, apply auto-defer gate (< 12 = Deferred, >= 12 = Scoring)
6. Append row to `docs/product/_backlog/01_IDEAS.md`
7. Report result with ID, ICE breakdown, priority tier, and next step guidance

## Quality Checklist

- [ ] Idea description captured from user
- [ ] IDEA-NNN ID generated correctly
- [ ] Source captured from user selection
- [ ] ICE score computed and auto-defer gate applied
- [ ] Row appended to 01_IDEAS.md
- [ ] Result reported with next step guidance
