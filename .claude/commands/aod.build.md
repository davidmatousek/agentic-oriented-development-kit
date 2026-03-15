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

**Step 0a: Parse --no-security**

1. If `$ARGUMENTS` contains `--no-security`:
   - Set `skip_security = true`
   - Strip `--no-security` from `$ARGUMENTS` (trim extra whitespace)
   - Continue to Step 0b with remaining arguments

2. If `$ARGUMENTS` does NOT contain `--no-security`:
   - Set `skip_security = false`
   - Continue to Step 0b with `$ARGUMENTS` unchanged

**Step 0b: Parse --orchestrated**

1. If `$ARGUMENTS` contains `--orchestrated`:
   - Set `orchestrated = true`
   - Strip `--orchestrated` from `$ARGUMENTS` (trim extra whitespace)
2. If `$ARGUMENTS` does NOT contain `--orchestrated`:
   - Set `orchestrated = false`

**Step 0c: Parse --autonomous**

1. If `$ARGUMENTS` contains `--autonomous`:
   - Set `autonomous = true`
   - Strip `--autonomous` from `$ARGUMENTS` (trim extra whitespace)
2. If `$ARGUMENTS` does NOT contain `--autonomous`:
   - Set `autonomous = false`

## Overview

Executes feature implementation with Architect checkpoint reviews at priority boundaries.

**Flow**: Validate tasks → Check checklists → Load context → Setup project → Execute waves with parallel agents → Checkpoint reviews → Final validation → Security scan → Report completion

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
   - **If `autonomous == true`**: Auto-select `"Proceed"`. Display: `"Auto-selected: Proceed past incomplete checklists (autonomous mode)"`. Continue to step 2b.
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

6. **Wave continuation rule** (context-safe multi-wave execution):

   After each non-final wave, decide whether to **continue** or **stop**:

   **Continue to next wave** if:
   - `orchestrated == true` (no wave ceiling — orchestrator manages context), OR
   - This conversation has executed fewer than 3 waves so far

   **Stop and hand off** if:
   - `orchestrated == false` AND this conversation has executed 3 or more waves (hard ceiling)

   When `orchestrated == true`, log a soft warning at wave 5:
   ```
   Note: Wave 5+ reached. Context usage may be high. Continuing under orchestrated mode.
   ```

   **When continuing**: Display a brief wave summary and proceed to the next wave:
   ```
   WAVE {N}/{total} COMPLETE — {completed}/{total} tasks ({percentage}%)
   Continuing to Wave {N+1}...
   ```

   **When stopping** (only when `orchestrated == false`): Run `/continue` to generate a NEXT-SESSION.md handoff file, then display:
   ```
   WAVE {N}/{total} COMPLETE

   Tasks completed this wave: {count}
   Total progress: {completed}/{total} tasks ({percentage}%)

   Next: Wave {N+1} — {brief description from agent-assignments.md}

   To continue: Start a new conversation and run `/aod.build`
   The command will automatically resume from Wave {N+1}.

   Resume prompt:
     claude "Resume {feature} implementation (branch: {branch}). Waves 1-{N} complete. Run /aod.build to continue with Wave {N+1}."
   ```
   Then **STOP EXECUTION**.

   **Last wave exception**: If this is the LAST wave, always proceed to Step 5 (Final Validation) regardless of context state.

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

This step runs ONLY after the LAST wave completes (i.e., all tasks in all waves are marked `[X]`). For non-final waves, Step 4.6 stops execution instead.

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

## Step 6: Security Scan (Last Wave Only)

This step runs ONLY after Step 5 (Final Validation) completes. It analyzes all code files and dependency manifests changed on the feature branch for OWASP Top 10 vulnerabilities and known CVE patterns.

### 6a: Check Skip Conditions

1. If `skip_security` is true (from Step 0a):
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
4. **ERROR**:
   - **If `autonomous == true`**: Auto-select `"Skip and complete build"`. Display: `"Auto-selected: Skip security scan error (autonomous mode)"`. Record security_status = "Error — skipped ({error_message})"; proceed to Step 7.
   - Surface AskUserQuestion: "Security scan encountered an error: {error_message}. (A) Retry, (B) Skip and complete build, (C) Abort build"
   - If Retry: re-invoke skill (step 6b)
   - If Skip: record security_status = "Error — skipped ({error_message})"; proceed to Step 7
   - If Abort: stop execution

## Step 7: Report Completion (MANDATORY — continue immediately after Step 6)

**IMPORTANT**: After Step 6 completes (whether scan passed, was acknowledged, or was skipped), you MUST immediately proceed to this step. Do NOT stop or wait for user input between Steps 6 and 7.

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

{If all APPROVED: "READY FOR DEPLOYMENT"}
{If BLOCKED: "Issues require resolution"}

Deferred Issues: {count}

Next: /aod.deliver FEATURE: {feature_number} - {feature_name}
Then: /aod.document (code quality review, CHANGELOG, docstrings)
```

**Structured completion signal** (orchestrated mode only):

When `orchestrated == true`, append a machine-readable signal after the completion report:

```
<!-- AOD_BUILD_RESULT:COMPLETE:waves={wave_count}:tasks={completed}/{total} -->
```

When `orchestrated == true` and the build stops early (any reason):

```
<!-- AOD_BUILD_RESULT:PARTIAL:waves={completed_waves}/{total_waves}:tasks={completed}/{total}:reason={reason} -->
```

When `orchestrated == false` (standalone): no change — keep current display format only.

## Quality Checklist

- [ ] All Triad sign-offs approved before execution
- [ ] Checklists verified (or user acknowledged incomplete)
- [ ] Implementation context fully loaded (tasks, plan, spec, assignments)
- [ ] Project setup verified (ignore files for detected technologies)
- [ ] Agent-assignments.md parsed for task->agent mapping
- [ ] Waves executed with parallel agent spawning
- [ ] Wave continuation respected (max 3 waves standalone, no ceiling when orchestrated)
- [ ] --orchestrated flag parsed correctly (when present)
- [ ] --autonomous flag parsed correctly (when present)
- [ ] Autonomous defaults applied for incomplete checklists and security scan errors (when autonomous)
- [ ] Wave ceiling skipped when orchestrated (no hard stop at 3)
- [ ] Structured completion signal emitted when orchestrated
- [ ] TDD approach followed (tests before implementation)
- [ ] Architect checkpoint reviews at P0, P1, P2 boundaries
- [ ] Blocking checkpoint issues resolved before proceeding
- [ ] Final validation completed (Architect + Code + Security)
- [ ] All tasks marked [X] in tasks.md
- [ ] Security Scan step executed or explicitly skipped with reason (--no-security)
- [ ] Security scan findings acknowledged or build halted on CRITICAL/HIGH
- [ ] Security scan status recorded in completion report
- [ ] Implementation summary displayed

Note: This command requires a complete task breakdown in tasks.md with Triad sign-offs. If tasks are incomplete or missing, run `/aod.tasks` first to generate the task list with governance approval. After build and delivery, run `/aod.document` for code quality review (simplification, docstrings, CHANGELOG, API docs).
