# SDLC Triad - Quick Reference Guide

**Version**: 2.0.0 (Constitution v1.4.0 Principle XI)
**Status**: Template

---

## What is the SDLC Triad?

**The SDLC Triad** is a lightweight collaboration framework ensuring Product-Architecture-Engineering alignment for all PRDs and specs.

**The Three Roles**:
1. **PM (product-manager)**: Defines **What** & **Why** (user value, business goals)
2. **Architect**: Defines **How** (technical approach, infrastructure baseline)
3. **Tech-Lead (team-lead)**: Defines **When** & **Who** (timeline, agent assignments)

**Purpose**: Prevent PRD technical inaccuracies through structured review and validation gates

---

## Complete Triad Workflow (Simple)

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│              │     │              │     │              │     │              │     │              │
│ /triad.prd   │ --> │/triad.specify│ --> │ /triad.plan  │ --> │ /triad.tasks │ --> │/triad.       │
│              │     │              │     │              │     │              │     │ implement    │
│              │     │              │     │              │     │              │     │              │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
      ↓                    ↓                    ↓                    ↓                    ↓
 PM + Arch +           Research +          PM + Arch           PM + Arch +         Arch checkpoints
 Tech-Lead             PM sign-off         sign-off            Tech-Lead           during execution
 validation                                                    sign-off

Creates PRD         Research phase →     Creates plan.md     Creates tasks.md    Executes tasks
with Triad          Creates spec.md      with architecture   with breakdown      with reviews
```

**Each step auto-validates before proceeding** ✅

---

## Quick Start

### Creating a PRD with Triad

```bash
/triad.prd <topic>
```

**Auto-detects workflow type**:
- Infrastructure keywords (deploy, infrastructure, provision) → Sequential Triad
- Feature keywords (UI, component, API, feature) → Parallel Triad

**What happens automatically**:
1. PM drafts PRD (via `/triad.prd`)
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

`/triad.specify` includes a **mandatory research phase** before generating the specification. This ensures specs are grounded in reality rather than assumptions.

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

**After `/triad.prd` completes, you must have**:

### For PRDs
- ✅ **Architect baseline** (if infrastructure) or **Architect review** (if feature)
- ✅ **Tech-Lead feasibility** with timeline estimate
- ✅ **Architect technical review** with APPROVED verdict
- ✅ **PM approval** (marks PRD as "Approved")

### For Spec.md (after `/triad.specify`)
- ✅ **Research phase completed**: KB, codebase, architecture, web research
- ✅ **research.md created**: Findings documented
- ✅ **PM sign-off**: Product alignment validated
- ✅ **PM approval**: Spec ready for planning

### For Plan.md (after `/triad.plan`)
- ✅ **PM sign-off**: Feasibility validated
- ✅ **Architect sign-off**: Architecture decisions validated
- ✅ **PM approval**: Plan ready for tasks

### For Tasks.md (after `/triad.tasks`)
- ✅ **PM sign-off**: Prioritization validated
- ✅ **Architect sign-off**: Technical approach validated
- ✅ **Team-Lead sign-off**: Agent assignments and parallel execution optimized
- ✅ **PM approval**: Tasks ready for implementation

**Constitution Requirement**: All three sign-offs MUST be present before proceeding to next phase

---

## Triad Commands

### Automatic Triad (Recommended)

**Complete Production Workflow** (ALL `/triad.*`):
```bash
/triad.prd <topic>         # Create PRD with auto-Triad validation
/triad.specify             # Create spec.md with auto PM sign-off
/triad.plan                # Create plan.md with auto PM + Architect sign-off
/triad.tasks               # Create tasks.md with auto PM + Architect + Team-Lead sign-off
/triad.implement           # Execute with auto architect checkpoints
```

**Benefits of `/triad.*` Commands**:
- ✅ Automatic agent sign-off validation (no manual invocation)
- ✅ Frontmatter auto-updated with verdicts
- ✅ Blocking on CHANGES_REQUESTED (prevents proceeding with issues)
- ✅ Constitution compliance enforced automatically
- ✅ Upgrade-safe wrapper architecture (open source commands stay pristine)

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
/triad.analyze  # Validates PRD-spec-plan-tasks alignment + Triad completeness
```

---

## Troubleshooting

### "PRD has inaccuracies"
- **Cause**: PM didn't read architect baseline before drafting
- **Fix**: Re-run `/triad.prd` which will auto-invoke baseline first

### "Timeline estimate unrealistic"
- **Cause**: Tech-Lead didn't account for dependencies
- **Fix**: Re-run `/triad.tasks` after clarifying scope

### "Architect blocked PRD"
- **Cause**: Technical infeasibility or inaccuracies ≥3
- **Fix**: Address architect's corrections in PRD, re-submit for review

### "Triad cycle too slow (>4 hours)"
- **Cause**: Rework loops from inaccuracies or missing baseline
- **Prevention**: Always run `/triad.prd` (auto-Triad) instead of manual PM draft

---

## Examples

### Example 1: Infrastructure PRD
```bash
# User request: "Create PRD for production deployment setup"
/triad.prd production-deployment-setup

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
/triad.prd user-dashboard-feature

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
- Use `/triad.prd` for automatic Triad workflow (recommended)
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
- [Constitution, Principle XI](.aod/memory/constitution.md) - SDLC Triad Collaboration

**Detailed Guides**:
- [TRIAD_COLLABORATION.md](standards/TRIAD_COLLABORATION.md) - Comprehensive guide
- [PRODUCT_SPEC_ALIGNMENT.md](standards/PRODUCT_SPEC_ALIGNMENT.md) - Dual sign-off requirements

**Agent Documentation**:
- [product-manager agent](.claude/agents/product-manager.md) - PM responsibilities
- [architect agent](.claude/agents/architect.md) - Baseline + review responsibilities
- [team-lead agent](.claude/agents/team-lead.md) - Feasibility + execution

**Command Reference**:
- [/triad.prd](.claude/commands/triad.prd.md) - Auto-Triad PRD creation
- [/triad.specify](.claude/commands/triad.specify.md) - Spec creation with auto PM sign-off
- [/triad.plan](.claude/commands/triad.plan.md) - Plan creation with auto dual sign-off
- [/triad.tasks](.claude/commands/triad.tasks.md) - Task creation with auto triple sign-off
- [/triad.implement](.claude/commands/triad.implement.md) - Implementation with auto checkpoints

---

**Last Updated**: 2026-01-31
**Maintained By**: Team Lead (workflow orchestration)
**Review Trigger**: After every 5 PRDs or major process change
