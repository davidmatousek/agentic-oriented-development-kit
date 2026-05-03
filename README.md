<!--
  Aesthetic Philosophy (T006, Feature 169):
  - Visual mood: professional, technical, opinionated — matches AOD's governance-first positioning
  - Typeface: GitHub-rendered markdown (no custom fonts on landing page); badges use shields.io defaults
  - Color temperature: cool/neutral — governance + methodology, not playful or warm-corporate
  - Visual density: medium-balanced — enough detail to convey depth, no wall-of-text
-->

<div align="center">

# AOD Kit

**A governance-first development template with SDLC Triad collaboration for AI-assisted development**

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](CHANGELOG.md)
[![Claude Code](https://img.shields.io/badge/Claude_Code-v2.1.16+-purple.svg)](https://claude.ai/claude-code)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

[Quick Start](#quick-start) •
[What is AOD?](#what-is-aod) •
[Capabilities](#capabilities) •
[Documentation](#documentation) •
[Contributing](#contributing)

</div>

---

## What is AOD?

AOD Kit is an open-source project template that brings **product-led governance** to AI agent-assisted development. In a world where coding agents can generate entire features in minutes, the bottleneck shifts from "can we build it?" to "should we build it, and are we building it right?" AOD provides the governance layer — a Product Manager / Architect / Team-Lead Triad — that ensures AI-assisted development follows proper product thinking, architectural review, and quality gates.

AOD is **methodology, not application code**. You bring your own stack; AOD gives you a proven workflow that works with any AI coding agent and any technology choice.

> **Why governance now?** Speed without direction is just velocity. AOD turns AI agents from unsupervised code generators into collaborative team members with built-in review checkpoints, sign-offs, and Definition-of-Done gates.

---

## Quick Start

```bash
# Clone the template
git clone https://github.com/davidmatousek/agentic-oriented-development-kit.git my-project
cd my-project

# Bootstrap your project (one-shot — substitutes project name, stack, dates)
make init

# Set up product vision and design identity (recommended)
/aod.foundation
```

After `make init`, the README, CLAUDE.md, and other templated files are personalized to your project. From there, run `/aod.define` to draft your first PRD with Triad governance.

**Prerequisites**: [Claude Code](https://claude.ai/claude-code) v2.1.16+ and `git`. Other AI agent tools work too (the methodology is agent-agnostic), but built-in slash commands are tuned for Claude Code.

---

## Capabilities

| Capability | What it does |
|---|---|
| **SDLC Triad governance** | PM, Architect, and Team-Lead sign-offs at every phase gate (spec, plan, tasks). Triple sign-off is the minimum governance floor. |
| **Six-stage AOD lifecycle** | Discover → Define → Plan → Build → Deliver → Document. Each stage has its own commands, skills, and quality gates. |
| **Product Discovery Lifecycle (PDL)** | Structured idea capture, ICE scoring, PM validation, and user story generation — from raw idea to backlog-ready in one flow. |
| **Stack Packs** | Drop-in technology conventions for Next.js + Supabase, FastAPI + React, and more. Activate one with `/aod.stack use <pack>`. |
| **Modular rules system** | `.claude/rules/` contains commit-friendly governance, design-quality, deployment, and context-loading rules — easy to customize per project. |
| **Local-first workflows** | All artifacts live in `.aod/` and `specs/` as markdown files in your repo. Cloud-optional. |
| **Three governance tiers** | Light (solo / prototypes), Standard (team projects, default), Full (regulated industries). Choose what fits your project. |

---

## Documentation

- **[The AOD Triad](docs/AOD_TRIAD.md)** — How PM, Architect, and Team-Lead collaborate at every gate.
- **[Standards](docs/standards/README.md)** — Definition of Done, naming conventions, git workflow.
- **[Core Principles](docs/core_principles/README.md)** — Thinking lenses (5 Whys, Pre-Mortem, First Principles, etc.) for systematic analysis.
- **[Adopter Guides](docs/guides/README.md)** — Downstream update walkthrough, Triad collaboration guide, kickstarter for new projects.
- **[Architecture](docs/architecture/README.md)** — System design, ADRs, deployment environments.
- **[Product Documentation](docs/product/README.md)** — Vision, PRDs, roadmap, OKRs, user stories.
- **[Constitution](.aod/memory/constitution.md)** — Core governance principles (XI universal rules) and tier configuration.

---

## Project Structure

```
your-project/
├── .aod/              # Active feature workspace + scripts + templates
│   ├── memory/        # Constitution and project memory
│   ├── scripts/bash/  # Lifecycle automation (state, GitHub sync, etc.)
│   ├── scaffold/      # Bootstrap-only artifacts (token-bearing seeds)
│   └── templates/     # spec.md / plan.md / tasks.md templates
├── .claude/           # Agents, skills, commands, design archetypes
│   ├── agents/        # Triad + specialized agent personas
│   ├── skills/        # Reusable automation capabilities
│   ├── commands/      # Slash commands (/aod.define, /aod.plan, etc.)
│   └── rules/         # Modular governance rules
├── docs/              # Product, architecture, devops, standards docs
├── specs/             # Per-feature artifacts (spec.md, plan.md, tasks.md, research.md)
├── stacks/            # Optional stack packs (Next.js+Supabase, FastAPI+React, etc.)
├── scripts/           # init.sh, check.sh, extract.sh, sync-upstream.sh
└── CLAUDE.md          # AI agent context (auto-loaded by Claude Code)
```

You bring your own `src/` (or `backend/`, `frontend/`, etc.). AOD lives alongside your code, not inside it.

---

## How AOD Works

AOD organizes a feature's life around six stages, each with its own governance gates:

1. **Discover** — Capture an idea, score it (ICE), validate with the PM. (`/aod.discover`)
2. **Define** — Draft a PRD with Triad review. (`/aod.define`)
3. **Plan** — Generate spec → plan → tasks with PM, Architect, and Team-Lead sign-offs. (`/aod.plan`)
4. **Build** — Execute waves of tasks in parallel with Architect checkpoints. (`/aod.build`)
5. **Deliver** — Validate against Definition of Done and run the retrospective. (`/aod.deliver`)
6. **Document** — Code simplification, CHANGELOG, docstrings, API docs. (`/aod.document`)

The full lifecycle can be chained with `/aod.run` — autonomous mode runs through every stage with the same governance gates as interactive mode, halting only on circuit breakers or BLOCKED verdicts.

---

## Contributing

AOD is open source under the [MIT License](LICENSE). Contributions, bug reports, and feature ideas are welcome.

- **Issues**: [github.com/davidmatousek/agentic-oriented-development-kit/issues](https://github.com/davidmatousek/agentic-oriented-development-kit/issues)
- **Discussions**: [github.com/davidmatousek/agentic-oriented-development-kit/discussions](https://github.com/davidmatousek/agentic-oriented-development-kit/discussions)
- **Contributing guide**: [CONTRIBUTING.md](CONTRIBUTING.md)

---

<div align="center">

Built with the AOD Triad — PM ✓ Architect ✓ Team-Lead ✓

[Open an issue](https://github.com/davidmatousek/agentic-oriented-development-kit/issues) · [Read the Triad guide](docs/AOD_TRIAD.md) · [Run `make init`](#quick-start)

</div>
