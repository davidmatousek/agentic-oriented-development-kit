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

**Step 0a: Parse --no-simplify**

1. If `$ARGUMENTS` contains `--no-simplify`:
   - Set `skip_simplify = true`
   - Strip `--no-simplify` from `$ARGUMENTS` (trim extra whitespace)
   - Continue to Step 1 with remaining arguments

2. If `$ARGUMENTS` does NOT contain `--no-simplify`:
   - Set `skip_simplify = false`
   - Continue to Step 1 with `$ARGUMENTS` unchanged

## Overview

Executes feature implementation with Architect checkpoint reviews at priority boundaries.

**Flow**: Validate tasks --> Check checklists --> Load context --> Setup project --> Execute waves with parallel agents --> Checkpoint reviews --> Final validation --> Code simplification --> Report completion

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
7. **GitHub Lifecycle Update (early)**: If a GitHub Issue exists for this feature, update its stage label to `stage:build` using `aod_gh_update_stage` from `.aod/scripts/bash/github-lifecycle.sh`. This moves the issue to the Build column on the Projects board at the *start* of implementation, reflecting current work status. Run `.aod/scripts/bash/backlog-regenerate.sh` to refresh BACKLOG.md. If `gh` is unavailable, skip silently (graceful degradation).

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

6. **STOP after wave** (MANDATORY — context overflow prevention):
   - Run `/continue` to generate a NEXT-SESSION.md handoff file
   - Display wave completion summary:
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

## Step 6: Code Simplification (Last Wave Only)

This step runs ONLY after Step 5 (Final Validation) completes. It reviews all code changed on the feature branch for reuse, quality, and efficiency opportunities.

### 6a: Check Skip Conditions

1. If `skip_simplify` is true (from Step 0):
   - Record: simplify_status = "Skipped (--no-simplify)"
   - Proceed to Step 7

2. Detect changed code files:
   - Run: `git diff --name-only main...HEAD`
   - **If this command fails** (e.g., main branch not available, detached HEAD):
     Use AskUserQuestion: "Changed file detection failed: {error_message}"
     Options: (A) Retry, (B) Skip and complete build, (C) Abort
     If Skip: Record simplify_status = "Error — skipped ({error_message})" and proceed to Step 7
   - Filter to code extensions: `.py`, `.js`, `.ts`, `.jsx`, `.tsx`, `.sh`, `.go`, `.rs`, `.java`, `.rb`, `.swift`, `.kt`
   - Exclude patterns: `*.lock`, `*.min.js`, `*.min.css`, `*.map`, `*.generated.*`, `vendor/`, `dist/`, `build/`, `node_modules/`, `.aod/`, `docs/`
   - Store result as `changed_files` list and `file_count`

3. If `file_count` is 0:
   - Record: simplify_status = "Skipped (no code files changed)"
   - Proceed to Step 7

4. If `file_count` > 50:
   - Use AskUserQuestion: "Large diff ({file_count} code files). Simplify may take several minutes. Continue or skip?"
   - Options: (A) Continue with simplify, (B) Skip simplify
   - If user selects Skip: Record simplify_status = "Skipped (user skipped large diff)" and proceed to Step 7

5. Display: "Reviewing {file_count} changed code files for simplification opportunities..."

### 6b: Invoke /simplify

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
     (B) Skip and complete build — proceed to Step 7
     (C) Abort — halt build execution
   - If Retry: Go back to step 6b.2
   - If Skip: Record simplify_status = "Error — skipped ({error_message})" and proceed to Step 7
   - If Abort: Stop execution entirely

### 6c: Evaluate Results

1. Detect which files were modified by simplify:
   - Run: `git diff --name-only`
   - Compare against pre-invocation state from 6b.1
   - Store `modified_files` list and `modified_count`

2. If `modified_count` is 0:
   - Record: simplify_status = "Passed — no issues found ({file_count} files reviewed)"
   - Proceed to Step 7

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

## Step 7: Report Completion

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

Code Simplification:
- /simplify: {simplify_status}
- Commit: {simplify_commit}        ← omit line if no commit was created

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
- [ ] Code Simplification step executed or explicitly skipped with reason
- [ ] Simplify changes reviewed by user before commit (if applicable)
- [ ] Simplify status recorded in completion report
- [ ] Implementation summary displayed

Note: This command requires a complete task breakdown in tasks.md with Triad sign-offs. If tasks are incomplete or missing, run `/aod.tasks` first to generate the task list with governance approval.
