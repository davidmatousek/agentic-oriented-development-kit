# CLAUDE.md - Agentic Oriented Development Kit

<!-- Context Budget: Target <80 lines -->

## Core Constraints
- **Product-Led**: Start with product vision, PRDs, and user stories
- **Source of Truth**: `.aod/spec.md`
- **Validation Required**: Run `/triad.analyze` before PRs
- **Local-First**: Always supports local `.aod/` file workflows

## Git Workflow
**Always use feature branches**: `git checkout -b NNN-feature-name`
- Never commit to main directly
- Create PR for review before merge
- Branch format: `NNN-descriptive-name` (e.g., `001-initial-feature`)

## Project Structure
```
agentic-oriented-development-kit/
├── .claude/           → Agents, skills, commands
├── .aod/              → spec.md, plan.md, tasks.md (source of truth)
├── docs/              → Product, architecture, devops docs
├── scripts/           → init.sh, check.sh
└── CLAUDE.md          → AI agent context
```

**Note**: Template provides methodology only. Users bring their own code.

## Context Discovery
- **Thinking Lenses**: `docs/core_principles/README.md` (5 Whys, Pre-Mortem, etc.)
- **Project Standards**: `docs/standards/README.md` (DoD, naming, git)
- **Product Docs**: `docs/product/README.md`
- **Architecture**: `docs/architecture/README.md`
- **Triad Guide**: `docs/AOD_TRIAD.md`
- **Constitution**: `.aod/memory/constitution.md`

## Commands
**PDL workflow** (optional, before Triad):
- `/pdl.run` → `/pdl.idea` → `/pdl.score` → `/pdl.validate`

**Triad workflow**:
- `/triad.prd` → `/triad.specify` → `/triad.plan` → `/triad.tasks` → `/triad.implement`

**Supporting commands**:
- `/triad.clarify` — Resolve spec ambiguities
- `/triad.analyze` — Cross-artifact consistency check
- `/triad.checklist` — Generate quality checklist
- `/triad.constitution` — Manage governance principles
- `/triad.close-feature` — Close completed feature

## SDLC Triad Governance
| Role | Defines | Authority |
|------|---------|-----------|
| PM | What & Why | Scope & requirements |
| Architect | How | Technical decisions |
| Team-Lead | When & Who | Timeline & resources |

**Sign-off Requirements**:
- `spec.md`: PM sign-off
- `plan.md`: PM + Architect sign-off
- `tasks.md`: PM + Architect + Team-Lead sign-off

## Deployment Policy
All deployments must go through the devops agent. Never deploy without verification.

## Key Principles
- **Vision First**: `/triad.prd` (includes vision) → spec → plan → tasks
- **Triple Sign-off**: PM + Architect + Team-Lead approval on tasks.md
- **Definition of Done**: 3-step validation before marking complete

## Context Boundaries
**EXCLUDE**: `archive/`, `node_modules/`, `.git/`, `*.log`
**FOCUS**: `.aod/`, `docs/`, `.claude/`, current feature branch

## Tips
- Use `make review-spec` or `make review-plan` for manual governance checks
- Search `docs/core_principles/` for thinking methodologies
- Review `agent-assignments.md` for workload distribution

## Recent Changes
- **v2.0.0**: Anthropic Claude Code v2.1.16 Integration
  - Parallel Triad reviews, context forking, version detection
  - See `docs/devops/MIGRATION.md` for upgrade guide
- **v1.1.0**: Modular rules system
