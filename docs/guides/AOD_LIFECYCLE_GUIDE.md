# AOD Complete Lifecycle Guide

**Version**: 2.0.0
**Read Time**: ~8 minutes

**Related**:
- [AOD Quickstart](AOD_QUICKSTART.md) -- Quick onboarding guide
- [AOD Infographic](AOD_INFOGRAPHIC.md) -- Visual workflow at a glance
- [SDLC Triad Reference](../AOD_TRIAD.md) -- Governance layer documentation
- [AOD Lifecycle Reference](AOD_LIFECYCLE.md) -- Stage definitions and governance tiers

This guide covers the complete product lifecycle from raw idea to shipped feature using the AOD (Agentic Oriented Development) Lifecycle.

---

## Visual Flow

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

---

## Complete Lifecycle Overview

```
Discovery                                     Delivery
──────────────────────────────────           ──────────────────────────────────

Stage 1        Stage 2       Stage 3          Stage 4        Stage 5
Discover    →  Define     →  Plan          →  Build       →  Deliver
    │              │              │                │              │
    ▼              ▼              ▼                ▼              ▼
GitHub Issue   PRD doc      spec.md +         Implemented    Closed feature +
+ evidence                  plan.md +         feature        retrospective +
                            tasks.md                         KB entry
```

---

## Stage 1: Discover

**Command**: `/aod.discover "your idea"` (full flow with PM validation) or `/aod.discover` with capture-only mode

**What happens**:
1. A unique IDEA-NNN identifier is generated
2. The idea description is recorded
3. ICE scoring (Impact, Confidence, Effort) is applied
4. Evidence prompt: "Who has this problem, and how do you know?"
5. PM validation gate (tier-dependent)
6. If approved: user story generated, GitHub Issue created with `stage:discover` label

**Output**: GitHub Issue with `stage:discover` label, scored idea with evidence.

**ICE Quick Reference**:
- P0 (25-30): Critical — fast-track
- P1 (18-24): High — next sprint
- P2 (12-17): Medium — when capacity allows
- Deferred (< 12): Auto-deferred — PM override via `/aod.validate`

---

## Stage 2: Define

**Command**: `/aod.define <topic>`

**What happens**:
1. PRD creation flow begins with Triad review
2. If a backlog item is selected, PRD frontmatter includes source traceability:
   ```yaml
   source:
     idea_id: IDEA-001
     story_id: US-001
   ```
3. PM drafts, Architect + Team-Lead review, PM finalizes

**Output**: PRD in `docs/product/02_PRD/{NNN}-{topic}-{date}.md`

**Governance Gate**: Triad PRD review (tier-dependent)

---

## Stage 3: Plan

**Command**: `/aod.plan` (router — run up to 3 times)

The Plan stage has 3 sequential sub-steps. The `/aod.plan` router auto-detects which sub-step you're on based on artifact state.

| Sub-step | Direct Command | Output | Sign-off |
|----------|---------------|--------|----------|
| Specification | `/aod.spec` | spec.md | PM |
| Architecture Plan | `/aod.project-plan` | plan.md | PM + Architect |
| Task Breakdown | `/aod.tasks` | tasks.md + agent-assignments.md | PM + Architect + Team-Lead |

**Router logic**:
1. No spec.md → delegates to `/aod.spec`
2. Spec approved, no plan.md → delegates to `/aod.project-plan`
3. Plan approved, no tasks.md → delegates to `/aod.tasks`
4. All approved → "Plan stage complete"

### Specification (Sub-step 1)

**What happens**:
1. Research phase: KB query, codebase exploration, architecture docs, web search
2. Spec generation with functional requirements, user scenarios, acceptance criteria
3. PM review and sign-off

### Architecture Plan (Sub-step 2)

**What happens**:
1. Architecture decisions, API contracts, data models
2. PM + Architect dual sign-off

### Task Breakdown (Sub-step 3)

**What happens**:
1. Tasks decomposed from plan with agent assignments
2. Parallel execution waves defined
3. PM + Architect + Team-Lead triple sign-off

---

## Stage 4: Build

**Command**: `/aod.build`

**What happens**:
1. Execute tasks from approved task breakdown
2. Architect checkpoints at wave boundaries
3. Implementation proceeds wave by wave

**Output**: Implemented feature on feature branch

**Governance Gate**: Architect checkpoints during execution

---

## Stage 5: Deliver

**Command**: `/aod.deliver`

**What happens**:
1. Definition of Done validation
2. Structured retrospective:
   - Estimated vs. actual duration
   - "What surprised us" (lessons learned)
   - "What should we do next" (new ideas)
3. KB entry from lessons learned
4. New ideas fed back to Discover as GitHub Issues with `stage:discover` label

**Output**: Closed feature, retrospective, KB entry, feedback loop to Discover

**Governance Gate**: DoD check (all tiers)

---

## Commands by Stage

| Stage | Command | Output |
|-------|---------|--------|
| 1. Discover | `/aod.discover <idea>` | GitHub Issue + scored idea |
| 2. Define | `/aod.define <topic>` | PRD |
| 3. Plan | `/aod.plan` (router) | spec.md, plan.md, tasks.md |
| 4. Build | `/aod.build` | Implemented feature |
| 5. Deliver | `/aod.deliver` | Closed feature + retrospective |

**Full flow shortcut**: `/aod.discover <idea>` covers the entire Discover stage in one command.

---

## Traceability Model

The complete traceability chain from idea to delivery:

```
IDEA-001 (GitHub Issue, stage:discover)
  └── US-001 (User Story)
        └── PRD 005 (docs/product/02_PRD/005-*.md)
              └── spec.md (specs/005-*/spec.md)
                    └── plan.md (specs/005-*/plan.md)
                          └── tasks.md (specs/005-*/tasks.md)
                                └── Implementation files
```

Each artifact references its source:
- User Story → links to IDEA-NNN via Source column
- PRD → links to IDEA-NNN and US-NNN via `source` frontmatter
- Spec → links to PRD via `prd_reference` frontmatter
- Plan → links to Spec via `spec_reference`
- Tasks → links to Plan via `plan_reference`

---

## Status Flow Diagram

### Idea Status (GitHub Issues)

```
[Capture] → stage:discover (>= 12) → stage:define (PRD started)
                │
                └→ Deferred (< 12) → Re-scored (>= 12) → stage:define
                │
                └→ Rejected (PM rejected)
```

### Feature Lifecycle (GitHub Issue labels)

```
stage:discover → stage:define → stage:plan → stage:build → stage:deliver
```

---

## End-to-End Example

### Step 1: Discover

```bash
/aod.discover "Add dark mode support for the dashboard"
```

- **IDEA-001** created, GitHub Issue with `stage:discover`
- ICE Score: 24 (I:9 C:9 E:6) — P1 (High)
- Evidence: "Customer feedback — 12 requests in last quarter"
- PM agent reviews: APPROVED

### Step 2: Define

```bash
/aod.define dark-mode-support
```

- PRD created with `source.idea_id: IDEA-001`
- GitHub Issue label updated to `stage:define`

### Step 3: Plan (3 sessions)

```bash
/aod.plan    # Session 1: generates spec.md (PM sign-off)
/aod.plan    # Session 2: generates plan.md (PM + Architect sign-off)
/aod.plan    # Session 3: generates tasks.md (Triple sign-off)
```

- GitHub Issue label updated to `stage:plan`

### Step 4: Build

```bash
/aod.build
```

- Tasks executed with Architect checkpoints
- GitHub Issue label updated to `stage:build`

### Step 5: Deliver

```bash
/aod.deliver
```

- DoD validated, retrospective captured, KB entry created
- GitHub Issue label updated to `stage:deliver`
- New ideas from retrospective → new GitHub Issues with `stage:discover`

Feature delivered with full traceability from original idea to shipped code.

---

## Summary

| Stage | Command | Output | Governance |
|-------|---------|--------|-----------|
| 1. Discover | `/aod.discover` | Scored idea + evidence | PM validation (tier-dependent) |
| 2. Define | `/aod.define` | PRD | Triad PRD review |
| 3. Plan | `/aod.plan` (x3) | spec + plan + tasks | PM, PM+Arch, Triple sign-off |
| 4. Build | `/aod.build` | Implementation | Architect checkpoints |
| 5. Deliver | `/aod.deliver` | Closed feature + retro | DoD check |
