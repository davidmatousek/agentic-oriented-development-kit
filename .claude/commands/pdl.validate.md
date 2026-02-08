---
description: PM validation gate for ideas with user story generation
---

## User Input

```text
$ARGUMENTS
```

Consider user input before proceeding (if not empty).

## Overview

Submits an idea to the Product Manager agent for validation. On approval, generates a user story and adds it to the product backlog. On rejection, updates the idea status.

**Flow**: Parse IDEA-NNN → Find idea → Launch PM review → Handle result → Generate user story (if approved) → Update backlogs → Report

## Step 1: Validate Input

1. Parse IDEA-NNN identifier from `$ARGUMENTS`
2. Validate format: Must match `IDEA-` followed by a 3-digit number (e.g., `IDEA-001`)
3. If invalid or missing: Display usage `Usage: /pdl.validate IDEA-NNN`

## Step 2: Execute Validation

Follow the workflow defined in the pdl-validate skill (`.claude/skills/pdl-validate/SKILL.md`):

1. Auto-create backlog files if missing (FR-7)
2. Read `docs/product/_backlog/01_IDEAS.md` and find the matching row
3. Verify idea is eligible (not already Rejected or Validated)
4. Launch PM validation via Task tool with product-manager subagent
5. **If Rejected**: Update status to "Rejected" in 01_IDEAS.md, display rationale
6. **If Approved**:
   a. Generate user story in "As a [persona], I want [action], so that [benefit]" format
   b. Present for user confirmation (accept or edit)
   c. Generate US-NNN ID and determine priority
   d. Append to `docs/product/_backlog/02_USER_STORIES.md`
   e. Update idea status to "Validated" in 01_IDEAS.md
   f. Document PM override rationale if idea was auto-deferred
7. Report result with next step guidance (`/triad.prd`)

## Quality Checklist

- [ ] IDEA-NNN format validated
- [ ] Idea found and eligible for validation
- [ ] PM agent invoked with idea details
- [ ] Rejection or approval handled correctly
- [ ] User story generated and confirmed (if approved)
- [ ] Both backlog files updated correctly
- [ ] Result reported with next step
