# System Design

Auto-generated from approved plan.md files. Each feature section captures component architecture and data flow at the time of planning approval.

---

## System Overview

The AOD Kit comprises four core component types:

| Component | Count | Location | Purpose |
|-----------|-------|----------|---------|
| Agents | 13 | `.claude/agents/` | Specialized AI personas (PM, Architect, Team-Lead, etc.) |
| Skills | 24 | `.claude/skills/` | Automation capabilities (11 public, 13 internal) |
| Commands | 23 | `.claude/commands/` | User-invocable slash commands |
| Rules | 8 | `.claude/rules/` | Behavioral constraints and standards |

### Agent Tiers
- **Core Team** (7): product-manager, architect, team-lead, orchestrator, senior-backend-engineer, frontend-developer, tester
- **Specialized Support** (6): devops, code-reviewer, debugger, web-researcher, ux-ui-designer, security-analyst

### Skill Types
- **Public** (11): User-invocable via `/skill-name` (e.g., `/aod.foundation`, `/security`)
- **Internal** (13): Prefixed with `~`, invoked by commands or orchestrator (e.g., `~aod-build`)

---

<!-- Content is auto-populated by /aod.plan when features are planned. -->

### Feature 097: design-capabilities-enhancement

**Components**: 8 components (C1-C8) covering design quality rules (core + supplements), scaffold font fix, build pipeline gate, design token scaffolds, brand identity pattern, personality archetypes, and Figma MCP guide. All file-based — markdown rules, CSS scaffolds, command modifications.

**Data Flow**: Two-layer enforcement: (1) Prevention — core rules + stack supplements + brand/archetype context loaded into agent context at generation time; (2) Detection — grep-based design quality gate in `/aod.build` catches regressions in changed files before PR. Token scaffolds constrain agent output to defined values. Brand identity overrides archetype defaults, which override scaffold defaults.

**Tech Stack**: Markdown (rules, archetypes, docs), CSS with Tailwind v4 `@theme` (token scaffolds), grep-based inline checks (build gate). Follows ADR-011 multi-flag opt-out pattern (`--no-design-check`). No external dependencies.

**Component Map**:

| Component | Location | Purpose |
|-----------|----------|---------|
| Core Design Rules | `.claude/rules/design-quality.md` | Stack-agnostic design quality standards (typography, spacing, color, shadows, component states). Loaded by all UI-generating agents. |
| Design Context Loader | `.claude/rules/design-context-loader.md` | 5-step discovery sequence with precedence order: brand identity > archetype > scaffold tokens > core rules. Instructs agents to load context before generating UI code. |
| Design Archetypes | `.claude/design/archetypes/` | 6 personality-based aesthetic presets (boldness, playful, precision, sophistication, technical, warmth). Define font pairing, color palette, spacing, motion style, shadow depth, border-radius. |
| Brand Identity | `brands/{name}/` | Per-project brand overrides. Contains `brand.md` (mandatory), `tokens.css` (mandatory), `anti-patterns.md` (optional), `reference/` (optional). Highest precedence in design context. |
| Stack Design Supplements | `stacks/{pack}/rules/design-quality-tailwind.md` | Tailwind v4 specific implementations of core design rules. Injected via Dual-Surface Injection when a stack pack is active. |
| Scaffold Token Files | `stacks/{pack}/scaffold/*/globals.css` or `app.css` | CSS files with `@theme` token definitions. Constrain agent output to defined design token values. |
| Build Pipeline Gate | `.claude/commands/aod.build.md` Step 6 | Grep-based design quality gate. Checks font compliance, spacing compliance, shadow count, and reduced-motion support on changed UI files. Opt-out via `--no-design-check`. |
| ADR-011 | `docs/architecture/02_ADRs/ADR-011-...` | Multi-flag opt-out and step insertion pattern. Governs `--no-design-check` flag alongside `--no-security` and `--no-simplify`. |

### Feature 100: project-foundation-workshop

**Components**: 3 components — Workshop Skill File (SKILL.md), Init Script Update (scripts/init.sh), Documentation Updates (getting started guides + commands.md). All file-based — markdown skill, bash script modifications, documentation edits. No application code.

**Data Flow**: Two-part sequential workshop: (1) State Detection — checks product-vision.md for `[To be refined]` markers and brands/ directory for existing identity; (2) Part 1 (Vision) — 5 interactive questions via AskUserQuestion → generates product-vision.md; (3) Part 2 (Design) — archetype browser via AskUserQuestion → token mapping using canonical table → generates brands/{project-name}/brand.md, tokens.css, anti-patterns.md. Show-before-write pattern on all file outputs. Idempotent re-runs detect existing content and offer edit/keep/replace.

**Tech Stack**: Markdown (SKILL.md skill file), AskUserQuestion tool (interactive prompts), CSS custom properties (single-layer `:root {}` block for tokens.css), Bash 3.2 (init.sh modifications). No external dependencies. Token generation via direct field mapping from archetype markdown tables with explicit name translation layer (e.g., `--color-error` → `--color-destructive`).

**Component Map**:

| Component | Location | Purpose |
|-----------|----------|---------|
| Workshop Skill | `.claude/skills/aod-foundation/SKILL.md` | Two-part guided workshop (Vision + Design Identity). Parses `--vision`/`--design` flags, detects state, runs interactive Q&A, generates brand files via canonical token mapping table. |
| Init Script Update | `scripts/init.sh` (lines ~275-300) | Reorders "Next steps" section to list `/aod.foundation` as step 1 (before stack pack activation). |
| Documentation Updates | `docs/guides/GETTING_STARTED_PATH_B.md`, `.claude/rules/commands.md` | Adds workshop mention to getting started guide and registers `/aod.foundation` in the utility commands list. |

### Feature 110: archive-test-artifacts

**Components**: 4 components — Delivery Template Extension (new "Test Evidence" section), Deliver Skill Extension (Collect Test Evidence step), Gitignore Negation Rules, Testing Documentation Update. All file-based — markdown templates, skill instructions, gitignore rules, documentation. No application code.

**Data Flow**: Sequential within `/aod.deliver` workflow: (1) Steps 1-8 execute existing retrospective flow; (2) Collect Test Evidence step auto-detects test artifacts in 4 standard locations (`.aod/test-results/`, `test-results/`, `coverage/`, root-level glob matches); (3) Developer confirms, provides custom paths, or skips; (4) Confirmed files copied to `specs/{NNN}-*/test-results/`; (5) Best-effort metric extraction (JUnit XML via xmllint, LCOV via grep/bc); (6) Generate Delivery Document step re-reads delivery template (including new "Test Evidence" section) and populates from collected data. Non-fatal guard (ADR-006) on entire step.

**Note**: Originally added as Steps 9-10. Renumbered to Steps 10-11 by Feature 113 (E2E Validation Gate inserted as Step 9). Per ADR-011, descriptive stage names used above to reduce renumbering blast radius.

**Tech Stack**: Markdown (skill instructions, templates, docs), xmllint (JUnit XML parsing, ships with macOS), grep/bc (LCOV coverage calculation, standard Unix), Git gitignore negation patterns. No external dependencies.

**Component Map**:

| Component | Location | Purpose |
|-----------|----------|---------|
| Delivery Template Extension | `.aod/templates/delivery-template.md` | New "Test Evidence" section between "Source Artifacts" and "Documentation Updates". Fields: artifact table, test summary metrics, notes. |
| Deliver Skill Extension | `.claude/skills/~aod-deliver/SKILL.md` | Collect Test Evidence step (currently Step 10). Auto-detect in 4 locations, confirm/prompt/skip, copy to specs archive, extract metrics. Non-fatal per ADR-006. |
| Gitignore Negation | `.gitignore` (after line 47) | `!specs/*/test-results/` and `!specs/*/test-results/**` negation rules. Allows archived test evidence while keeping project-root `test-results/` ignored. |
| Testing Docs Update | `docs/testing/README.md` | New section documenting `specs/{NNN}-*/test-results/` convention, supported formats, size guidance, and sensitive data warnings. |

### Feature 113: wire-tester-agent-deliver

**Components**: 3 components — E2E Validation Gate Step (new Step 9 in deliver skill), Flag Parsing & Step Coordination (deliver command), Delivery Template Expansion. All file-based — markdown skill instructions, command definitions, and templates. No application code.

**Data Flow**: Sequential within `/aod.deliver` workflow: (1) Step 0 parses `--require-tests` flag alongside `--autonomous`; (2) Steps 1-8 execute existing workflow unchanged; (3) New Step 9 detects Playwright config → invokes tester agent (subagent_type: `tester`) with spec path → parses results (pass/fail/counts) → evaluates gate (soft=warn, hard=block, autonomous=proceed); (4) Step 10 (formerly 9) collects test evidence from `.aod/test-results/` (auto-detected, no modification needed); (5) Step 11 (formerly 10) generates delivery document with expanded E2E validation section.

**Tech Stack**: Markdown (skill/command instructions), Claude Code Agent SDK (tester agent invocation via Agent tool), AskUserQuestion (soft gate prompt), Subagent Return Policy (minimal response contract). No external dependencies added — Playwright is user-installed.

**Component Map**:

| Component | Location | Purpose |
|-----------|----------|---------|
| E2E Validation Gate | `.claude/skills/~aod-deliver/SKILL.md` Step 9 | New step with 4 sub-steps: detect Playwright config, invoke tester agent, parse results, evaluate gate decision (soft/hard/autonomous). Non-fatal by default (ADR-006). |
| Flag Parsing Update | `.claude/commands/aod.deliver.md` Step 0 | Adds `--require-tests` flag. Updates Step 6 invocation range to include new Step 9. Updates all downstream SKILL.md step references. |
| Template Expansion | `.aod/templates/delivery-template.md` | Adds "E2E Validation Gate" subsection to Test Evidence: status, gate mode, gate result, test summary, failure details. |

### Feature 109: test-execution-regression-gate

#### Components

| Component | Location | Purpose |
|-----------|----------|---------|
| Flag Parsing | `.claude/commands/aod.build.md` Step 0e-0f | Parse `--no-tests` (opt-out) and `--require-tests` (opt-in hard gate) |
| Test Execution Sub-Step | `.claude/commands/aod.build.md` Step 4.5 | Detect test runner, execute suite, classify failures, gate wave progression |
| Test Generation Sub-Step | `.claude/commands/aod.build.md` Step 4.6 | Invoke tester agent for unit/integration tests on wave code (P1) |
| Coverage Tracking | `.claude/commands/aod.build.md` Step 4.5 | Capture coverage delta per wave when tooling available (P1) |
| Completion Report Extension | `.claude/commands/aod.build.md` Step 8 | Test execution summary in build report |
| Checkpoint Extension | `.claude/commands/aod.build.md` Step 4.5 | Test summary section in architect checkpoint reviews |
| Deliver Extension | `.claude/commands/aod.deliver.md` | Extend test evidence collection to discover build-wave artifacts |
| ADR-011 Amendment | `docs/architecture/02_ADRs/ADR-011-*.md` | Document `--require-tests` as opt-in severity modifier pattern |

#### Data Flow

```
Wave completes → Skip check (--no-tests? no code changes?) → Detect test runner
→ Execute suite (capture to failures.log) → Parse results → Load previous wave results
→ Classify (regression/new/pre-existing) → Store results.json → Gate decision
→ [P1: Generate tests → Track coverage] → Continue to checkpoint review
```

#### Tech Stack

- Prompt engineering (markdown command files)
- JSON test artifacts (results.json, coverage.json, summary.json)
- ADR-011 (multi-flag pattern), ADR-010 (minimal returns)

### Feature 108: autonomous-document-stage

#### Components

6 components extending the AOD lifecycle from 5 stages to 6:

| # | Component | File(s) | Purpose |
|---|-----------|---------|---------|
| 1 | Autonomous Flag | `.claude/commands/aod.document.md` | `--autonomous` flag suppresses interactive prompts |
| 2 | State Machine Extension | `.claude/skills/~aod-run/SKILL.md` | Add document stage to core loop, skill mapping, transitions |
| 3 | Stage Map Display | `.claude/skills/~aod-run/SKILL.md` | Extend stage map from 5 to 6 positions |
| 4 | GitHub Label Integration | `github-lifecycle.sh`, `backlog-regenerate.sh`, SKILL.md | Add `stage:document` label, update mappings |
| 5 | State Validation | `run-state.sh`, `entry-modes.md` | Validate `document` as valid stage, extend initial state JSON |
| 6 | Lifecycle Complete | `error-recovery.md` | Check 6 stages for completion, update display |

#### Data Flow

```
Deliver completes → Context boundary → GitHub label: stage:document
→ State: document.status = "in_progress" → Invoke aod.document --autonomous
→ Creates {NNN}-document-stage branch → Auto-accept all changes
→ PR squash-merge → State: document.status = "completed"
→ GitHub label: stage:done → Lifecycle Complete (6/6)
```

#### Tech Stack

- Markdown (skill/command files), Bash 3.2 (shell scripts), JSON/jq (state management)
- GitHub CLI (`gh`) for label management (non-blocking, graceful degradation)

---

### Feature 121: GitHub Issues Board Sync Fix

#### Components

1. **Skill Instruction Hardening** — `.claude/skills/~aod-discover/SKILL.md`: Top-level "Critical Constraints" section prohibiting direct `gh issue create`, with checklist promotion
2. **Board Reconciliation Integration** — `.aod/scripts/bash/backlog-regenerate.sh`: Single `aod_gh_reconcile_board()` call after BACKLOG.md write, guarded by `aod_gh_check_board`
3. **Lifecycle Script Audit** — Read-only verification that `create-issue.sh`, `aod_gh_create_issue()`, and `aod_gh_update_stage()` all include board sync calls (confirmed: no gaps)

#### Data Flow

```
Agent runs /aod.discover
  ├─ [Fix 1] SKILL.md constraint → forces agent to use create-issue.sh
  │   └─ create-issue.sh → aod_gh_create_issue() → aod_gh_add_to_board()
  └─ [If agent bypasses constraint]
      └─ gh issue create directly → issue NOT on board
          └─ [Fix 2] backlog-regenerate.sh → aod_gh_reconcile_board()
              └─ Detects orphan → aod_gh_move_on_board() → board synced
```

#### Tech Stack

- Bash 3.2 (shell scripts), Markdown (SKILL.md), GitHub CLI (`gh`) for Projects v2 API
- Defense-in-depth: prevention (skill constraint) + detection & repair (reconciliation)

### Feature 124: deliver-retro-empty-bodies

#### Components

2 components — Command Definition Fix and Source-of-Truth Reference. Single-file markdown edit. No application code, no script changes.

| Component | Location | Purpose |
|-----------|----------|---------|
| Command Definition Fix | `.claude/commands/aod.deliver.md` line 128 | Add missing `--body "$BODY"` parameter with inline structured template to `create-issue.sh` invocation for retro ideas |
| Source-of-Truth Reference | `.claude/commands/aod.deliver.md` | Comment referencing SKILL.md as canonical source for body template (prevents drift per KB Entry 9) |

#### Data Flow

```
User runs /aod.deliver
  └─> Step 6.3: Feedback Loop
       └─> Agent reads command definition (aod.deliver.md)
            └─> Constructs $BODY from inline template
                 └─> Calls: create-issue.sh --title "..." --body "$BODY" --stage discover --type retro
                      └─> create-issue.sh passes to aod_gh_create_issue()
                           └─> gh issue create --title "..." --body "$BODY" --label "stage:discover" --label "type:retro"
                                └─> GitHub Issue created with populated body
```

#### Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Command Definition | Markdown | Agent instruction file (`.claude/commands/`) |
| Issue Creation | Bash + gh CLI | `create-issue.sh` → `github-lifecycle.sh` |
| Target | GitHub Issues API | Issue body content |

No new technologies introduced.
