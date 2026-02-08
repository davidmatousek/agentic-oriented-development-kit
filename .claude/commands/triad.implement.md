---
description: Execute implementation with Architect checkpoints at critical phases - Streamlined v2
---

## User Input

```text
$ARGUMENTS
```

Consider user input before proceeding (if not empty).

## Overview

Executes feature implementation with Architect checkpoint reviews at priority boundaries.

**Flow**: Validate tasks --> Check checklists --> Load context --> Setup project --> Execute waves with parallel agents --> Checkpoint reviews --> Final validation

**Key Feature**: Architect reviews at P0->P1->P2 boundaries for governed quality gates.

## Step 1: Validate Prerequisites

1. Get branch: `git branch --show-current` --> must match `NNN-*` pattern
2. Find tasks: `specs/{NNN}-*/tasks.md` --> must exist
3. Parse frontmatter: Verify all three sign-offs (PM, Architect, Team-Lead) are APPROVED
4. Find assignments: `specs/{NNN}-*/agent-assignments.md` --> must exist
5. If validation fails: Show error with required workflow order and exit

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

4. **Verify completion**: Check all wave tasks marked `[X]`
5. **Checkpoint review** (if wave triggers checkpoint):
   - Launch architect agent for review
   - Parse STATUS: APPROVED / APPROVED_WITH_CONCERNS / CHANGES_REQUESTED / BLOCKED
   - If BLOCKED on blocking checkpoint: spawn debugger, retry, or exit
   - If CHANGES_REQUESTED: spawn appropriate agent to fix, retry review

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

## Step 5: Final Validation

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

## Step 6: Report Completion

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

{If all APPROVED: "READY FOR DEPLOYMENT"}
{If BLOCKED: "Issues require resolution"}

Deferred Issues: {count}

Next: Create PR, deploy to staging, run acceptance tests
```

## Quality Checklist

- [ ] All Triad sign-offs approved before execution
- [ ] Checklists verified (or user acknowledged incomplete)
- [ ] Implementation context fully loaded (tasks, plan, spec, assignments)
- [ ] Project setup verified (ignore files for detected technologies)
- [ ] Agent-assignments.md parsed for task->agent mapping
- [ ] Waves executed with parallel agent spawning
- [ ] TDD approach followed (tests before implementation)
- [ ] Architect checkpoint reviews at P0, P1, P2 boundaries
- [ ] Blocking checkpoint issues resolved before proceeding
- [ ] Final validation completed (Architect + Code + Security)
- [ ] All tasks marked [X] in tasks.md
- [ ] Implementation summary displayed

Note: This command requires a complete task breakdown in tasks.md with Triad sign-offs. If tasks are incomplete or missing, run `/triad.tasks` first to generate the task list with governance approval.
