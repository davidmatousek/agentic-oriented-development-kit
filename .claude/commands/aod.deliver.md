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

## Step 1b: Budget Tracking (Non-Fatal)

Initialize session budget tracking. All budget operations are wrapped in error-swallowing guards — failures here never block skill execution.

1. **Check state file**: `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_exists && echo "exists" || echo "none"'`
   - If "none" → step 3 (create state)
   - If "exists" → step 2 (check orchestrator)

2. **Detect active orchestrator**: Run `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_get_loop_context'` (returns `stage|substage|status`) and `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_get ".updated_at"'`.
   - If any stage is `in_progress` AND `updated_at` is within 5 minutes of now → **skip all budget tracking** (orchestrator is active, it handles budget). Proceed to Step 2.
   - Otherwise → standalone mode, continue to step 2b.

2b. **Validate feature ID match**: Extract feature ID from branch: `BRANCH=$(git branch --show-current) && echo "$BRANCH" | sed 's/^\([0-9]\{3\}\).*/\1/'`. Compare with state's `feature_id` via `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_get ".feature_id"'`.
   - Match → step 4
   - No match → Use AskUserQuestion: "A state file exists for feature {state_feature_id} but you're on branch {branch}. Archive old state and create new?" Options: "Archive and create new", "Keep existing state". If archive: copy `.aod/run-state.json` to `specs/{old_feature_id}-*/run-state.json`, then proceed to step 3. If keep: proceed to step 4.

3. **Read calibrated defaults from registry**: Query the performance registry for calibrated budget values:
   ```
   USABLE_BUDGET=$(bash -c 'source .aod/scripts/bash/performance-registry.sh 2>/dev/null && aod_registry_get_default usable_budget || echo 60000')
   SAFETY_MULT=$(bash -c 'source .aod/scripts/bash/performance-registry.sh 2>/dev/null && aod_registry_get_default safety_multiplier || echo 1.5')
   DELIVER_EST=$(bash -c 'source .aod/scripts/bash/performance-registry.sh 2>/dev/null && aod_registry_get_default per_stage_estimates.deliver || echo 5000')
   ```

4. **Create state file**: Extract feature ID from branch (`NNN` from `NNN-*` pattern; default `"000"` if no match). Extract feature name from branch (everything after `NNN-`). Create state via:
   ```
   bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_create '"'"'{"version":"1.0","feature_id":"{NNN}","feature_name":"{name}","github_issue":null,"idea":"","branch":"{branch}","started_at":"{now}","updated_at":"{now}","governance_tier":"standard","current_stage":"deliver","current_substage":null,"session_count":1,"intervention_count":0,"stages":{"discover":{"status":"pending","started_at":null,"completed_at":null,"artifacts":[],"governance":null,"substages":null,"error":null},"define":{"status":"pending","started_at":null,"completed_at":null,"artifacts":[],"governance":null,"substages":null,"error":null},"plan":{"status":"pending","started_at":null,"completed_at":null,"artifacts":[],"governance":null,"substages":{"spec":{"status":"pending","artifacts":[]},"project_plan":{"status":"pending","artifacts":[]},"tasks":{"status":"pending","artifacts":[]}},"error":null},"build":{"status":"pending","started_at":null,"completed_at":null,"artifacts":[],"governance":null,"substages":null,"error":null},"deliver":{"status":"pending","started_at":null,"completed_at":null,"artifacts":[],"governance":null,"substages":null,"error":null}},"token_budget":{"window_total":200000,"usable_budget":{USABLE_BUDGET},"safety_multiplier":{SAFETY_MULT},"estimated_total":0,"stage_estimates":{"discover":{"pre":0,"post":0},"define":{"pre":0,"post":0},"plan":{"pre":0,"post":0},"build":{"pre":0,"post":0},"deliver":{"pre":0,"post":0}},"threshold_percent":80,"adaptive_mode":false,"last_checkpoint":null,"prior_sessions":[]},"error_log":[],"gate_rejections":[]}'"'"''
   ```

5. **Write pre-estimate**: `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_update_budget "deliver" "pre" "{DELIVER_EST}"'`

If any step fails, log the error and continue to Step 2 — budget tracking is non-fatal.

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
| All succeed | Proceed to Step 5 (Retrospective) |
| Partial failure | Prompt: (A) Retry failed, (B) Proceed anyway, (C) Abort |
| All fail | Abort and report errors |

## Step 5: Structured Retrospective

Run the `~aod-deliver` skill's retrospective flow (Steps 2-8 from `.claude/skills/~aod-deliver/SKILL.md`):

1. **Delivery Metrics**: Capture estimated vs. actual duration (actual computed from branch creation date)
2. **Surprise Log**: Prompt for "what surprised us" (1 sentence minimum, required)
3. **Feedback Loop**: Prompt for new ideas — each creates a GitHub Issue with `stage:discover` label and source "Retrospective", then adds it to the Projects board: `source .aod/scripts/bash/github-lifecycle.sh && aod_gh_update_stage "$new_issue_number" "discover"`
4. **Lessons Learned**: Capture key lesson with category, append KB entry to `docs/INSTITUTIONAL_KNOWLEDGE.md`
5. **GitHub Update**: Post delivery metrics as comment on feature's GitHub Issue, transition to `stage:deliver` (at retrospective start)
6. **BACKLOG.md**: Regenerate via `.aod/scripts/bash/backlog-regenerate.sh`

## Step 5b: Performance Registry Population (Non-Fatal)

After the retrospective completes, populate the performance registry with this feature's budget data for future calibration. All operations are non-fatal — failures here never block feature closure.

1. **Check for run-state**: Verify a run-state file exists for this feature:
   ```
   bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_exists && echo "exists" || echo "none"'
   ```
   - If "none" → skip registry population, proceed to Step 6
   - If "exists" → continue

2. **Archive run-state to specs directory**: Copy the run-state to the feature's specs directory before modifying:
   ```
   cp .aod/run-state.json specs/{NNN}-*/run-state.json 2>/dev/null || true
   ```

3. **Populate performance registry**: Call the registry append function with the archived run-state path:
   ```
   bash -c 'source .aod/scripts/bash/performance-registry.sh 2>/dev/null && aod_registry_append_feature "specs/{NNN}-*/run-state.json" || true'
   ```
   - If run-state lacks valid `token_budget` data (no stages with post > 0), the function skips gracefully with an INFO message.
   - If the registry does not exist, the function creates it automatically.

4. **Recalculate calibrated defaults**: Trigger recalculation of calibrated defaults from all features:
   ```
   bash -c 'source .aod/scripts/bash/performance-registry.sh 2>/dev/null && aod_registry_recalculate || true'
   ```

5. **Log result**: If registry update succeeded, note it for inclusion in Step 10's closure report.

## Step 6: Cleanup Tasks

1. **Delete feature branch** (local and remote, ignore if already deleted)
2. **Validate**: Check `git status`, search for TBD/TODO in docs/

## Step 7: Upstream Sync (Optional)

If the project has an upstream template repo to sync to, prompt the user now.

1. Check if `scripts/extract.sh` exists **and** `../agentic-oriented-development-kit/` exists
2. **If both found**: Ask the user: "Run upstream sync?"
   - (A) Yes — run `scripts/extract.sh --sync` (or invoke `/aod.sync-upstream` if available)
   - (B) Skip — continue without syncing
3. **If either is missing**: Skip silently
4. If skipped, note it in the closure report (Step 9) as `[ ] Upstream sync`

## Step 8: Commit and Push

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

## Step 9: Close GitHub Issue

After commit and push, finalize the GitHub Issue lifecycle:

1. Transition from `stage:deliver` to `stage:done`: `source .aod/scripts/bash/github-lifecycle.sh && aod_gh_update_stage "$issue_number" "done"`
2. Close the issue: `gh issue close "$issue_number" --comment "Feature delivered. Retrospective complete."`
3. Regenerate BACKLOG.md: `.aod/scripts/bash/backlog-regenerate.sh`
4. If `gh` is unavailable, skip silently (graceful degradation)

This is the terminal lifecycle state — the issue is now fully closed and removed from the active backlog.

## Step 10: Generate Closure Report

**Re-ground before output**: Re-read the template below exactly. Do not paraphrase or substitute retrospective commentary into the template structure.

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

### Retrospective
- Estimated: {estimated_duration}
- Actual: {actual_duration}
- Surprise: {surprise_log}
- Lessons: Entry {N} in INSTITUTIONAL_KNOWLEDGE.md
- New Ideas: {count or "None"}

### Cleanup
- [x] Feature branch deleted
- [x] All tasks complete
- [x] No TBD/TODO in docs
- [x] Committed and pushed
- [x] GitHub Issue closed (`stage:done`)
- [{sync_status}] AOD-kit upstream sync

### Performance Registry Updated
{registry_section}

**Feature {NUMBER} is now officially CLOSED.**
```

**Registry Section Generation** (for `{registry_section}` in the template above):

After Step 5b (Performance Registry Population) completes, generate the registry section content:

1. **Read registry state**: `bash -c 'source .aod/scripts/bash/performance-registry.sh 2>/dev/null && aod_registry_read || echo "{}"'`

2. **If registry population succeeded** (Step 5b returned success):
   - Parse `features.length` from registry JSON
   - Parse `calibrated_defaults.usable_budget` from registry JSON
   - Parse `calibrated_defaults.per_stage_estimates` from registry JSON
   - Format section:
     ```
     - Features tracked: {N}/5
     - Calibrated usable_budget: {usable_budget} tokens
     - Per-stage averages: discover={D}, define={DEF}, plan={P}, build={B}, deliver={DEL}
     ```
   - If `features.length == 1`, append: `(seed data — calibration improves with more features)`

3. **If registry population failed or was skipped**:
   - Display: `(registry update skipped)`

4. **If registry does not exist** (first feature, no run-state):
   - Display: `(no budget data available)`

### Budget Tracking (Non-Fatal)

1. Read calibrated estimate: `DELIVER_EST=$(bash -c 'source .aod/scripts/bash/performance-registry.sh 2>/dev/null && aod_registry_get_default per_stage_estimates.deliver || echo 5000')`
2. Write post-estimate: `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_exists && aod_state_update_budget "deliver" "post" "{DELIVER_EST}" || true'`
3. Read summary: `bash -c 'source .aod/scripts/bash/run-state.sh && aod_state_exists && aod_state_get_budget_summary || echo "0|0|0|false"'` — returns `estimated_total|usable_budget|threshold_percent|adaptive_mode`
3. Parse the pipe-delimited result. Calculate `utilization = (estimated_total * 100) / usable_budget`.
4. If `estimated_total > 0`, append to the completion output: `(~{utilization}% budget used)`
5. If any step fails, omit the budget line — do not display errors.

## Error Handling

| Scenario | Action |
|----------|--------|
| PR not merged | Prompt to verify on GitHub or delete branch |
| Tasks incomplete | List incomplete, prompt for resolution |
| Agent fails | Show results table, prompt for retry/proceed/abort |
| Git push fails | Report error, suggest manual push |
