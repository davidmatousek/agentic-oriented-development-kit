# Article Series: Building with the AOD Triad

This document maps an 8-chapter article series to the template files that implement each concept. Use this as a guide for understanding the methodology or for writing about AOD Kit.

---

## Chapter 1: The Problem (Why Governance?)

**Theme**: Why AI agent-assisted development needs governance guardrails.

**Key Template Files**:
- `docs/AOD_TRIAD.md` -- The governance framework overview
- `CLAUDE.md` -- How governance rules are embedded into agent context

---

## Chapter 2: The SDLC Triad

**Theme**: The three-role governance model and how sign-offs work.

**Key Template Files**:
- `docs/AOD_TRIAD.md` -- Triad roles, workflows, sign-off requirements
- `.claude/agents/` -- PM, Architect, and Team-Lead agent definitions

---

## Chapter 3: Product-Led Thinking

**Theme**: Starting every feature from product value, not technical curiosity.

**Key Template Files**:
- `docs/product/` -- Product vision, PRDs, user stories
- `docs/guides/` -- Workflow guides for product-led development

---

## Chapter 4: Thinking Lenses

**Theme**: Structured analysis tools (5 Whys, Pre-Mortem, First Principles) for deeper decision-making.

**Key Template Files**:
- `docs/core_principles/` -- Thinking lens definitions and usage guides

---

## Chapter 5: Specification as Code

**Theme**: Treating specs, plans, and tasks as version-controlled source of truth.

**Key Template Files**:
- `.aod/` -- spec.md, plan.md, tasks.md structure
- `.claude/commands/triad.specify.md` -- The specify command workflow

---

## Chapter 6: Architecture Governance

**Theme**: How the Architect role ensures technical soundness at every phase.

**Key Template Files**:
- `docs/architecture/` -- System design, deployment environments, constraints
- `.claude/agents/architect.md` -- Architect agent responsibilities and review process

---

## Chapter 7: Implementation Waves

**Theme**: Parallel execution through wave-based task orchestration.

**Key Template Files**:
- `.claude/commands/triad.implement.md` -- Implementation workflow with checkpoints
- `.claude/commands/triad.tasks.md` -- Task breakdown with execution waves

---

## Chapter 8: Continuous Governance

**Theme**: Ongoing quality through standards, skills, and institutional knowledge.

**Key Template Files**:
- `docs/standards/` -- Definition of Done, naming conventions, collaboration standards
- `.claude/skills/` -- Reusable agent skills for governance automation
