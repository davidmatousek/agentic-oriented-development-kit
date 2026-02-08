# Changelog

All notable changes to the Agentic Oriented Development Kit (AOD Kit) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-08

### Added

- **AOD Triad governance framework** with PM, Architect, and Team-Lead roles
- **Triad workflow commands**: `/triad.prd`, `/triad.specify`, `/triad.plan`, `/triad.tasks`, `/triad.implement`
- **Utility commands**: `/triad.clarify`, `/triad.analyze`, `/triad.checklist`, `/triad.constitution`, `/triad.close-feature`
- **Optional PDL discovery commands**: `/pdl.run`, `/pdl.idea`, `/pdl.score`, `/pdl.validate`
- **Agent definitions** for product-manager, architect, team-lead, and specialist roles
- **Reusable agent skills** for governance automation
- **Modular rules system** (`.claude/rules/`) for governance, git workflow, context loading, and deployment
- **Thinking lenses** (5 Whys, Pre-Mortem, First Principles, Systems Thinking, Constraint Analysis)
- **`.aod/` directory structure** with spec.md, plan.md, tasks.md as source of truth
- **Constitution and institutional knowledge** for governance memory
- **Document templates** for specs, plans, PRDs, and reviews
- **Setup and validation scripts** (`make init`, `make check`)
- **Example feature** (`specs/000-example-feature/`) demonstrating spec/plan/tasks format
- **Solo developer quick start** with guidance on wearing all three Triad hats
- **Multi-agent compatibility** documentation for Cursor, Copilot, and Windsurf
- **Community infrastructure**: CONTRIBUTING.md, CODE_OF_CONDUCT.md, issue templates
- **Article series mapping** linking 8 governance chapters to template files
