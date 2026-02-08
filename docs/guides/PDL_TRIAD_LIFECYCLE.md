# PDL + Triad Complete Lifecycle Guide

**Version**: 1.0.0
**Read Time**: ~8 minutes

**Related**:
- [PDL + Triad Quickstart](PDL_TRIAD_QUICKSTART.md) -- Unified onboarding guide
- [PDL + Triad Infographic](PDL_TRIAD_INFOGRAPHIC.md) -- Visual workflow at a glance
- [SDLC Triad Reference](../AOD_TRIAD.md) -- Comprehensive Triad documentation

This guide covers the complete product lifecycle from raw idea to shipped feature, integrating the Product Discovery Lifecycle (PDL) with the Triad workflow.

---

## Visual Flow

```
PDL Discovery                                          Triad Delivery
─────────────────────────────────────    ─────────────────────────────────────────
┌────────┐   ┌────────┐   ┌──────────┐    ┌────────┐   ┌────────┐   ┌────────┐
│  IDEA  │──▶│ SCORE  │──▶│ VALIDATE │══▶│  PRD   │──▶│SPECIFY │──▶│  PLAN  │
│        │   │ (ICE)  │   │   (PM)   │    │        │   │        │   │        │
└────────┘   └────────┘   └──────────┘    └────────┘   └────────┘   └────────┘
 Stage 1      Stage 2      Stage 3         Stage 5      Stage 6      Stage 7
                              │                                          │
              ┌──────────┐    │                                          ▼
              │ BACKLOG  │◀───┘                          ┌────────┐   ┌────────┐
              │          │                               │DEPLOYED│◀──│IMPLEMENT│
              └──────────┘                               │        │   │        │
               Stage 4                                   └────────┘   └────────┘
                                            ┌────────┐    Stage 10    Stage 9
                                            │ TASKS  │──────────────────▲
                                            │        │
                                            └────────┘
                                             Stage 8
```

---

## Complete Lifecycle Overview

```
PDL (Discovery)                              Triad (Delivery)
──────────────────────────────────           ──────────────────────────────────

Stage 1        Stage 2       Stage 3          Stage 5        Stages 6-10
Idea Capture → ICE Scoring → PM Validation → Triad Handoff → PRD → Spec → Plan → Tasks → Implement
    │              │              │                │
    ▼              ▼              ▼                ▼
01_IDEAS.md    01_IDEAS.md   02_USER_STORIES.md  PRD with source
(New entry)    (Scored)      (User story)        traceability

                         Stage 4
                    Product Backlog
                  (Prioritized stories)
```

---

## Stage 1: Idea Capture

**Command**: `/pdl.idea "your idea"` or `/pdl.run "your idea"`

**What happens**:
1. A unique IDEA-NNN identifier is generated
2. The idea description is recorded
3. The source is captured (Brainstorm, Customer Feedback, Team Idea, User Request)
4. The idea is added to `docs/product/_backlog/01_IDEAS.md`

**Output**: A new row in the Ideas Backlog table.

**Example Entry**:
```
| IDEA-001 | Add dark mode to dashboard | Brainstorm | 2026-01-29 | Scoring | 24 (I:9 C:9 E:6) |
```

---

## Stage 2: ICE Scoring

**Integrated with**: Stage 1 (scoring happens during capture)

**What happens**:
1. Each dimension (Impact, Confidence, Effort) is scored 1-10
2. Quick-assessment shortcuts: High (9), Medium (6), Low (3)
3. ICE Total = Impact + Confidence + Effort (range 3-30)
4. Priority tier assigned based on total score
5. Auto-defer gate: Score < 12 automatically defers the idea

**Score Tiers**:
- P0 (25-30): Critical — fast-track to development
- P1 (18-24): High — queue for next sprint
- P2 (12-17): Medium — consider when capacity allows
- Deferred (< 12): Auto-deferred — requires PM override

---

## Stage 3: PM Validation

**Command**: `/pdl.validate IDEA-NNN` or automatic in `/pdl.run`

**What happens**:
1. The product-manager agent reviews the idea
2. PM evaluates alignment with vision, scoring accuracy, and user value
3. **If Approved**: A user story is generated and added to the backlog
4. **If Rejected**: The idea status is updated to "Rejected"

**PM Override**: For auto-deferred ideas (score < 12), PM can approve with documented rationale.

**Example User Story**:
```
"As a Template Adopter, I want dark mode support for the dashboard,
so that I can reduce eye strain during extended sessions."
```

---

## Stage 4: Product Backlog

**File**: `docs/product/_backlog/02_USER_STORIES.md`

**What happens**:
1. Approved ideas become user stories in "As a [persona], I want [action], so that [benefit]" format
2. Stories are prioritized by ICE score tier
3. Status starts as "Ready for PRD"

**Status Flow**:
```
Ready for PRD → In PRD → In Development → Delivered
```

---

## Stage 5: Triad Handoff

**Command**: `/triad.prd <topic>`

**What happens**:
1. The PRD creation flow detects backlog items with "Ready for PRD" status
2. If a backlog item is selected, PRD frontmatter includes source traceability:
   ```yaml
   source:
     idea_id: IDEA-001
     story_id: US-001
   ```
3. The user story status updates from "Ready for PRD" to "In PRD"

This source traceability ensures every PRD can be traced back to the original idea and validated user story, creating an unbroken audit trail from discovery through delivery.

---

## Stages 6-10: Triad Workflow

Once the PRD is created, the standard Triad workflow takes over:

| Stage | Command | Output | Sign-offs |
|-------|---------|--------|-----------|
| 6 | `/triad.specify` | spec.md | PM |
| 7 | `/triad.plan` | plan.md | PM + Architect |
| 8 | `/triad.tasks` | tasks.md | PM + Architect + Team-Lead |
| 9 | `/triad.implement` | Code/Files | Architect checkpoints |
| 10 | `/triad.close-feature` | Docs updated | Final validation |

### Sign-off Details by Stage

| Stage | Phase | Sign-offs | What Gets Validated |
|-------|-------|-----------|---------------------|
| 6 | Specify | PM | Requirements alignment, user story coverage, scope boundaries |
| 7 | Plan | PM + Architect | Technical feasibility, architecture decisions, risk assessment |
| 8 | Tasks | PM + Architect + Team-Lead | Task completeness, agent assignments, parallel execution plan |
| 9 | Implement | Architect (checkpoints) | Code quality, architecture compliance at wave boundaries |
| 10 | Close | Auto | Documentation completeness, feature library update |

**Review Outcomes**:
- **APPROVED**: Proceed to next phase
- **CHANGES REQUESTED**: Revise and re-submit for review
- **BLOCKED**: Critical issue -- halt until resolved

### Artifact Examples

**spec.md** (Stage 6):
```
## Functional Requirements
### FR-1: Dark Mode Toggle
- System shall provide a toggle in the dashboard settings panel
- Acceptance: Theme switches within 200ms without page reload

## User Scenarios
### Scenario 1: Enable Dark Mode
Given the user is on the dashboard
When they toggle dark mode in settings
Then all UI elements switch to the dark color scheme
```

**plan.md** (Stage 7):
```
## Technical Approach
### Component: ThemeProvider
- Pattern: React Context with CSS custom properties
- Risk: Third-party component compatibility (Medium)

## Architecture Decisions
- ADR-001: CSS custom properties over CSS-in-JS for theme switching
```

**tasks.md** (Stage 8):
```
## Wave 1 (Parallel)
- [ ] T-001: Create ThemeProvider context (frontend-developer)
- [ ] T-002: Define dark color tokens (ux-ui-designer)

## Wave 2 (Depends on Wave 1)
- [ ] T-003: Update dashboard components (frontend-developer)
```

---

## Commands by Stage

| Stage | PDL Command | Triad Command | Output |
|-------|-------------|---------------|--------|
| 1. Idea Capture | `/pdl.idea <idea>` | -- | 01_IDEAS.md entry |
| 2. ICE Scoring | (integrated) | -- | ICE score in IDEAS.md |
| 3. PM Validation | `/pdl.validate IDEA-NNN` | -- | User story in 02_USER_STORIES.md |
| 4. Product Backlog | (automatic) | -- | Status: Ready for PRD |
| 5. Triad Handoff | -- | `/triad.prd <topic>` | PRD with source traceability |
| 6. Specify | -- | `/triad.specify` | spec.md |
| 7. Plan | -- | `/triad.plan` | plan.md |
| 8. Tasks | -- | `/triad.tasks` | tasks.md + agent-assignments.md |
| 9. Implement | -- | `/triad.implement` | Code/Files |
| 10. Close | -- | `/triad.close-feature NNN` | Documentation updates |

**Full flow shortcut**: `/pdl.run <idea>` covers stages 1-4 in one command.

---

## Traceability Model

The complete traceability chain from idea to delivery:

```
IDEA-001 (01_IDEAS.md)
  └── US-001 (02_USER_STORIES.md)
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

### Idea Status (01_IDEAS.md)

```
[Capture] → Scoring (>= 12) → Validated (PM approved)
                │
                └→ Deferred (< 12) → Scoring (re-scored >= 12) → Validated
                │                                                    │
                └→ Rejected (PM rejected) → Scoring (re-scored) ────┘
```

### User Story Status (02_USER_STORIES.md)

```
Ready for PRD → In PRD → In Development → Delivered
```

---

## End-to-End Example

### Step 1: Capture and Score

```bash
/pdl.run "Add dark mode support for the dashboard"
```

- **IDEA-001** created
- ICE Score: 24 (I:9 C:9 E:6) — P1 (High)
- Source: User Request

### Step 2: PM Validation (automatic in /pdl.run)

- PM agent reviews: APPROVED
- Rationale: "High user demand, proven pattern, moderate effort"

### Step 3: User Story Generated

- **US-001**: "As a Template Adopter, I want dark mode support for the dashboard, so that I can reduce eye strain during extended sessions."
- Priority: 2 (P1)
- Status: Ready for PRD

### Step 4: Triad Handoff

```bash
/triad.prd dark-mode-support
```

- PRD created with `source.idea_id: IDEA-001` and `source.story_id: US-001`
- US-001 status updated to "In PRD"

### Step 5: Triad Workflow

```bash
/triad.specify
/triad.plan
/triad.tasks
/triad.implement
/triad.close-feature 005
```

Feature delivered with full traceability from original idea to shipped code.

---

## Summary

| Stage | Artifact | Purpose | Owner |
|-------|----------|---------|-------|
| 1 | 01_IDEAS.md | Raw concept + ICE score | PM |
| 2 | (integrated) | ICE scoring during capture | PM |
| 3 | 02_USER_STORIES.md | PM-validated user story | PM |
| 4 | 02_USER_STORIES.md | Prioritized product backlog | PM |
| 5 | PRD | Business context, scope, metrics | PM + Architect + Team-Lead |
| 6 | spec.md | Functional requirements | PM |
| 7 | plan.md | Technical architecture | PM + Architect |
| 8 | tasks.md | Work breakdown + agent assignments | PM + Architect + Team-Lead |
| 9 | Code | Implementation | Agents |
| 10 | Feature Library | Production record | Auto |
