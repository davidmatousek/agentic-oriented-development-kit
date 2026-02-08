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
/triad.prd <topic>         # Create PRD with Triad validation (includes optional vision workshop)
/triad.specify             # Create spec.md with auto PM sign-off
/triad.plan                # Create plan.md with auto PM + Architect sign-off
/triad.tasks               # Create tasks.md with auto triple sign-off
/triad.implement           # Execute with auto architect checkpoints
/triad.close-feature {NNN} # Close feature with parallel doc updates
```

### Utility Commands

```bash
/triad.clarify             # Ask clarification questions about current feature
/triad.analyze             # Verify spec/plan/task consistency
/triad.checklist           # Run Definition of Done checklist
/triad.constitution        # View or update governance constitution
```

**When to Use**:
- Production features requiring quality gates
- Multi-stakeholder projects needing sign-offs
- Complex features with architecture review requirements
- When you need documented governance trail
- Clarifying requirements or verifying consistency at any phase

---

## PDL Commands (Optional Discovery)

Use PDL commands for lightweight product discovery before the Triad workflow. PDL is optional — you can start directly at `/triad.prd` if you prefer.

```bash
/pdl.run <idea>            # Full discovery flow: capture → score → validate → backlog
/pdl.idea <idea>           # Capture idea + ICE scoring
/pdl.score IDEA-NNN        # Re-score an existing idea
/pdl.validate IDEA-NNN     # PM validation gate + user story generation
```

**When to Use**:
- Capturing feature ideas during brainstorming or development
- Evaluating ideas with ICE scoring before committing to PRD creation
- Maintaining a prioritized product backlog of validated user stories
- Running PM validation gates on ideas before heavy Triad governance
