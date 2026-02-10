---
description: Auto-detect Plan stage progress and route to the correct sub-step (spec → project-plan → tasks)
---

## User Input

```text
$ARGUMENTS
```

Consider user input before proceeding (if not empty).

## Overview

Routes to the correct Plan sub-step by reading artifact frontmatter. No governance gates on the router itself — governance is handled by the sub-commands it invokes.

**Flow**: Detect branch → Read artifact states → Apply decision table → Invoke sub-command or report completion

## Execution

Invoke the `aod-plan` skill to perform routing logic. Pass any user arguments through to the selected sub-command.

The skill will:
1. Determine the current feature from the git branch
2. Check spec.md, plan.md, and tasks.md for existence and approval status
3. Route to `/aod.spec`, `/aod.project-plan`, or `/aod.tasks` as appropriate
4. Report "Plan stage complete" if all artifacts are approved
