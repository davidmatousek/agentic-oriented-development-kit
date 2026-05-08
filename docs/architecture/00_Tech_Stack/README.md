# Technology Stack - {{PROJECT_NAME}}

**Last Updated**: {{CURRENT_DATE}}
**Owner**: Architect

---

## Overview

This document defines the technology stack for {{PROJECT_NAME}}.

---

## Frontend

**Framework**: {{FRONTEND_FRAMEWORK}}
- Version: {{VERSION}}
- Why: {{RATIONALE}}

**UI Library**: {{UI_LIBRARY}}
- Examples: React, Vue, Svelte, Angular

**Styling**: {{STYLING_APPROACH}}
- Examples: Tailwind CSS, CSS Modules, Styled Components

**State Management**: {{STATE_MANAGEMENT}}
- Examples: Redux, Zustand, Jotai, Context API

**Build Tool**: {{BUILD_TOOL}}
- Examples: Vite, Webpack, Parcel

---

## Backend

**Runtime**: {{BACKEND_RUNTIME}}
- Examples: Node.js, Python, Go, Rust

**Framework**: {{BACKEND_FRAMEWORK}}
- Examples: Fastify, Express, FastAPI, Gin

**Language**: {{BACKEND_LANGUAGE}}
- Version: {{VERSION}}

**API Style**: {{API_STYLE}}
- Examples: REST, GraphQL, gRPC

---

## Database

**Primary Database**: {{DATABASE_TYPE}}
- Examples: PostgreSQL, MySQL, MongoDB

**Version**: {{VERSION}}
**Provider**: {{DATABASE_PROVIDER}}
- Examples: Self-hosted, AWS RDS, Neon, PlanetScale

**ORM/Query Builder**: {{ORM}}
- Examples: Prisma, Drizzle, TypeORM, SQLAlchemy

---

## Infrastructure

**Hosting Platform**: {{HOSTING_PLATFORM}}
- Examples: Vercel, AWS, Google Cloud, Railway

**Container Runtime**: {{CONTAINER_RUNTIME}}
- Examples: Docker, Kubernetes, None (serverless)

**CI/CD**: {{CICD_PLATFORM}}
- Examples: GitHub Actions, GitLab CI, CircleCI

---

## Monitoring & Observability

**Logging**: {{LOGGING_SOLUTION}}
**Metrics**: {{METRICS_SOLUTION}}
**Error Tracking**: {{ERROR_TRACKING}}

---

## Development Tools

**Package Manager**: {{PACKAGE_MANAGER}}
**Code Quality**: {{LINTING_TOOLS}}
**Testing**: {{TESTING_FRAMEWORKS}}

---

## AOD Kit Internal Tooling

These are tools used by the AOD Kit itself (not the adopter's application stack).

### Shell Scripts

**Bash 3.2** (macOS default `/bin/bash`)
- All `.aod/scripts/bash/*.sh` files AND `scripts/*.sh` files must be Bash 3.2 compatible
- Why: macOS ships Bash 3.2.57 due to GPLv3 licensing; portability is mandatory
- Constraints: No associative arrays (`declare -A`), no case modification (`${var^^}`), no `readarray`/`mapfile`, no `globstar` (`shopt -s globstar`), no `&>` / `|&`
- **Permitted**: Parameter expansion `${str//pattern/replacement}` (bash 3.2 supports this — used for placeholder literal-replace in Feature 129)
- **Defensive pattern — `set +e` / `set -e` bracket around command substitutions** (precedent: `scripts/check-manifest-coverage.sh:115-118`; applied: `scripts/update.sh:832` via Feature 132; enforced via FR-017 across both new F134 modules at `.aod/scripts/bash/bootstrap.sh` and `.aod/scripts/bash/check-placeholders.sh`): When a script runs under `set -euo pipefail` and needs to capture a non-zero helper return code via `local rc=$?`, the `set -e` must be temporarily disabled across the command substitution. Otherwise bash exits **before** `$?` is captured and the error-collector branch becomes unreachable. `|| true` is **NOT** a valid substitute on bash 3.2 — it clobbers `$?` to zero. F132 introduced the bracket to fix one site; F134 promoted it to a recurring requirement (FR-017) and documented it as a first-class kit pattern. See Feature 132 PRD/plan, [F134 plan.md](../../../specs/134-update-bootstrap-placeholder-migration/plan.md) §FR-017, and [03_patterns/README.md `set +e` bracket](../03_patterns/README.md#pattern-set-e-bracket-for-rc-capture-under-strict-shell).
- **CI enforcement** (Features 128, 129, 130): Three workflows now mirror the same bash:3.2 Docker pattern — catches bash-4+ regressions in the validators themselves even though GitHub's `ubuntu-latest` runner ships bash 5.x:
  - `.github/workflows/manifest-coverage.yml` — runs `scripts/check-manifest-coverage.sh` (template-file ownership manifest)
  - `.github/workflows/extract-coverage.yml` — runs `scripts/check-extract-coverage.sh` (extraction classification snapshot)
  - `.github/workflows/stack-contract.yml` — runs `.aod/scripts/bash/stack-contract-lint.sh --all` (stack pack test contract schema)

  All three workflows SHA-pin `actions/checkout`, use `permissions: contents: read`, and set `concurrency.cancel-in-progress: true`. The `stack-contract.yml` workflow adds path filters (`stacks/**/STACK.md`, the lint script, the workflow file itself) to avoid running on unrelated PRs; fetch-depth stays at 1 because the lint reads only working-tree files.

**Key scripts**:
| Script | Purpose | Added |
|--------|---------|-------|
| `.aod/scripts/bash/logging.sh` | Simple logging utility for timestamped log entries; provides `aod_log` function with configurable output path and graceful error handling | Feature 049 |
| `.aod/scripts/bash/run-state.sh` | Atomic read/write/validate for orchestrator state (`.aod/run-state.json`); includes compound helpers for incremental reads and governance caching | Feature 022, extended Feature 030 |
| `.aod/scripts/bash/github-lifecycle.sh` | GitHub Issue label management for stage transitions; Projects board sync (`aod_gh_reconcile_board`, `aod_gh_add_to_board`, `aod_gh_move_on_board`); `AOD_BOARD` env var support and board cache validation; **public `aod_gh_setup_labels()` for one-shot stage-label bootstrap** (F172, callable via subshell-source pattern from `init.sh`); strict title-pinned board discovery — no greedy "AOD Backlog" fallback (F172) | Pre-022, extended Features 121, 172 |
| `.aod/scripts/bash/backlog-regenerate.sh` | Regenerate product backlog from GitHub Issues; triggers board reconciliation after BACKLOG.md write (guarded by `aod_gh_check_board`) | Pre-022, extended Feature 121 |
| `.aod/scripts/bash/template-manifest.sh` | Line-delimited manifest parser + category lookup + glob match + precedence resolution (`while read` + `case`, bash 3.2); powers `/aod.update` | Feature 129 |
| `.aod/scripts/bash/template-validate.sh` | Path sanitization (`..`, `~`, absolute-path reject), symlink rejection, residual placeholder scan; assertion helpers used by both update and sync flows | Feature 129 |
| `.aod/scripts/bash/template-json.sh` | JSON output helpers, `schema_version: 1.0` | Feature 129 |
| `.aod/scripts/bash/template-git.sh` | HTTPS upstream fetch (standalone `git clone --depth=1`), diff computation, retag detection, same-filesystem device-number helper (`stat -f %d` on BSD / `stat -c %d` on GNU) | Feature 129 |
| `.aod/scripts/bash/template-substitute.sh` | 12-placeholder canonical list (single source of truth, refactored from `init.sh:117-161`) + bash parameter-expansion literal-replace + `.aod/personalization.env` loader | Feature 129 |
| `.aod/scripts/bash/stack-contract-lint.sh` | Bash 3.2 fenced-YAML parser + schema validator for stack pack test contracts (3-key schema: `test_command` + XOR(`e2e_command`, `e2e_opt_out`)). Stable exit-code taxonomy (0/1/2/3/4/5); single-file and `--all` repo-wide modes; `awk` range match on HTML sentinel comments for block extraction; compiler-diagnostic stderr format (`[aod-stack-contract] <file>:<line>: <SEVERITY>: <message>`); inline `CONTENT_PACKS=()` allowlist for content-only packs (e.g., knowledge-system) | Feature 130 |
| `.aod/scripts/bash/bootstrap.sh` | Bootstrap subcommand implementation invoked from `scripts/update.sh --bootstrap`. Owns: overwrite-guard (FR-002-a) and PLSK-fingerprint guard (FR-002-b); upstream URL resolution via `CANONICAL_URL` extraction or env (FR-003); shallow-clone orchestration via F129 `aod_template_fetch_upstream`; 8-auto + 4-prompt placeholder discovery (FR-006); confirmation UX via F129 `aod_update_confirm` (FR-007); atomic writes via F129 `aod_template_init_personalization` + `aod_template_write_version_file` (FR-004, FR-008); F132 rc-capture brackets at every helper call site (FR-017) | Feature 134 |
| `.aod/scripts/bash/check-placeholders.sh` | Placeholder drift scanner invoked from `scripts/update.sh --check-placeholders`. Owns: scope computation from `git ls-files` minus exclusion list (FR-011); detection pattern `{{[A-Z_][A-Z0-9_]*}}` (FR-012); canonical-set filter against `AOD_CANONICAL_PLACEHOLDERS` (FR-013); `LEGACY_MAP` definition + version-stamped migration-table emitter (FR-015); flag-only enforcement — zero mutation of adopter files under any circumstance (FR-016); exit code 13 on drift (non-colliding with F129 0–10 and F139 10–12, allocated under [ADR-013](../02_ADRs/ADR-013-delivery-verification-first.md) additive-only philosophy) | Feature 134 |

**Maintainer-facing CLI entry points** (not libraries — executed directly):
| Script | Purpose | Added |
|--------|---------|-------|
| `scripts/update.sh` | Adopter-facing CLI — `make update` / `/aod.update` entry point. Reads manifest, fetches upstream, stages, applies atomically. Embeds hardcoded user-owned guard list (FR-007) for tamper resistance. **Feature 134 added** two additive, mutually-exclusive subcommand branches: `--bootstrap` (delegates to `.aod/scripts/bash/bootstrap.sh`; also reachable via `make update-bootstrap`) and `--check-placeholders` (delegates to `.aod/scripts/bash/check-placeholders.sh`; exit 13 on drift). Default `make update` happy path is unchanged. | Feature 129 (extended Feature 134) |
| `scripts/check-manifest-coverage.sh` | Bash 3.2 validator — iterates `git ls-files`, asserts each file is categorized in the manifest. Runs in CI (Docker `bash:3.2` to catch bash-4+ regressions in the validator itself) and optionally as a pre-commit hook | Feature 129 |
| `scripts/extract.sh` | Maintainer-facing `user → PLSK` extraction pipeline. Directory allow-list (`MANIFEST_DIRS` + `MANIFEST_ROOT_FILES`), externalized content-reset templates under `scripts/reset-templates/`, five-layer defense bundle (allow-list / residual scan / deny-list regex / safe-path assert / fail-loud template existence) | Pre-128 (refactored F128) |
| `scripts/check-extract-coverage.sh` | Bash 3.2 validator — iterates `git ls-files`, classifies each file against `MANIFEST_DIRS` + `MANIFEST_ROOT_FILES` + `.extractignore`, diffs against `scripts/extract-classification.txt` snapshot. Runs in CI (Docker `bash:3.2`) to catch manifest ↔ tracked-file drift at PR time | Feature 128 |
| `scripts/sync-upstream.sh` | Legacy maintainer-only sync helper. Non-interactive flags (`--yes`, `--dry-run`, etc.) added to support CI/automation paths; no-flags default preserves interactive prompts | Pre-128 (extended F128) |

### CLI Dependencies

| Tool | Required By | Purpose | Install |
|------|-------------|---------|---------|
| `jq` | `run-state.sh` | JSON parsing and atomic state manipulation | `brew install jq` (macOS) / `apt-get install jq` (Linux) |
| `gh` | `github-lifecycle.sh`, `run-state.sh` (optional), `scripts/init.sh` (optional) | GitHub Issue/label management, Projects board sync and reconciliation, board creation during init | `brew install gh` / `gh auth login` |

**Note**: `gh` degrades gracefully -- the orchestrator falls back to artifact-only detection when `gh` is unavailable or unauthenticated. Similarly, `scripts/init.sh` skips GitHub Projects board creation when `gh` is missing, unauthenticated, or lacks the `project` OAuth scope, reporting status in the init summary with remediation guidance.

### Template Variables

Substitution logic is centralized in `.aod/scripts/bash/template-substitute.sh` (Feature 129 — single source of truth, canonicalized from `init.sh:117-161`). Both `scripts/init.sh` (first install) and `scripts/update.sh` (subsequent updates) source the same library and apply the same 12 canonical placeholders.

**Canonical placeholders** (12 — defined in `template-substitute.sh::CANONICAL_PLACEHOLDERS`):

| Placeholder | Replaced With | Mutability |
|-------------|---------------|------------|
| `{{PROJECT_NAME}}` | Adopter's project name (init prompt) | Immutable after init |
| `{{PROJECT_DESCRIPTION}}` | Short project description (init prompt) | Immutable |
| `{{GITHUB_ORG}}` | GitHub org or user (init prompt) | Immutable |
| `{{GITHUB_REPO}}` | Repo name (init prompt) | Immutable |
| `{{AI_AGENT}}` | Primary AI agent (init prompt, default `claude`) | Immutable |
| `{{TECH_STACK}}` | Primary tech stack label (init prompt) | Immutable |
| `{{TECH_STACK_DATABASE}}` | Database tech (init prompt) | Immutable |
| `{{TECH_STACK_VECTOR}}` | Vector store (init prompt) | Immutable |
| `{{TECH_STACK_AUTH}}` | Auth tech (init prompt) | Immutable |
| `{{RATIFICATION_DATE}}` | Constitution ratification date (init-time snapshot) | **Init-only — never recomputed by `/aod.update`** |
| `{{CURRENT_DATE}}` | Initial install date (init-time snapshot) | **Init-only — never recomputed by `/aod.update`** |
| `{{CLOUD_PROVIDER}}` | Cloud provider (init prompt, default "Not yet defined") | Editable by adopter |

**Substitution strategy** (Feature 129 architectural decision): **bash parameter expansion** `${str//pattern/replacement}` — truly literal, bash 3.2 compatible. `sed`-based substitution was REJECTED because `sed` interprets `&` (matched pattern) and `\1` (backreferences) in the RHS even with non-default delimiters — a `PROJECT_NAME="Cats & Dogs"` would break. Bash parameter expansion has no regex interpretation on the replacement side.

**`{{PROJECT_NAME}}` is a first-class template variable** (Feature 061). All user-facing template files in `.claude/`, `docs/`, `CLAUDE.md`, and `README.md` use this placeholder rather than hardcoding "Agentic Oriented Development Kit". After `make init`, adopters see their own project name throughout.

When adding a new user-facing template file to the kit, use `{{PROJECT_NAME}}` wherever the project name should appear and confirm the file is included in the manifest (`.aod/template-manifest.txt`). Files that carry placeholders MUST be categorized as `personalized` so `/aod.update` re-applies the substitutions on every update.

**Legacy placeholder migration** (Feature 134): `LEGACY_MAP` is a static, version-stamped mapping from observed pre-canonical placeholder names (e.g., `{{DATABASE_TYPE}}`, `{{DATABASE_PROVIDER}}`, `{{VECTOR_DB}}`, `{{AUTH_PROVIDER}}`, `{{PROJECT_URL}}`) to their canonical equivalents (or to documented exceptions). Defined in `.aod/scripts/bash/check-placeholders.sh` and conceptually co-located with `AOD_CANONICAL_PLACEHOLDERS` as a single source of truth — adding a legacy alias is a parallel-array update. The `make update --check-placeholders` subcommand reports each detected drift occurrence and emits the `LEGACY_MAP` migration table (versioned with the date it was last touched). See Feature 134 in [01_system_design/README.md](../01_system_design/README.md#feature-134-update-bootstrap-placeholder-migration) for full data flow.

See [ADR-009](../02_ADRs/ADR-009-template-variable-expansion-scope.md), the [Template Variable Expansion pattern](../03_patterns/README.md#pattern-template-variable-expansion), and [downstream-update-architecture.md](../01_system_design/downstream-update-architecture.md) for the full update flow.

---

### Extraction Manifest & Classification Snapshot (Feature 128)

**Purpose**: The `user → PLSK` extraction pipeline (maintainer-only, `scripts/extract.sh`) must never ship private data (active specs, closed PRDs, security scan artifacts, maintainer credentials) downstream. Feature 128 replaces the hand-curated per-file manifest with a directory-based allow-list plus a committed classification snapshot gated by CI.

**Manifest composition** (inline in `scripts/extract.sh`):

| Component | Type | Role |
|-----------|------|------|
| `MANIFEST_DIRS` | Bash array of top-level directory paths | Allow-list; every file inside auto-ships unless overridden |
| `MANIFEST_ROOT_FILES` | Bash array of root-relative file paths | Allow-list; explicit root-level files that ship |
| `.extractignore` | gitignore-style glob patterns (no negation in v1) | Subtractive overlay; removes files from allow-listed directories |
| `CONTENT_RESET_FILES` | `<dest>:<template-src>` registry | Files shipped then overwritten with a reset template (sync mode only) |
| `scripts/reset-templates/*` | Externalized template bodies | Source-of-truth content for reset targets (replaces former inline heredocs) |

**Classification values** recorded in `scripts/extract-classification.txt`:
- `SHIP` — file is covered by `MANIFEST_DIRS` or `MANIFEST_ROOT_FILES` and not excluded
- `EXCL-by-override` — file would ship, but is removed by `.extractignore`
- `EXCL-by-construction` — file is in a private-by-construction directory (e.g., `specs/`, `.security/`, `.aod/closures/`)

**Five-layer defense bundle** (binary acceptance — all five required):

1. **Allow-list** (`MANIFEST_DIRS` + `MANIFEST_ROOT_FILES`) — additions require explicit maintainer intent
2. **Residual placeholder scan** (`aod_template_scan_residual_placeholders`) — rejects shipped files with leftover `{{[A-Z_]+}}` markers
3. **Deny-list regex scan** — inline `DENY_LIST_PATTERNS` array in `extract.sh` (project markers + maintainer-username pattern, LICENSE excluded)
4. **Safe-path assert** (`aod_template_assert_safe_path` + `aod_template_assert_no_symlink`) — rejects `..`, absolute, `~`, `.`, and symlink entries
5. **Fail-loud template existence** — missing content-reset template path halts within 1 s before any destination write (SC-010)

**CI enforcement**: `.github/workflows/extract-coverage.yml` runs `scripts/check-extract-coverage.sh` in a `bash:3.2` Docker container on every push/PR to main. It computes live classifications from `git ls-files`, diffs against the committed `scripts/extract-classification.txt` snapshot, and emits compiler-diagnostic output (`extract-classification.txt:N: <message>`) on divergence. Maintainer remediation: `make extract-classify` regenerates the snapshot; `git diff` + explicit commit acknowledges the change. Target recovery time: <5 min.

**Makefile targets**:
| Target | Purpose |
|--------|---------|
| `make extract-check` | Run the validator locally without regenerating the snapshot |
| `make extract-classify` | Regenerate `scripts/extract-classification.txt` from the current manifest + `.extractignore` |

**Non-interactive sync flags** (`/aod.sync-upstream`, `scripts/sync-upstream.sh`):
- `--yes` — skip interactive confirmation prompt (dirty-tree abort guard still applies)
- `--dry-run` — print preview without writing
- `--strategy={main,branch,manual}` — select commit strategy non-interactively
- No-flags path preserves pre-128 interactive default (FR-024 backwards compatibility)

See [upstream-sync-architecture.md](../01_system_design/upstream-sync-architecture.md) for the full push-flow topology and five-layer defense diagram.

---

### Template Manifest & Version Pin (Feature 129)

**File**: `.aod/template-manifest.txt` (upstream source of truth; fetched fresh by adopter on each `make update`).

**Format**: Line-delimited plain text — `<category>|<path-or-glob>` per line. Parser uses `while read` + `case` (bash 3.2 compatible). Comments (`#`) and blank lines ignored.

**Categories** (6): `owned`, `personalized`, `user`, `scaffold`, `merge`, `ignore`. Precedence (highest wins): `ignore > (hardcoded user-owned guard list, FR-007) > user > scaffold > merge > personalized > owned`.

**File**: `.aod/aod-kit-version` (adopter-side). Bash-sourceable KV written atomically via temp + `mv` (ADR-001 pattern). 5 required fields: `version`, `sha`, `updated_at`, `upstream_url`, `manifest_sha256`.

**File**: `.aod/personalization.env` (adopter-side). Bash-sourceable KV created by `init.sh`, read by `/aod.update` on every run. Values must not contain newlines or `|` (rejected at load).

**Supply-chain defenses** (three independent mechanisms, all introduced by Feature 129):
1. **Commit SHA pinning** — every install/update records exact upstream SHA.
2. **Retag detection** — if a tag now points to a different SHA than recorded, halt unless `--force-retag`.
3. **Manifest SHA-256 tracking** — fetched fresh each run; `user → owned` transitions flagged in preview.

**CI enforcement**: `.github/workflows/manifest-coverage.yml` (the upstream template's first CI workflow) runs `scripts/check-manifest-coverage.sh` in a `bash:3.2` Docker container on every push/PR. `actions/checkout` SHA-pinned (not `@v4`), `permissions: contents: read`, concurrency group with `cancel-in-progress`.

See [downstream-update-architecture.md](../01_system_design/downstream-update-architecture.md) for the full topology and atomicity contract.

---

### Anti-Rationalization Tables — Markdown Content Convention (Feature 158)

**Purpose**: 18 in-scope AOD command/skill files (11 commands at `.claude/commands/aod.{spec,plan,project-plan,tasks,build,deliver,document,clarify,analyze,define,discover}.md` + 7 skills at `.claude/skills/~aod-{spec,plan,project-plan,build,deliver,define,discover}/SKILL.md`) ship two new H2 sections — `## Common Rationalizations` (2-column markdown table) and `## Red Flags` (markdown bullet list) — that prime the loaded command/skill at invocation time with file-specific shortcut narratives, concrete consequences, and observable-behavior reviewer audit checklists.

**Content-only delta — no new dependencies, no new scripts, no new exit codes**: F158 is strictly additive markdown. Every verification check uses pre-existing POSIX `grep` + `awk` (already hard kit dependencies for AOD scripts). The 4 forward-CI audits documented in [retro.md](../../../specs/158-anti-rationalization-tables/retro.md) use only POSIX BRE + portable `awk` one-liners (NO `-P`, NO `-z`, NO PCRE) — confirmed working on BSD grep (macOS), GNU grep (Linux/CI), and BusyBox per AD-003 / SC-003.

**Format contract** (binding for any future Phase 2 CI gate or content audit):

| Section | H2 header (literal) | Body | Anchor |
|---|---|---|---|
| Rationalizations | `## Common Rationalizations` | 2-col table `\| Rationalization \| Reality \|` — 2–8 rows / file (recommended 3–5); first-person quoted ≤15-word narratives in column 1; concrete-consequence ≤25-word rebuttals in column 2 (no appeal-to-authority phrases) | Exactly one blank line between H2 and table |
| Red Flags | `## Red Flags` | Markdown bullet list — ≥3 bullets (recommended 5–8); one externally-observable behavior per bullet | Exactly one blank line between H2 and first bullet |

**Layer split** (AD-005, validated at delivery): command files host invocation-level rationalizations (flags, modes, routing, arguments); skill files host execution-level rationalizations (steps, gates, sign-offs, artifacts). No same-layer pair MAY host the same Rationalization verbatim — the Wave 6 T025 dedupe pass enforces this.

**Adopter sync**: Both `.claude/commands/` and `.claude/skills/` are `owned` opaque overwrites under the F129 manifest. Clean adopter sync via `make update`; F129 conflict-resolution path applies for adopters with non-trivial local edits to any of the 18 files.

**Pattern source**: Adapted from [addyosmani/agent-skills `docs/skill-anatomy.md`](https://github.com/addyosmani/agent-skills/blob/main/docs/skill-anatomy.md) per FR-010 Q-001 (single-line attribution lives in `CLAUDE.md` `## Recent Changes`, not as a hard dependency).

See [01_system_design/README.md Feature 158](../01_system_design/README.md#feature-158-anti-rationalization-tables) for the full Components / Data Flow / Architectural Decisions ledger, and [03_patterns/README.md `Anti-Rationalization Tables — Behavioral Primer`](../03_patterns/README.md#pattern-anti-rationalization-tables-behavioral-primer) for the reusable pattern documentation.

---

### Subagent Results Directory

**Directory**: `.aod/results/` (ephemeral session artifacts, gitignored)
- Architecture: File-based offloading for minimal subagent returns (Feature 073)
- Convention: Each subagent writes detailed findings to `.aod/results/{agent-name}.md` before returning
- Return policy: Subagents return only STATUS + ITEMS count + DETAILS path to the main context (max 10 lines / ~200 tokens)
- Overwrite semantics: Each invocation overwrites the prior results file for the same agent
- Initialization: Subagents create the directory if absent (self-healing, no pre-init required)
- See [ADR-010](../02_ADRs/ADR-010-minimal-return-architecture.md) for the design decision
- See [Minimal-Return Subagent pattern](../03_patterns/README.md#pattern-minimal-return-subagent) for implementation guidance

**Context budget impact**: A full Triad review cycle (3 reviewers) consumes less than 600 tokens in the main context (down from 1,500-6,000 tokens), enabling 90+ minute sustained orchestration sessions.

---

### Stack Packs System

**Directory**: `stacks/` (convention contracts, persona supplements, scaffold templates, rules)
- Architecture: Dual-surface injection pattern (Feature 058)
- Management skill: `.claude/skills/aod-stack/SKILL.md` (`/aod.stack use|remove|list|scaffold`)
- State file: `.aod/stack-active.json` (JSON, tracks active pack name and activation timestamp)
- Runtime rules surface: `.claude/rules/stack/` (copied on activation, cleaned on removal)
- See ADR-007 for the design decision behind dual-surface injection

**Shipped packs**:
| Pack | Status | Purpose |
|------|--------|---------|
| `stacks/nextjs-supabase/` | Full | Next.js + TypeScript + Supabase + Prisma + Vercel conventions |
| `stacks/fastapi-react/` | Full | Python FastAPI + SQLAlchemy 2.0 async + React 19 + TypeScript + Vite + Docker Compose (Feature 078) |
| `stacks/fastapi-react-local/` | Full | Python FastAPI + SQLAlchemy 2.0 async + aiosqlite + React 19 + Vite + Tailwind CSS 4 — zero external dependencies, local-first variant (Feature 085) |
| `stacks/swiftui-cloudkit/` | Skeleton | SwiftUI + CloudKit native iOS conventions |
| `stacks/knowledge-system/` | Full | Markdown + YAML + Claude Code for knowledge-intensive content systems (Feature 064) |

**Pack anatomy** (each pack directory):
| Path | Purpose |
|------|---------|
| `STACK.md` | Convention contract (required, ≤500 lines) |
| `agents/*.md` | Persona supplements for specialized/hybrid agents (≤100 lines each) |
| `rules/*.md` | Stack-specific coding rules (copied to `.claude/rules/stack/` on activation) |
| `scaffold/` | Project template files (optional, used by `/aod.stack scaffold`) |
| `skills/` | Stack-specific skills (optional, reserved for future use) |

**Context budget enforcement**:
| Component | Max Lines | Loaded When |
|-----------|-----------|-------------|
| STACK.md | 500 | Every agent invocation (if pack active) |
| Persona supplement | 100 | Specialized/hybrid agent invocations only |
| Stack rules (all files combined) | 200 | Every agent invocation (via rules discovery) |
| Total pack overhead | 800 | Maximum per invocation |

### Stack Pack Test Contract (Feature 130)

**Purpose**: Replace filesystem-based E2E runner detection in `/aod.deliver` Step 9 with a declarative, per-pack contract. Pack authors declare their unit+integration command and either an E2E command or an explicit opt-out reason; the kit reads the contract at delivery time and CI enforces the schema on every PR.

**Contract surface**: Fenced YAML block inside `STACK.md` Section 7 (Testing Conventions), bracketed by HTML sentinel comments so Markdown prettifiers cannot corrupt the machine-addressable edges.

```
<!-- BEGIN: aod-test-contract -->
```yaml
test_command: "<unit+integration>"
e2e_command: "<e2e runner>"      # XOR with e2e_opt_out
# OR
# e2e_opt_out: "<reason — SHOULD include #NNN issue ref>"
```
<!-- END: aod-test-contract -->
```

**3-key schema** (enforced by `stack-contract-lint.sh`):

| Key | Required | Constraint |
|---|---|---|
| `test_command` | Always | Non-empty shell invocation |
| `e2e_command` | XOR with `e2e_opt_out` | Non-empty shell invocation |
| `e2e_opt_out` | XOR with `e2e_command` | ≥10 chars; SHOULD contain `#NNN` |

Unknown keys trigger a distinct error code (exit 4) so typos (`e2e_comand`) surface immediately. The schema is designed for a steady-state of ~10–20 packs; authors are nudged toward wrapper scripts (`./scripts/run-e2e.sh`) when a command would otherwise contain shell-chaining metacharacters (lint emits WARN but not ERROR for `;`, `&&`, `||`, `$()`, backticks).

**Stable exit-code taxonomy** (`stack-contract-lint.sh`):

| Code | Name | Step 9 Treatment |
|---|---|---|
| `0` | VALID | Proceed to Step 9b with extracted command |
| `1` | RUNTIME_ERROR | `e2e_validation.status = "error"` |
| `2` | MISSING_TEST_COMMAND | `e2e_validation.status = "error"` |
| `3` | XOR_VIOLATION | `e2e_validation.status = "error"` |
| `4` | UNKNOWN_KEY | `e2e_validation.status = "error"` |
| `5` | MISSING_BLOCK | **Grace period (one release, FR-031)**: implicit opt-out with stderr warning. **Post-grace**: `e2e_validation.status = "error"`. |

Codes are **stable forever** — adding new codes is permitted; repurposing existing ones is not. This is a versioned API surface between pack authors, `/aod.deliver` Step 9a, and CI (documented in `specs/130-e2e-hard-gate/contracts/stack-contract-lint.md`).

**Multi-violation resolution**: When a single file violates multiple rules, the lint reports every violation in a single pass and exits with the **numerically lowest** applicable code. Example: a file missing `test_command` AND containing an unknown key exits with code 2 (not code 4) but prints both error lines. Step 9a branches on exit code ranges, not string parsing.

**Stderr format** (compiler-diagnostic, parseable by GitHub Actions annotator):

```
[aod-stack-contract] <file>:<line>: <SEVERITY>: <message>
See: docs/stacks/TEST_COMMAND_CONTRACT.md[#<anchor>]
```

**`/aod.deliver` Step 9 integration** (replaces filesystem detection from Feature 113):

1. **Step 9a** reads `.aod/stack-active.json` (absent OR malformed JSON → skip; backward-compat for non-stack-pack projects and defensive against future PRD-058 schema drift).
2. Resolves active pack → `stacks/<pack>/STACK.md` and invokes `stack-contract-lint.sh <path>`.
3. Branches on exit code: 0 → continue to Step 9b with extracted `TEST_COMMAND` / `E2E_COMMAND` / `E2E_OPT_OUT`; 2/3/4/1 → `e2e_validation.status = "error"`; 5 → error branch with lint stderr diagnostic (Feature 142 removed the former grace-period fallback — Issue #142).
4. **Step 9b** generalizes the tester-agent prompt from hardcoded Playwright to "Execute scenarios via the declared E2E command: `${E2E_COMMAND}`." Timeout and agent-failure branches unchanged.
5. **Step 11c** renders `e2e_validation.skip_reason` in delivery.md's E2E Validation Gate table.

**`e2e_validation.command` population rule**: `command` is populated **only** when `status == "pass"` or `status == "fail"`. For `status == "skipped"` (opt-out or grace-period) and `status == "error"`, `command` is absent — the payload semantically says "this is what we ran and these are the results," never "this is what we would have run."

**Content-pack allowlist**: Inline bash 3.2 indexed array in `stack-contract-lint.sh`: `CONTENT_PACKS=("knowledge-system")`. In `--all` mode the script skips these packs (they ship no runtime and no tests). Single-file mode (`lint <path>`) ignores the allowlist — explicit invocation always validates. If the allowlist grows to 3+ entries, a future PRD may extract it to a file (`.contract-ignore`).

**Historical: Grace-period semantics** (FR-031, removed by Feature 142): The grace-period fallback that let packs without a contract block silently skip E2E validation existed in the release prior to Feature 142 (Issue #142). Exit code 5 now routes through the error branch, producing `e2e_validation.status = "error"` instead of `"skipped"`.

**Tester agent parameterization** (`.claude/agents/tester.md`):
- Expertise array line 17: `playwright-automation` → `e2e-automation` (runner-agnostic identifier)
- Body line 65 and 134: references generalized from Playwright-specific examples to "the declared E2E runner from the active pack's STACK.md contract"
- Pre-rename `grep -r 'playwright-automation' .` check mandated in tasks.md to catch downstream skill-matching dependencies

**Day-1 pack rollout** (declarations at #130 ship; see Feature 138 for fastapi-react flip):
| Pack | Declaration |
|---|---|
| `nextjs-supabase` | `e2e_command: "npx playwright test"` |
| `swiftui-cloudkit` | `e2e_opt_out` with tracking issue `#140` |
| `fastapi-react` | `e2e_opt_out` with tracking issue `#138` → **flipped to `e2e_command: "npm --prefix frontend run test:e2e"` in Feature 138 (PR #146, 2026-04-22)** |
| `fastapi-react-local` | `e2e_opt_out` with tracking issue `#138` → **flipped to `e2e_command: "npm --prefix frontend run test:e2e"` in Feature 138 (PR #146, 2026-04-22)** |
| `knowledge-system` | Allowlisted (content pack, no runtime) |

**CI workflow**: `.github/workflows/stack-contract.yml` runs `stack-contract-lint.sh --all` in `bash:3.2` Alpine Docker — mirrors `manifest-coverage.yml` shell (Feature 129). Path filters scope triggers to `stacks/**/STACK.md`, `.aod/scripts/bash/stack-contract-lint.sh`, `.github/workflows/stack-contract.yml`. `actions/checkout` SHA-pinned, `permissions: contents: read`, `concurrency.cancel-in-progress: true`, fetch-depth 1 (lint reads working-tree only).

**Migration doc**: `docs/stacks/TEST_COMMAND_CONTRACT.md` — schema, examples, error codes, wrapper-script pattern, nested-comment pathological case callout.

See [ADR-012](../02_ADRs/ADR-012-stack-pack-test-contract.md) for the full decision record, [Feature 130 plan](../../../specs/130-e2e-hard-gate/plan.md) for the architectural ledger, and [contracts/stack-contract-lint.md](../../../specs/130-e2e-hard-gate/contracts/stack-contract-lint.md) for the binary CLI contract.

### Stack Pack Scaffold Test Dependencies

Tools that ship via stack pack `scaffold/` directories (adopter-side), not as template-level dependencies:

| Tool | Version | Shipped By | Role |
|---|---|---|---|
| `@playwright/test` | `^1.58` | `stacks/fastapi-react/scaffold/frontend/package.json`, `stacks/fastapi-react-local/scaffold/frontend/package.json` | E2E runner for FastAPI stack packs (Feature 138). Ships as `devDependency` — installed by adopter `npm install`. Matches tiangolo FastAPI template pin. |

**Not a template-level dependency**: Playwright runs in adopter projects after `/aod.stack scaffold fastapi-react` (or `-local`). The template repo itself contains no Playwright install. `nextjs-supabase` pack uses `npx playwright test` and follows the same scaffold-only ship model.

### Kickstart Skill

**Skill file**: `.claude/skills/~aod-kickstart/SKILL.md` (`/aod.kickstart`)
- Architecture: Three-stage interactive workflow (Idea Intake → Stack Selection → Guide Generation) (Feature 085)
- Output: `docs/guides/CONSUMER_GUIDE_{PROJECT_NAME}.md` — sequenced consumer guide with 6-10 seed features
- Stack detection: Reads `.aod/stack-active.json` to auto-detect active pack; falls back to manual selection
- Seed features structured for direct copy-paste into `/aod.discover`
- No infrastructure dependencies; pure methodology/template skill

### Orchestrator Skill Architecture

**Skill file**: `.claude/skills/~aod-run/SKILL.md` (~620 lines, core execution loop)
- Architecture: Segmented prompt with on-demand reference loading (Feature 030)
- Core file contains routing, state machine loop, and stage mapping
- Reference files loaded via Read tool only when needed:

| Reference File | Purpose | Loaded When |
|----------------|---------|-------------|
| `references/governance.md` | Governance gate detection, tiers, rejection handling | Governance cache miss |
| `references/entry-modes.md` | New-idea, issue, resume, status entry handlers | Mode routing |
| `references/dry-run.md` | Read-only preview handler | `--dry-run` flag |
| `references/error-recovery.md` | Corrupted state and lifecycle complete handlers | Error or completion |

- See ADR-002 for the design decision behind prompt segmentation

### Orchestrator State

**State file**: `.aod/run-state.json`
- Format: JSON (managed via `jq`)
- Atomicity: Write-then-rename pattern (`write to .tmp`, then `mv`) for crash safety
- Schema version: `1.0`
- Governance cache: Verdicts stored in `governance_cache` object to eliminate redundant artifact reads (Feature 030)
- Compound helpers: `aod_state_get_multi`, `aod_state_get_loop_context`, `aod_state_get_governance_cache` for incremental reads (Feature 030)
- See ADR-001 for the design decision behind atomic state management
- See ADR-006 for the design decision behind non-fatal error handling in observability operations

---

**Template Instructions**: Replace all `{{TEMPLATE_VARIABLES}}` with your actual technology choices. Document the "Why" for each major decision.
