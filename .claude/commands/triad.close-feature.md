---
description: Close a completed feature with automatic documentation updates and cleanup (Triad-enhanced)
---

## Purpose

Close a completed feature by validating readiness, launching parallel documentation agents, performing cleanup, and committing all changes.

## Input

```
$ARGUMENTS
```

Feature number (e.g., `007` or `007-phase-brain-rag`). If omitted, detect from recent PRs or prompt.

## Step 1: Validate Closure Readiness

Run these checks (in parallel where possible):

| Check | Command | Pass Condition |
|-------|---------|----------------|
| Feature exists | `ls specs/*{NUMBER}*` | Directory found |
| PR merged | `git branch -a \| grep {NUMBER}` | Branch NOT found (deleted after merge) |
| Tasks complete | `grep "^\- \[ \]" specs/{FEATURE}/tasks.md` | Zero incomplete tasks |

**If validation fails**, prompt user with options:
- Branch exists: (A) Check PR status, (B) Delete branch, (C) Abort
- Tasks incomplete: (A) Mark complete, (B) Abort, (C) Proceed anyway

## Step 2: Gather Feature Context

Read `specs/{FEATURE}/tasks.md` and `specs/{FEATURE}/spec.md` to extract:

| Field | Source |
|-------|--------|
| Feature number & name | Directory name |
| Completion date | Today |
| PR number | Git log or tasks.md |
| Task count | Count `[x]` in tasks.md |
| Key deliverables | spec.md summary |

## Step 3: Launch Documentation Agents (PARALLEL)

Launch 3 agents simultaneously. Each reads `docs/DOCS_TO_UPDATE_AFTER_NEW_FEATURE.md` and updates their assigned section.

| Agent | Checklist Section | Key Files |
|-------|-------------------|-----------|
| product-manager | Section 1: Product | STATUS.md, completed-features.md, roadmap files, PRD INDEX |
| architect | Section 2: Architecture | architecture/README.md, tech-stack.md, CLAUDE.md |
| devops | Section 3: DevOps | devops/README.md, environment-variables.md, env configs |

**Agent prompt template:**
```
Update {DOMAIN} documentation for Feature {NUMBER} ({NAME}) closure.
Reference: Section {N} of docs/DOCS_TO_UPDATE_AFTER_NEW_FEATURE.md
Context: Date={DATE}, PR=#{PR}, Tasks={COUNT} complete
Output: List files updated with brief summary.
```

## Step 4: Handle Agent Results

| Scenario | Action |
|----------|--------|
| All succeed | Proceed to Step 5 |
| Partial failure | Prompt: (A) Retry failed, (B) Proceed anyway, (C) Abort |
| All fail | Abort and report errors |

## Step 5: Cleanup Tasks

1. **Delete feature branch** (local and remote, ignore if already deleted)
2. **Prompt for learnings**: Ask if any insights for INSTITUTIONAL_KNOWLEDGE.md (allow "skip")
3. **Validate**: Check `git status`, search for TBD/TODO in docs/

## Step 6: Commit and Push

Stage `docs/`, `deployment/`, `CLAUDE.md` and commit:

```
docs: close Feature {NUMBER} - update all documentation

Product: STATUS.md, completed-features.md, roadmap (PM)
Architecture: README.md, tech-stack.md (Architect)
DevOps: environment configs (DevOps)
Cleanup: branch deleted, tasks verified

Co-Authored-By: Claude <noreply@anthropic.com>
```

Then `git push origin main`.

## Step 7: Generate Closure Report

```markdown
## ✅ Feature {NUMBER} Closure Complete

**Feature**: {NUMBER} - {NAME}
**Closed**: {DATE}
**Commit**: {HASH}

### Documentation Updates

| Domain | Agent | Files | Status |
|--------|-------|-------|--------|
| Product | product-manager | {n} | ✅ |
| Architecture | architect | {n} | ✅ |
| DevOps | devops | {n} | ✅ |

### Cleanup
- [x] Feature branch deleted
- [x] All tasks complete
- [x] No TBD/TODO in docs
- [x] Committed and pushed

**Feature {NUMBER} is now officially CLOSED.**
```

## Error Handling

| Scenario | Action |
|----------|--------|
| PR not merged | Prompt to verify on GitHub or delete branch |
| Tasks incomplete | List incomplete, prompt for resolution |
| Agent fails | Show results table, prompt for retry/proceed/abort |
| Git push fails | Report error, suggest manual push |
