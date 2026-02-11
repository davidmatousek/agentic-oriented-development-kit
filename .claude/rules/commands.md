# Commands

<!-- Rule file for Agentic Oriented Development Kit -->
<!-- This file is referenced from CLAUDE.md using @-syntax -->

## Overview

Agentic Oriented Development Kit provides the **Triad Commands** with automatic governance, PM/Architect/Team-Lead sign-offs, and full SDLC workflow support.

---

## Triad Commands

Use Triad commands for governance, quality gates, and multi-agent collaboration.

### SDLC Workflow Commands

```bash
/aod.define <topic>         # Create PRD with Triad validation (includes optional vision workshop)
/aod.spec             # Create spec.md with auto PM sign-off
/aod.project-plan                # Create plan.md with auto PM + Architect sign-off
/aod.tasks               # Create tasks.md with auto triple sign-off
/aod.build           # Execute with auto architect checkpoints
/aod.deliver {NNN} # Close feature with parallel doc updates
```

### Utility Commands

```bash
/aod.clarify             # Ask clarification questions about current feature
/aod.analyze             # Verify spec/plan/task consistency
/aod.checklist           # Run Definition of Done checklist
/aod.constitution        # View or update governance constitution
```

**When to Use**:
- Production features requiring quality gates
- Multi-stakeholder projects needing sign-offs
- Complex features with architecture review requirements
- When you need documented governance trail
- Clarifying requirements or verifying consistency at any phase

### Maintenance Commands

```bash
/aod.sync-upstream       # Sync template files to upstream agentic-oriented-development-kit repo
```

**When to Use**:
- Ad-hoc fixes, refactors, or direct commits to main that bypass `/aod.deliver`
- Any time template content changes and needs to be propagated upstream
- Standalone alternative to Step 7 of `/aod.deliver`

---

## PDL Commands (Optional Discovery)

Use PDL commands for lightweight product discovery before the Triad workflow. PDL is optional — you can start directly at `/aod.define` if you prefer.

```bash
/aod.discover <idea>            # Full discovery flow: capture → score → validate → backlog
/aod.discover <idea>           # Capture idea + ICE scoring
/aod.score #NNN            # Re-score an existing idea (NNN = GitHub Issue number)
/aod.validate #NNN         # PM validation gate + user story generation
```

**When to Use**:
- Capturing feature ideas during brainstorming or development
- Evaluating ideas with ICE scoring before committing to PRD creation
- Maintaining a prioritized product backlog of validated user stories
- Running PM validation gates on ideas before heavy Triad governance
