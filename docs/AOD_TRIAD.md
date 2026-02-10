# AOD Triad Governance - Quick Reference Guide

**Version**: 3.0.0 (AOD Lifecycle Formalization)
**Status**: Template

---

## What is the AOD Triad?

**The AOD Triad** is the governance layer of the AOD Lifecycle, ensuring Product-Architecture-Engineering alignment at every stage boundary. While the AOD Lifecycle defines five stages (Discover, Define, Plan, Build, Deliver), the Triad provides the approval gates that control progression between them.

**The Three Roles**:
1. **PM (product-manager)**: Defines **What** & **Why** (user value, business goals)
2. **Architect**: Defines **How** (technical approach, infrastructure baseline)
3. **Tech-Lead (team-lead)**: Defines **When** & **Who** (timeline, agent assignments)

**Purpose**: Govern stage transitions through structured review and validation gates, preventing misalignment between product intent and technical execution

---

## Lifecycle Context

The **AOD Lifecycle** defines 5 stages that every feature progresses through:

```
Discover → Define → Plan → Build → Deliver
```

The **Triad** operates as a governance layer at stage boundaries (gates), not as stages themselves:

```
  Discover    │ G1 │    Define     │ G2 │     Plan      │ G3 │    Build     │ G4 │   Deliver
              │    │               │    │               │    │              │    │
  Ideas,      │gate│  PRD,        │gate│  spec.md,     │gate│  Execute    │gate│  Close,
  scoring     │    │  research    │    │  plan.md,     │    │  tasks,     │    │  verify,
              │    │               │    │  tasks.md     │    │  review     │    │  document
```

**Governance Tiers** (configurable per project):

| Tier | Gates | Best For |
|------|-------|----------|
| **Light** | G2 (spec sign-off) + G3 (tasks sign-off) | Small features, quick iterations |
| **Standard** | G1 + G2 + G3 + G4 (6 checkpoints) | Most production features |
| **Full** | All gates with extended reviews | Critical infrastructure, security changes |

See `docs/guides/AOD_LIFECYCLE.md` for the full lifecycle reference.

---

## Complete Lifecycle with Triad Governance (Simple)

```
 DISCOVER        │ DEFINE          │         PLAN                          │ BUILD           │ DELIVER
                 │                 │                                       │                 │
┌──────────────┐ │ ┌──────────────┐ │ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │ ┌──────────────┐
│              │ │ │              │ │ │              │ │              │ │              │ │ │              │
│  /aod.define │ │ │  /aod.spec   │ │ │/aod.project- │ │  /aod.tasks  │ │  /aod.build  │ │ │  /aod.close  │
│  (PRD)       │ │ │  (spec.md)   │ │ │ plan         │ │  (tasks.md)  │ │  (execute)   │ │ │  (deliver)   │
│              │ │ │              │ │ │  (plan.md)   │ │              │ │              │ │ │              │
└──────────────┘ │ └──────────────┘ │ └──────────────┘ └──────────────┘ └──────────────┘ │ └──────────────┘
      ↓          │       ↓          │       ↓                ↓                ↓          │       ↓
 PM + Arch +    G1   Research +    G2   PM + Arch       PM + Arch +     Arch checkpts   G4   Verify +
 Tech-Lead           PM sign-off        sign-off        Tech-Lead       during exec          document
 validation                                             sign-off (G3)

Creates PRD          Research →        Creates plan.md  Creates tasks    Executes tasks      Close feature
with Triad           Creates spec.md   with architecture with breakdown  with reviews        with docs
```

**Governance gates (G1-G4) auto-validate before stage transitions** ✅

---

## Quick Start

### Creating a PRD with Triad Governance

```bash
/aod.define <topic>
```

**Auto-detects workflow type**:
- Infrastructure keywords (deploy, infrastructure, provision) → Sequential Triad
- Feature keywords (UI, component, API, feature) → Parallel Triad

**What happens automatically**:
1. PM drafts PRD (via `/aod.define`)
2. Architect creates baseline (if infrastructure) or reviews (if feature)
3. Tech-Lead performs feasibility check with timeline estimate
4. Architect performs technical review
5. PM finalizes with all Triad approvals

**Time**: 2-4 hours for infrastructure PRD, 1-2 hours for feature PRD

---

## Two Workflows

### Sequential Triad (Infrastructure PRDs)

**Use when**: Topic contains "deploy", "infrastructure", "provision", "environment"

**Workflow**:
```
Phase 0: Architect Baseline (30 min)
  ↓ [baseline report handed to PM]
Phase 1: PM Drafts PRD (45 min)
  ↓ [draft PRD handed to Tech-Lead]
Phase 2: Tech-Lead Feasibility (30 min)
  ↓ [timeline estimate handed to PM]
Phase 3: PM Incorporates Timeline (10 min)
  ↓ [updated PRD handed to Architect]
Phase 4: Architect Review (30 min)
  ↓ [APPROVED verdict handed to PM]
Phase 5: PM Finalizes (5 min)
```

**Total**: ~2-4 hours typical

**Target Metrics**:
- Technical inaccuracies: <3 per PRD
- Architect review: <30 min for standard PRDs
- Timeline accuracy: Within 20% of actual
- Infrastructure accuracy: >95%

### Parallel Triad (Feature PRDs)

**Use when**: No infrastructure keywords detected

**Workflow**:
```
Phase 1: PM Drafts PRD (45 min)
  ↓ [draft PRD handed to both agents]
Phase 2a: Tech-Lead Feasibility ─┐
Phase 2b: Architect Review       ├─ [Both run in parallel, 30 min]
  ↓                              ─┘
Phase 3: PM Incorporates Feedback (15 min)
  ↓
Phase 4: PM Finalizes (5 min)
```

**Total**: ~1-2 hours typical

---

## Artifacts Created

### For Infrastructure PRDs

```
specs/{NNN}-{topic}/
├── architect-baseline.md       # Phase 0: Infrastructure status
├── feasibility-check.md        # Phase 2: Timeline & agent assignments
└── [created during spec phase]

docs/product/02_PRD/
└── {NNN}-{topic}-{date}.md     # Phase 1: PRD (approved)

docs/agents/architect/
└── {date}_{NNN}_prd-review_ARCH.md  # Phase 4: Technical review
```

### For Feature PRDs

```
specs/{NNN}-{topic}/
└── feasibility-check.md        # Phase 2a: Timeline & assignments

docs/product/02_PRD/
└── {NNN}-{topic}-{date}.md     # Phase 1: PRD (approved)

docs/agents/architect/
└── {date}_{NNN}_prd-review_ARCH.md  # Phase 2b: Technical review
```

---

## Success Criteria

**Per Constitution v1.4.0, all PRDs should achieve**:

| Metric | Target | Description |
|--------|--------|-------------|
| Technical inaccuracies | <3 | Factual errors in PRD technical claims |
| Architect review time | <30 min | Time for technical validation |
| Infrastructure accuracy | >95% | Accuracy of infrastructure status claims |
| Timeline accuracy | Within 20% | Estimated vs actual delivery time |
| Triad cycle time | <4 hours | Total time for full Triad review |

---

## Research Phase (Before Specification)

`/aod.spec` includes a **mandatory research phase** before generating the specification. This ensures specs are grounded in reality rather than assumptions.

### What Gets Researched (in parallel)

| Source | What to Find | Why It Matters |
|--------|--------------|----------------|
| **Knowledge Base** | Similar patterns, lessons learned, past bug fixes | Avoid repeating mistakes |
| **Codebase** | Existing implementations, naming conventions, utilities | Follow established patterns |
| **Architecture** | Relevant docs, constraints, dependencies | Respect technical boundaries |
| **Web Research** | Industry best practices, common patterns | Learn from broader ecosystem |

### Output

Creates `specs/{NNN}-*/research.md` with:
- KB findings and relevant lessons
- Similar features in codebase (with file paths)
- Architecture constraints and dependencies
- Industry best practices and references
- Recommendations for the spec

**This research informs spec creation** - the spec author uses these findings to write a more accurate, realistic specification.

---

## Triple Sign-Off Requirements

**After `/aod.define` completes, you must have**:

### For PRDs
- ✅ **Architect baseline** (if infrastructure) or **Architect review** (if feature)
- ✅ **Tech-Lead feasibility** with timeline estimate
- ✅ **Architect technical review** with APPROVED verdict
- ✅ **PM approval** (marks PRD as "Approved")

### For Spec.md (after `/aod.spec`)
- ✅ **Research phase completed**: KB, codebase, architecture, web research
- ✅ **research.md created**: Findings documented
- ✅ **PM sign-off**: Product alignment validated
- ✅ **PM approval**: Spec ready for planning

### For Plan.md (after `/aod.project-plan`)
- ✅ **PM sign-off**: Feasibility validated
- ✅ **Architect sign-off**: Architecture decisions validated
- ✅ **PM approval**: Plan ready for tasks

### For Tasks.md (after `/aod.tasks`)
- ✅ **PM sign-off**: Prioritization validated
- ✅ **Architect sign-off**: Technical approach validated
- ✅ **Team-Lead sign-off**: Agent assignments and parallel execution optimized
- ✅ **PM approval**: Tasks ready for implementation

**Constitution Requirement**: All three sign-offs MUST be present before proceeding to next phase

---

## AOD Lifecycle Commands (with Triad Governance)

### Automatic Governance (Recommended)

**Complete Production Workflow** (ALL `/aod.*`):
```bash
/aod.define <topic>        # Define stage: Create PRD with auto-Triad validation
/aod.spec                  # Plan stage: Create spec.md with auto PM sign-off
/aod.project-plan          # Plan stage: Create plan.md with auto PM + Architect sign-off
/aod.tasks                 # Plan stage: Create tasks.md with auto PM + Architect + Team-Lead sign-off
/aod.build                 # Build stage: Execute with auto architect checkpoints
```

**Benefits of `/aod.*` Commands**:
- ✅ Lifecycle stages with built-in governance gates
- ✅ Automatic agent sign-off validation (no manual invocation)
- ✅ Frontmatter auto-updated with verdicts
- ✅ Blocking on CHANGES_REQUESTED (prevents proceeding with issues)
- ✅ Constitution compliance enforced automatically
- ✅ Configurable governance tiers (Light, Standard, Full)

---

## Validation

### Check Triad Artifacts Exist
```bash
# Check if PRD has all Triad artifacts
ls docs/agents/architect/*{NNN}*prd-review*   # Architect review

# Verify PRD status
cat docs/product/02_PRD/INDEX.md | grep {NNN}
```

### Run Cross-Artifact Analysis
```bash
/aod.analyze  # Validates PRD-spec-plan-tasks alignment + Triad completeness
```

---

## Troubleshooting

### "PRD has inaccuracies"
- **Cause**: PM didn't read architect baseline before drafting
- **Fix**: Re-run `/aod.define` which will auto-invoke baseline first

### "Timeline estimate unrealistic"
- **Cause**: Tech-Lead didn't account for dependencies
- **Fix**: Re-run `/aod.tasks` after clarifying scope

### "Architect blocked PRD"
- **Cause**: Technical infeasibility or inaccuracies ≥3
- **Fix**: Address architect's corrections in PRD, re-submit for review

### "Triad cycle too slow (>4 hours)"
- **Cause**: Rework loops from inaccuracies or missing baseline
- **Prevention**: Always run `/aod.define` (auto-Triad governance) instead of manual PM draft

---

## Examples

### Example 1: Infrastructure PRD
```bash
# User request: "Create PRD for production deployment setup"
/aod.define production-deployment-setup

# Auto-detects "production" + "deployment" → Infrastructure PRD
# Runs Sequential Triad:
# - Architect reads current infrastructure docs, creates baseline
# - PM drafts PRD with baseline facts
# - Tech-Lead estimates timeline
# - Architect reviews, validates accuracy
# - PM finalizes PRD

# Result: PRD approved with 0-3 inaccuracies
```

### Example 2: Feature PRD
```bash
# User request: "Create PRD for user dashboard feature"
/aod.define user-dashboard-feature

# Auto-detects "feature" (no infrastructure keywords) → Feature PRD
# Runs Parallel Triad:
# - PM drafts PRD
# - Tech-Lead + Architect review in parallel (saves 30 min)
# - PM incorporates feedback
# - PM finalizes PRD

# Result: PRD approved in 1-2 hours
```

---

## Best Practices

### DO ✅
- Use `/aod.define` for automatic Triad governance (recommended)
- Create architect baseline BEFORE PM drafts (infrastructure PRDs)
- Use Tech-Lead timeline estimate (not PM guess)
- Cross-check all infrastructure claims against baseline
- Block PRD finalization if Architect verdict is CHANGES REQUESTED

### DON'T ❌
- Skip architect baseline for infrastructure PRDs (causes inaccuracies)
- Let PM guess timeline (causes errors)
- Approve PRD with ≥3 technical inaccuracies
- Rush Triad phases (quality > speed)
- Ignore Architect BLOCKED verdict

---

## Related Documentation

**Constitutional Authority**:
- [Constitution, Principle XI](.aod/memory/constitution.md) - AOD Triad Governance

**Detailed Guides**:
- [TRIAD_COLLABORATION.md](standards/TRIAD_COLLABORATION.md) - Comprehensive guide
- [PRODUCT_SPEC_ALIGNMENT.md](standards/PRODUCT_SPEC_ALIGNMENT.md) - Dual sign-off requirements

**Agent Documentation**:
- [product-manager agent](.claude/agents/product-manager.md) - PM responsibilities
- [architect agent](.claude/agents/architect.md) - Baseline + review responsibilities
- [team-lead agent](.claude/agents/team-lead.md) - Feasibility + execution

**Command Reference**:
- [/aod.define](.claude/commands/aod.define.md) - Define stage: PRD creation with Triad governance
- [/aod.spec](.claude/commands/aod.spec.md) - Plan stage: Spec creation with auto PM sign-off
- [/aod.project-plan](.claude/commands/aod.project-plan.md) - Plan stage: Plan creation with auto dual sign-off
- [/aod.tasks](.claude/commands/aod.tasks.md) - Plan stage: Task creation with auto triple sign-off
- [/aod.build](.claude/commands/aod.build.md) - Build stage: Implementation with auto checkpoints

**Lifecycle Reference**:
- [AOD_LIFECYCLE.md](guides/AOD_LIFECYCLE.md) - Full lifecycle stage reference

---

**Last Updated**: 2026-02-09
**Maintained By**: Team Lead (workflow orchestration)
**Review Trigger**: After every 5 PRDs or major process change
