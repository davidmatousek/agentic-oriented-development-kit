---
description: Quality review — code simplification, docstrings, CHANGELOG, API docs (supports --autonomous)
---

## User Input

```text
$ARGUMENTS
```

Consider user input before proceeding (if not empty).

## Step 0a: Parse --autonomous

1. If `$ARGUMENTS` contains `--autonomous`:
   - Set `autonomous = true`
   - Strip `--autonomous` from `$ARGUMENTS` (trim extra whitespace)
2. If `$ARGUMENTS` does NOT contain `--autonomous`:
   - Set `autonomous = false`

## Overview

Post-delivery quality review for the completed feature. This is Stage 6 of the AOD
lifecycle — the one stage designed for human judgment. Each step presents findings
interactively and commits only what the human approves.

**Flow (split mode)**: Validate context → Branch → Code simplification → Docs-lint → CHANGELOG → API sync → KB review → PR squash-merge → Report

<!-- pr_per_cycle:single -->
**Flow (single mode)**: Validate context → Resolve and enter the feature branch → Code simplification → Docs-lint → CHANGELOG → API sync → KB review → Post-refactor verification (Step 5b) → Closeout: prepare, merge once through `pr-closeout.sh`, upstream sync → Report
<!-- /pr_per_cycle:single -->

**IMPORTANT**: Execute ALL steps 0–7 sequentially. Do not stop or wait for further instructions between steps. After completing each step (including user interaction), immediately proceed to the next step until the Step 7 Report is displayed.

<!-- pr_per_cycle:single -->
**IMPORTANT (single mode)**: Execute ALL steps 0–7 sequentially, including Step 5b (between Step 5 and Step 6), under the same no-stop rule. In single mode Step 0b is not executed.
<!-- /pr_per_cycle:single -->

## Step 0: Validate Context

The text of Step 0 and Step 0b below is the split-mode flow. Resolve the mode first (see "Step 0 (single mode)" below); in single mode follow the single-mode blocks instead of Step 0b.

1. Get branch: `git branch --show-current`
2. Determine feature number NNN:
   - If on a `NNN-*` branch: extract NNN from branch name
   - If on `main`: extract NNN from user input `$ARGUMENTS`, or detect from most recent `feat(NNN)` or `docs(NNN)` commit on main
   - If NNN cannot be determined: prompt the user for the feature number
3. Find tasks: `specs/{NNN}-*/tasks.md` → verify all tasks marked `[X]` (build complete)
4. If tasks incomplete: warn "Build may not be complete — {incomplete_count} tasks remain" and ask whether to proceed
5. Display: "Document stage for Feature {NNN}"

<!-- pr_per_cycle:single -->
### Step 0 (single mode): Resolve and enter the feature branch

The whole cycle runs on the feature branch and merges one PR. Use this order; it overrides the numbered Step 0 list above after item 2 (items 3-5 run at the end, on the feature branch, because `specs/` lives there).

`NNN` is the three-digit prefix; the issue number is `$((10#$NNN))`.

**Determine `NNN` (the mode is unknown until it is known).** Use item 1-2 of the numbered list, with this change for the default branch:

- On a `NNN-*` branch: take `NNN` from the branch name.
- `$ARGUMENTS` names a feature: use it.
- On the default branch with no feature argument: do NOT use the "most recent `feat(NNN)` or `docs(NNN)` commit on main" heuristic here. In single mode nothing from the in-flight feature is on the default branch, so the heuristic would pick the previous feature and run closeout for the wrong one. Without an `NNN` there is no pin or branch to resolve, so read the config mode with `source .aod/scripts/bash/aod-config.sh && aod_pr_mode_from_config`:
  - `split` → follow the unmarked Step 0 and Step 0b, heuristic included; ignore every single-mode block in this file.
  - `single`, or rc 4 → interactive: ask the user for the feature number. Autonomous: write a `precondition_failed` record (detail "feature number required on the default branch in single mode"; feature `unknown`, so the file is `.aod/state/document-unknown.halt.json`) and stop.

**Resolve the mode.** Once `NNN` is known, mode resolution is gh-free and does not write the pin yet:

```bash
source .aod/scripts/bash/aod-config.sh
rc=0; PR_MODE=$(aod_pr_mode "$NNN" --no-pin) || rc=$?   # add --autonomous when autonomous == true
```

- `PR_MODE=split` → follow the unmarked Step 0 and Step 0b and ignore every single-mode block in this file.
- Autonomous rc 4 → write an `invalid_config` record and stop. Autonomous rc 6 (ambiguous feature branch) → write a `precondition_failed` record and stop.

**Single mode, in this order:**

1. **gh preflight (autonomous only, before anything else):** require `gh` >= 2.40 (`gh --version`) and a working login (`gh auth status --hostname <origin host, default github.com>`). On failure write a `gh_unavailable` record and stop, before any Step 1-5 commit.
2. **Resolve the PR:** `bash .aod/scripts/bash/pr-closeout.sh resolve --feature "$NNN"` (add `--autonomous` when autonomous). It prints `branch=<b> pr=<N> state=<state> default=<d>`.
   - rc 5 (interactive ambiguity): ask the user which candidate to use, then re-run with the chosen full branch name as `--feature`.
   - rc 10: a halt record was written; report `halted (<reason>)` at Step 7 and stop.
3. **Map `state`:**
   - `MERGED` → run `pr-closeout.sh post-merge --feature <branch> --pr <N>`, then the upstream sync of Step 6 (single mode), then the Step 7 report (`Outcome: merged #<N> (merge <sha7>)`, sha from `gh pr view <N> --json mergeCommit`). Skip Steps 1-6.
   - `NONE` or `CLOSED` → the existing stop: display "No open feature PR found for Feature {NNN}", and in autonomous mode write a `precondition_failed` record.
   - `OPEN` → continue.
   - `UNKNOWN` (gh unavailable; only git refs were checked) → interactive: continue on the unique local branch (if `branch=` is empty there is none: stop and tell the user to fix `gh` or name the branch) and print the manual-closeout steps at Step 6 (Steps 1-5b commit locally only, so manual step 0 pushes them); autonomous: write a `gh_unavailable` record and stop.
4. **Clean tree before checkout:** `git status --porcelain --untracked-files=no` must be empty. Otherwise stop (interactive: tell the user to commit or stash; autonomous: `precondition_failed` record).
5. **Enter the branch:** `git checkout <branch>` then `git pull --ff-only origin <branch>`, then set `FEATURE=<branch from resolve>`. Steps 5b and 6 reuse this `FEATURE` (re-derive it with `git branch --show-current` if the shell did not persist). A pull failure stops with a `head_mismatch` record (autonomous) or a message (interactive).
6. **Write the pin:** `aod_pr_mode "$NNN" [--autonomous]` (no `--no-pin`) now that HEAD is the feature branch. The closeout finalize commit includes a newly written pin.
7. **Set the stage label** with the issue number, never the PR number, in a subshell:

   ```bash
   source .aod/scripts/bash/github-lifecycle.sh
   rc=0; ( aod_gh_update_stage "$((10#$NNN))" document ) || rc=$?
   ```

   A non-zero `rc` is a warning only.
8. Run Step 0 items 3-5 (find `tasks.md`, completeness check, display) on the feature branch. Incomplete tasks: interactive asks whether to proceed; autonomous stops with a `precondition_failed` record.

**Autonomous early stops write a record.** Every autonomous stop in this step (branch or PR not found, ambiguous PR, dirty tree, pull failure, tasks incomplete) writes a Document halt record before stopping:

```bash
source .aod/scripts/bash/halt-signal.sh
write_document_halt_record "<feature or NNN>" <reason> "<pr or empty>" "<head sha or empty>" "<one-line detail>"
```

`<reason>` is `precondition_failed` unless a specific reason above applies (`invalid_config`, `gh_unavailable`, `head_mismatch`).

**Re-entry.** If HEAD already carries `docs({NNN}): update CHANGELOG` or `docs({NNN}): review KB entries` commits after the newest `docs: close Feature {NNN}` commit, offer to skip Steps 1-5 (autonomous skips automatically). Re-entry always runs Step 5b and Step 6; they decide from branch history, not from this run.
<!-- /pr_per_cycle:single -->

## Step 0b: Create Document Branch (split mode only)

1. If not already on main: `git checkout main && git pull origin main`
2. Create branch: `git checkout -b {NNN}-document-stage`
3. Display: "Working on branch {NNN}-document-stage"

## Step 1: Code Simplification

Detect changed code files and run /simplify for human review.

### 1a: Detect Changed Files

1. Run: `git diff --name-only main...HEAD`
<!-- pr_per_cycle:single -->
   **Single mode:** run `git fetch origin` and use `git diff --name-only origin/<default>...HEAD` instead (`<default>` from `aod_default_branch`).
<!-- /pr_per_cycle:single -->
2. Filter to code extensions: `.py`, `.js`, `.ts`, `.jsx`, `.tsx`, `.sh`, `.go`, `.rs`, `.java`, `.rb`, `.swift`, `.kt`
3. Exclude: `*.lock`, `*.min.js`, `*.min.css`, `*.map`, `*.generated.*`, `vendor/`, `dist/`, `build/`, `node_modules/`, `.aod/`, `docs/`
4. Store as `changed_files` list and `file_count`
5. If `file_count` is 0: display "No code files changed — skipping simplification", proceed to Step 2
6. If `file_count` > 50: warn "Large diff ({file_count} files). Simplify may take several minutes." and ask whether to continue or skip

### 1b: Run Simplification

1. Record pre-invocation file states: `git diff --name-only`
2. Invoke `/simplify` skill via Skill tool
3. If skill fails: display error, ask (A) Retry, (B) Skip → proceed to Step 2, (C) Abort

### 1c: Review Results

1. Detect modified files: `git diff --name-only`
2. If no files modified: display "No simplification changes — code looks good", proceed to Step 2
3. Get diff stats: `git diff --stat`
4. If `autonomous == true`: auto-accept all simplification changes — stage and commit with `refactor({NNN}): simplify code per /simplify review` → proceed to Step 2
5. If `autonomous == false`: Present summary via AskUserQuestion:
   ```
   Code Simplification Review:
     Files reviewed: {file_count}
     Files modified: {modified_count}
     Changes: +{insertions} -{deletions} lines

     {one-line summary per modified file}

   Options:
     (A) Accept all — commit as refactor({NNN}): simplify
     (B) Reject all — revert and continue
     (C) Abort
   ```
   - Accept: stage and commit with `refactor({NNN}): simplify code per /simplify review` → proceed to Step 2
   - Reject: revert modified files with `git checkout -- {files}` → proceed to Step 2

## Step 2: Docs-Lint

Analyze changed code for undocumented complex functions and suggest docstrings.

### 2a: Analyze Complexity

1. Use the `changed_files` list from Step 1a (re-detect if Step 1 was skipped)
<!-- pr_per_cycle:single -->
   **Single mode:** re-detect with the `origin/<default>...HEAD` base from Step 1a.
<!-- /pr_per_cycle:single -->
2. Filter to supported languages: `.py`, `.ts`, `.tsx`, `.js`, `.jsx`, `.go`, `.rs`, `.java`
3. For each file, identify functions/methods and count branch statements (if, else, for, while, match, switch, case)
4. Flag functions where: complexity >= 3 AND no existing docstring
5. If no functions flagged: display "All complex functions are documented", proceed to Step 3

### 2b: Present Docstring Suggestions

1. For each flagged function, generate a docstring matching the file's existing style
2. If `autonomous == true`: auto-accept all suggested docstrings — apply docstrings, stage, commit with `docs({NNN}): add docstrings per docs-lint` → proceed to Step 3
3. If `autonomous == false`: Present via AskUserQuestion:
   ```
   Docs-Lint Review:
     Files analyzed: {file_count}
     Functions flagged: {flagged_count}

     {list each: file:line — function_name (complexity: N)}

   Options:
     (A) Accept all suggested docstrings
     (B) Skip all
     (C) Review individually
   ```
   - If accepted: apply docstrings, stage, commit with `docs({NNN}): add docstrings per docs-lint` → proceed to Step 3
   - If skipped or reviewed individually: apply approved changes (if any), then proceed to Step 3

<!-- pr_per_cycle:single -->
#### Commit subjects (single mode)

Every Step 1 and Step 2 commit, including commits from "review individually", uses exactly one of these subjects:

- `refactor({NNN}): simplify code per /simplify review`
- `docs({NNN}): add docstrings per docs-lint`

The verification gate in Step 5b is diff-based (any code-touching commit after the `docs: close Feature {NNN}` anchor needs re-verification), so the subject never decides whether a commit is checked; the exact subjects keep the history readable and testable.
<!-- /pr_per_cycle:single -->

## Step 3: CHANGELOG Generation

Generate CHANGELOG entries from the feature's delivery commits on main (not the document branch).

### 3a: Collect and Categorize Commits

1. Run: `git log --format="%H %s" main` and filter to commits matching `(NNN)` or the feature name from `specs/{NNN}-*/`
2. If no commits: display "No commits found", proceed to Step 4
3. If `CHANGELOG.md` exists: read it and exclude commits whose SHA (first 7 chars) already appear
4. If all commits already captured: display "CHANGELOG is up to date", proceed to Step 4
5. Parse conventional commit prefixes:
   - `feat:` → **Added**
   - `fix:` → **Fixed**
   - `refactor:`, `docs:`, `chore:`, `style:`, `perf:`, `test:` → **Changed**
   - Contains "remove"/"delete"/"drop" → **Removed**
   - Others → **Other**

<!-- pr_per_cycle:single -->
### Step 3 (single mode): CHANGELOG from the PR

Replaces 3a items 1 and 3, and the heading in 3b item 1:

1. Collect commits with `git log --format=%s origin/<default>..HEAD` (the single PR's commits, not `main`). Exclude the `chore({NNN}): open feature branch` and `chore({NNN}): pin pr_per_cycle=*` commits. Categorize as in 3a item 5.
2. The section heading is `### Feature {NNN} (#PR)`, where `PR` is the number from Step 0. Entries carry no SHAs.
3. Dedupe: skip this step with "CHANGELOG is up to date" when a line matching `^### Feature {NNN}( |$)` already exists under `[Unreleased]`. The pattern is word-bounded, so `### Feature 20` never matches Feature 204.
4. Acceptance, commit message and autonomous behavior are unchanged (3b items 3-5).
<!-- /pr_per_cycle:single -->

### 3b: Generate and Review

1. Build markdown section: `### Feature {NNN}`
2. List entries by category with short SHA
3. Create `CHANGELOG.md` if missing (Keep a Changelog format)
4. If `autonomous == true`: auto-accept CHANGELOG entries — insert under `## [Unreleased]`, stage, commit with `docs({NNN}): update CHANGELOG` → proceed to Step 4
5. If `autonomous == false`: Present via AskUserQuestion:
   ```
   CHANGELOG Preview:
     New entries: {count}
     Categories: {list}

   (A) Accept and commit
   (B) Skip
   ```
   - If accepted: insert under `## [Unreleased]`, stage, commit with `docs({NNN}): update CHANGELOG` → proceed to Step 4
   - If skipped: proceed to Step 4

## Step 4: API Documentation Sync

Compare code endpoints against OpenAPI spec and flag mismatches.

### 4a: Discover Spec and Changed Endpoints

1. Search for OpenAPI spec: `openapi.yaml`, `openapi.json`, `swagger.yaml`, `swagger.json` in root, `docs/`, `api/`, `spec/`
2. If no spec found: display "No OpenAPI spec found — skipping", proceed to Step 5
3. Get changed files: `git diff --name-only main...HEAD`
<!-- pr_per_cycle:single -->
   **Single mode:** use `git diff --name-only origin/<default>...HEAD`.
<!-- /pr_per_cycle:single -->
4. Filter to API-relevant extensions: `.py`, `.js`, `.ts`, `.jsx`, `.tsx`, `.go`, `.java`, `.rb`
5. Scan for framework endpoint patterns (FastAPI, Express, Flask decorators)
6. If no endpoints in changed files: display "No API endpoints changed", proceed to Step 5

### 4b: Compare and Report

1. Extract endpoint signatures from code (method, path, params, response type)
2. Parse OpenAPI spec for corresponding definitions
3. Identify mismatches: new endpoints, changed params, removed endpoints, response type diffs — classify each as **additive** (new endpoint) or **breaking** (removed endpoint, changed param, response-type diff)
4. If no mismatches: display "API docs are in sync", proceed to Step 5
5. If `autonomous == true`:
   - If the diff contains **only additive** mismatches (no removed endpoints, no changed params, no response-type diffs): auto-sync — update spec for each new endpoint, stage, commit with `docs({NNN}): sync OpenAPI spec (additive)` → proceed to Step 5
   - If the diff contains **any breaking** mismatch (removed endpoint, changed param, or response-type diff): do NOT auto-rewrite — display the following and proceed to Step 5 without modifying the spec:
     ```
     API Sync — Human Review Required (autonomous mode):
       Breaking changes detected in the diff — auto-sync is blocked.
       Spec: {spec_path}
       Breaking mismatches: {list each breaking mismatch with category}
       Additive mismatches: {list each additive mismatch, if any}

     Action required: re-run /aod.document (without --autonomous) to review and approve these changes interactively.
     ```
6. If `autonomous == false`: Present via AskUserQuestion:
   ```
   API Sync Review:
     Spec: {spec_path}
     Mismatches: {count}

     {list each mismatch}

   (A) Review each individually
   (B) Skip all
   ```
   - For each mismatch user approves: update spec, then stage and commit with `docs({NNN}): sync OpenAPI spec` → proceed to Step 5
   - If skipped: proceed to Step 5

## Step 5: KB Entry Review

Review knowledge base entries captured during build and deliver.

1. Check `docs/INSTITUTIONAL_KNOWLEDGE.md` for recent entries related to Feature {NNN}
2. If no entries found: display "No KB entries to review", proceed to Step 6
3. If `autonomous == true`: auto-accept KB entries as-is — commit any KB updates with `docs({NNN}): review KB entries` → proceed to Step 6
4. If `autonomous == false`: Present each entry for validation: confirm accuracy, improve wording if needed
5. Commit any KB updates with `docs({NNN}): review KB entries`

<!-- pr_per_cycle:single -->
## Step 5b (single mode): Post-Refactor Verification

Runs on every entry, including re-entry. The script decides from branch history, not from this run:

```bash
bash .aod/scripts/bash/pr-closeout.sh verify --feature "$FEATURE" [--autonomous]
```

`FEATURE` is the feature branch set in Step 0 (single mode) item 5 (equal to `git branch --show-current`). Read the result:

- rc 0, `verify=skipped`: no code-touching commit after the `docs: close Feature {NNN}` anchor. Re-verification line: `not needed (no refactor commits)`.
- rc 0, `verify=pass`: the stack's test command passed. Re-verification line: `pass (<command>)`.
- rc 0, `verify=not_reverified`: no test command could be resolved (no active stack pack, or an active content pack). Allowed; say so plainly in the report: `not re-verified (<reason from post-refactor.json>)`.
- rc 10 (`tests_failed`, a halt record exists): report `halted (tests_failed)`. Interactive: show the failure and do not offer the merge. Fix or revert the simplification commit and re-run `/aod.document`.

Do not skip this step: `prepare` in Step 6 refuses to continue (`tests_failed`) unless every code-touching commit is covered by a passing or `not_reverified` record.
<!-- /pr_per_cycle:single -->

## Step 6: PR Squash-Merge (split mode)

Push the document branch, create a PR, and squash-merge to main.

1. If no commits on the document branch (`git log main..HEAD --oneline` is empty): display "No changes to merge — skipping PR", proceed to Step 7
2. Push: `git push -u origin {NNN}-document-stage`
3. Create PR:
   ```
   gh pr create --title "docs({NNN}): post-delivery quality review" --body "$(cat <<'EOF'
   ## Summary
   Post-delivery documentation review for Feature {NNN}.

   {one-line summary per commit on the branch}

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   EOF
   )"
   ```
4. If `autonomous == true`: proceed directly to squash-merge without confirmation
5. If `autonomous == false`: display PR URL and ask for confirmation before merging:
   ```
   PR created: {pr_url}

   (A) Squash-merge and delete branch
   (B) Leave PR open for manual review
   ```
   - If (B): display "PR left open — skipping merge", proceed to Step 7
6. Squash-merge: `gh pr merge --squash --delete-branch`
7. Switch to main: `git checkout main && git pull origin main`
8. Prune stale remote refs: `git remote prune origin`

<!-- pr_per_cycle:single -->
## Step 6 (single mode): Closeout and Merge

The one PR was opened at plan time. Every merge goes through `pr-closeout.sh`; never merge the PR by any other means. If Step 0 reported `UNKNOWN` (gh unavailable), skip to "Manual steps" below.

1. **Prepare:**

   ```bash
   bash .aod/scripts/bash/pr-closeout.sh prepare --feature "$FEATURE" [--autonomous]
   ```

   rc 0 prints `pr=<N> sha=<40-hex> checks=<pass|none> default=<d> verify=<…>`; capture `N`, `sha` and `default`. rc 10 → report `halted (<reason>)` (reasons include `checks_failed`, `conflict`, `tests_failed`, `head_mismatch`, `heal_pr_open`, `precondition_failed`, `gh_unavailable`, `not_merged` with detail `review required`) and do not offer a merge. A `requires-review` label on the PR means a human must review it; that is a `precondition_failed` halt. Interactive `gh_unavailable` also prints the manual steps below; the record commit and any Steps 1-5b commits are still unpushed, so manual step 0 applies.
2. **Interactive:** ask in plain chat: "Merge PR #N now? (head `<sha7>`, checks: `<pass|none>`, re-verification: `<…>`)".
   - Yes → `bash .aod/scripts/bash/pr-closeout.sh merge --feature "$FEATURE" --pr <N> --sha <sha>`. rc 0 → merged. rc 10 → the merge did not complete: `detail=queued` is the `queued` outcome; any other reason is `done — awaiting merge (merge not completed: <reason>)`. Either way the PR stays ready, no sync runs, and the report points to `/aod.sync-upstream`.
   - No → outcome `done — awaiting merge`; skip the sync with a pointer to `/aod.sync-upstream`.
3. **Autonomous:** run `merge --feature "$FEATURE" --pr <N> --sha <sha> --autonomous` immediately. rc 10 → `halted (<reason>)`.
4. **After a verified merge (`merged=<N> merge_commit=<sha> post_merge=…` on stdout):** `merge` already closed the issue, returned to the default branch and deleted the branch. Then run the upstream sync (same logic as `/aod.deliver` Step 8): apply only when `scripts/extract.sh` exists and `../agentic-oriented-development-kit/` exists, otherwise produce no output. Interactive: ask "Run upstream sync?" (A) Yes, run `scripts/extract.sh --sync`, (B) Skip. Autonomous: auto-select Yes. On decline or failure, point to `/aod.sync-upstream`. A `post_merge=partial` result is a warning; show its `detail`.

### Manual steps (single mode, gh unavailable)

Print these only when Step 5b did not halt; after `tests_failed`, report `halted (tests_failed)` and stop. Replace `<default>` with the repository default branch:

0. Push first. Steps 1-5b committed locally and nothing has pushed them. Assert `git branch --show-current` is `NNN-name`, then `git push origin HEAD:refs/heads/NNN-name`.
1. Open the PR page and confirm its head commit equals `git rev-parse HEAD` (otherwise stop and investigate). Confirm checks, then squash-merge it.
2. Close the issue if still open.
3. Sync and clean up. `git checkout <default> && git pull --ff-only origin <default>`. Delete the remote branch only if `git ls-remote origin refs/heads/NNN-name` still shows the merged PR head: `git push origin --delete NNN-name`. Delete the local branch only if `git rev-parse NNN-name` equals the merged PR head: `git branch -d NNN-name`. If `-d` refuses (normal after a squash merge), compare the heads yourself and delete by hand only when they match; never force-delete unchecked. Then `git remote prune origin`.
4. Template repo only: `scripts/extract.sh --sync` (or `/aod.sync-upstream`).

Outcome for this path: `done — awaiting merge`; Re-verification as reported by Step 5b.
<!-- /pr_per_cycle:single -->

## Step 7: Report

Display summary of all documentation activities:

```
DOCUMENT STAGE COMPLETE

Feature: {NNN}
PR: #{pr_number} (squash-merged)

Results:
  Code Simplification: {accepted/rejected/skipped/no changes}
  Docs-Lint: {N functions documented / skipped / no flags}
  CHANGELOG: {N entries added / skipped / up to date}
  API Sync: {N mismatches resolved / skipped / in sync / no spec}
  KB Review: {N entries reviewed / no entries}
```

<!-- pr_per_cycle:single -->
### Report (single mode)

Use the same Results block, with `PR: #{pr_number}` as the PR line (the one PR from Step 0) and these two extra lines:

```
Outcome: {see below}
Re-verification: {see below}
```

`Outcome:` is exactly one of:

- `merged #PR (merge <sha7>)`
- `done — awaiting merge` (interactive "no", or manual steps printed)
- `done — awaiting merge (merge not completed: <reason>)` (approved but the merge failed; PR stays ready, no sync, pointer to `/aod.sync-upstream`)
- `queued — the merge queue will merge PR #N; re-run /aod.document afterwards to finish post-merge steps`
- `halted (<reason>)` (autonomous, or an interactive failure before the merge question: `checks_failed`, `conflict`, `tests_failed`, ...)

`Re-verification:` is exactly one of:

- `pass (<command>)`
- `not re-verified (no test command available)`
- `not needed (no refactor commits)`
- `unknown` (the Step 0 `MERGED` path, where Step 5b did not run in this session)
<!-- /pr_per_cycle:single -->

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Feature is delivered — I'll skip `/aod.document` and let the user run it later" | Without it, the Step 3 CHANGELOG, Step 4 OpenAPI sync, and Step 5 KB review drift from merged code. Run immediately after `/aod.deliver`. |
| "I'll pause between Step 1 (simplify) and Step 2 (docs-lint) to let the user verify" | Important note requires steps 0-7 to execute sequentially without stops. The AskUserQuestion at each step IS the gate; pausing stalls the flow. |
| "I'll run `/aod.document --autonomous` to skip the AskUserQuestion prompts" | `--autonomous` (Step 0a) auto-accepts decisions at Steps 1c, 2b, 3b, 4b, 5, and 6. Reserved for `aod.run` orchestrator runs; pause at each gate interactively. |
| (split mode) "I'll run `/aod.document` directly on the feature branch instead of `{NNN}-document-stage`" | Step 0b creates `{NNN}-document-stage` from main. Feature-branch use mixes build and post-delivery commits and breaks the Step 6 squash-merge. |

<!-- pr_per_cycle:single -->
| Rationalization (single mode) | Reality |
|---|---|
| "Single mode: I'll create a `{NNN}-document-stage` branch anyway" | Single mode works on the feature branch and the one PR. Step 0 (single mode) checks it out; a second branch means a second PR. |
| "Step 5b can be skipped; I only changed docstrings" | Step 6 `prepare` independently refuses to continue unless every code-touching commit is verified. Run Step 5b on every entry. |
<!-- /pr_per_cycle:single -->

## Red Flags

- (split mode) Agent invokes `/aod.document` on a feature branch whose build commits are not yet merged to main.
- Agent stops mid-flow between Steps 0-7 waiting for instructions despite the IMPORTANT "Do not stop" rule.
- Agent runs `--autonomous` outside an `aod.run` orchestrator context and rubber-stamps every Step 1-5 change.
- (split mode) Agent skips Step 0b branch creation and commits directly on the feature branch.
- Agent reports "DOCUMENT STAGE COMPLETE" without producing the Step 7 per-stage Results breakdown.

<!-- pr_per_cycle:single -->
- (single mode) Agent merges outside `pr-closeout.sh`, or runs a merge command by hand.
- (single mode) Agent creates a `{NNN}-document-stage` branch or a second PR.
- (single mode) Agent checks out the feature branch before the `--untracked-files=no` clean-tree check.
- (single mode) Agent skips Step 5b on re-entry, or offers the merge after a `tests_failed` halt.
- (single mode) Agent sets the stage label with the PR number instead of the issue number.
<!-- /pr_per_cycle:single -->
