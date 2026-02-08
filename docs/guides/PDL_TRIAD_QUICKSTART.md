# PDL + Triad Unified Quickstart

**Version**: 1.0.0
**Read Time**: ~5 minutes

**Related**:
- [PDL + Triad Lifecycle Guide](PDL_TRIAD_LIFECYCLE.md) -- Stage-by-stage deep reference
- [PDL + Triad Infographic](PDL_TRIAD_INFOGRAPHIC.md) -- Visual workflow at a glance
- [SDLC Triad Reference](../AOD_TRIAD.md) -- Comprehensive Triad documentation

---

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     PDL + TRIAD UNIFIED WORKFLOW                           │
└─────────────────────────────────────────────────────────────────────────────┘

  PDL (Discovery)                              Triad (Delivery)
  ───────────────                              ────────────────

  ┌────────┐    ┌────────┐    ┌──────────┐    ┌────────┐    ┌────────┐    ┌────────┐
  │  IDEA  │───▶│ SCORE  │───▶│ VALIDATE │═══▶│  PRD   │───▶│SPECIFY │───▶│  PLAN  │
  │        │    │ (ICE)  │    │   (PM)   │    │        │    │        │    │        │
  └────────┘    └────────┘    └──────────┘    └────────┘    └────────┘    └────────┘
                                                                               │
  ┌────────┐    ┌──────────┐                                                   │
  │DEPLOYED│◀───│IMPLEMENT │◀──────────────────────────────┌────────┐◀─────────┘
  │        │    │          │                               │ TASKS  │
  └────────┘    └──────────┘                               └────────┘
```

---

## What is PDL?

PDL is the **Product Discovery Lifecycle** -- a structured discovery phase that captures ideas, scores them with ICE (Impact, Confidence, Effort), validates with a PM, and maintains a prioritized product backlog. PDL answers the question: **"Should we build this?"** It is entirely optional; you can skip it and start directly at the Triad workflow.

---

## What is Triad?

The **SDLC Triad** is a governance framework ensuring Product-Architecture-Engineering alignment throughout the delivery process. Three specialized roles -- PM (What & Why), Architect (How), and Team-Lead (When & Who) -- provide sign-offs at each phase to prevent technical inaccuracies and scope drift. Triad answers the question: **"How do we build this right?"**

---

## Quick Start

The fastest path from idea to implementation:

```bash
# Option 1: Full flow (PDL discovery + Triad delivery)
/pdl.run "Add dark mode support"          # Capture + Score + Validate + Backlog
/triad.prd dark-mode-support              # Create PRD with Triad validation
/triad.specify                            # Create spec with PM sign-off
/triad.plan                               # Create plan with PM + Architect sign-off
/triad.tasks                              # Create tasks with triple sign-off
/triad.implement                          # Execute with Architect checkpoints

# Option 2: Skip PDL (start directly at Triad)
/triad.prd dark-mode-support              # PDL is optional
```

---

## PDL Command Reference

| Command | Purpose | Input | Output |
|---------|---------|-------|--------|
| `/pdl.run <idea>` | Full discovery flow in one step | Idea description | IDEA + User Story (if approved) |
| `/pdl.idea <idea>` | Capture idea + ICE scoring only | Idea description | IDEA entry in backlog |
| `/pdl.score IDEA-NNN` | Re-score an existing idea | Idea identifier | Updated ICE score |
| `/pdl.validate IDEA-NNN` | PM validation + user story generation | Idea identifier | User Story (if approved) |

---

## Triad Command Reference

| Command | Purpose | Sign-offs | Output |
|---------|---------|-----------|--------|
| `/triad.prd <topic>` | Create PRD with Triad validation | PM + Architect + Team-Lead | PRD file |
| `/triad.specify` | Create spec with research phase | PM | spec.md |
| `/triad.plan` | Create implementation plan | PM + Architect | plan.md |
| `/triad.tasks` | Create task breakdown | PM + Architect + Team-Lead | tasks.md + agent-assignments.md |
| `/triad.implement` | Execute with checkpoints | Architect checkpoints | Implementation |
| `/triad.close-feature NNN` | Close completed feature | Auto | Documentation updates |

---

## ICE Scoring Quick Reference

ICE stands for **Impact**, **Confidence**, and **Effort** (ease of implementation). Each dimension is scored 1-10, with a total range of 3-30.

### Quick-Assessment Anchors

| Dimension | High (9) | Medium (6) | Low (3) |
|-----------|----------|------------|---------|
| **Impact** | Transformative | Solid improvement | Minor enhancement |
| **Confidence** | Proven pattern | Some unknowns | Speculative |
| **Effort (Ease)** | Days of work | Weeks of work | Months of work |

### Priority Tiers

| Score Range | Priority | Action |
|-------------|----------|--------|
| 25-30 | P0 (Critical) | Fast-track to development |
| 18-24 | P1 (High) | Queue for next sprint |
| 12-17 | P2 (Medium) | Consider when capacity allows |
| < 12 | Deferred | Auto-defer; requires PM override via `/pdl.validate` |

### Auto-Defer Gate

Ideas scoring below 12 are automatically deferred. This catches ideas where all dimensions score poorly (e.g., Low/Low/Low = 9). The PM can override this gate using `/pdl.validate IDEA-NNN`.

---

## PDL to Triad Handoff

When a user story reaches "Ready for PRD" status in the product backlog, run `/triad.prd <topic>` to begin the Triad delivery workflow. The PRD creation flow detects backlog items with "Ready for PRD" status and links them automatically.

The PRD includes `source.idea_id` and `source.story_id` fields in its frontmatter, establishing full traceability:

```
IDEA --> User Story --> PRD --> spec.md --> plan.md --> tasks.md --> Code
```

Each artifact references its source, so you can trace any piece of delivered code back to the original idea.

---

## Triad Roles Summary

| Role | Defines | Authority | Key Question |
|------|---------|-----------|--------------|
| **PM** | What & Why | Scope & requirements | Does this solve the right problem? |
| **Architect** | How | Technical decisions | Is this technically sound? |
| **Team-Lead** | When & Who | Timeline & resources | Can we deliver this effectively? |

---

## Sign-off Requirements

| Phase | Required Sign-offs | Command |
|-------|-------------------|---------|
| PRD | PM + Architect + Team-Lead | `/triad.prd` |
| Specification | PM | `/triad.specify` |
| Plan | PM + Architect | `/triad.plan` |
| Tasks | PM + Architect + Team-Lead | `/triad.tasks` |
| Implementation | Architect checkpoints | `/triad.implement` |

Each step auto-validates before proceeding. If a reviewer returns **CHANGES REQUESTED**, the phase repeats until all required sign-offs are **APPROVED**.

---

## File Locations

```
PDL Artifacts:
  docs/product/_backlog/
  ├── 01_IDEAS.md              # All captured ideas with ICE scores
  └── 02_USER_STORIES.md       # PM-validated user stories

Triad Artifacts:
  .aod/                    # Active feature (source of truth)
  ├── spec.md                  # Feature specification
  ├── plan.md                  # Implementation plan
  └── tasks.md                 # Task breakdown

  specs/{NNN}-{feature}/       # Archived specifications
  docs/product/02_PRD/         # PRD documents
```

---

## Troubleshooting

**"Idea auto-deferred but I want to build it"**
Use `/pdl.validate IDEA-NNN` to submit the idea for PM review. The PM can override the auto-defer gate with documented rationale.

**"Is PDL mandatory?"**
No. PDL is entirely optional. You can start directly at `/triad.prd` without any PDL artifacts.

**"Spec has no PM sign-off"**
Use `/triad.specify` instead of creating spec.md manually. The Triad command automatically invokes PM review and records the sign-off.

**"Plan blocked after multiple iterations"**
Split the feature into smaller, independently deliverable pieces, or escalate to the user for scope clarification.

**"Command not found"**
Ensure you are using the correct prefix: `/pdl.` for discovery commands and `/triad.` for delivery commands. Run `/help` to see all available commands.
