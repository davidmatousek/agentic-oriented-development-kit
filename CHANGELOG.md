# Changelog

All notable changes to Agentic Oriented Development Kit (formerly Product-Led Spec Kit) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [5.0.0] - 2026-02-09

### BREAKING CHANGES

#### Unified `/aod.*` Command Namespace (Feature 010)

All lifecycle commands unified under `/aod.*` namespace. The dual namespace (`/pdl.*` + `/triad.*`) has been replaced with a single, consistent command set aligned with the 5-stage AOD lifecycle: Discover → Define → Plan → Build → Deliver.

**Command Namespace Migration:**

| Former Command | New Command | Stage | Notes |
|----------------|-------------|-------|-------|
| `/pdl.idea` | `/aod.discover` | Discover | Unified capture + score + validate |
| `/pdl.run` | `/aod.discover` | Discover | Full discovery flow |
| `/pdl.score` | `/aod.score` | Discover | Re-score existing idea |
| `/pdl.validate` | *(removed)* | — | Integrated into `/aod.discover` |
| `/triad.prd` | `/aod.define` | Define | Create PRD with Triad sign-off |
| `/triad.specify` | `/aod.spec` | Plan | Create spec.md with PM sign-off |
| `/triad.plan` | `/aod.project-plan` | Plan | Create plan.md with PM+Architect sign-off |
| `/triad.tasks` | `/aod.tasks` | Plan | Create tasks.md with triple sign-off |
| `/triad.implement` | `/aod.build` | Build | Execute with Architect checkpoints |
| `/triad.close-feature` | `/aod.deliver` | Deliver | Close feature with retrospective |
| `/triad.clarify` | `/aod.clarify` | — | Resolve spec ambiguities |
| `/triad.analyze` | `/aod.analyze` | — | Cross-artifact consistency check |
| `/triad.checklist` | `/aod.checklist` | — | Quality checklist |
| `/triad.constitution` | `/aod.constitution` | — | Governance principles |

**New Commands:**
- `/aod.plan` — Intelligent router that auto-detects which Plan sub-step (spec → project-plan → tasks) comes next
- `/aod.status` — Backlog snapshot and lifecycle stage summary

**Migration**: Replace all `/pdl.*` and `/triad.*` commands with their `/aod.*` equivalents. See `docs/guides/AOD_MIGRATION.md` for detailed instructions.

### Added — AOD Lifecycle Formalization (Feature 010)

**Lifecycle Tracking:**
- GitHub Issues track feature lifecycle stage via `stage:*` labels
- `BACKLOG.md` auto-regenerated from GitHub Issues grouped by lifecycle stage
- All `/aod.*` commands auto-update Issue labels on stage transitions
- New scripts: `github-lifecycle.sh`, `backlog-regenerate.sh`, `migrate-backlog.sh`

**Governance Tiers:**
- **Light** (2 gates): Prototype/exploration mode
- **Standard** (6 gates, default): Production features
- **Full** (all gates): Regulated environments

**Documentation:**
- `docs/guides/AOD_LIFECYCLE.md` — Full lifecycle documentation
- `docs/guides/AOD_LIFECYCLE_GUIDE.md` — Practical usage guide
- `docs/guides/AOD_QUICKSTART.md` — Quick start for new adopters
- `docs/guides/AOD_MIGRATION.md` — Migration guide from old namespaces
- `docs/guides/AOD_INFOGRAPHIC.md` — Visual lifecycle diagram

**Skill Consolidation:**
- 9 old skills (`pdl-*`, `prd-create`, `spec-validator`, `architecture-validator`, `implementation-checkpoint`, `thinking-lens`) replaced by 10 unified `aod-*` skills
- Skills are now self-contained with no cross-skill Skill tool coupling

### Added — GitHub Projects Lifecycle Board (Feature 011)

Visual kanban board integration via GitHub Projects (v2) with 5 columns matching AOD lifecycle stages.

**Board Functions:**
- `aod_gh_setup_board` — One-time board creation with 5 Status columns
- `aod_gh_add_to_board` — Auto-add issues to board on creation
- `aod_gh_move_on_board` — Auto-move issues between columns on stage transitions
- `aod_gh_check_board` — Board availability check with session-scoped caching

**Integration:**
- `/aod.discover` auto-adds issue to "Discover" column
- `/aod.define`, `/aod.spec`, `/aod.build`, `/aod.deliver` auto-move issues to matching columns
- 7-level graceful degradation — board failures never block core workflow

**Prerequisites:**
- GitHub CLI (`gh`) v2.40+
- OAuth scope: `project` (add via `gh auth refresh -s project`)

### Removed
- All 14 `/pdl.*` and `/triad.*` command files
- 9 old skill directories (`pdl-*`, `prd-create`, `spec-validator`, etc.)
- 3 old guide files (`PDL_TRIAD_INFOGRAPHIC.md`, `PDL_TRIAD_LIFECYCLE.md`, `PDL_TRIAD_QUICKSTART.md`)

---

## [4.0.0] - 2026-02-08

### BREAKING CHANGES

#### AOD Rebranding — Renamed .specify/ to .aod/ and Replaced All Spec Kit Branding

The project has been rebranded from "Product-Led Spec Kit" to "Agentic Oriented Development Kit" (AOD Kit). This is a comprehensive rename affecting directory structure, branding text, and file names across the repository.

**Structural Changes:**
- `.specify/` directory renamed to `.aod/` (git history preserved via `git mv`)
- `docs/SPEC_KIT_TRIAD.md` renamed to `docs/AOD_TRIAD.md`
- Environment variables: `SPECIFY_FEATURE` → `AOD_FEATURE`, `SPECIFY_DIR` → `AOD_DIR`
- Log prefixes: `[specify]` → `[aod]`

**Branding Replacements:**
- `Product-Led Spec Kit` → `Agentic Oriented Development Kit`
- `SPEC_KIT` → `AOD` (constant-case identifiers)
- `Spec Kit` → `AOD Kit` (user-facing text)
- `spec-kit` → `aod` (kebab-case identifiers)
- All `spec-kit-ops` upstream references removed from active files

**Preserved:**
- `/triad.specify` command name (unchanged — "specify" is a verb, not branding)
- Historical specs (001-007) and their artifacts
- Historical planning documents and prior CHANGELOG entries
- Private GitHub repository name (`product-led-spec-kit`)

**Migration**: Update any local scripts or documentation referencing `.specify/` paths to `.aod/`. Update any references to `docs/SPEC_KIT_TRIAD.md` to `docs/AOD_TRIAD.md`.

### Added - 3 New Thinking Lenses (Feature 009)

Added three new structured thinking lenses to `docs/core_principles/` and updated the thinking-lens skill:

- **Four Causes** (`four_causes.md`) - Aristotelian causal analysis examining Material, Formal, Efficient, and Final causes to understand why something exists or happens
- **Cargo Cult Detection** (`cargo_cult_detection.md`) - Identifies practices copied without understanding, helping teams distinguish genuine best practices from superficial mimicry
- **Golden Mean** (`golden_mean.md`) - Aristotelian balance-finding framework for navigating engineering trade-offs between extremes

**Details:**
- Content-only addition (no code, API, or infrastructure changes)
- Updated `docs/core_principles/README.md` lens registry with all three lenses
- Updated `.claude/skills/thinking-lens/SKILL.md` to reference new lenses
- PR: [#8](https://github.com/davidmatousek/product-led-spec-kit/pull/8)
- Tasks completed: 26/26

---

## [3.0.0] - 2026-02-07

### BREAKING CHANGES

#### SpecKit Commands Removed — Unified Triad Workflow

All `/speckit.*` commands have been removed and consolidated into the `/triad.*` command set. The dual command architecture (Triad + Vanilla) has been replaced with a single, unified workflow.

**Command Mapping:**

| Former Command | New Command | Notes |
|----------------|-------------|-------|
| `/speckit.specify` | `/triad.specify` | Logic inlined with research + PM sign-off |
| `/speckit.plan` | `/triad.plan` | Logic inlined with PM + Architect sign-off |
| `/speckit.tasks` | `/triad.tasks` | Logic inlined with triple sign-off |
| `/speckit.implement` | `/triad.implement` | Logic inlined with Architect checkpoints |
| `/speckit.clarify` | `/triad.clarify` | Direct transfer with reference updates |
| `/speckit.analyze` | `/triad.analyze` | Direct transfer with reference updates |
| `/speckit.checklist` | `/triad.checklist` | Direct transfer with reference updates |
| `/speckit.constitution` | `/triad.constitution` | Direct transfer with reference updates |

**Migration**: Replace all `/speckit.*` commands with their `/triad.*` equivalents. No other changes needed.

### Added
- 4 new triad commands: `/triad.clarify`, `/triad.analyze`, `/triad.checklist`, `/triad.constitution`
- Archive tag `v2.0.0-pre-speckit-removal` preserves historical state

### Removed
- All 8 `/speckit.*` command files
- "Vanilla Commands" sections from all documentation
- `compatible_with_speckit` and `last_tested_with_speckit` frontmatter from all command files

### Changed
- 4 core triad commands now self-contained (no Skill tool coupling to speckit commands)
- All documentation, rules, skills, and agents reference only `/triad.*` commands
- CLAUDE.md updated with unified command set (10 triad commands)
- Renamed `speckit-validator` skill to `spec-validator` (removes speckit branding)

---

## [2.1.0] - 2026-01-31

### Added - Agent Refactoring (Feature 003)

**Agent Best Practices Documentation**
- Created `_AGENT_BEST_PRACTICES.md` with 8 core principles for agent design
- Created `_README.md` agent directory overview and quick reference

**Agent Refactoring**
- Refactored all 12 agents to consistent 8-section structure (58% line reduction)
- Split team-lead into team-lead + orchestrator (13 agents total)
- Standardized YAML frontmatter across all agents (version, changelog, boundaries, triad-governance)

**New Skill**
- Added thinking-lens skill for structured analysis methodologies

**Key Metrics**
- Tasks completed: 140
- Total agent line reduction: 58% (7,885 → ~3,300 lines)
- All 12 agents now follow standardized 8-section structure
- 100% YAML frontmatter standardization

---

## [2.0.0] - 2026-01-24

### Added - Anthropic Claude Code v2.1.16 Integration

**Parallel Triad Reviews**
- PM + Architect reviews now run simultaneously with context forking
- Triple sign-off (PM + Architect + Team-Lead) executes in parallel for tasks.md
- Review results merge automatically using severity ranking (Critical > Warning > Suggestion)

**Version Detection & Feature Flags**
- Automatic Claude Code version detection at session start
- Feature flags system (`.claude/config/feature-flags.json`) for capability management
- Graceful degradation for older Claude Code versions (sequential fallback)

**New Libraries**
- `.claude/lib/version/detect.sh` - Version detection utilities
- `.claude/lib/version/feature-gate.sh` - Feature gating logic
- `.claude/lib/version/degradation.sh` - Graceful fallback handling
- `.claude/lib/triad/merge-results.sh` - Parallel review result merging
- `.claude/lib/triad/timing-metrics.sh` - Performance measurement
- `.claude/lib/dependencies/` - Task dependency resolution system

**New Skills**
- `.claude/skills/triad/pm-review.md` - PM review skill for parallel execution
- `.claude/skills/triad/architect-review.md` - Architect review skill
- `.claude/skills/triad/teamlead-review.md` - Team-Lead review skill

**Documentation**
- `docs/devops/FEATURE_MATRIX.md` - Feature compatibility by Claude Code version
- `docs/devops/MIGRATION.md` - DevOps migration guide
- PRD-002: Anthropic Updates Integration specification

**Test Fixtures**
- `specs/002-anthropic-updates-integration/test-fixtures/` - Comprehensive test suite
  - Version detection tests
  - Parallel execution tests
  - Context forking tests
  - Degradation tests
  - Dependency resolution tests

### Changed
- Triad commands now auto-detect version and use parallel execution when available
- `_triad-init.md` command initializes version detection at session start
- Review workflows use isolated contexts to prevent cross-contamination

### Migration
See [MIGRATION.md](MIGRATION.md) for detailed upgrade instructions from v1.x to v2.0.0.

---

## [1.1.0] - 2025-12-15

### Added - Modular Rules System

**Modular Governance Rules**
- `.claude/rules/governance.md` - Sign-off requirements, Triad workflow
- `.claude/rules/git-workflow.md` - Branch naming, PR policies
- `.claude/rules/deployment.md` - DevOps agent policy
- `.claude/rules/scope.md` - Project boundaries
- `.claude/rules/commands.md` - Triad + Vanilla command reference
- `.claude/rules/context-loading.md` - Context loading guide

**Documentation**
- `MIGRATION.md` - Guide for customizing modular rules

### Changed
- Refactored CLAUDE.md from 192 to 70 lines using @-references
- Instant context loading (<1 second vs 5-10 seconds with manual `cat` commands)
- Topic-specific editing without merge conflicts

---

## [1.0.0] - 2025-12-04

### Added - Initial Release

**Core Governance**
- Product-led governance template
- SDLC Triad collaboration framework (PM + Architect + Tech-Lead)
- Templatized constitution with `{{PLACEHOLDERS}}` for easy customization

**Agents**
- 13 specialized agents for different roles
- Product Manager, Architect, Team-Lead, and implementation agents

**Skills**
- 8 automation capabilities
- PRD creation, specification, planning, task generation, implementation

**Commands**
- Triad commands with governance (sign-offs required)
- Vanilla commands for fast prototyping (no governance)

**Documentation**
- Constitution template (`.specify/memory/constitution.md`)
- Product documentation structure (`docs/product/`)
- Architecture documentation (`docs/architecture/`)
- Core principles (`docs/core_principles/`)

---

## Version Comparison

| Feature | v1.0.0 | v1.1.0 | v2.0.0 | v2.1.0 | v3.0.0 | v4.0.0 | **v5.0.0** |
|---------|--------|--------|--------|--------|--------|--------|--------|
| Command Set | Triad + Vanilla | Triad + Vanilla | Triad + Vanilla | Triad + Vanilla | Triad only (10) | Triad only (10) | **AOD unified (16)** |
| Namespace | /speckit + /triad | /speckit + /triad | /speckit + /triad | /speckit + /triad | /triad + /pdl | /triad + /pdl | **/aod.*** |
| Triad Governance | Sequential | Sequential | Parallel | Parallel | Parallel | Parallel | Parallel |
| Governance Tiers | - | - | - | - | - | - | **Light/Standard/Full** |
| CLAUDE.md Size | 192 lines | 70 lines | 70 lines | 70 lines | ~80 lines | ~80 lines | ~80 lines |
| Context Loading | Manual | @-references | @-references | @-references | @-references | @-references | @-references |
| Version Detection | - | - | Automatic | Automatic | Automatic | Automatic | Automatic |
| Degradation | - | - | Graceful | Graceful | Graceful | Graceful | Graceful (7 levels) |
| Agent Count | 13 | 13 | 13 | 13 (refactored) | 13 | 13 | 13 |
| Skill Tool Coupling | - | - | 3 cross-calls | 3 cross-calls | 0 (self-contained) | 0 (self-contained) | 0 (self-contained) |
| Branding | Spec Kit | Spec Kit | Spec Kit | Spec Kit | Spec Kit | AOD Kit | AOD Kit |
| Thinking Lenses | 5 | 5 | 5 | 5 | 5 | 8 | 14 |
| Lifecycle Tracking | - | - | - | - | - | - | **GitHub Issues + Board** |

---

[5.0.0]: https://github.com/davidmatousek/agentic-oriented-development-kit/compare/v4.0.0...v5.0.0
[4.0.0]: https://github.com/davidmatousek/product-led-spec-kit/compare/v3.0.0...v4.0.0
[3.0.0]: https://github.com/davidmatousek/product-led-spec-kit/compare/v2.1.0...v3.0.0
[2.1.0]: https://github.com/davidmatousek/product-led-spec-kit/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/davidmatousek/product-led-spec-kit/compare/v1.1.0...v2.0.0
[1.1.0]: https://github.com/davidmatousek/product-led-spec-kit/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/davidmatousek/product-led-spec-kit/releases/tag/v1.0.0
