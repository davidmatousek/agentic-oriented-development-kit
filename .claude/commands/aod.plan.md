---
description: Run the full Plan stage — spec → project-plan → tasks — advancing automatically on approval, stopping on rejection
---

## User Input

```text
$ARGUMENTS
```

Consider user input before proceeding (if not empty).

## Overview

Orchestrates all three Plan sub-steps in sequence. Advances automatically when governance reviews pass (APPROVED). Stops if any review returns CHANGES_REQUESTED or BLOCKED, so the user can fix and re-run `/aod.plan` to resume from where it stopped.

**Flow**: Detect branch → Read artifact states → Run sub-steps in sequence (spec → project-plan → tasks) → Stop on rejection or report completion

## Execution

Invoke the `~aod-plan` skill to perform orchestration. Pass any user arguments through to the sub-commands.

The skill will:
1. Determine the current feature from the git branch
2. Check spec.md, plan.md, and tasks.md for existence and approval status
3. Start from the first sub-step that needs work (skips already-approved artifacts)
4. After each sub-step is approved, automatically advance to the next
5. Stop on CHANGES_REQUESTED or BLOCKED — report what needs fixing
6. Report "Plan stage complete" when all three artifacts are approved
