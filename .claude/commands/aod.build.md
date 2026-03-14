---
description: Execute implementation with Architect checkpoints at critical phases - Streamlined v2
---

## User Input

```text
$ARGUMENTS
```

Consider user input before proceeding (if not empty).

## Step 0: Parse Arguments

Parse optional flags from `$ARGUMENTS`. Flags can appear anywhere in the arguments string.

All three flags are independent — they may coexist in any combination (e.g., `--no-security --no-simplify --no-docs`). Each controls only its own step. Per ADR-011, flag independence is maintained.

**Step 0a: Parse --no-simplify**

1. If `$ARGUMENTS` contains `--no-simplify`:
   - Set `skip_simplify = true`
   - Strip `--no-simplify` from `$ARGUMENTS` (trim extra whitespace)
   - Continue to next flag check with remaining arguments

2. If `$ARGUMENTS` does NOT contain `--no-simplify`:
   - Set `skip_simplify = false`
   - Continue to next flag check with `$ARGUMENTS` unchanged

**Step 0b: Parse --no-security**

1. If `$ARGUMENTS` contains `--no-security`:
   - Set `skip_security = true`
   - Strip `--no-security` from `$ARGUMENTS` (trim extra whitespace)
   - Continue to next flag check with remaining arguments

2. If `$ARGUMENTS` does NOT contain `--no-security`:
   - Set `skip_security = false`
   - Continue to next flag check with `$ARGUMENTS` unchanged

**Step 0c: Parse --no-docs**

1. If `$ARGUMENTS` contains `--no-docs`:
   - Set `skip_docs = true`
   - Strip `--no-docs` from `$ARGUMENTS` (trim extra whitespace)
   - Continue to Step 1 with remaining arguments

2. If `$ARGUMENTS` does NOT contain `--no-docs`:
   - Set `skip_docs = false`
   - Continue to Step 1 with `$ARGUMENTS` unchanged

## Overview

Executes feature implementation with Architect checkpoint reviews at priority boundaries.

**Flow**: Validate tasks --> Check checklists --> Load context --> Setup project --> Execute waves with parallel agents --> Checkpoint reviews + CHANGELOG --> Final validation + API doc sync --> Security scan --> Code simplification + docs-lint --> Report completion

**Key Feature**: Architect reviews at P0->P1->P2 boundaries for governed quality gates.

## Step 1: Validate Prerequisites

1. Get branch: `git branch --show-current` --> must match `NNN-*` pattern
2. Find tasks: `specs/{NNN}-*/tasks.md` --> must exist
3. Parse frontmatter: Verify all three sign-offs (PM, Architect, Team-Lead) are APPROVED
4. Find assignments: `specs/{NNN}-*/agent-assignments.md` --> must exist
5. If validation fails: Show error with required workflow order and exit
6. Detect resume state: Scan tasks.md for `[X]` marked tasks. Count completed vs total tasks per wave from agent-assignments.md.
   - If resuming (some waves complete): Display "RESUMING: Waves 1-N complete, starting at Wave {N+1}"
   - If fresh start: Display "Starting implementation from Wave 1"
7. **GitHub Lifecycle Update (early)**: Move the feature's GitHub Issue to `stage:build` at the *start* of implementation. The issue number is the NNN prefix extracted from the branch in step 1 (e.g., branch `086-my-feature` → issue `86`). Run:
   ```bash
   bash -c 'source .aod/scripts/bash/github-lifecycle.sh && aod_gh_update_stage NNN build'
   ```
   Then regenerate BACKLOG.md:
   ```bash
   bash .aod/scripts/bash/backlog-regenerate.sh
   ```
   If `gh` is unavailable or the issue does not exist, skip silently (graceful degradation).

## Step 2: Check Checklists and Load Context

### 2a: Check Checklists Status

If `specs/{NNN}-*/checklists/` exists:

1. Scan all checklist files in the checklists/ directory
2. For each checklist, count:
   - Total items: All lines matching `- [ ]` or `- [X]` or `- [x]`
   - Completed items: Lines matching `- [X]` or `- [x]`
   - Incomplete items: Lines matching `- [ ]`
3. Create a status table:

   | Checklist | Total | Completed | Incomplete | Status |
   |-----------|-------|-----------|------------|--------|
   | ux.md     | 12    | 12        | 0          | PASS   |
   | test.md   | 8     | 5         | 3          | FAIL   |
   | security.md | 6   | 6         | 0          | PASS   |

4. Calculate overall status:
   - **PASS**: All checklists have 0 incomplete items
   - **FAIL**: One or more checklists have incomplete items

5. **If any checklist is incomplete**:
   - Display the table with incomplete item counts
   - **STOP** and ask: "Some checklists are incomplete. Do you want to proceed with implementation anyway? (yes/no)"
   - Wait for user response before continuing
   - If user says "no" or "wait" or "stop", halt execution
   - If user says "yes" or "proceed" or "continue", proceed to step 2b

6. **If all checklists are complete**: Display the table showing all checklists passed, proceed to step 2b

### 2b: Load Implementation Context

1. **REQUIRED**: Read `tasks.md` for the complete task list and execution plan
2. **REQUIRED**: Read `plan.md` for tech stack, architecture, and file structure
3. **REQUIRED**: Read `spec.md` for requirements context
4. **REQUIRED**: Parse `agent-assignments.md` for task->agent mapping and wave definitions
5. **IF EXISTS**: Read `data-model.md` for entities and relationships
6. **IF EXISTS**: Read `contracts/` for API specifications and test requirements
7. **IF EXISTS**: Read `research.md` for technical decisions and constraints
8. **IF EXISTS**: Read `quickstart.md` for integration scenarios
9. **IF EXISTS**: Read `.aod/stack-active.json` for active stack pack state. If a pack is active, note the pack name for agent dispatch in Step 4.

### 2c: Define Checkpoints

| Checkpoint | After Waves | Description | Blocking |
|------------|-------------|-------------|----------|
| P0 | 1, 2 | POC validation - Go/No-Go decision | Yes |
| P1 | 3, 4, 5 | Core functionality - Production cutover | Yes |
| P2 | 6, 7 | All features - Pre-final review | No |

## Step 3: Project Setup Verification

Before executing waves, verify the project environment is properly configured.

**Detection and Creation Logic**:
- Check if the repository is a git repo (`git rev-parse --git-dir 2>/dev/null`) --> create/verify `.gitignore` if so
- Check if `Dockerfile*` exists or Docker in plan.md --> create/verify `.dockerignore`
- Check if `.eslintrc*` or `eslint.config.*` exists --> create/verify `.eslintignore`
- Check if `.prettierrc*` exists --> create/verify `.prettierignore`
- Check if `.npmrc` or `package.json` exists --> create/verify `.npmignore` (if publishing)
- Check if terraform files (`*.tf`) exist --> create/verify `.terraformignore`
- Check if helm charts present --> create/verify `.helmignore`

**If ignore file already exists**: Verify it contains essential patterns, append missing critical patterns only.
**If ignore file missing**: Create with full pattern set for detected technology.

**Common Patterns by Technology** (from plan.md tech stack):
- **Node.js/JavaScript**: `node_modules/`, `dist/`, `build/`, `*.log`, `.env*`
- **Python**: `__pycache__/`, `*.pyc`, `.venv/`, `venv/`, `dist/`, `*.egg-info/`
- **Java**: `target/`, `*.class`, `*.jar`, `.gradle/`, `build/`
- **C#/.NET**: `bin/`, `obj/`, `*.user`, `*.suo`, `packages/`
- **Go**: `*.exe`, `*.test`, `vendor/`, `*.out`
- **Universal**: `.DS_Store`, `Thumbs.db`, `*.tmp`, `*.swp`, `.vscode/`, `.idea/`

**Tool-Specific Patterns**:
- **Docker**: `node_modules/`, `.git/`, `Dockerfile*`, `.dockerignore`, `*.log*`, `.env*`, `coverage/`
- **ESLint**: `node_modules/`, `dist/`, `build/`, `coverage/`, `*.min.js`
- **Prettier**: `node_modules/`, `dist/`, `build/`, `coverage/`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`
- **Terraform**: `.terraform/`, `*.tfstate*`, `*.tfvars`, `.terraform.lock.hcl`

## Step 4: Wave Execution with Checkpoints

For each wave:

1. **Skip if complete**: Check if all wave tasks marked `[X]` in tasks.md
2. **Group by agent**: Map tasks to specialized agents from agent-assignments.md
3. **Launch parallel**: Send **SINGLE message with multiple Task calls** for true parallelism
   - Use [Agent Registry](.claude/agents/) for task->agent mapping
   - Agent assignments from `agent-assignments.md` take precedence
   - **Stack pack persona injection**: If `.aod/stack-active.json` indicates an active pack, and the dispatched agent is Specialized (frontend-developer, senior-backend-engineer, security-analyst, tester, code-reviewer, devops) or Hybrid (ux-ui-designer, debugger), append to the agent's task prompt: "Before executing, read `stacks/{pack}/agents/{agent-name}.md` as supplementary stack-specific context for conventions, anti-patterns, and guardrails." Core agents (product-manager, architect, team-lead, orchestrator, web-researcher) MUST NOT receive persona injection.

4. **Verify completion**: Check all wave tasks marked `[X]`
5. **Checkpoint review** (if wave triggers checkpoint):
   - Launch architect agent for review
   - Parse STATUS: APPROVED / APPROVED_WITH_CONCERNS / CHANGES_REQUESTED / BLOCKED
   - If BLOCKED on blocking checkpoint: spawn debugger, retry, or exit
   - If CHANGES_REQUESTED: spawn appropriate agent to fix, retry review

6. **CHANGELOG generation** (Step 4.5a — runs after checkpoint review, before mandatory stop):

   **Skip condition**: If `skip_docs` is true, skip this sub-step entirely. Record `changelog_status` for the wave as "Skipped (--no-docs)".

   **Collect commits**:
   - Run: `git log --format="%H %s" main..HEAD`
   - If the command fails (e.g., detached HEAD, corrupted git state): skip CHANGELOG for this wave with warning "CHANGELOG: Skipped (git error: {message})". Record `changelog_status` = "Skipped (git error: {message})". Proceed to Step 4.7.
   - If no commits are returned: skip with note "No new commits in wave {N}". Record `changelog_status` = "Skipped (no new commits)". Proceed to Step 4.7.

   **Deduplicate by SHA**:
   - If `CHANGELOG.md` exists in the project root, read its contents
   - For each collected commit, check if the commit SHA (first 7+ characters) already appears in `CHANGELOG.md`
   - Exclude any commits whose SHA is already present (captured in prior wave entries)
   - If all commits are already captured: skip with note "All commits already in CHANGELOG". Record `changelog_status` = "Skipped (no new commits)". Proceed to Step 4.7.

   **Parse and categorize**:
   - For each remaining (new) commit, parse the subject line for conventional commit prefixes:
     - `feat:` or `feat(` → **Added**
     - `fix:` or `fix(` → **Fixed**
     - `refactor:`, `docs:`, `chore:`, `style:`, `perf:`, `test:` (and scoped variants) → **Changed**
     - Commits containing "remove", "delete", or "drop" in the subject → **Removed**
     - All others → **Other**
   - Group commits by category, preserving commit order within each group

   **Create CHANGELOG.md if missing**:
   - If no `CHANGELOG.md` exists in the project root, create one with the standard Keep a Changelog header:
     ```markdown
     # Changelog

     All notable changes to this project will be documented in this file.

     The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

     ## [Unreleased]
     ```

   **Format and append entry**:
   - Build a markdown section with heading: `### Feature {NNN} — Wave {N}`
   - Under the heading, list each non-empty category with its entries:
     ```markdown
     #### Added
     - {commit subject} (`{short SHA}`)

     #### Fixed
     - {commit subject} (`{short SHA}`)
     ```
   - Omit categories with zero entries
   - Insert the new section under the `## [Unreleased]` heading in `CHANGELOG.md`
     - If `## [Unreleased]` exists: insert immediately after the `## [Unreleased]` line (before any existing wave entries)
     - If `## [Unreleased]` does not exist (non-standard format): append a new `## [Unreleased]` section at the end of the file, then insert the entry below it
   - Include each commit's short SHA (first 7 characters) in the entry for deduplication traceability

   **Record status**:
   - Count the number of entries added
   - Record `changelog_status` = "Generated ({entry_count} entries)"
   - Stage and commit: `git add CHANGELOG.md` then commit with message:
     ```
     docs({NNN}): update CHANGELOG for wave {N}

     Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
     ```

7. **STOP after wave** (MANDATORY — context overflow prevention):
   - Run `/continue` to generate a NEXT-SESSION.md handoff file
   - Display wave completion summary:
     ```
     WAVE {N}/{total} COMPLETE

     Tasks completed this wave: {count}
     Total progress: {completed}/{total} tasks ({percentage}%)

     CHANGELOG: {changelog_status}

     Next: Wave {N+1} — {brief description from agent-assignments.md}

     To continue: Start a new conversation and run `/aod.build`
     The command will automatically resume from Wave {N+1}.

     Resume prompt:
       claude "Resume {feature} implementation (branch: {branch}). Waves 1-{N} complete. Run /aod.build to continue with Wave {N+1}."
     ```
   - **STOP EXECUTION. Do not proceed to the next wave.**
   - This is MANDATORY — never continue to the next wave in the same conversation.
   - Exception: If this is the LAST wave, proceed to Step 5 (Final Validation) instead of stopping.

### Implementation Execution Rules

During wave execution, agents must follow these rules:

- **Follow TDD approach**: Execute test tasks before their corresponding implementation tasks
- **File-based coordination**: Tasks affecting the same files must run sequentially within a wave
- **Setup first**: Initialize project structure, dependencies, configuration in early waves
- **Tests before code**: Write tests for contracts, entities, and integration scenarios first
- **Core development**: Implement models, services, CLI commands, endpoints
- **Integration work**: Database connections, middleware, logging, external services
- **Polish and validation**: Unit tests, performance optimization, documentation

### Progress Tracking and Error Handling

- Report progress after each completed task
- Halt execution if any non-parallel task fails
- For parallel tasks [P], continue with successful tasks, report failed ones
- Provide clear error messages with context for debugging
- Suggest next steps if implementation cannot proceed
- **IMPORTANT**: For completed tasks, mark the task as `[X]` in tasks.md

## Step 5: Final Validation (Last Wave Only)

This step runs ONLY after the LAST wave completes (i.e., all tasks in all waves are marked `[X]`). For non-final waves, Step 4.7 stops execution instead. Includes API documentation sync verification (Step 5.7) when `--no-docs` is not set.

After all waves complete:

1. Verify all tasks marked `[X]`
2. Check that implemented features match the original specification
3. Validate that tests pass and coverage meets requirements
4. Confirm the implementation follows the technical plan
5. Launch final reviews in parallel (single message, multiple Task calls):

| Agent | subagent_type | Focus |
|-------|---------------|-------|
| Architect | architect | Overall architecture, security, production readiness |
| Code Review | code-reviewer | Code quality (if code files changed) |
| Security | security-analyst | Security posture (if auth/secrets changed) |

6. Parse all STATUS results

### 5.7: API Documentation Sync Verification (runs after existing Step 5 validations)

**Skip condition**: If `skip_docs` is true (from Step 0c), skip this sub-step entirely. Record `apisync_status` = "Skipped (--no-docs)". Proceed to Step 6.

**OpenAPI spec discovery**:
1. Search for spec files in this order (first match wins):
   - Project root: `openapi.yaml`, `openapi.json`, `swagger.yaml`, `swagger.json`
   - Then directories: `docs/`, `api/`, `spec/` — same filenames in each
2. If no spec file is found: skip silently (FR-018). Record `apisync_status` = "Skipped (no spec found)". Proceed to Step 6.
3. If a spec file is found but fails to parse (malformed YAML/JSON): report "Spec parse error: {path}: {error_message}", record `apisync_status` = "Skipped (spec parse error)". Proceed to Step 6. Do NOT block the build.

**Identify changed API files**:
1. Get changed files: `git diff --name-only main...HEAD`
2. Filter to code files that may contain API route definitions (`.py`, `.js`, `.ts`, `.jsx`, `.tsx`, `.go`, `.java`, `.rb`)
3. For each changed file, scan for framework-specific endpoint patterns:
   - **FastAPI** (Python): `@app.get`, `@app.post`, `@app.put`, `@app.delete`, `@app.patch`, `@router.get`, `@router.post`, `@router.put`, `@router.delete`, `@router.patch`
   - **Express** (JS/TS): `router.get`, `router.post`, `router.put`, `router.delete`, `router.patch`, `app.get`, `app.post`, `app.put`, `app.delete`, `app.patch`
   - **Flask** (Python): `@app.route`, `@blueprint.route`, `@bp.route`
4. If no changed files contain recognized API framework patterns: skip silently. Record `apisync_status` = "Skipped (no API endpoints in changed files)". Proceed to Step 6.

**Extract and compare endpoint signatures**:
1. For each detected endpoint in changed files, extract:
   - HTTP method (GET, POST, PUT, DELETE, PATCH)
   - Route path (e.g., `/api/users/{id}`)
   - Parameters (path params, query params, request body fields)
   - Response type (if detectable from type annotations or decorators)
   - Source location: file path and line number
2. Parse the discovered OpenAPI spec and extract corresponding endpoint definitions
3. Compare code endpoints against spec endpoints and identify mismatches:
   - **New endpoint**: Endpoint exists in code but not in spec
   - **Changed parameter**: Parameter name, type, or required status differs
   - **Changed route**: Route path differs between code and spec
   - **Removed endpoint**: Endpoint in spec but removed from code (only check endpoints in changed files — FR-022)
   - **Response type mismatch**: Response schema differs between code and spec

**Report mismatches**:
- For each mismatch, display:
  ```
  [{index}] {HTTP_METHOD} {route_path}
     Code: {code_file_path}:{line_number}
     Spec: {spec_file_path} → paths.{route}.{method}
     Issue: {description of discrepancy}
  ```

**Context limit awareness** (FR-032): If context limits are approached during API doc sync analysis, terminate early with warning "API doc sync truncated (context limit)" and record `apisync_status` = "Truncated ({N} of {total} endpoints analyzed)". The build continues with partial or no results.

### 5.7a: Per-Mismatch Resolution Options

If mismatches are found, present resolution options via AskUserQuestion:

```
API Documentation Sync Review:
  Spec file: {spec_file_path}
  Endpoints checked: {total_endpoints_checked}
  Mismatches found: {mismatch_count}

  {mismatch list from above}

  Options:
    (A) Review each mismatch individually
    (B) Skip all — no spec updates
    (C) Halt validation
```

**Option A — Review individually**:
For each mismatch, present via AskUserQuestion:
```
[{index}/{total}] {HTTP_METHOD} {route_path}
  Code: {code_file_path}:{line_number}
  Spec: {spec_file_path} → paths.{route}.{method}
  Issue: {description}

  (A) Auto-update spec — requires explicit confirmation per change (FR-021)
  (B) Skip this mismatch
```

- If user selects Auto-update: apply the change to the spec file. Each auto-update requires its own explicit confirmation (no batch approval).
- If any spec updates were applied:
  - Stage the spec file: `git add {spec_file_path}`
  - Create commit:
    ```
    docs({NNN}): sync OpenAPI spec with code changes

    Endpoints updated: {updated_count}

    Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
    ```
  - Record: `apisync_status` = "{mismatch_count} mismatches ({updated_count} resolved)"
  - Record: `apisync_commit` = commit hash

- If no updates applied: Record `apisync_status` = "{mismatch_count} mismatches (0 resolved)"

**Option B — Skip all**:
- No changes made
- Record: `apisync_status` = "{mismatch_count} mismatches (0 resolved)"

**Option C — Halt validation**:
- Stop Final Validation. Display: "API doc sync halted by user. Resolve mismatches manually and re-run `/aod.build`."
- Note: This is advisory — it halts validation display but does NOT block the build pipeline (FR-029). The user can re-run to continue.

If no mismatches found: Record `apisync_status` = "Passed". Proceed to Step 6.

## Step 6: Security Scan (Last Wave Only)

This step runs ONLY after Step 5 (Final Validation) completes. It analyzes all code files and dependency manifests changed on the feature branch for OWASP Top 10 vulnerabilities and known CVE patterns.

### 6a: Check Skip Conditions

1. If `skip_security` is true (from Step 0b):
   - Write `specs/{NNN}-*/security-scan.md` with content: `Security Scan: Skipped (--no-security)` + current timestamp
   - Record: security_status = "Skipped (--no-security)"
   - Proceed to Step 7

2. If no code files and no dependency manifests changed (pre-check via `git diff --name-only main...HEAD`):
   - Record: security_status = "Skipped (no code or manifest files changed)"
   - Proceed to Step 7

### 6b: Invoke /security Skill

Invoke the `security` skill via the Skill tool:
```
Skill tool: skill="security"
```

The skill handles all analysis steps internally (file detection, SAST, SCA, severity gate, artifact writing, commit strategy). Parse the result on completion.

### 6c: Handle Result

1. **PASSED** (no findings): Record security_status = "Passed — no issues found"; proceed to Step 7
2. **FINDINGS ACKNOWLEDGED**: Record security_status = "Findings acknowledged ({count} finding(s))"; proceed to Step 7
3. **BLOCKED** (developer selected "Fix now" or "Abort"):
   - If Fix now: halt build session; display "Fix the identified issues and re-run `/aod.build` to resume at Step 6"
   - If Abort: stop execution entirely
4. **ERROR**: Surface AskUserQuestion: "Security scan encountered an error: {error_message}. (A) Retry, (B) Skip and complete build, (C) Abort build"
   - If Retry: re-invoke skill (step 6b)
   - If Skip: record security_status = "Error — skipped ({error_message})"; proceed to Step 7
   - If Abort: stop execution

## Step 7: Code Simplification (Last Wave Only — continue immediately after Step 6)

**IMPORTANT**: After Step 6 completes (whether scan passed, was acknowledged, or was skipped), you MUST immediately proceed to this step. Do NOT stop or wait for user input between Steps 6 and 7.

This step runs ONLY after Step 6 (Security Scan) completes. It reviews all code changed on the feature branch for reuse, quality, and efficiency opportunities.

### 7a: Check Skip Conditions

1. If `skip_simplify` is true (from Step 0a):
   - Record: simplify_status = "Skipped (--no-simplify)"
   - Proceed to Step 8

2. Detect changed code files:
   - Run: `git diff --name-only main...HEAD`
   - **If this command fails** (e.g., main branch not available, detached HEAD):
     Use AskUserQuestion: "Changed file detection failed: {error_message}"
     Options: (A) Retry, (B) Skip and complete build, (C) Abort
     If Skip: Record simplify_status = "Error — skipped ({error_message})" and proceed to Step 8
   - Filter to code extensions: `.py`, `.js`, `.ts`, `.jsx`, `.tsx`, `.sh`, `.go`, `.rs`, `.java`, `.rb`, `.swift`, `.kt`
   - Exclude patterns: `*.lock`, `*.min.js`, `*.min.css`, `*.map`, `*.generated.*`, `vendor/`, `dist/`, `build/`, `node_modules/`, `.aod/`, `docs/`
   - Store result as `changed_files` list and `file_count`

3. If `file_count` is 0:
   - Record: simplify_status = "Skipped (no code files changed)"
   - Proceed to Step 8

4. If `file_count` > 50:
   - Use AskUserQuestion: "Large diff ({file_count} code files). Simplify may take several minutes. Continue or skip?"
   - Options: (A) Continue with simplify, (B) Skip simplify
   - If user selects Skip: Record simplify_status = "Skipped (user skipped large diff)" and proceed to Step 8

5. Display: "Reviewing {file_count} changed code files for simplification opportunities..."

### 7b: Invoke /simplify

1. Record pre-invocation file states: `git diff --name-only` (to detect which files simplify actually modifies)

2. Invoke the `/simplify` skill via the Skill tool:
   ```
   Skill tool: skill="simplify"
   ```
   Provide the changed file list as context for the review.

3. **Error handling**: If the skill invocation fails (timeout, unavailable, or any error):
   - Use AskUserQuestion: "Code simplification encountered an error: {error_message}"
   - Options:
     (A) Retry — re-invoke the skill
     (B) Skip and complete build — proceed to Step 8
     (C) Abort — halt build execution
   - If Retry: Go back to step 7b.2
   - If Skip: Record simplify_status = "Error — skipped ({error_message})" and proceed to Step 8
   - If Abort: Stop execution entirely

### 7b-docs: Docs-Lint Pass (runs after /simplify, before results evaluation)

**Skip conditions**:
1. If `skip_docs` is true (from Step 0c): skip this sub-step entirely. Record `docslint_status` = "Skipped (--no-docs)". Proceed to Step 7c.
2. If `skip_simplify` is true (from Step 0a): skip this sub-step entirely (docs-lint depends on Step 7's execution context). Record `docslint_status` = "Skipped (--no-simplify)". Proceed to Step 7c.
3. If `file_count` is 0 (from Step 7a): skip this sub-step. Record `docslint_status` = "Skipped (no code files changed)". Proceed to Step 7c.

**Language filter**: Only analyze files in supported languages:
- Python: `.py`
- TypeScript/JavaScript: `.ts`, `.tsx`, `.js`, `.jsx`
- Go: `.go`
- Rust: `.rs`
- Java: `.java`
- Files in unsupported languages are skipped silently (FR-014)

**Complexity estimation**: For each supported file in the `changed_files` list from Step 7a:
1. Identify function/method/class definitions using language-appropriate patterns:
   - Python: `def `, `class `
   - JS/TS: `function `, `=> {`, method definitions in classes
   - Go: `func `
   - Rust: `fn `
   - Java: method declarations within classes
2. For each identified function/method/class, count branch statements as a complexity proxy:
   - Count: `if`, `else if`/`elif`/`else`, `for`, `while`, `match`, `switch`, `case`
   - Each occurrence adds 1 to the complexity score
3. Check for existing docstring/documentation comment:
   - Python: triple-quoted string immediately after definition (`"""` or `'''`)
   - JS/TS: JSDoc comment (`/** ... */`) immediately before definition
   - Go: godoc comment (`//` block) immediately before function
   - Rust: rustdoc comment (`///` or `//!`) immediately before function
   - Java: Javadoc comment (`/** ... */`) immediately before method

**Flagging threshold**: Flag functions/methods where:
- Complexity score >= 3 (3 or more branch statements) AND
- No existing docstring/documentation comment detected
- Functions with complexity < 3 are NOT flagged, even if undocumented (FR-011)
- Functions with existing docstrings are NEVER flagged (FR-012)

**Docstring style detection**: When generating suggested docstrings, detect the file's existing documentation style:
- `.py`: Scan for existing docstrings → Google-style (`Args:`, `Returns:`), numpy-style (`:param`), or Sphinx; default to Google-style if no existing convention
- `.js`/`.ts`/`.jsx`/`.tsx`: JSDoc (`/** @param {type} name */`)
- `.go`: godoc (comment block above function starting with function name)
- `.rs`: rustdoc (`/// Description` with `/// # Arguments` section)
- `.java`: Javadoc (`/** @param name description */`)

**Imprecise complexity detection** (FR-031): If branch counting produces uncertain results (e.g., minified code, template literals containing control flow keywords, unusual syntax), err on the side of NOT flagging. False negatives are acceptable; false positives are not.

**Context limit awareness** (FR-032): If context limits are approached during docs-lint analysis, terminate early with warning "Documentation check truncated (context limit)" and record `docslint_status` = "Truncated ({N} of {total} files analyzed)". The build continues with partial or no results.

**Output**: Collect all flagged items into a `docslint_findings` list, each containing:
- `file_path`: Absolute path to the file
- `line_number`: Line where the function/method is defined
- `function_name`: Name of the function/method/class
- `complexity_score`: Estimated complexity (branch count)
- `suggested_docstring`: Auto-generated docstring matching detected style
- `language`: Detected language of the file

If `docslint_findings` is empty: Record `docslint_status` = "Passed (no flags)". Proceed to Step 7c.
If `docslint_findings` is non-empty: Proceed to Step 7b-docs-approve.

### 7b-docs-approve: Docs-Lint Approval Flow

Present flagged functions to the developer for independent approval (separate from `/simplify` changes per FR-015):

1. Display docs-lint summary via AskUserQuestion:
   ```
   Docs-Lint Review:
     Files analyzed: {supported_file_count} (of {file_count} changed)
     Functions flagged: {flagged_count}

     Flagged items:
     1. {file_path}:{line_number} — {function_name} (complexity: {complexity_score})
        Suggested docstring:
        {suggested_docstring}

     2. {file_path}:{line_number} — {function_name} (complexity: {complexity_score})
        Suggested docstring:
        {suggested_docstring}

     ...

   Options:
     (A) Accept all suggested docstrings
     (B) Skip all — no docstrings added
     (C) Review individually — choose per function
   ```

2. Based on user response:

   **Accept all**:
   - Apply all suggested docstrings to their respective files
   - Stage modified files: `git add {modified_files}`
   - Create commit:
     ```
     docs({NNN}): add docstrings per docs-lint

     Functions documented: {accepted_count}

     Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
     ```
   - Record: `docslint_status` = "Flagged {flagged_count} functions ({accepted_count} accepted)"
   - Record: `docslint_commit` = commit hash

   **Skip all**:
   - No changes made
   - Record: `docslint_status` = "Flagged {flagged_count} functions (0 accepted)"

   **Review individually**:
   - For each flagged item, present via AskUserQuestion:
     ```
     [{index}/{total}] {file_path}:{line_number} — {function_name}
     Complexity: {complexity_score} | Language: {language}

     Suggested docstring:
     {suggested_docstring}

     (A) Accept  (B) Skip
     ```
   - Apply accepted docstrings, skip rejected ones
   - If any were accepted: stage and commit as above with actual accepted count
   - Record: `docslint_status` = "Flagged {flagged_count} functions ({accepted_count} accepted)"

3. Proceed to Step 7c for `/simplify` results evaluation (independent approval flow).

### 7c: Evaluate Results (MANDATORY — continue immediately after /simplify completes)

**IMPORTANT**: After the `/simplify` skill returns, you MUST immediately proceed through this entire step and then Step 8. Do NOT stop, pause, or wait for user input between Steps 7b and 7c.

1. Detect which files were modified by simplify:
   - Run: `git diff --name-only`
   - Compare against pre-invocation state from 7b.1
   - Store `modified_files` list and `modified_count`

2. If `modified_count` is 0:
   - Record: simplify_status = "Passed — no issues found ({file_count} files reviewed)"
   - Proceed to Step 8

3. Get diff statistics: `git diff --stat` on the modified files
   - Extract insertions, deletions counts

4. Present summary to user via AskUserQuestion:
   ```
   Code Simplification Review:
     Files reviewed: {file_count}
     Files modified: {modified_count}
     Changes: +{insertions} -{deletions} lines

     {one-line summary per modified file from simplify output}

   Options:
     (A) Accept all changes — commit as refactor({NNN}): simplify
     (B) Reject all changes — revert modified files and continue
     (C) Skip — discard changes and proceed
   ```

5. Based on user response:

   **Accept**:
   - Stage modified files: `git add {modified_files}`
   - Create commit:
     ```
     refactor({NNN}): simplify code per /simplify review

     Files simplified: {modified_count}
     Changes: +{insertions} -{deletions}

     Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
     ```
   - Record: simplify_status = "Fixed ({modified_count} files, {insertions}+/{deletions}-)"
   - Record: simplify_commit = commit hash

   **Reject**:
   - Revert ONLY the modified files: `git checkout -- {file1} {file2} ...`
     (targeted revert, NOT `git checkout -- .`)
   - Record: simplify_status = "Changes rejected by user ({modified_count} issues found, 0 fixed)"

   **Skip**:
   - Revert modified files: `git checkout -- {file1} {file2} ...`
   - Record: simplify_status = "Skipped by user after review"

## Step 8: Report Completion (MANDATORY — continue immediately after Step 7)

**IMPORTANT**: After Step 7 completes (whether changes were accepted, rejected, skipped, or simplify was skipped entirely), you MUST immediately proceed to this step. Do NOT stop or wait for user input between Steps 7 and 8.

**Re-ground before output**: Re-read the template below exactly. Do not paraphrase or substitute checkpoint/review commentary into the template structure.

Display summary:
```
IMPLEMENTATION COMPLETE

Feature: {feature_number}
Tasks: {completed}/{total}
Waves: {wave_count}

Checkpoint Results:
- P0: {status}
- P1: {status}
- P2: {status}

Final Validation:
- Architect: {status}
- Code Review: {status}
- Security: {status}

Security Scan (Step 6):
- SAST: {sast_status} ({code_file_count} file(s) scanned)
- SCA: {sca_status} ({manifest_count} manifest(s) audited)
- Report: specs/{NNN}-*/security-scan.md
- /security: {security_status}

Code Simplification:
- /simplify: {simplify_status}
- Commit: {simplify_commit}        ← omit line if no commit was created

Documentation:
- CHANGELOG: {changelog_status}
- Docs-lint: {docslint_status}
- API sync: {apisync_status}

{If all APPROVED: "READY FOR DEPLOYMENT"}
{If BLOCKED: "Issues require resolution"}

Deferred Issues: {count}

Next: /aod.deliver FEATURE: {feature_number} - {feature_name}
```

## Quality Checklist

- [ ] All Triad sign-offs approved before execution
- [ ] Checklists verified (or user acknowledged incomplete)
- [ ] Implementation context fully loaded (tasks, plan, spec, assignments)
- [ ] Project setup verified (ignore files for detected technologies)
- [ ] Agent-assignments.md parsed for task->agent mapping
- [ ] Waves executed with parallel agent spawning
- [ ] Execution stopped after each wave with resume instructions (context overflow prevention)
- [ ] TDD approach followed (tests before implementation)
- [ ] Architect checkpoint reviews at P0, P1, P2 boundaries
- [ ] Blocking checkpoint issues resolved before proceeding
- [ ] Final validation completed (Architect + Code + Security)
- [ ] All tasks marked [X] in tasks.md
- [ ] Security Scan step executed or explicitly skipped with reason (--no-security)
- [ ] Security scan findings acknowledged or build halted on CRITICAL/HIGH
- [ ] Security scan status recorded in completion report
- [ ] Code Simplification step executed or explicitly skipped with reason
- [ ] Simplify changes reviewed by user before commit (if applicable)
- [ ] Simplify status recorded in completion report
- [ ] Documentation steps executed or explicitly skipped with reason (--no-docs)
- [ ] Documentation status recorded in completion report
- [ ] Implementation summary displayed

Note: This command requires a complete task breakdown in tasks.md with Triad sign-offs. If tasks are incomplete or missing, run `/aod.tasks` first to generate the task list with governance approval.
