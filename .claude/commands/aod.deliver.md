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

## Step 0: Parse Flags

1. If `$ARGUMENTS` contains `--autonomous`:
   - Set `autonomous = true`
   - Strip `--autonomous` from `$ARGUMENTS` (trim extra whitespace)
   - Default: `autonomous = false`
2. If `$ARGUMENTS` contains `--require-tests`:
   - Set `require_tests = true`
   - Strip `--require-tests` from `$ARGUMENTS` (trim extra whitespace)
   - Default: `require_tests = false`

<!-- pr_per_cycle:single -->
#### Flags (single mode)

1. If `$ARGUMENTS` contains `--orchestrated`:
   - Set `orchestrated = true`
   - Strip `--orchestrated` from `$ARGUMENTS` (trim extra whitespace) so feature-number detection is not polluted
   - Default: `orchestrated = false`
<!-- /pr_per_cycle:single -->

#### Mode resolution (both modes)

1. Determine `FEATURE` (full `NNN-name`) and `NNN` from the remaining arguments, else from `git branch --show-current`.
2. Resolve the mode (library: `.aod/scripts/bash/aod-config.sh`):

   ```bash
   source .aod/scripts/bash/aod-config.sh
   rc=0
   PR_MODE=$(aod_pr_mode "$FEATURE") || rc=$?   # add --autonomous when autonomous == true
   ```

   - rc 4: halt with `invalid_config` (print `Halted — deliver: invalid_config`, then stop).
   - rc 6 (ambiguous feature branch): halt with `precondition_failed` (print `Halted — deliver: precondition_failed`, then stop).
   - `aod_pr_mode` writes the pin `.aod/pr-mode/${NNN}` only while on the feature branch.
3. Carry `PR_MODE`, `FEATURE`/`NNN` and `orchestrated` to the `~aod-deliver` skill the same way `require_tests` and `autonomous` are carried (the parameters must exist in both the command and the skill).
4. When `PR_MODE` is not `single`, every single-mode block in this file is ignored and the split text applies unchanged.


## Step 1: Validate Closure Readiness

Run these checks (in parallel where possible):

| Check | Command | Pass Condition |
|-------|---------|----------------|
| Feature exists | `ls specs/*{NUMBER}*` | Directory found |
| PR merged | `git branch -a \| grep {NUMBER}` | Branch NOT found (deleted after merge) |
| Tasks complete | `grep "^\- \[ \]" specs/{FEATURE}/tasks.md` | Zero incomplete tasks |

### Branch & PR Handling (Automatic, split mode)

Per git workflow rules, feature branches require PRs — handle this automatically without prompting:

1. **If uncommitted changes exist**: Stage and commit all changes with a conventional commit message
2. **If branch is not pushed**: Push to remote with `-u` flag
3. **If no PR exists**: Create one via `gh pr create` with a summary of all branch commits
4. **If PR exists but not merged**: Merge it via `gh pr merge --squash --delete-branch`
5. **If PR already merged and branch deleted**: Proceed directly

Only prompt the user if an automated step fails (e.g., merge conflicts, CI failure).

<!-- pr_per_cycle:single -->
### Branch & PR Handling (single mode)

Single mode replaces the split rows "PR merged" and the five numbered handling rules above. Deliver stays on the feature branch and NEVER merges.

1. Assert `git branch --show-current` matches `^${NNN}-` and is not the default branch (`aod_default_branch`). If the PR is already merged or the branch is missing, error out and stop. Then set `FEATURE=$(git branch --show-current)`. Every refspec in this command (`git push origin HEAD:refs/heads/$FEATURE`) uses this value, never the command argument (which may be only `NNN`).
2. Commit pending changes with a conventional commit message, then push with an explicit refspec: `git push origin HEAD:refs/heads/$FEATURE`.
3. If no PR exists for the branch, create it via `gh pr create` with a body containing `Closes #$((10#$NNN))` (the unpadded issue number) and the line `<!-- aod:pr_per_cycle=single -->`.
4. If `gh` is unavailable: commit and push, print "Open the PR manually; its body must contain `Closes #<issue>` (the unpadded issue number, e.g. `#204` or `#21`) and `<!-- aod:pr_per_cycle=single -->`", and continue (the skill's PR-ready step is skipped).
5. Do not merge, delete the branch, or enable auto-merge anywhere in this command.
<!-- /pr_per_cycle:single -->

### Other Validation Failures

- Tasks incomplete:
  - **If `autonomous == true`**: Auto-select `"Proceed anyway"`. Display: `"Auto-selected: Proceed past incomplete tasks (autonomous mode)"`
  - Else: (A) Mark complete, (B) Abort, (C) Proceed anyway

## Step 2: Gather Feature Context

Read `specs/{FEATURE}/tasks.md` and `specs/{FEATURE}/spec.md` to extract:

| Field | Source |
|-------|--------|
| Feature number & name | Directory name |
| Completion date | Today |
| PR number | Git log or tasks.md |
| Task count | Count `[x]` in tasks.md |
| Key deliverables | spec.md summary |
| Accomplishments | User stories completed from spec.md + key tasks from tasks.md |
| How to see & test | Acceptance criteria from spec.md + any test/run commands from plan.md |

## Step 3: Launch Documentation Agents (PARALLEL)

**Pre-snapshot**: Before launching agents, capture the current file change state: `git diff --name-only` → store as `pre_agent_files`.

Launch 3 agents simultaneously. Each reads `docs/DOCS_TO_UPDATE_AFTER_NEW_FEATURE.md` and updates their assigned section.

| Agent | Checklist Section | Key Files |
|-------|-------------------|-----------|
| product-manager | Section 1: Product | STATUS.md, completed-features.md, roadmap files, PRD INDEX |
| architect | Section 2: Architecture | architecture/README.md, tech-stack.md |
| devops | Section 3: DevOps | devops/README.md, CI_CD_GUIDE.md, environment-variables.md, env configs |

**Agent prompt template:**
```
Update {DOMAIN} documentation for Feature {NUMBER} ({NAME}) closure.
Reference: Section {N} of docs/DOCS_TO_UPDATE_AFTER_NEW_FEATURE.md
Context: Date={DATE}, PR=#{PR}, Tasks={COUNT} complete
Delivery document: specs/{NNN}-*/delivery.md (generated by Skill Step 11)
Output: List files updated with brief summary.
```

## Step 4: Handle Agent Results

| Scenario | Action |
|----------|--------|
| All succeed | Proceed to Step 5 (Documentation Change Validation) |
| Partial failure | **If `autonomous == true`**: Auto-select `"Proceed anyway"`. Else: Prompt: (A) Retry failed, (B) Proceed anyway, (C) Abort |
| All fail | Abort and report errors |

## Step 5: Documentation Change Validation

After Step 4 handles agent results, validate that documentation agents actually produced file changes.

1. **Post-snapshot**: Capture current file change state: `git diff --name-only` → store as `post_agent_files`
2. **Compare**: Diff `post_agent_files` against `pre_agent_files` (captured in Step 3) to identify newly modified files
3. **If no new changes detected**: Display warning:
   ```
   Warning: Documentation agents reported success but no files were modified.
   Options: (A) Investigate — review agent output, (B) Skip — proceed with delivery
   ```
   This step is non-blocking — the developer can always skip and proceed.
4. **If changes detected**: Display confirmation list of modified file paths:
   ```
   Documentation agents modified {N} file(s):
   - {file_path_1}
   - {file_path_2}
   ...
   ```

## Step 6: Structured Retrospective

Run the `~aod-deliver` skill's retrospective and validation flow (Steps 2-14 from `.claude/skills/~aod-deliver/SKILL.md`):

**Pass flags to skill**: The `require_tests` and `autonomous` flags parsed in Step 0 must be available to the skill's Step 9d (Gate Decision) for gate mode evaluation.

1. **Delivery Metrics**: Capture estimated vs. actual duration (actual computed from branch creation date)
2. **Surprise Log**: Prompt for "what surprised us" (1 sentence minimum, required)
   - **If `autonomous == true`**: Auto-provide `"Automated delivery — no surprises logged"`. Display: `"Auto-selected: default surprise log (autonomous mode)"`
3. **Feedback Loop**: Prompt for new ideas — for each idea, construct a `BODY` variable with the structured template below, then create a GitHub Issue via `bash .aod/scripts/bash/create-issue.sh --title "{idea_description}" --body "$BODY" --stage discover --type retro` (handles both issue creation and project board sync)

   <!-- Source of truth: .claude/skills/~aod-deliver/SKILL.md lines 144-160 -->
   **Body template for `$BODY`**:
   ```markdown
   # {idea_description}

   ## ICE Score
   Impact: —, Confidence: —, Effort: — = **Not yet scored**

   ## Evidence
   Retrospective: Emerged during delivery of {feature_name}

   ## Metadata
   - Source: Retrospective
   - Priority: Not yet scored
   - Date: {YYYY-MM-DD}
   - Status: New (from retrospective)
   - Origin Feature: {feature_name}
   ```

   - **If `autonomous == true`**: Skip feedback prompt (no new ideas to capture). Display: `"Auto-selected: skip feedback loop (autonomous mode)"`
4. **Lessons Learned**: Capture key lesson with category, append KB entry to `docs/INSTITUTIONAL_KNOWLEDGE.md`
   - **If `autonomous == true`**: Auto-generate a brief lesson from the delivery context. Display: `"Auto-generated: KB entry from delivery context (autonomous mode)"`
5. **GitHub Update**: (Handled by skill — see skill Step 1 for `stage:deliver` transition and skill Step 7 for metrics comment)
6. **E2E Validation Gate**: Run Step 9 (sub-steps 9a-9d) — detect Playwright, invoke tester agent, parse results, evaluate gate decision using `require_tests` and `autonomous` flags
7. **Build-Wave Test Evidence**: Before Step 10 artifact detection, discover build-wave test results alongside E2E results:
   - Scan `specs/{NNN}-*/test-results/wave-*/results.json` for per-wave test outcomes
   - Scan `specs/{NNN}-*/test-results/summary.json` for the build-wide aggregate summary
   - If found, parse pass/fail counts from each `results.json` and the overall status from `summary.json`
   - Merge build-wave metrics into `test_evidence.metrics` alongside any E2E results from `.aod/test-results/`
   - Include a **Build-Wave Test Results** subsection in the delivery document's Test Evidence section:
     ```
     ### Build-Wave Test Results
     | Wave | Tests | Passed | Failed | Status |
     |------|-------|--------|--------|--------|
     | wave-1 | {total} | {passed} | {failed} | {pass/fail} |
     **Build Summary**: {summary.json overall status} — {total_passed}/{total_tests} passed
     ```
   - If no build-wave directories exist, omit the subsection silently (non-fatal)

## Step 7: Cleanup Tasks

<!-- pr_per_cycle:single -->
#### Cleanup (single mode)

Skipped in single mode: the branch must survive until Document's closeout merges the PR. See `/aod.document` closeout. The split text below applies only in split mode.
<!-- /pr_per_cycle:single -->

1. **Delete feature branch** (local and remote, ignore if already deleted)
2. **Validate**: Check `git status`, search for TBD/TODO in docs/

## Step 8: Upstream Sync (Template Repo Only)

<!-- pr_per_cycle:single -->
#### Upstream sync (single mode)

Skipped in single mode with zero output; sync belongs to Document's closeout. The split text below applies only in split mode.
<!-- /pr_per_cycle:single -->

This step applies ONLY to the upstream template project. Consumer projects will never have `scripts/extract.sh` — skip this step entirely with NO output, NO message, and NO mention in the closure report.

1. Check if `scripts/extract.sh` exists **and** `../agentic-oriented-development-kit/` exists
2. **If both found**:
   - **If `autonomous == true`**: Auto-select `"Yes"`. Display: `"Auto-selected: Run upstream sync (autonomous mode)"`. Run the sync.
   - Ask the user: "Run upstream sync?"
     - (A) Yes — run `scripts/extract.sh --sync`
     - (B) Skip — continue without syncing
3. **If either is missing**: Skip with ZERO output — do not print any message, warning, or status. Proceed directly to Step 9.
4. Only include the "AOD-kit upstream sync" line in the closure report (Step 12) if `scripts/extract.sh` exists

## Step 9: Commit and Push

### 9a: Regenerate Snapshots (Prevent CI Divergence)

Before staging, regenerate the file-coverage snapshots so any new files added during the retrospective (ADR, delivery.md, KB entries, PRD updates) are acknowledged. This closes the recurring class of "CI fails on extract/manifest coverage after /aod.deliver commits" captured in KB Entries 38 and 39.

Only run these when the corresponding infrastructure is present in the repo:

1. **Extract-classification snapshot**: If `scripts/check-extract-coverage.sh` exists, run `make extract-classify` (or `bash scripts/check-extract-coverage.sh --regenerate > scripts/extract-classification.txt`). Skip silently if the script is absent.
2. **Manifest coverage check**: If `scripts/check-manifest-coverage.sh` exists, run it. If it reports uncategorized paths, STOP and ask the user how to categorize them — new top-level directories need an explicit category decision (`owned|`, `user|`, `ignore|`, etc.) in `.aod/template-manifest.txt`. Skip silently if the script is absent.

Both snapshots, if regenerated, are staged alongside the docs in Step 9b.

### 9b: Stage and Commit

<!-- pr_per_cycle:single -->
#### Stage and commit (single mode)

Single mode commits to the feature branch and never touches the default branch. The split staging, commit and push text below applies only in split mode.

1. Assert the current branch is not the default branch (`[ "$(git branch --show-current)" != "$(aod_default_branch)" ]`) and matches `^${NNN}-`. If not, stop with an error.
2. Stage the explicit single-mode set: `docs/`, `deployment/`, `CLAUDE.md`, any snapshots regenerated in 9a, `specs/${NNN}-*/` (delivery.md, `test-results/**`) and `.aod/pr-mode/${NNN}`.
3. Then run `git add -u`. On a feature branch every tracked modification belongs to the feature, so this also covers `.aod/audit/*.jsonl` and any other tracked file deliver writes.
4. Commit with the same message layout as split (subject `docs: close Feature {NUMBER} - update all documentation`, trailer `Co-Authored-By: Claude <noreply@anthropic.com>`; keep the trailer generic).
5. Push with `git push origin HEAD:refs/heads/$FEATURE`.
6. After the commit, if `git status --porcelain --untracked-files=no` is non-empty, list the remaining tracked changes as a warning.
<!-- /pr_per_cycle:single -->

Stage `docs/`, `deployment/`, `CLAUDE.md`, and any regenerated snapshots from Step 9a, then commit:

```
docs: close Feature {NUMBER} - update all documentation

Product: STATUS.md, completed-features.md, roadmap (PM)
Architecture: README.md, tech-stack.md (Architect)
DevOps: CI_CD_GUIDE.md, environment configs (DevOps)
Cleanup: branch deleted, tasks verified

Co-Authored-By: Claude <noreply@anthropic.com>
```

> **Trailer must stay generic.** Do NOT pin a model name or version into the trailer above — this command ships to adopters via `extract.sh`; a pinned trailer mis-attributes their commits and re-introduces attribution drift.

Then `git push origin main`.

> **Post-merge exception**: `aod.deliver` runs AFTER the squash-merge to main, so this direct `git push origin main` of the closed-feature docs is the one legitimate direct-to-main push in the workflow. Documentation only — recorded here as an exception; no automated check performs or verifies it.

## Step 10: Close GitHub Issue

<!-- pr_per_cycle:single -->
#### Issue lifecycle (single mode)

In single mode the issue intentionally stays open at `stage:deliver`; Document's closeout finalizes it. The skill does not relabel or close it, and this command only confirms the issue is still open. The split text below applies only in split mode.
<!-- /pr_per_cycle:single -->

After commit and push, the skill (Steps 12 and 8) finalizes the GitHub Issue lifecycle — `stage:done` transition, issue close, and BACKLOG.md regeneration are all owned by the skill. This command step confirms the close is complete.

1. Confirm the GitHub Issue is closed (performed by skill Step 12): the issue transitions to `stage:done`, closes with a delivery comment, and BACKLOG.md is regenerated.
2. If `gh` is unavailable, skip silently (graceful degradation).

## Step 11: User Story Export

<!-- pr_per_cycle:single -->
#### Story export (single mode)

In single mode the issue is still open, so the prerequisite differs from the split text below:

- Prerequisite: the issue carries `stage:deliver`, `stage:document` or `stage:done`. If it carries none of them, skip with message "Story export skipped: issue is not at stage:deliver, stage:document or stage:done".
- All other sub-steps (read issue, `## Stories` check, duplicate check, append, stage and commit) are unchanged.
- After the export commit, push it with `git push origin HEAD:refs/heads/$FEATURE`, so a later "Document later" choice leaves no local-only commit.
<!-- /pr_per_cycle:single -->

After the GitHub Issue is closed with `stage:done`, export validated user stories to the aggregated reference.

1. **Read GitHub Issue**: Run `gh issue view {NUMBER} --json body,labels` to fetch the issue body and labels
2. **Check prerequisites**:
   - If `gh` CLI is unavailable: skip gracefully with no output (do not block delivery)
   - If the issue has no `stage:done` label: skip with message "Story export skipped: issue does not have stage:done label"
   - If the issue body has no `## Stories` section: skip with message "Story export skipped: no ## Stories section found in issue body"
3. **Extract stories**: Parse the text between `## Stories` and the next `##` heading (or end of body)
4. **Check for duplicates**: Read `docs/product/05_User_Stories/README.md` and search for `### Feature {NUMBER}:` heading
   - If heading already exists: skip with message "Story export skipped: stories already present for Feature {NUMBER}"
5. **Append stories**: Add extracted stories under a new heading `### Feature {NUMBER}: {feature-name}` in the "Aggregated Feature Stories" section of `docs/product/05_User_Stories/README.md`
6. **Stage and commit**: `git add docs/product/05_User_Stories/README.md` and commit with message:
   ```
   docs({NUMBER}): export user stories from GitHub Issue

   Co-Authored-By: Claude <noreply@anthropic.com>
   ```
   > **Trailer must stay generic** — same rule as Step 9: do NOT pin a model name or version into this export-commit trailer (ships to adopters via `extract.sh`).

## Step 12: Verify Delivery Document

Confirm the delivery document was generated by Skill Step 11 (invoked in Command Step 6).

1. Check if `specs/{NNN}-*/delivery.md` exists (where `{NNN}` is the feature number from the branch name)
2. **If found**: Display the path and confirm:
   ```
   Delivery document verified: specs/{NNN}-{feature}/delivery.md
   ```
3. **If missing**: Display a warning but do NOT block the workflow:
   ```
   Warning: Delivery document not found at specs/{NNN}-*/delivery.md
   The retrospective data was displayed in the terminal during Step 6.
   ```

Do NOT write any file in this step — the delivery document is generated by the skill in Step 6 (Skill Step 11).

## Step 13: Prompt for /aod.document

<!-- pr_per_cycle:single -->
#### Document hand-off (single mode)

Step 13 runs after the skill has finished, which includes the lock release (skill Step 14).

- `orchestrated = true` (any `/aod.run` invocation, interactive or autonomous): never invoke or offer `/aod.document`. Print "Document runs next under /aod.run".
- Standalone and interactive: prompt as in the split text below.
- Standalone and `autonomous == true`: auto-invoke `/aod.document --autonomous`.
<!-- /pr_per_cycle:single -->

After delivery is complete, prompt the user about the next lifecycle step:

```
Next step: Run `/aod.document` for post-delivery quality review.
This covers code simplification, docstrings, CHANGELOG, and API docs.

Run `/aod.document` now? (Y/n)
```

- **If `autonomous == true`**: Auto-select `"Yes"`. Display: `"Auto-selected: Run /aod.document (autonomous mode)"`. Invoke `/aod.document`.
- **If user selects "Y" or presses enter**: Invoke `/aod.document`
- **If user selects "n"**: Display: `"Skipped. Run /aod.document when ready for post-delivery quality review."`

## Error Handling

| Scenario | Action |
|----------|--------|
| PR not merged | Auto-merge via `gh pr merge --squash --delete-branch`; prompt only on failure |
| Tasks incomplete | List incomplete, prompt for resolution |
| Agent fails | Show results table, prompt for retry/proceed/abort |
| Git push fails | Report error, suggest manual push |

<!-- pr_per_cycle:single -->
#### Error Handling (single mode)

The "PR not merged" row above is split-only. In single mode deliver never merges.

| Scenario | Action |
|----------|--------|
| PR missing | Create it with `Closes #$((10#$NNN))` and the `<!-- aod:pr_per_cycle=single -->` marker; if `gh` is unavailable print the manual-PR instruction and continue |
| PR already merged or branch missing | Error out and stop |
| Invalid config (`aod_pr_mode` rc 4) | Halt with `invalid_config` |
| Ambiguous feature branch (rc 6) | Halt with `precondition_failed` |
| Tracked changes remain after 9b commit | List them as a warning |
<!-- /pr_per_cycle:single -->

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Feature is merged — I'll skip `/aod.deliver`" | Step 6 retrospective, Step 9 commit, and Step 10 Issue close → `stage:done` are required. Skipping leaves Issues stuck at `stage:build`. |
| "Tests are flaky — I'll run with `--autonomous` to auto-bypass them" | `--autonomous` (Step 0 line 19) auto-selects defaults. Step 6 sub-step 7 still invokes the E2E gate and halts in autonomous mode. Not a test bypass. |
| "I'll run `/aod.deliver` while the PR is still open and unmerged" | Step 1 expects branch deleted (PR merged). Lines 40-48 auto-handle uncommitted/unpushed/un-PR'd states via `gh pr merge --squash --delete-branch`. Hand-fix only on conflict. |
| "I'll select `n` at Step 13 — `/aod.document` is optional anyway" | Step 13 names `/aod.document` as the next lifecycle step. Skipping defers CHANGELOG, KB review, and OpenAPI sync. Run it now or schedule a follow-up. |

<!-- pr_per_cycle:single -->
#### Common Rationalizations (single mode)

| Rationalization | Reality |
|---|---|
| "I'll merge the PR from deliver to save a step" | Single mode merges once, in Document's closeout, after verification. Deliver only commits, pushes and marks the PR ready. |
| "I'll close the issue here, deliver is the last stage" | The issue stays at `stage:deliver` until Document's closeout finalizes it. |
| "`--orchestrated` is only a hint, I'll still offer `/aod.document`" | Under `/aod.run` the orchestrator owns the Document transition. Never start it from Step 13. |
<!-- /pr_per_cycle:single -->

## Red Flags

- Agent invokes `/aod.deliver` with the feature branch unmerged and bypasses the Step 1 lines 40-48 auto-merge flow.
- Agent runs `--autonomous` interactively (not via `aod.run` orchestrator) and accepts every Step 4 / Step 6 / Step 13 prompt without review.
- Agent uses `--require-tests` and overrides the Step 6 sub-step 7 hard halt instead of fixing the failing tests.
- Agent reports "delivery complete" before Step 10 closes the GitHub Issue — Issue stuck at `stage:deliver` rather than `stage:done`.
- Agent skips Step 13 (`/aod.document` prompt) and reports "delivery complete" with no scheduling of the post-delivery quality review.
- Agent runs `/aod.deliver` in `--autonomous` mode and overrides a `BLOCKED` retrospective gate instead of halting (per skill Step 9d gate behavior).

<!-- pr_per_cycle:single -->
#### Red Flags (single mode)

- Agent merges the PR from deliver while the pin is `single`.
- Agent commits or pushes to the default branch, or pushes without the `HEAD:refs/heads/$FEATURE` refspec.
- Agent leaves tracked changes uncommitted after 9b (skipped `git add -u`).
- Agent starts `/aod.document` while `orchestrated = true`, or before the lock is released.
- Agent treats an issue left at `stage:deliver` as a failure; in single mode that is the expected state.
<!-- /pr_per_cycle:single -->
