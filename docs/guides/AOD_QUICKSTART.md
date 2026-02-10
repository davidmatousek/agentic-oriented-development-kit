# AOD Quickstart

**Version**: 2.0.0
**Read Time**: ~5 minutes

**Related**:
- [AOD Lifecycle Reference](AOD_LIFECYCLE.md) -- Stage-by-stage deep reference
- [AOD Infographic](AOD_INFOGRAPHIC.md) -- Visual workflow at a glance
- [SDLC Triad Reference](../AOD_TRIAD.md) -- Governance layer documentation
- [AOD Migration Guide](AOD_MIGRATION.md) -- Old command mapping

---

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          AOD LIFECYCLE                                     │
└─────────────────────────────────────────────────────────────────────────────┘

  Discovery                                  Delivery
  ─────────                                  ────────

  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
  │1.Discover│───▶│ 2.Define │───▶│ 3. Plan  │───▶│ 4.Build  │───▶│5.Deliver │
  │          │    │          │    │          │    │          │    │          │
  └──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘
       │                                                               │
       └───────────────────── Feedback Loop ◀──────────────────────────┘
```

---

## What is AOD?

AOD is **Agentic Oriented Development** -- a unified lifecycle with 5 stages that takes work from raw idea to delivered feature. Governance gates (Triad sign-offs) operate as a **separate, configurable layer** between stages. AOD answers two questions: **"Should we build this?"** (Discovery) and **"How do we build this right?"** (Delivery).

---

## Quick Start

The fastest path from idea to implementation:

```bash
# Full flow: 5 commands covering 5 stages
/aod.discover "Add dark mode support"     # Stage 1: Capture idea + ICE score + PM validation
/aod.define dark-mode-support             # Stage 2: Create PRD with Triad review
/aod.plan                                 # Stage 3: Router (run 3x for spec → plan → tasks)
/aod.build                                # Stage 4: Execute tasks with Architect checkpoints
/aod.deliver                              # Stage 5: Close feature with retrospective
```

`/aod.plan` handles the Plan stage internally across 3 sessions (spec, project-plan, tasks). It auto-detects which sub-step you're on.

---

## Command Reference

### Primary Lifecycle Commands (1 per stage)

| Command | Stage | What It Does |
|---------|-------|-------------|
| `/aod.discover` | 1. Discover | Capture idea, ICE score, evidence prompt, PM validation |
| `/aod.define` | 2. Define | Create PRD with Triad review |
| `/aod.plan` | 3. Plan | Router: auto-delegates to `/aod.spec`, `/aod.project-plan`, `/aod.tasks` |
| `/aod.build` | 4. Build | Execute tasks with architect checkpoints |
| `/aod.deliver` | 5. Deliver | Close feature with DoD check and retrospective |

### Utility Commands

| Command | Purpose |
|---------|---------|
| `/aod.score` | Re-score an existing idea |
| `/aod.status` | Regenerate BACKLOG.md, show stage summary |
| `/aod.analyze` | Cross-artifact consistency check |
| `/aod.clarify` | Resolve spec ambiguities |
| `/aod.checklist` | Generate quality checklist (Definition of Done) |
| `/aod.constitution` | View or update governance constitution |

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
| < 12 | Deferred | Auto-defer; requires PM override via `/aod.validate` |

### Auto-Defer Gate

Ideas scoring below 12 are automatically deferred. The PM can override this gate using `/aod.validate IDEA-NNN`.

---

## Governance Tiers

Governance gates are a configurable layer. Choose a tier that matches your risk level.

| Tier | Gate Count | When to Use |
|------|-----------|-------------|
| **Light** | 2 | Solo developers, prototypes, internal tools |
| **Standard** (default) | 6 | Team projects, production features |
| **Full** | all | Regulated industries, critical systems |

Configure in `.aod/memory/constitution.md`:
```yaml
governance:
  tier: standard  # light | standard | full
```

---

## Triad Roles Summary

| Role | Defines | Authority | Key Question |
|------|---------|-----------|--------------|
| **PM** | What & Why | Scope & requirements | Does this solve the right problem? |
| **Architect** | How | Technical decisions | Is this technically sound? |
| **Team-Lead** | When & Who | Timeline & resources | Can we deliver this effectively? |

---

## Sign-off Requirements

| Stage | Required Sign-offs | Command |
|-------|-------------------|---------|
| Define | PM + Architect + Team-Lead | `/aod.define` |
| Plan: Spec | PM | `/aod.spec` (via `/aod.plan`) |
| Plan: Architecture | PM + Architect | `/aod.project-plan` (via `/aod.plan`) |
| Plan: Tasks | PM + Architect + Team-Lead | `/aod.tasks` (via `/aod.plan`) |
| Build | Architect checkpoints | `/aod.build` |
| Deliver | DoD check | `/aod.deliver` |

Each step auto-validates before proceeding. If a reviewer returns **CHANGES REQUESTED**, the phase repeats until all required sign-offs are **APPROVED**.

---

## File Locations

```
Active Feature:
  .aod/                          # Source of truth
  ├── spec.md                    # Feature specification
  ├── plan.md                    # Implementation plan
  └── tasks.md                   # Task breakdown

Feature Archives:
  specs/{NNN}-{feature}/         # Per-feature archives

Product Artifacts:
  docs/product/02_PRD/           # PRD documents
  docs/product/_backlog/         # BACKLOG.md (auto-generated)
```

---

## Troubleshooting

**"Idea auto-deferred but I want to build it"**
Use `/aod.validate IDEA-NNN` to submit the idea for PM review. The PM can override the auto-defer gate with documented rationale.

**"Is Discovery mandatory?"**
No. You can start directly at `/aod.define` without any Discovery artifacts.

**"Spec has no PM sign-off"**
Use `/aod.plan` (which invokes `/aod.spec`) instead of creating spec.md manually. The command automatically invokes PM review.

**"Plan blocked after multiple iterations"**
Split the feature into smaller, independently deliverable pieces, or escalate to the user for scope clarification.

**"Command not found"**
All lifecycle commands use the `/aod.*` prefix. Run `/help` to see all available commands. See [AOD Migration Guide](AOD_MIGRATION.md) for old-to-new command mapping.
