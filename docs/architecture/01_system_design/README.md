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

---

### Feature 129: Downstream Template Update Mechanism

**Components**: 8 components spanning a new adopter-facing CLI (`/aod.update`, `make update`), 5 shared bash libraries (`template-*.sh`), a line-delimited file-ownership manifest (`.aod/template-manifest.txt`), version pin + personalization env (`.aod/aod-kit-version`, `.aod/personalization.env`), hardcoded user-owned guard list (FR-007, embedded in `scripts/update.sh`), and the upstream template's first CI workflow (`.github/workflows/manifest-coverage.yml`). All file-based — markdown commands, bash scripts, YAML workflow, line-delimited manifest. No application code.

**Data Flow**: Nine-phase atomic transaction within `scripts/update.sh`: (1) Preflight acquires `.aod/update.lock` via PID+nonce+timestamp PRIMARY on macOS (flock opportunistic on Linux) and verifies same-filesystem staging via device number (`stat -f %d` BSD / `-c %d` GNU — NOT `%T` which is filesystem type name); (2) Fetch upstream via HTTPS `git clone --depth=1` into `.aod/update-tmp/<uuid>/upstream/`; (3) Fetch fresh manifest + SHA-256 hash; flag `user → owned` transitions against recorded `manifest_sha256`; (4) Plan operations by resolving precedence (`ignore > user-owned guard > user > scaffold > merge > personalized > owned`); (5) Validate (path traversal, symlinks, guard list); (6) Stage processed files with placeholder re-substitution (bash `${str//pattern/replacement}` for `personalized` category — NOT `sed`); (7) Render grouped preview; confirm or `--yes`; (8) Atomic `mv` loop for staged files; version file `mv` LAST as transaction commit; (9) Cleanup staging on success, preserve on failure for inspection.

**Tech Stack**: Bash 3.2 (all scripts verified — no `declare -A`, no `readarray`, no `globstar`; CI runs in `bash:3.2` Docker container to catch regressions), POSIX utilities (`mv`, `stat`, `find`, `mktemp`), Git ≥ 2.30 (HTTPS fetch, tag resolution, SHA computation), GitHub Actions (upstream template's first workflow; `actions/checkout` SHA-pinned, `permissions: contents: read`, concurrency cancel-in-progress), Markdown (command files, docs). Applies ADR-001 (atomic state persistence) at transaction granularity.

**Component Map**:

| Component | Location | Purpose |
|-----------|----------|---------|
| `/aod.update` CLI | `scripts/update.sh`, `.claude/commands/aod.update.md`, `Makefile` `update` target | Adopter-facing entry point. 9-phase atomic transaction: preflight → fetch → manifest load → plan → validate → stage → preview → apply → cleanup. Supports `--dry-run`, `--yes`, `--json`, `--edge`, `--force-retag`, `--upstream-url=<url>`. |
| Template Helpers — Manifest | `.aod/scripts/bash/template-manifest.sh` | Line-delimited parser + category lookup + glob match + precedence resolution (`while read` + `case`). |
| Template Helpers — Validate | `.aod/scripts/bash/template-validate.sh` | Path sanitization (`..`, `~`, absolute reject), symlink rejection, residual placeholder scan. |
| Template Helpers — JSON | `.aod/scripts/bash/template-json.sh` | JSON output helpers, `schema_version: 1.0`. |
| Template Helpers — Git | `.aod/scripts/bash/template-git.sh` | HTTPS upstream fetch (standalone `git clone --depth=1` into temp), diff computation, retag detection, fs-device helper (`aod_template_fs_device`). |
| Template Helpers — Substitute | `.aod/scripts/bash/template-substitute.sh` | 12-placeholder canonical list (single source of truth, refactored from `init.sh:117-161`) + bash `${str//pattern/replacement}` literal-replace + `.aod/personalization.env` loader. |
| File-Ownership Manifest | `.aod/template-manifest.txt` | Line-delimited (NOT YAML — bash 3.2 compatibility). Format: `<category>|<path-or-glob>`. Categories: `owned`, `personalized`, `user`, `scaffold`, `merge`, `ignore`. Fetched fresh each run (FR-013); SHA-256 hash recorded for drift detection. |
| Version Pin | `.aod/aod-kit-version` | KV format (bash-sourceable). 5 fields: `version`, `sha`, `updated_at`, `upstream_url`, `manifest_sha256`. Written atomically as LAST step of transaction (ADR-001 pattern at transaction scale). |
| Personalization Env | `.aod/personalization.env` | KV format. Created by `init.sh`, read by `/aod.update`. 12 canonical placeholders. `RATIFICATION_DATE` + `CURRENT_DATE` are init-only snapshots (never recomputed). Values with newlines or `|` rejected at load. |
| Hardcoded Guard List (FR-007) | Embedded `readonly USER_OWNED_GUARD` array in `scripts/update.sh` (NOT a shared lib — tamper resistance) | Anchored-to-root globs: `docs/product/**`, `docs/architecture/**`, `brands/**`, `.aod/memory/**`, `specs/**`, `roadmap.md`, `okrs.md`, `CHANGELOG.md`. Overrides manifest. Two-layer check (plan + validate). |
| CI Workflow | `.github/workflows/manifest-coverage.yml` + `scripts/check-manifest-coverage.sh` | The upstream template's first CI workflow. Validator runs in `bash:3.2` Docker container to catch bash-4+ regressions (ubuntu-latest ships bash 5.x). `actions/checkout` SHA-pinned, explicit `permissions: contents: read`, concurrency group with `cancel-in-progress`. Pre-commit hook variant documented in CONTRIBUTING.md. |

**Key architectural decisions**:
- **Line-delimited manifest over YAML**: bash 3.2 compatibility; avoids `yq` dependency.
- **Same-filesystem pre-flight via device number**: `stat -f %d` (BSD) / `stat -c %d` (GNU). **NOT `%T`** (returns filesystem type name, false-passes two distinct APFS volumes or NFS mounts).
- **PID+nonce+timestamp PRIMARY on macOS** (not fallback): `flock(1)` is not shipped on macOS by default. `flock` is used opportunistically as a fast-path when available.
- **Bash parameter expansion for substitution** (not `sed`): `sed` interprets `&` and `\1` in RHS even with non-default delimiters; bash `${str//pattern/replacement}` is truly literal.
- **Three independent supply-chain defenses**: commit SHA pinning, retag detection, manifest SHA-256 tracking.
- **Two-layer guard enforcement**: hardcoded array in `scripts/update.sh` + `template-validate.sh::assert_safe_path` check. Both must pass.

See [downstream-update-architecture.md](downstream-update-architecture.md) for topology diagrams and the full atomicity contract.

### Feature 128: directory-based-extraction-manifest

**Components**: Four cleanly-decoupled components built in parallel after Component A's interface locks:
- **Component A (Manifest Engine, `scripts/extract.sh`)** — replaces `MANIFEST_FILES` with `MANIFEST_DIRS` + `MANIFEST_ROOT_FILES`; externalizes content-reset heredocs to `scripts/reset-templates/`; adds new Step 5 post-copy defense gate (residual-placeholder + deny-list scans on sync AND non-sync paths). Owns FR-001/002/006-013, FR-030.
- **Component B (Coverage Validator + CI)** — new `scripts/check-extract-coverage.sh` validator + `scripts/extract-classification.txt` snapshot + `.github/workflows/extract-coverage.yml` (1:1 mirror of `manifest-coverage.yml`) + `make extract-check`/`make extract-classify` targets. Owns FR-014-018, FR-011 Layer (d).
- **Component C (Sync-Upstream Flags)** — adds `--yes`, `--dry-run`, `--strategy={main,branch,manual}` to `.claude/commands/aod.sync-upstream.md`; preserves no-flags interactive default; dirty-tree abort regardless of `--yes` (PM Decision Q2). Owns FR-019-026, FR-032-035.
- **Component D (Docs + BATS Test Suite)** — `docs/guides/PLSK_MAINTAINER_GUIDE.md` migration section; 12 BATS scenarios across `tests/unit/extract-*.bats` and `tests/integration/extract-end-to-end.bats`. Owns FR-027-029, FR-031.

**Data Flow**: Five-step extraction pipeline gated by new Step 5 defense check. Step 0 (preflight + alphabetical lint) → Step 1 (directory copy) → Step 1b (`.extractignore` overlay, Layer 1) → Step 2 (root files copy) → Step 3 (`.gitkeep` seeding) → Step 4 (content-reset, sync-only, fail-loud on missing template = Layer 5) → **Step 5 (residual-placeholder + deny-list scans on sync AND non-sync = Layers 2+3)** → Step 6 (mirror-delete, sync-only) → Step 7 (summary). Independent CI flow (Layer 4): `bash:3.2` Docker runs `check-extract-coverage.sh` → diffs live classification against committed snapshot → blocks PR if diverged. Sync-upstream wrapper flow: `--dry-run` short-circuits to preview-only; `--yes` skips Step 3 confirmation; `--strategy=` skips Step 6 prompt; dirty-tree pre-flight aborts unconditionally.

**Tech Stack**: Bash 3.2 (macOS `/bin/bash` parity, KB Entry 6 binding); GitHub Actions YAML; Markdown for maintainer docs. CI runs in `bash:3.2` Docker for OS parity. BATS 1.x for test framework. **Reusable libraries — zero modification**: `aod_template_scan_residual_placeholders` (Layer 2), `aod_template_glob_match` (validator glob engine), `aod_template_assert_safe_path` (template-path validation), `aod_template_assert_no_symlink` (symlink edge case). **Out of stack**: no new shell library, no YAML/JSON for `.extractignore` (PM Q4), no `--json` mode on sync-upstream (PM Q6).

**Architecture Decisions**:
- **Bundled binary acceptance for 5-layer defense (FR-011)**: any one layer absent → bundle unsatisfied. Architect's strongest recommendation, preserved verbatim from PRD.
- **Stricter forward globs over `!`-negation in `.extractignore`**: `0[1-9][0-9]-*.md` + `[1-9][0-9][0-9]-*.md` patterns exclude numbered PRDs while preserving `000-example`. Avoids extending the bash 3.2 glob engine. PM Decision Q4 — defer negation to v2.
- **Externalized content-reset templates as Layer 5**: missing template → fail-loud exit 1 within 1 second (SC-010), no destination written. Adding a new reset target is a 2-line maintainer change (one template file + one registry entry).
- **CI workflow 1:1 mirror of `manifest-coverage.yml`**: action SHA pinning (`actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683`), `permissions: contents: read`, `concurrency: cancel-in-progress: true`, push+PR-to-main triggers, `bash:3.2` Docker step. New workflow naming pinned in tasks.md (architect concern §6.2).
- **Compiler-diagnostic error format `<file>:<line>: <message>`** across all defense-layer failures (FR-013) — enables GitHub Actions annotator auto-parsing.

See plan.md (`specs/128-directory-based-extraction-manifest/plan.md`) and contracts (`specs/128-directory-based-extraction-manifest/contracts/`) for full schemas, CLI surface, and acceptance scenarios.

### Feature 130: Stack Pack Test Contract

**Delivered**: 2026-04-21 (PR #141)

**Components**: 7 components replacing filesystem-based E2E runner detection in `/aod.deliver` Step 9 with a declarative contract embedded in every stack pack's `STACK.md`, enforced by a bash-3.2 lint with a stable exit-code taxonomy, and protected at PR time by a new CI workflow. All file-based — markdown skill/agent edits, bash script, YAML workflow, fenced YAML in STACK.md files. No application code.

| # | Component | File(s) | Purpose |
|---|-----------|---------|---------|
| 1 | Lint Tool | `.aod/scripts/bash/stack-contract-lint.sh` | Bash-3.2 fenced-YAML parser + schema validator. Single-file + `--all` modes. Stable exit codes 0/1/2/3/4/5. Stderr in `[aod-stack-contract] <file>:<line>: <SEVERITY>: <message>` format. Inline `CONTENT_PACKS=()` allowlist. |
| 2 | STACK.md Contract Block | `stacks/*/STACK.md` Section 7 | Fenced YAML between `<!-- BEGIN/END: aod-test-contract -->` sentinels. 3-key schema: `test_command` (required) + XOR(`e2e_command`, `e2e_opt_out`). Metacharacter warnings nudge authors toward wrapper scripts. |
| 3 | Deliver Step 9 Rewrite | `.claude/skills/~aod-deliver/SKILL.md` Steps 9a/9b/11c | Step 9a reads `.aod/stack-active.json` → lint active pack's STACK.md → branch on exit code. Step 9b parameterizes tester prompt with `${E2E_COMMAND}`. Step 11c surfaces `skip_reason` in E2E Gate table. `e2e_validation.command` populated only on pass/fail. |
| 4 | Tester Agent Parameterization | `.claude/agents/tester.md` lines 17, 65, 134 | `playwright-automation` → `e2e-automation` in expertise array; body examples generalized to "declared E2E runner from active pack's STACK.md contract." Pre-rename grep check mandated to catch downstream skill-matching heuristics. |
| 5 | CI Workflow | `.github/workflows/stack-contract.yml` | Runs `stack-contract-lint.sh --all` in `bash:3.2` Alpine Docker. Mirrors `manifest-coverage.yml` shell (SHA-pinned checkout, read-only permissions, cancel-in-progress). Path filters: `stacks/**/STACK.md`, lint script, workflow file. Fetch-depth 1. |
| 6 | Migration Doc | `docs/stacks/TEST_COMMAND_CONTRACT.md` | Pack-author reference: schema, examples, error codes, wrapper-script pattern, nested-comment pathological case callout. |
| 7 | Day-1 Pack Rollout | `stacks/nextjs-supabase`, `stacks/swiftui-cloudkit`, `stacks/fastapi-react`, `stacks/fastapi-react-local`, `stacks/knowledge-system` | nextjs-supabase declares `e2e_command`; the two fastapi variants and swiftui-cloudkit declare `e2e_opt_out` with tracking issues (#138/#140); knowledge-system is allowlisted as content-only. Per-pack tester supplements under tight line caps (FR-021..FR-024). |

**Data Flow**:

```
Author time (local):
  Edit stacks/<pack>/STACK.md Section 7 between sentinels
   └─ Local: bash stack-contract-lint.sh stacks/<pack>/STACK.md → exit 0/1/2/3/4/5
       └─ Pre-commit pass → git commit

PR time (CI):
  PR opened → .github/workflows/stack-contract.yml triggered (path filter match)
   └─ bash:3.2 Docker → stack-contract-lint.sh --all
       └─ Iterate stacks/*/STACK.md (skip CONTENT_PACKS entries)
           └─ Per-pack diagnostics to stderr; exit = min(per-pack codes)
               └─ PR check passes if exit 0; fails with annotated diff otherwise

Delivery time (adopter):
  /aod.deliver Step 9a
   └─ Read .aod/stack-active.json → resolve active pack
       └─ stack-contract-lint.sh stacks/<pack>/STACK.md → parse exit code
           ├─ 0 → Step 9b: tester agent with ${E2E_COMMAND} parameter
           │      └─ tester returns .aod/results/tester.md
           │          └─ e2e_validation.{status, command, total, passed, ...}
           ├─ 1/2/3/4/5 → error branch → e2e_validation.status = "error", error = <stderr>
           │              (Feature 142 removed the former grace-period fallback — Issue #142;
           │               exit 5 now routes through the same error branch as exits 1–4)
           └─ file absent OR malformed → skip contract check (non-stack-pack project)
      └─ Step 11c: render skip_reason / error in E2E Validation Gate table

Distribution:
  Kit → adopter via PRD 129 template-manifest (scripts/sync-upstream.sh → /aod.update)
   └─ Contract files carried: stacks/*/STACK.md, lint script, migration doc, CI workflow
```

> **Note (Feature 142, Issue #142)**: The grace-period branch shown above for exit 5 was removed by Feature 142. In the original Feature 130 shipping release, exit 5 (missing contract block) routed to `e2e_validation.status = "skipped"` with `skip_reason = "no_contract_declared — migrate before next release"` as a one-release backward-compatibility grace period. Exit 5 now routes through the same error branch as exits 1–4, producing `e2e_validation.status = "error"` with the lint stderr diagnostic. This honors the Feature 130 Plan Decision 1 commitment that the grace-period fallback would be removed in the release following PR #141.

**Tech Stack**:

| Layer | Choice | Rationale |
|---|---|---|
| Shell | Bash 3.2 (macOS `/bin/bash`) | KB Entry 6 binding; no runtime deps |
| Parsers | POSIX `awk`, `grep`, `sed` | Ubiquitous; bash-3.2 compatible; zero install cost |
| Contract format | Markdown + fenced YAML in HTML sentinels | Human-editable; sentinels survive prettifier reflow |
| CI | GitHub Actions + `bash:3.2` Docker | Mirrors manifest-coverage.yml; enforces bash-3.2 parity |
| Distribution | PRD 129 template-manifest | Existing adopter-update channel — no new path |
| Backward compat | One-release grace period (FR-031) — *historical, removed by Feature 142 (Issue #142)* | Satisfied Constitution Principle III without indefinite dead code; grace period has since been removed per its one-release commitment |

**Key Architectural Decisions** (from plan.md):

- **Contract surface in STACK.md, not separate file**: Authors already edit STACK.md; co-locating machine-readable contract with human-readable prose prevents drift.
- **HTML sentinel comments as parser anchors**: Markdown prettifiers reflow fenced blocks aggressively but almost never touch HTML comments. `awk` range match on sentinels is reflow-proof.
- **Exit-code taxonomy over structured JSON**: Bash 3.2 cannot emit JSON without `jq`; stderr + exit code matches `manifest-coverage.yml` precedent and GitHub Actions annotator format; no new dependencies.
- **XOR e2e_command / e2e_opt_out**: Makes "no E2E" a first-class state distinguishable from "forgot to declare." Opt-out reason is auditable; `#NNN` warning nudges authors toward tracked issues.
- **Unconditional prose-level grace-period branching** *(historical, removed by Feature 142 — Issue #142)*: No runtime feature flag was used; removal was a trivial one-line diff in a spin-out PR. Kept Step 9a bash-clean. The grace-period branch was removed in the release following PR #141 per its one-release commitment.
- **CI reuses manifest-coverage.yml shell**: Established `bash:3.2` Docker pattern from Feature 129 — SHA-pinned checkout, read-only permissions, concurrency cancel-in-progress, fetch-depth 1.
- **`e2e_validation.command` populated only on pass/fail** (plan Decision 4, option (a)): Payload semantically means "what we ran and got results for" — never "what we would have run." Absent on skipped/error.
- **Content-pack allowlist inline array, not external file**: Day-1 has one entry (`knowledge-system`). If allowlist grows to 3+ entries, future PRD may extract to `.contract-ignore`.
- **Tester agent renamed `playwright-automation` → `e2e-automation`**: Runner-agnostic identifier. Pre-rename repo-wide grep catches downstream skill-matching dependencies.

**Constitutional alignment**:
- **Principle II (API-First)**: The 3-key schema + exit-code taxonomy + stderr format + `e2e_validation.*` payload is a versioned API surface between pack authors and `/aod.deliver`. Codes stable forever; schema extensions additive-only.
- **Principle III (Backward Compatibility, NON-NEGOTIABLE)**: Grace period (FR-031) prevented immediate adopter breakage at Feature 130 ship time. Exit-5 semantic flip was completed by Feature 142 (Issue #142) in the release following PR #141, per the original one-release commitment.
- **Principle VI (Testing Excellence)**: Unit tests on 8 fixtures, 6-scenario manual integration checklist (DoD-cited), contract-snapshot `all-packs-declare` regression guard.
- **Principle VIII (Observability)**: Errors emit `file:line:` format for GitHub Actions annotator; `delivery.md` logs declared command OR opt-out reason OR error (FR-012/13/14).

See [ADR-012](../02_ADRs/ADR-012-stack-pack-test-contract.md) for the decision record, [plan.md](../../../specs/130-e2e-hard-gate/plan.md) for architectural ledger, [contracts/stack-contract-lint.md](../../../specs/130-e2e-hard-gate/contracts/stack-contract-lint.md) for binary CLI contract, and [data-model.md](../../../specs/130-e2e-hard-gate/data-model.md) for schema details.

---

### Feature 138: playwright-e2e-fastapi-stack-packs

**Delivered**: 2026-04-22 (PR #146, merge commit `7569dc5`)

**Source**: [specs/138-playwright-e2e-fastapi-stack-packs/plan.md](../../../specs/138-playwright-e2e-fastapi-stack-packs/plan.md) (approved 2026-04-21, PM + Architect APPROVED_WITH_CONCERNS; all concerns addressed at build time — see `specs/138-playwright-e2e-fastapi-stack-packs/t012-t019-verification-status.md`).

**Feature summary**: Ship Playwright E2E scaffolds to both `fastapi-react` and `fastapi-react-local` stack packs, using Playwright's built-in `webServer` config to manage backend + frontend subprocess lifecycle. Flip both packs' `STACK.md` declarations from `e2e_opt_out` → `e2e_command: "npm --prefix frontend run test:e2e"`. Smoke test is health-check-only (matched to scaffold's minimal surface); adopter template at `_templates/auth-crud.template.ts` shows the canonical growth shape.

**Trigger E correction (post-plan)**: The plan originally declared `npx --prefix frontend playwright test` as the `e2e_command`. Runtime verification surfaced a silent cwd bug — `npx --prefix` changes the binary resolution directory but does NOT change the working directory where Playwright loads `playwright.config.ts`, causing the runner to miss the config. Corrected to `npm --prefix frontend run test:e2e` (scripted npm command preserves package-relative cwd). Applied to both packs' `STACK.md` contract blocks. See Wave 3 commit `83458b3` for the flip.

#### Components

| Component | Location | Purpose |
|---|---|---|
| Playwright config | `scaffold/frontend/playwright.config.ts` (both packs) | `webServer` array (backend + frontend), retries/workers/trace, testIgnore, redaction hook |
| Smoke spec | `scaffold/frontend/e2e/smoke.spec.ts` (both packs) | Health-check-only smoke — page loads + backend `/health` reachable |
| Adopter template | `scaffold/frontend/e2e/_templates/auth-crud.template.ts` (both packs) | Copy-ready auth + CRUD shape for adopter growth |
| Shared fixtures | `scaffold/frontend/e2e/fixtures.ts` (both packs; Postgres guards vs SQLite ephemeral differ per pack) | Redaction hook + DB isolation preconditions |
| Env sample (Postgres only) | `scaffold/frontend/.env.test.example` (fastapi-react only) | Documents `TEST_DATABASE_URL` + test ports |
| Frontend package.json | `scaffold/frontend/package.json` (both packs) | `@playwright/test@^1.58` devDep + `test:e2e` script |
| Tester supplement | `stacks/<pack>/agents/tester.md` (both packs) | E2E Conventions section replacing #130's opt-out paragraph (≤ +25 lines net) |
| STACK.md contract block | `stacks/<pack>/STACK.md` (both packs) | `e2e_command: "npm --prefix frontend run test:e2e"` (post-Trigger-E correction; see note above) |
| Pre-flight lint check | `bash .aod/scripts/bash/stack-contract-lint.sh` (existing, from #130) | Defensive confirmation tool works before flipping declaration |

#### Data Flow

**Adopter-time flow** (`npm --prefix frontend run test:e2e`):

1. npm resolves the `test:e2e` script from `frontend/package.json`, which invokes the Playwright CLI with cwd=`frontend/`. `@playwright/test@^1.58` is in devDeps.
2. Playwright CLI reads `playwright.config.ts`.
3. Playwright spawns backend subprocess: `bash -c "alembic upgrade head && uvicorn app.main:app --host 127.0.0.1 --port <BACKEND_TEST_PORT>"` with test DB env (`TEST_DATABASE_URL` for Postgres, ephemeral SQLite file for local).
4. Playwright spawns frontend subprocess: `npm run dev -- --host 127.0.0.1 --port <FRONTEND_TEST_PORT>`.
5. Playwright polls each `webServer.url` (backend: `/health` → 200; frontend: `/` → 2xx/3xx/400-403) within timeouts (120s backend, 60s frontend).
6. Smoke spec runs: navigate to frontend, assert bootstrap, `page.request.get(/health)` → assert HTTP 200.
7. Teardown: Playwright kills both subprocesses; SQLite temp file deleted for local pack.
8. Exit 0 with one passing test.

**Delivery-time flow** (`/aod.deliver` post-#139 hard-gate):

1. `/aod.deliver` Step 9a reads `stacks/<pack>/STACK.md` `aod-test-contract` block.
2. Parses `e2e_command: "npm --prefix frontend run test:e2e"`.
3. Substitutes into tester agent prompt via `${E2E_COMMAND}`.
4. Tester invokes the command from scaffolded project root.
5. Playwright executes the adopter-time flow (steps 1-8).
6. Exit code + stdout/stderr captured in `e2e_validation` record.
7. Hard gate (post-#139) fails delivery if exit ≠ 0.

**CI-time flow** (lint on the stack pack itself):

1. CI workflow invokes `bash .aod/scripts/bash/stack-contract-lint.sh stacks/fastapi-react/STACK.md`.
2. Lint parses contract block; validates `test_command` present, `e2e_command` XOR `e2e_opt_out`, no metachars (WARN-only).
3. Post-merge: both FastAPI packs pass exit 0, zero WARN.

#### Tech Stack

| Technology | Version | Purpose |
|---|---|---|
| TypeScript | 5.5+ | Playwright spec language |
| @playwright/test | ^1.58 | Test runner + browser automation (matches tiangolo template pin) |
| Chromium | bundled with Playwright | Browser under test (no Firefox/WebKit) |
| Python | 3.11+ | Backend runtime (existing scaffolds) |
| FastAPI | 0.115+ | App under test (existing scaffolds) |
| uvicorn | existing | Subprocess boot target |
| alembic | existing | DB migrations, pre-boot step |
| asyncpg (fastapi-react) | existing | Postgres driver |
| aiosqlite (fastapi-react-local) | existing | SQLite driver |
| Bash | 3.2+ | `stack-contract-lint.sh` (macOS compatibility) |

**Constitutional alignment**:
- **Principle III (Backward Compatibility)**: Adopters opt in via `/aod.update` or `/aod.stack scaffold`; no retroactive mods.
- **Principle IV (Concurrency & Data Integrity)**: `workers: 1` + DB isolation guards (TEST_DATABASE_URL naming-prefix + ephemeral SQLite) prevent test-to-dev contamination.
- **Principle V (Privacy & Data Isolation)**: Playwright trace redaction hook strips `Authorization` and `Cookie` from captured traces.
- **Principle VI (Testing Excellence)**: This feature IS the E2E coverage layer for two stack packs; health-check smoke is honest v1.
- **Principle VII (Definition of Done)**: FR-014 verification is the "Tested" step — both packs scaffold + install + smoke-run before declaration flip.

**webServer pattern notes** (delivered state):
- Backend `webServer` entry: `bash -c "alembic upgrade head && uvicorn app.main:app --host 127.0.0.1 --port <BACKEND_TEST_PORT>"` — migration runs inline before boot.
- Frontend `webServer` entry: `npm run dev -- --host 127.0.0.1 --port <FRONTEND_TEST_PORT>`.
- Config flags: `retries: 2`, `workers: 1`, `trace: 'on-first-retry'`, `testIgnore: /\.template\.ts$/` (excludes adopter template from runner).
- Postgres pack (`fastapi-react`) DB isolation: dual guard — `TEST_DATABASE_URL` naming-prefix (must contain `test_` or `_test`) + equality guard vs `DATABASE_URL`. `SECRET_KEY` propagated via webServer env injection with test-only default.
- SQLite pack (`fastapi-react-local`) DB isolation: per-run ephemeral `/tmp/e2e-<uuid>.db` + `globalTeardown` cleanup.
- Bi-directional trace redaction: `page.route()` with `route.fetch` + `route.fulfill` strips `Authorization` / `Cookie` on requests and `Set-Cookie` on responses.

See [PRD 138](../../product/02_PRD/138-playwright-e2e-fastapi-stack-packs-2026-04-21.md) for product context, [plan.md](../../../specs/138-playwright-e2e-fastapi-stack-packs/plan.md) for full architectural ledger, and [contracts/](../../../specs/138-playwright-e2e-fastapi-stack-packs/contracts/) for fixture/config/smoke contracts.


### Feature 139: Delivery Means Verified, Not Documented

Flip `/aod.deliver` from documentation-first to verification-first. Hard-gate default (soft-gate warn removed), autonomous mode no longer overrides, AC-coverage pre-gate with strict Given/When/Then parser, bounded auto-fix loop with deterministic scope guard and heal-PR escalation, concurrency + crash-recovery (lockfile + sentinel), orchestrator halt signal via three channels, append-only JSONL audit log for opt-outs, stack-pack `test_paths` contract extension.

#### Components

- **Modified**: `.claude/skills/~aod-deliver/SKILL.md` (integration point — Steps 0 / 0.5 / 9a.5 / 9c.5 / 9d / 9e / 11); `.claude/agents/tester.md` (`mode: heal`); `.aod/templates/delivery-template.md` (three-section rewrite); `.aod/templates/spec-template.md` (AC format rule); `.aod/scripts/bash/stack-contract-lint.sh` (accept `test_paths`); `stacks/{nextjs-supabase,fastapi-react,fastapi-react-local}/STACK.md` (day-1 `test_paths`).
- **New bash libraries** (7, sourced by SKILL.md): `deliver-lock.sh`, `deliver-flag-parse.sh`, `ac-coverage-parse.sh`, `scope-guard.sh`, `heal-pr.sh`, `halt-signal.sh`, `audit-log.sh`.
- **New state/config**: `.aod/config.json` (schema v1, `deliver.heal_attempts` + `deliver.heal_max_timeout_multiplier`); `.aod/audit/deliver-opt-outs.jsonl` (append-only JSONL); `.aod/state/deliver-{NNN}.halt.json` (halt record); `.aod/state/deliver-{NNN}.state.json` (crash sentinel); `.aod/locks/deliver-{NNN}.lock` (advisory lock).
- **New docs**: `docs/architecture/02_ADRs/ADR-013-delivery-verification-first.md`, `docs/guides/AC_COVERAGE_MIGRATION.md`, `docs/guides/DELIVERY_HARD_GATE_MIGRATION.md`.
- **New tests** (5 per FR-010): `tests/unit/{deliver-flags,ac-coverage-gate,scope-guard}.test.sh`, `tests/integration/{heal-pr-escalation,auto-fix-loop}.test.sh`.

#### Data Flow

Unified gate decision path (interactive + autonomous):

```
/aod.deliver [--no-tests=<reason> | --require-tests (deprecated)]
  → Step 0: Flag parse (deliver-flag-parse.sh)
  → Step 0.5: Acquire lock (deliver-lock.sh) — exit 11 concurrent / exit 12 abandoned
  → Step 9a: Read stack-pack contract (e2e_command + test_paths)
  → Step 9a.5: AC-Coverage (ac-coverage-parse.sh) — strict Given/When/Then parse
  → Step 9b: Tester generates scenarios (tagged @US-NN-AC-N)
  → Step 9c: Run e2e_command
      pass  → Step 10
      fail  → Step 9c.5 Auto-Fix Loop (if heal_attempts > 0)
  → Step 9c.5: For N in 1..heal_attempts:
      tester (mode: heal) → proposed diff
      scope-guard.sh → allowed | rejected+reason
      allowed → apply + commit "e2e-heal(attempt N/M)" + re-run
      rejected OR exhausted → heal-pr.sh
  → Step 9d: Gate decision (unified — no autonomous override)
  → Step 9e: Halt signal if autonomous (halt-signal.sh)
      stdout  "Halted — heal-PR {URL} requires human review"
      file    .aod/state/deliver-{NNN}.halt.json (JSON-Schema draft-07)
      exit    10 (halted for review)
  → Step 10: Render delivery.md (3-section template: Test Scenarios / Execution Evidence / Manual Validation)
  → Step 11: Release lock + remove sentinel
```

Exit-code taxonomy (additive to PRD 130's 0-5): **0** success / **1** runtime error / **10** halted for review / **11** concurrent run / **12** abandoned heal (sentinel present on entry).

Three-channel halt protocol (FR-011): orchestrators can branch on any of stdout line, halt record at `.aod/state/deliver-{NNN}.halt.json`, or exit code 10.

#### Tech Stack

- **bash 3.2+** (macOS GPLv3 constraint, KB Entry 6): no `declare -A`, `readarray`, `yq`, `|&`, `${var^^}`, `${var,,}`.
- **jq** (PRD 130 baseline): compact JSON construction (`jq -c -n`) + parse with graceful defaults (`|| echo DEFAULT` per ADR-006).
- **gh** (GitHub CLI): heal-PR creation, idempotency lookup via `--label e2e-heal --json number,url,body` + local grep (not `--search` — unreliable HTML-comment tokenization).
- **POSIX awk/grep/sed**: scope-guard diff parsing, YAML block extraction (no `yq`), spec.md AC extraction.
- **git**: commit-per-attempt, heal-branch creation, rename/atomicity via write-to-tmp + `mv`.
- **markdown + Mermaid**: delivery-template.md, ADR-013.

No new runtime dependencies beyond PRD 130 baseline.

**Security invariants**: (1) No AOD skill may invoke `gh pr merge` on any PR labeled `e2e-heal` — grep-enforced. (2) Scope-guard authorization path is deterministic (5 static rules + diff file-path check); no LLM judgment. (3) Opt-out reasons bounded 10-500 chars for line-atomic JSONL appends.

See [PRD 139](../../product/02_PRD/139-delivery-verified-not-documented-2026-04-22.md) for product context, [plan.md](../../../specs/139-delivery-verified-not-documented/plan.md) for full architectural ledger, [contracts/](../../../specs/139-delivery-verified-not-documented/contracts/) for config/halt-record/audit-log/heal-PR-body/scope-guard/test_paths schemas.

---

### Feature 132: Fix `scripts/update.sh` Silent Exit 5 on Uncategorized Files

**Status**: Delivered (PR #152, merged 2026-04-23 at commit `47d89567` to `main`)

**Source**: [PRD 132](../../product/02_PRD/132-fix-update-sh-silent-exit-2026-04-23.md) (Rev 1.1, Approved) → [plan.md](../../../specs/132-fix-scripts-update/plan.md) (PM + Architect approved)

#### Components

This is a diagnostic fix; the "component" view is simply the call chain the fix restores.

```
Makefile:15  → scripts/update.sh  → aod_update_discover_phase()  → aod_template_category_for_path()  → (rc=0|rc=5|rc=1)
                     ↑                                                        │
                     │  set -e was aborting here                              │
                     │  on rc=5/rc=1                                          │
                     │                                                        │
                     └── error collector at                                   │
                         scripts/update.sh:929-934                            │
                         (previously unreachable)                             │
                                                                              │
                         Fix: set +e / set -e bracket at line 832             │
                         lets cat_rc=$? capture 5, branch to                  │
                         uncategorized collector, emit error on exit.         │
```

No new components. No data flow changes. No new tech stack entries.

#### Data Flow

No data flow changes. The fix is a control-flow restoration (the `set -e` abort was preventing the collector from running; the bracket restores the intended sequence).

#### Tech Stack

| Layer | Technology | Version | Already Present | Notes |
|-------|------------|---------|-----------------|-------|
| Shell | bash | 3.2.57 (macOS) / 5.x (Linux CI) | Yes | Project-wide compatibility minimum (KB Entry 6). |
| Test | bats-core | existing | Yes | Used for rc=5 + rc=1 fixture tests. |
| JSON | jq | existing | Yes | Indirectly used by harness; no new calls in this feature. |
| VCS | git | existing | Yes | Used by harness fixture seeding; no new usage. |

No new dependencies introduced.

---

### Feature 134: update-bootstrap-placeholder-migration

**Status**: Delivered (2026-04-25, branch `134-update-bootstrap-placeholder-migration`)

#### Components

The feature extends three existing components without adding a new top-level component:

- **`scripts/update.sh`** (adopter CLI) — gains 2 subcommand branches (`--bootstrap`, `--check-placeholders`) in its argument parser. Dispatch delegates to new library modules based on the flag.
- **`.aod/scripts/bash/bootstrap.sh`** (NEW library module) — owns: overwrite-guard (FR-002-a); PLSK-fingerprint guard (FR-002-b); upstream URL resolution (FR-003); shallow-clone orchestration via F129 fetch helper (FR-004/005); auto-discovery heuristics (FR-006); confirmation UX (FR-007); atomic writes via F129 helpers (FR-004, FR-008).
- **`.aod/scripts/bash/check-placeholders.sh`** (NEW library module) — owns: scan scope computation from `git ls-files` minus exclusion list (FR-011); detection pattern match (FR-012); canonical-set filter (FR-013); `LEGACY_MAP` definition + migration-table emitter (FR-015); flag-only enforcement (FR-016).
- **`docs/guides/DOWNSTREAM_UPDATE.md`** (existing doc) — gains a new "Bootstrap (pre-F129 adopters)" second-level section; three TODO pointers at lines 51/115/186 replaced with forward links.
- **`Makefile`** (existing) — gains one new target: `update-bootstrap`.

#### Data Flow

**Bootstrap** (`make update-bootstrap` → `scripts/update.sh --bootstrap` → `bootstrap.sh`):

```
Invocation → guard_check_overwrite → guard_check_plsk_fingerprint → resolve_upstream_url
           → aod_template_fetch_upstream (F129; staging dir + trap EXIT)
           → compute_version_fields (sha, version, updated_at, manifest_sha256)
           → auto_discover_8 + always_prompt_4_or_env → confirm_summary
           → aod_template_init_personalization (F129; writes .aod/personalization.env FIRST)
           → aod_template_write_version_file (F129; writes .aod/aod-kit-version LAST — atomic transaction commit)
```

**Scanner** (`make update --check-placeholders` → `check-placeholders.sh`):

```
Invocation → compute_scan_scope (git ls-files minus exclusions) → scan_files (pattern {{[A-Z_][A-Z0-9_]*}})
           → filter_canonical (subtract AOD_CANONICAL_PLACEHOLDERS) → emit_findings (<path>:<line>: {{<name>}})
           → emit_migration_table (versioned LEGACY_MAP) → exit 0 clean / 13 drift
```

Every helper call site is bracketed with `set +e` / `set -e` (FR-017) per F132 precedent. `trap EXIT` guarantees staging dir cleanup on every terminal path.

#### Tech Stack

| Layer | Technology | Version | Already Present | Notes |
|-------|------------|---------|-----------------|-------|
| Shell | bash | 3.2.57 (macOS) / 5.x (Linux CI) | Yes | Constraint driver (KB Entry 6). Parallel arrays, no `declare -A`. |
| Git | git | ≥ 2.30 | Yes | Reused via F129 `aod_template_fetch_upstream`. No new git invocations outside helper. |
| Hash | shasum | BSD/GNU | Yes | `shasum -a 256` for `manifest_sha256` (local file read). |
| Atomic writes | F129 helpers | existing | Yes | `aod_template_write_version_file` + `aod_template_init_personalization` reused unchanged. |
| Interactive prompt | F129 `aod_update_confirm` | existing | Yes | Reused for FR-007 contract consistency. |
| Test | bats-core | existing | Yes | 1 new BATS file covering SC-001..SC-006 + F132 prevention-rule fixture. |
| Optional CLI | gh | any | Optional | Used in auto-discovery; degrades to prompt when absent. |

No new dependencies introduced. Feature is strictly additive — all infrastructure pre-existed from F129/F132/F139.

#### Architectural Decisions

- **Exit code 13 (placeholder drift) — non-colliding additive allocation**: The scanner's drift-exit code is allocated under the same single-taxonomy principle [ADR-013](../02_ADRs/ADR-013-delivery-verification-first.md) established for F139 — additive, non-repurposing, gap-aware. Pre-existing taxonomy occupants: F129 update transaction (0–5), F139 delivery (10–12). 13 was chosen as the next non-colliding integer past F139's reserved range. Plan-phase verification: `grep -rn "exit 13\|return 13" scripts/ .aod/scripts/` returned zero matches at 2026-04-24, confirming live non-collision. No new ADR was opened: ADR-013 already governs the allocation philosophy for the kit's CLI exit-code namespace, and F134's choice is a direct application rather than a new policy.
- **F132 rc-capture bracket as canonical pattern (FR-017)**: Every helper call site in `bootstrap.sh` and `check-placeholders.sh` is bracketed `set +e ... set -e` so `local rc=$?` captures helper exits before `set -e` can abort the parent. F132 introduced the bracket to fix one site; F134 elevates it to a recurring requirement enforced via FR-017 across two new modules. Documented as a first-class pattern in [03_patterns/README.md](../03_patterns/README.md#pattern-set-e-bracket-for-rc-capture-under-strict-shell). `|| true` is explicitly NOT a substitute on bash 3.2 — it clobbers `$?` to zero before the rc-capture line runs.
- **Two new library modules under `.aod/scripts/bash/`, dispatch inline in `update.sh`**: Mirrors F129's separation between adopter-facing CLI orchestrator (`scripts/update.sh`) and library modules (`.aod/scripts/bash/template-*.sh`). Keeps `update.sh` from exceeding comprehensible size; isolates new logic for BATS unit testing; preserves the single adopter-facing script UX. Inlining everything in `update.sh` was rejected as a violation of the F129 boundary; a second top-level script (`scripts/bootstrap-migration.sh`) was rejected as bad UX (adopters expect one entry point).
- **No global `--accept-all` escape hatch (FR-006)**: Per-field env vars (`AOD_BOOTSTRAP_<FIELD>=<value>`) required for every always-prompt and every low-confidence auto-discovered field. A global override means one typo writes wrong values to 12 placeholders; per-field forces deliberate specification and makes the error message point at the exact missing field. This is the deliberate inverse of the F139 `--no-tests=<reason>` posture: F139's escape applies to a single boolean gate; F134's would apply to 12 independent string values, and the blast radius asymmetry justifies the strictness.
- **`LEGACY_MAP` co-located with consumer (`check-placeholders.sh`)**: Single source of truth for migration guidance; adding a new legacy alias is a parallel-array update beside `AOD_CANONICAL_PLACEHOLDERS`. Externalizing to a separate config file was rejected — bash 3.2 has no native YAML parser and adding `yq` is forbidden by the kit's stack constraints (CI runs `bash:3.2` Docker; KB Entry 6).
- **`PROJECT_URL` remains legacy-only**: Mapped to "no canonical — pending Issue #68" in `LEGACY_MAP`; not promoted to a 13th canonical placeholder. F129 contract locks the canonical set at 12; promotion requires its own PRD + helper update. The scanner surfaces the drift to maintainers; canonical expansion is out-of-scope for F134.

See [plan.md](../../../specs/134-update-bootstrap-placeholder-migration/plan.md) Phase 0 §Decisions Made for the full alternatives-considered ledger and rejection rationales.


---

### Feature 158: anti-rationalization-tables

**Status**: Delivered 2026-05-01 (Issue #158, PR #159 squash-merged as `75004cd`). Triple sign-off (PM ✓ APPROVED, Architect ✓ APPROVED rev2, Team-Lead ✓ APPROVED) preceded build; pre-deliver retro at `specs/158-anti-rationalization-tables/retro.md` confirms all 4 POSIX-portable verification audits zero-output across 18 files; bundle metrics 80 Rationalizations + 103 Red Flags total; net diff 341 additions / 0 deletions (strictly additive — SC-008 PASS).

**Spec**: [specs/158-anti-rationalization-tables/spec.md](../../../specs/158-anti-rationalization-tables/spec.md) | **Plan**: [specs/158-anti-rationalization-tables/plan.md](../../../specs/158-anti-rationalization-tables/plan.md) | **Retro**: [specs/158-anti-rationalization-tables/retro.md](../../../specs/158-anti-rationalization-tables/retro.md) | **PRD**: [docs/product/02_PRD/158-anti-rationalization-tables-2026-04-29.md](../../product/02_PRD/158-anti-rationalization-tables-2026-04-29.md)

#### Components

The feature has no runtime components. The work is markdown content additions to 18 existing in-scope files plus auxiliary CHANGELOG / CLAUDE.md updates. Conceptually the work groups into:

1. **Target files (18, owned classification)**: 11 commands at `.claude/commands/aod.{spec,plan,project-plan,tasks,build,deliver,document,clarify,analyze,define,discover}.md` + 7 skills at `.claude/skills/~aod-{spec,plan,project-plan,build,deliver,define,discover}/SKILL.md`. F129 manifest verification (2026-04-29) confirms both trees are `owned` opaque overwrites — clean adopter sync via `make update`.
2. **Section format contracts**: `## Common Rationalizations` (2-column markdown table; ≤15-word first-person Rationalizations; ≤25-word concrete-consequence Realities; banned-phrase list) and `## Red Flags` (markdown bullet list; one-line observable behaviors only). Both H2 headers MUST be followed by exactly one blank line (the empty-line anchor contract — D-002).
3. **Content split rules**: command-vs-skill content domain split (commands host invocation-level rationalizations; skills host execution-level rationalizations); placement default + single exception; voice template; cross-file dedupe rules.
4. **Verification + delivery surface**: 4 POSIX-portable inline grep/awk audits (no `-P`, no `-z`, no PCRE — works on BSD/GNU/BusyBox grep); CHANGELOG `[Unreleased]` entry with adopter-framing format; single-line CLAUDE.md `## Recent Changes` attribution to addyosmani/agent-skills source.

#### Data Flow

The "data" is markdown content; the "flow" is the authorship + verification sequence under one author in a single sequential phase (FR-006 — content cohesion preference, not technical necessity since 18 independent files have zero file-level race conditions):

```
[Author] reads in-scope file N
    ↓
[Author] identifies file-specific gates / markers / steps via grep
    ↓
[Author] runs per-file pre-commit grep self-check on every cited file:line
    ↓ (R-001 defense-in-depth at file boundary)
[Author] drafts Rationalization quotes (≤15 words, first-person, in quotes)
    ↓
[Author] drafts Reality columns citing concrete consequences (≤25 words, no appeal-to-authority)
    ↓
[Author] drafts Red Flag bullets (observable behaviors, one line each)
    ↓
[Author] inserts at FR-005 placement (end-of-file for 17 files; AFTER line 798 / BEFORE line 800 for ~aod-define/SKILL.md ONLY)
    ↓
[Author] commits file N via Edit tool
    ↓ (sequential — FR-006; no parallel waves; AC-006-1 enforces zero [P] markers in tasks.md)
... repeat for files 1..11 (commands phase)
    ↓
[Architect] (strongly recommended) spot-check on 11 commands' tables
    ↓ (R-001 mitigation at commands→skills boundary; opt-out with recorded reason per AC-009-2)
... repeat for files 12..18 (skills phase)
    ↓
[Author] runs cross-file dedupe pass (sort + uniq -d on extracted Rationalization quotes)
    ↓
[Author] runs voice consistency pass (read all 18 columns end-to-end, verify shared voice properties)
    ↓
[Author] runs 4 POSIX-portable audits inline:
  - grep -L "^## Common Rationalizations$" <files> (coverage-1; expect zero output)
  - grep -L "^## Red Flags$" <files> (coverage-2; expect zero output)
  - awk '/^## Common Rationalizations$/{getline n; if(n!="") print FILENAME}' (anchor-1; expect zero output)
  - awk '/^## Red Flags$/{getline n; if(n!="") print FILENAME}' (anchor-2; expect zero output)
    ↓
[Author] adds CHANGELOG [Unreleased] entry with adopter-framing block
    ↓
[Author] adds CLAUDE.md ## Recent Changes single-line F158 attribution
    ↓
[/aod.deliver] runs AC-coverage check + DoD validation
```

#### Tech Stack

| Concern | Choice | Rationale |
|---------|--------|-----------|
| Content format | Markdown (CommonMark + GFM) | Native to AOD command/skill files. No new format. |
| Citation lookup | POSIX `grep` + POSIX `awk` | Already hard dependencies of AOD scripts. Portable across BSD (macOS) + GNU (Linux/CI) + BusyBox. NO PCRE, NO `-P`, NO `-z`. |
| Edit tool | Anthropic Claude `Edit` (string replacement) | Surgical insertion at end-of-file or after named anchor. Minimizes risk of accidentally rewriting unrelated content. |
| Verification | Inline POSIX one-liners in tasks.md | Per AD-006: no new permanent script. Phase 2 may revisit if a CI gate ships. |
| Voice template | PRD pre-drafted samples (FR-004-A) + plan-phase corrected `aod.spec` Reality (AD-004 second-pass) | Single source of truth for the bundle's prosodic voice. |
| Adopter sync | F129 `make update` (owned opaque overwrite) | Existing template-update mechanism. F129 conflict-resolution path applies for adopters with local edits. |

No new dependencies introduced. Feature is strictly additive markdown — all infrastructure pre-existed.

#### Architectural Decisions

- **AD-001 (sequential single-author execution)**: 18 file edits run sequentially under one author in one `/aod.build` session. Tasks.md MUST encode this as a single phase with zero parallel-wave markers. Rationale is content-cohesion preference (voice consistency across the bundle), not technical necessity — 18 independent files have zero file-level race conditions. Required by Team-Lead PRD review.
- **AD-002 (single placement exception — `~aod-define/SKILL.md` only)**: 17 files use end-of-file placement; `~aod-define/SKILL.md` uses post-pitfalls placement. Precise insertion: AFTER line 798 (closing `---` separator of existing `## Common PRD Pitfalls` block), BEFORE line 800 (next H2 `## Templates & Examples`). Verified by `grep -n "^## " .claude/skills/~aod-define/SKILL.md` at plan-revision time (2026-04-29).
- **AD-003 (POSIX-portable empty-line anchor contract — D-002 plan-revised)**: Both H2 headers MUST be followed by exactly one blank line. Verification path is POSIX-portable: `grep -L "^## <header>$"` for coverage + POSIX awk one-liner for blank-line anchor verification. NO `-P`, NO `-z`, NO PCRE. Original spec-phase draft used `grep -Pzo` which BSD grep on macOS rejects (`-P` not supported); architect plan-review caught the portability defect before tasks.md generation.
- **AD-004 (citation correction propagation — D-001 second-pass)**: PRD's `aod.spec` Reality draft (`"Markers are F139 hard gates — they fail /aod.deliver"`) was twice-corrected. First-pass spec-phase D-001 cited `~aod-spec/SKILL.md:77` and "Step 3.4" — architect plan-review found two factual errors (line 77 hosts a checkbox not a gate; "Step 3.4" lives in the command file not the skill). Second-pass plan-revision cites `.claude/commands/aod.spec.md:177` (the actual `### 3.4 Quality Validation` H3 header — verified by `grep -n` at plan-revision time). Aligns with AD-005 layer split.
- **AD-005 (commands-vs-skills layer split)**: Command files host invocation-level rationalizations (flags, modes, routing, arguments); skill files host execution-level rationalizations (steps, gates, sign-offs, artifacts). 5 worked borderline examples included in plan.md AD-005 to scaffold judgment calls. Pattern: "where does this *decision* happen — at invocation time, or partway through the skill executing?"
- **AD-006 (no helper script — inline grep/awk audits)**: The 4 verification audits are documented as one-liner POSIX grep + awk commands inline in tasks.md. No new file in `.aod/scripts/bash/`. Q-003 resolution.
- **AD-007 (architect spot-check at commands→skills boundary — strongly recommended)**: Tasks.md includes an architect spot-check task between command file 11 and skill file 1. Per R-001 likelihood upgrade (Medium → High, based on three drift instances across three governance phases), the spot-check is now strongly recommended; opt-out framing preserved with recorded reason.
- **R-001 likelihood upgrade (Medium → High)**: Three citation drift instances caught across three review phases (PRD review: build-side `--no-tests` syntax mis-attribution; spec phase D-001: `/aod.deliver` mis-attribution; plan-review: D-001's own correction cited wrong file/line). One-per-phase rate suggests base rate is High, not Medium. Mitigation: (a) AD-007 strongly-recommended spot-check; (b) per-file pre-commit grep self-check at file boundary (Audit 5, defense-in-depth); (c) bundle-level grep audits (Sub-phase E).

See [specs/158-anti-rationalization-tables/plan.md](../../../specs/158-anti-rationalization-tables/plan.md) for the full AD-001..AD-007 alternatives-considered ledger and rejection rationales.

#### Delivered Outcomes (2026-05-01)

| Metric | Target | Actual | Status |
|---|---|---|---|
| Coverage (`## Common Rationalizations`) | 18 / 18 files | 18 / 18 | PASS (SC-001) |
| Coverage (`## Red Flags`) | 18 / 18 files | 18 / 18 | PASS (SC-001) |
| Rationalization rows / file | 2–8 (FR-001) | range 3–6, mean 4.4 | PASS (FR-001 / AC-001-2) |
| Red Flag bullets / file | ≥3 (FR-002) | range 4–7, mean 5.7 | PASS (FR-002 / AC-002-2) |
| POSIX-portable forward-CI audits | 4 / 4 zero-output | 4 / 4 zero-output (Wave 7 + Wave 9 re-run) | PASS (SC-003, AD-003) |
| Citation drift instances at retro | 0 residual | 0 residual (40 surfaced + corrected during build) | PASS (SC-002) |
| Layer-split violations (AD-005) | 0 | 0 (architect spot-check T016 + Wave 5 zero-violations on first draft) | PASS (SC-005) |
| Cross-file dedupe (FR-007) | 0 verbatim duplicates | 0 (1 caught + specialized at Wave 6 T025) | PASS (SC-006) |
| Voice consistency (FR-006) | 0 word-count overflows | 35 MINOR caps remediated Wave 4 T017 (Strategy A semicolon-pivot) → 0 residual | PASS (SC-004) |
| Additive-only diff | 0 deletions | +341 / -0 | PASS (SC-008) |
| Architect spot-check (FR-009) | Encoded + executed | Encoded as task; executed at commands→skills boundary | PASS (SC-010) |
| Adopter docs (FR-008, FR-010) | CHANGELOG + CLAUDE.md | Both landed Wave 8 T032 + T033 | PASS (SC-009) |

**Architectural decisions actually applied** (vs. plan):
- AD-001 (sequential single-author): held — zero parallel `[P]` markers across all wave commits.
- AD-003 (POSIX-portable verification): held — 4 audits use only POSIX BRE + `awk` one-liners; no `-P`/`-z`/PCRE flags. Verified working on BSD grep (macOS) at retro time.
- AD-005 (commands-vs-skills layer split): held — every command-file Rationalization cites invocation-level concerns (flags, modes, routing, arguments); every skill-file Rationalization cites execution-level concerns (steps, gates, sign-offs, artifacts). 1 cross-layer verbatim duplicate caught + specialized (Wave 6 T025) preserves the split.
- AD-007 (architect spot-check at commands→skills boundary): executed — Wave 4 T016 invoked architect on the 11 commands; surfaced 35 voice-cap MINOR violations; T017 remediated all 35 via Strategy A semicolon-pivot; D-001 row at `aod.spec.md:338` preserved verbatim (exempt from compression).

**R-001 likelihood validation**: Plan upgraded R-001 (citation drift base rate) from Medium → High. Build confirmed: 3 cited-gate drift instances surfaced during the bundle (1 D-001 cell that shifted line numbers, 1 cross-file Rationalization duplicate, 4 banned-phrase escapes). All 3 caught + corrected by the layered defense (AD-007 spot-check + Audit 5 per-file pre-commit grep + bundle-level grep audits). The High base rate is now validated empirically and should be the assumed default for any future text-content bundle of similar scale.

**Behavioral primer pattern** documented for reuse: see [03_patterns/README.md `Anti-Rationalization Tables — Behavioral Primer for Agent-Loaded Files`](../03_patterns/README.md#pattern-anti-rationalization-tables-behavioral-primer).

### Feature 169: split-readme-marketing-and-scaffold

**Plan**: [specs/169-split-readme-into/plan.md](../../../specs/169-split-readme-into/plan.md) | **Status**: APPROVED_WITH_CONCERNS (PM + Arch)

#### Components

```
+-----------------------------+         +-------------------------------------+
| Root README.md (user|)      |         | .aod/scaffold/README.md (owned|)    |
| Hand-authored marketing.    |         | Token-bearing scaffold.             |
| No {{...}} tokens.          |         | Verbatim copy of pre-change root.   |
| Maintainer edits manually.  |         | Refreshed verbatim by /aod.update.  |
+-----------------------------+         +-------------------------------------+
            |                                            |
            v                                            v
   GitHub landing page                         Used by init.sh
   (visible to public)                         (one-shot bootstrap)
```

| File | Role | Manifest |
|------|------|----------|
| `README.md` | Hand-authored marketing landing page | `user|` (silent skip on `/aod.update`) |
| `.aod/scaffold/README.md` | Token-bearing bootstrap template | `owned|` (verbatim refresh) |
| `scripts/init.sh` | Adds guarded scaffold-copy block before `replace_in_files` | (script) |
| `scripts/extract.sh` | `MANIFEST_DIRS` extended with `.aod/scaffold` | (script) |
| `docs/guides/DOWNSTREAM_UPDATE.md` | New "README Lifecycle" section | (docs) |

#### Data Flow

```
   Maintainer edits     |  Adopter clones    |  Adopter runs           |  Adopter runs
   root README.md       |  AOD Kit           |  make init              |  /aod.update
        |               |        |           |        |                |        |
        v               |        v           |        v                |        v
   /aod.sync-upstream   |   GitHub renders   |   init.sh checks        |   update.sh reads
        |               |   marketing copy   |   .aod/scaffold/        |   manifest:
        v               |   (no tokens)      |   README.md exists      |   - root README user|
   extract.sh --sync    |                    |        |                |     -> silent skip
        |               |                    |        v                |   - scaffold owned|
        v               |                    |   cp scaffold root      |     -> verbatim refresh
   ../agentic-oriented- |                    |        |                |
   development-kit/     |                    |        v                |
   README.md            |                    |   replace_in_files      |
   .aod/scaffold/       |                    |   substitutes tokens    |
   README.md            |                    |        |                |
                        |                    |        v                |
                        |                    |   root README           |
                        |                    |   contains adopter      |
                        |                    |   project name          |
```

#### Tech Stack

- **Bash 3.2** (init.sh, extract.sh — macOS/Linux compatible)
- **Markdown** (README files, DOWNSTREAM_UPDATE.md)
- **Manifest DSL** (`.aod/template-manifest.txt` format: `{category}|{path}` per line)
- **bats-core** v1.x (regression test for post-init substitution)
- **No new dependencies** — all tools already in AOD Kit toolchain.
