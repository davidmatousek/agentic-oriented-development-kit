---
description: "Full product discovery flow: capture, score, validate, and add to backlog in one step"
---

## User Input

```text
$ARGUMENTS
```

Consider user input before proceeding (if not empty).

## Overview

Executes the complete Product Discovery Lifecycle in a single flow: captures an idea, scores it with ICE, validates with PM, and adds a user story to the product backlog.

**Flow**: Parse idea → Auto-create backlog files → Capture + Score → Auto-defer gate → PM validation → User story generation → Report

## Step 1: Validate Input

1. Parse idea description from `$ARGUMENTS`
2. If empty: Ask the user to describe their idea before proceeding

## Step 2: Execute Full Discovery Flow

Follow the workflow defined in the pdl-run skill (`.claude/skills/pdl-run/SKILL.md`):

1. Auto-create backlog files if missing (FR-7)
2. **Capture**: Generate IDEA-NNN ID, capture source, run ICE scoring (all inline)
3. **Auto-Defer Gate**: If score < 12, set status to "Deferred", report result, and **STOP**. Guide user to `/pdl.validate IDEA-NNN` for PM override.
4. **PM Validation**: If score >= 12, launch PM review via Task tool with product-manager subagent (inline)
5. **If Rejected**: Update status to "Rejected", report result, and stop
6. **If Approved**:
   a. Generate user story, present for confirmation
   b. Generate US-NNN ID, determine priority
   c. Append to `docs/product/_backlog/02_USER_STORIES.md`
   d. Update idea status to "Validated" in 01_IDEAS.md
7. Report complete flow summary: IDEA-NNN, ICE score, PM result, US-NNN (if approved), next step `/triad.prd`

## Quality Checklist

- [ ] Idea description captured from user
- [ ] IDEA-NNN ID generated and source captured
- [ ] ICE score computed and auto-defer gate applied
- [ ] Auto-deferred ideas stop flow with guidance
- [ ] PM validation invoked for qualifying ideas
- [ ] User story generated and confirmed (if approved)
- [ ] Both backlog files updated correctly
- [ ] Complete flow summary displayed
