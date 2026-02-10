# AOD Lifecycle Reference

**Version**: 1.0.0
**Status**: Active
**Spec Reference**: `specs/010-aod-lifecycle-formalization/spec.md` (FR-011)

---

## The AOD Lifecycle

The AOD Lifecycle is a single, linear sequence of 5 stages organized into 2 phases. All work passes through these stages from idea to delivered feature.

```
                    DISCOVERY                              DELIVERY
          .-----------------------. .------------------------------------------------.
          |                       | |                                                |
          |   [1. Discover]-->[2. Define]-->[3. Plan]-->[4. Build]-->[5. Deliver]    |
          |                       | |                                                |
          '-----------------------' '------------------------------------------------'
                                                                          |
                                                                   Feedback Loop
                                                                          |
                                                              New ideas --> Discover
```

### Lifecycle with Governance Gates

Governance gates are Triad approval checkpoints that operate **between stages**, not as stages themselves. Gates determine who approves before work advances.

```
  DISCOVERY PHASE                          DELIVERY PHASE
  ================                         ======================================

  +------------+       +----------+        +---------+       +---------+       +---------+
  |            |       |          |        |         |       |         |       |         |
  | 1.Discover |       | 2.Define |        | 3. Plan |       | 4.Build |       |5.Deliver|
  |            |       |          |        |         |       |         |       |         |
  | Capture    |       | Create   |        | Spec    |       | Execute |       | Close   |
  | ideas +    |       | PRD with |        | + Arch  |       | tasks   |       | feature |
  | ICE score  |       | Triad    |        | plan +  |       | with    |       | + retro |
  |            |       | review   |        | tasks   |       | reviews |       |         |
  +-----+------+       +----+-----+        +----+----+       +----+----+       +----+----+
        |                    |                   |                 |                 |
        v                    v                   v                 v                 v
   +---------+         +---------+     +------------------+  +---------+       +---------+
   |  GATE   |         |  GATE   |     |      GATES       |  |  GATE   |       |  GATE   |
   | PM val. |         | PRD     |     | PM spec sign-off |  | Arch    |       | DoD     |
   | (tier-  |         | review  |     | PM+Arch plan     |  | check-  |       | check   |
   | depend.)|         | (tier-  |     | Triple sign-off  |  | points  |       |         |
   +---------+         | depend.)|     +------------------+  +---------+       +---------+
                       +---------+
```

---

## Stage Definitions

### 1. Discover (Discovery Phase)

**Purpose**: Capture new feature ideas, score them with ICE, and gather evidence of the problem being solved.

| | |
|---|---|
| **Primary Command** | `/aod.discover` |
| **Key Output** | Scored idea with evidence, GitHub Issue (`stage:discover`) |
| **Governance Gate** | PM validation (tier-dependent) |

### 2. Define (Discovery Phase)

**Purpose**: Create a Product Requirements Document (PRD) through structured Triad review, establishing the "what" and "why" for a feature.

| | |
|---|---|
| **Primary Command** | `/aod.define` |
| **Key Output** | Approved PRD in `docs/product/02_PRD/` |
| **Governance Gate** | Triad PRD review (tier-dependent) |

### 3. Plan (Delivery Phase)

**Purpose**: Produce the specification, architecture plan, and task breakdown. This is the most complex stage, with 3 sequential sub-steps managed by a single router command.

| | |
|---|---|
| **Primary Command** | `/aod.plan` (router -- auto-delegates to sub-steps) |
| **Key Output** | `spec.md`, `plan.md`, `tasks.md` in `.aod/` |
| **Governance Gates** | PM spec sign-off, PM+Architect plan sign-off, Triple sign-off on tasks |

**Sub-steps** (auto-detected by `/aod.plan`):

| Sub-step | Command | Sign-off |
|----------|---------|----------|
| Specification | `/aod.spec` | PM sign-off |
| Architecture Plan | `/aod.project-plan` | PM + Architect sign-off |
| Task Breakdown | `/aod.tasks` | PM + Architect + Team-Lead sign-off |

### 4. Build (Delivery Phase)

**Purpose**: Execute tasks from the approved task breakdown with architect checkpoints during implementation.

| | |
|---|---|
| **Primary Command** | `/aod.build` |
| **Key Output** | Implemented feature on feature branch |
| **Governance Gate** | Architect checkpoints during execution |

### 5. Deliver (Delivery Phase)

**Purpose**: Close the feature with Definition of Done validation and a structured retrospective that feeds learnings back into discovery.

| | |
|---|---|
| **Primary Command** | `/aod.deliver` |
| **Key Output** | Closed feature, retrospective, KB entry, new ideas (feedback loop) |
| **Governance Gate** | DoD check (all tiers) |

---

## Governance Tiers

Governance gates are a **separate, configurable layer** on top of the lifecycle. Choose a tier that matches your project's risk level. The lifecycle stages are the same regardless of tier -- only the gates change.

### Tier Overview

| Tier | Gate Count | When to Use |
|------|-----------|-------------|
| **Light** | 2 | Solo developers, prototypes, internal tools, hackathons |
| **Standard** (default) | 6 | Team projects, production features, most work |
| **Full** | all | Regulated industries, critical systems, high-stakes launches |

### Tier Descriptions

**Light (2 gates)**: Minimal ceremony. Triple sign-off at Plan stage and DoD at Deliver. Discover and Define gates are optional or skipped. For work where speed matters more than risk mitigation.

**Standard (6 gates, default)**: Balanced governance. PM validation at Discover, PRD review at Define, PM+Architect sign-off plus Triple sign-off at Plan, Architect checkpoints at Build, DoD at Deliver. Appropriate for most production work.

**Full (all gates)**: Maximum rigor. Everything in Standard plus a separate PM spec sign-off before the architecture plan. For environments where audit trails and formal approval at every boundary are required.

### Configuration

Set the governance tier in `.aod/memory/constitution.md`:

```yaml
governance:
  tier: standard  # light | standard | full
```

### Rules

- Triple sign-off (PM + Architect + Team-Lead on tasks) is the **minimum governance floor** for all tiers
- DoD check and Architect build checkpoints apply to **all tiers**
- Tier affects only Discover, Define, and Plan stage gates
- Tier is configured per project, not per feature

---

## Governance Gate Matrix

Which gates activate at each stage, per tier.

| Tier | Discover | Define | Plan | Build | Deliver |
|------|----------|--------|------|-------|---------|
| **Light** | Optional | Skip | Triple sign-off only | Architect checkpoints | DoD |
| **Standard** | PM validation | PRD review | PM+Arch + Triple | Architect checkpoints | DoD |
| **Full** | PM validation | PRD review | PM spec + PM+Arch plan + Triple | Architect checkpoints | DoD |

**Reading the matrix**: "PM+Arch + Triple" means PM and Architect sign-off on the architecture plan, followed by PM + Architect + Team-Lead sign-off on the task breakdown. "PM spec" means a separate PM sign-off on the specification before the architecture plan proceeds.

---

## Command Reference

### Primary Lifecycle Commands (1 per stage)

| Command | Stage | Phase | What It Does |
|---------|-------|-------|-------------|
| `/aod.discover` | Discover | Discovery | Capture idea, ICE score, evidence prompt, PM validation |
| `/aod.define` | Define | Discovery | Create PRD with Triad review |
| `/aod.plan` | Plan | Delivery | Router: auto-delegates to `/aod.spec`, `/aod.project-plan`, `/aod.tasks` |
| `/aod.build` | Build | Delivery | Execute tasks with architect checkpoints |
| `/aod.deliver` | Deliver | Delivery | Close feature with DoD check and retrospective |

### Plan Sub-Commands (invoked by `/aod.plan` router)

| Command | Plan Sub-Step | Output |
|---------|--------------|--------|
| `/aod.spec` | Specification | `spec.md` with PM sign-off |
| `/aod.project-plan` | Architecture Plan | `plan.md` with PM + Architect sign-off |
| `/aod.tasks` | Task Breakdown | `tasks.md` with Triple sign-off |

### Utility Commands (no governance gates)

| Command | Purpose |
|---------|---------|
| `/aod.score` | Re-score an existing idea (stays in Discover stage) |
| `/aod.status` | Regenerate BACKLOG.md on demand, show stage summary |
| `/aod.analyze` | Cross-artifact consistency check |
| `/aod.clarify` | Resolve spec ambiguities |
| `/aod.checklist` | Generate quality checklist (Definition of Done) |
| `/aod.constitution` | View or update governance constitution |

### Minimum Feature Sequence

```
/aod.discover --> /aod.define --> /aod.plan (x3 sessions) --> /aod.build --> /aod.deliver
```

Five commands. `/aod.plan` handles the Plan stage internally across 3 sessions (spec, project-plan, tasks).

---

## Where Do I Find Things?

Artifacts are organized into 3 zones. Each zone has a distinct purpose.

### `.aod/` Zone -- Active Feature State

The source of truth for the current feature being worked on.

| File | Purpose |
|------|---------|
| `spec.md` | Feature specification (Plan stage output) |
| `plan.md` | Architecture plan (Plan stage output) |
| `tasks.md` | Task breakdown (Plan stage output) |
| `memory/constitution.md` | Governance principles + tier configuration |

### `specs/NNN-*/` Zone -- Feature Archives

Per-feature directory for research, design artifacts, and review records.

| File | Purpose |
|------|---------|
| `research.md` | Pre-specification research findings |
| `data-model.md` | Entity model and state machine design |
| `checklists/` | Quality checklists for the feature |
| `agent-assignments.md` | Task-to-agent mapping (Team-Lead output) |
| `spec.md` | Archived spec (copied from `.aod/`) |
| `plan.md` | Archived plan (copied from `.aod/`) |
| `tasks.md` | Archived tasks (copied from `.aod/`) |

### `docs/product/` Zone -- Product Documentation

Long-lived product artifacts that span features.

| File/Directory | Purpose |
|----------------|---------|
| `02_PRD/` | Product Requirements Documents (Define stage output) |
| `02_PRD/INDEX.md` | PRD index with status tracking |
| `_backlog/BACKLOG.md` | Auto-generated backlog grouped by lifecycle stage |
| `_backlog/archive/` | Archived legacy backlog files |
| `01_Product_Vision/` | Product vision and strategy |
| `03_Product_Roadmap/` | Roadmap and timeline |
| `05_User_Stories/` | User story library |
| `06_OKRs/` | Objectives and Key Results |

---

**Last Updated**: 2026-02-09
**Maintained By**: Product Manager (lifecycle governance)
**Source**: Feature 010 -- AOD Lifecycle Formalization
