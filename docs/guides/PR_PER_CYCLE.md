# Single PR per AOD Cycle (`pr_per_cycle`)

**Purpose**: Guide for AOD template adopters who want one pull request per feature instead of the classic two-PR flow, covering how to opt in, what changes, how closeout merges, and what to do when it halts.

**Spec**: [`specs/204-single-pr-per-cycle/spec.md`](../../specs/204-single-pr-per-cycle/spec.md)
**Config reference**: [`.aod/config.json.example.md`](../../.aod/config.json.example.md)

**Direction**: template release → your project — opt in after `/aod.update` lands this feature.

---

## Who is this for?

You if:

- You want one PR per feature that carries plan, build, delivery docs and documentation, reviewed and merged once.
- Your constitution says a human decides merges, and you do not want `/aod.deliver` pushing closure docs straight to the default branch.
- You run `/aod.orchestrate` or `/aod.run` and want a single merge at the end of each feature.

If the current flow works for you, do nothing. `split` is the default and is not deprecated.

---

## The two modes

| | `split` (default) | `single` (opt-in) |
|---|---|---|
| PRs per feature | Plan draft PR, plus a `{NNN}-document-stage` PR | One PR, opened at `/aod.plan` |
| `/aod.deliver` | Merges the feature PR, deletes the branch, pushes closure docs to the default branch | Commits everything to the feature branch, marks the PR ready, never merges |
| `/aod.document` | Opens and merges its own PR off the default branch | Commits to the same branch, then runs closeout |
| Merge | Inside deliver | Once, at the end of `/aod.document` |
| Issue closing | Deliver | The PR body's `Closes #N`, with an explicit close as a backstop |

A missing config file or missing `pr_per_cycle` key means `split`.

---

## Opt in

Opt in through a feature branch or a PR, never directly on the default branch:

```bash
source .aod/scripts/bash/aod-config.sh && aod_config_set_string pr_per_cycle single
git add .aod/config.json && git commit -m "chore: opt in to pr_per_cycle=single"
```

`aod_config_set_string` merges into the existing file, so other keys (`deliver.*`, `project_id`) survive. If `.aod/config.json` is malformed it refuses (rc 3) and leaves the file untouched instead of overwriting it.

Once the change reaches the default branch, features started with `/aod.plan` or `/aod.run` are pinned `single`. Features already pinned keep their mode.

An invalid value (for example `"Single"` or `true`) warns and uses `split` in interactive runs. Under `--autonomous` it halts with `invalid_config`, so a typo cannot silently send you back to the flow you opted out of.

---

## The per-feature pin

The first time a feature's mode is resolved, normally at `/aod.plan`, it is written to `.aod/pr-mode/NNN` (one line, `single` or `split`) and committed on the feature branch.

- **The pin wins over later config changes.** Flipping `pr_per_cycle` mid-feature does not change a feature that is already pinned.
- **Pins accumulate, one per feature, in both modes, by design.** Split features get a `split` pin. The files are tiny, adopter-owned and left alone by `/aod.update`.
- The pin is only written when HEAD is the `NNN-*` feature branch, never on the default branch or an unrelated branch.
- It can be read without `gh`, so a re-run after the PR merges still reads the right mode.

If more than one branch matches `NNN-*` and HEAD is not one of them, the mode is ambiguous. Interactive runs warn and resolve from config. Autonomous runs halt with `precondition_failed`.

---

## Flow in single mode

1. `/aod.plan` creates the branch, writes the pin, and opens a draft PR whose body contains `Closes #N` (unpadded issue number) and the marker `<!-- aod:pr_per_cycle=single -->`. Under `/aod.run` the pin is committed right after Discover and `/aod.deliver` creates the PR.
2. `/aod.build` pushes wave commits to the branch.
3. `/aod.deliver` commits the delivery doc, knowledge-base entries, docs and `specs/NNN-*/` on the branch, and marks the PR ready. The issue stays `stage:deliver`.
4. `/aod.document` runs on the same branch. The CHANGELOG cites the PR.
5. Closeout, at the end of `/aod.document`, sets `stage:done`, regenerates BACKLOG, pushes, then applies the merge policy below. Under `/aod.run`, Document is complete only when GitHub reports the PR `MERGED`.

---

## Merge policy

| Context | Behavior |
|---|---|
| Interactive (D2) | Asks "Merge PR #N now?". Only an explicit yes merges. No leaves the PR ready ("done, awaiting merge"). |
| `--autonomous` (D3) | Merges on its own once Document passes. If the merge cannot complete and be verified, the run halts and writes `.aod/state/document-NNN.halt.json`. |

Merging is always a squash guarded by the head commit that was verified. There is no admin override, no auto-merge, and no branch-deletion flag. A rejected merge is reported, never forced.

---

## Post-refactor re-verification

Document may change code after delivery (simplification, docstrings, docs lint). Closeout therefore re-verifies before merging.

- **Any code change made after delivery must pass the stack's tests before merge.** The check is diff-based: it looks at non-merge commits after the `docs: close Feature NNN` anchor that touch code files, wherever those files live (including `.aod/` and `docs/`). It is not limited to `/simplify` or docstring commits.
- It runs the active stack pack's `test_command` and records the result in `test-results/post-refactor.json`.
- With no active stack pack there is no command to run. The result is recorded as "not re-verified" and shown in the report and aod-run artifacts.
- An active content pack (for example knowledge-system) has no code tests either, so it also reports `not_reverified`.
- `not_reverified` is a `verify=` result, not a halt: no halt record is written and closeout continues. Review the report before you merge.
- Failing tests halt an autonomous run with `tests_failed` and block the interactive merge prompt.

### What this check does not cover

- **No E2E or UI re-run.** Only the stack pack's `test_command` runs.
- **The merged result is not tested here.** Tests run on the feature branch before the update from the default branch. After that update, the merged result is verified only by your CI required checks. Make sure the checks you care about are required on the default branch.
- **With no stack pack, nothing is re-run at all.** "Not re-verified" is a record of that, not a pass.
- Documentation-only changes after delivery do not trigger it.

---

## Halt reasons and fixes

Halts print `Halted — document closeout: <reason> (PR #<n>)` and write `.aod/state/document-NNN.halt.json`. Fix the cause, then re-run as stated.

| reason | Fix |
|--------|-----|
| `checks_failed` | Fix CI on the branch and re-run `/aod.document`. Also raised when required checks never report within `document.checks_timeout_seconds`. |
| `head_mismatch` | Someone pushed, or the local branch diverged. Review the branch, then re-run `/aod.document`. |
| `conflict` | Merge the default branch into the feature branch by hand, then re-run. Regenerable files (such as BACKLOG) are resolved automatically; anything else needs you. |
| `heal_pr_open` | An open heal PR (`e2e-heal`) exists for the feature. Resolve or close it, then re-run `/aod.deliver` and `/aod.document`. |
| `precondition_failed` | A deliver halt record exists or `delivery.md` is untracked: fix that and re-run `/aod.deliver`, then `/aod.document`. The PR carries the `e2e-heal` or `requires-review` label, the feature branch is ambiguous (autonomous), the PR is closed or missing, or an earlier closeout halt record is still present: take the specific action (remove the label or the stray branch, reopen or create the PR), then re-run `/aod.document` only. Do not re-run `/aod.deliver` for these. |
| `not_merged` | The merge was rejected or `detail=queued` (a merge queue or auto-merge accepted it): let it land, then re-run `/aod.document`, which goes to post-merge. With `detail=review required`, the PR needs an approving review: get the approval, then re-run. |
| `gh_unavailable` | Install and authenticate `gh` (2.40 or newer), or follow Manual closeout below. |
| `tests_failed` | Fix or revert the simplification commit and re-run `/aod.document`. The tests re-run on every entry. |
| `invalid_config` | Fix `pr_per_cycle` in `.aod/config.json`, or the contents of `.aod/pr-mode/NNN`. |

### Labels versus heal PRs

These two look alike but halt differently:

- A **label on the PR itself** (`e2e-heal` or `requires-review`) halts with `precondition_failed`. A `requires-review` label is read as a human action: someone asked for a person to look, so closeout will not merge past it. Remove the label once reviewed.
- Only an **open heal PR** (a separate PR with `e2e-heal`, opened by deliver's auto-fix loop) halts with `heal_pr_open`.

---

## Recommended: one orchestrate session at a time

In single mode every feature edits shared files (`BACKLOG.md`, CHANGELOG, index files) on its own branch, and each merge changes them under the next one. Run `/aod.orchestrate` with `max_concurrent_sessions: 1` for single-mode projects, so waves run one feature at a time and merges do not conflict.

`/aod.orchestrate` writes `project_id` with `aod_config_set_string`, so it no longer discards `pr_per_cycle` or other keys.

---

## `document.checks_timeout_seconds`

How long closeout waits for required PR checks to report before halting with `checks_failed`.

```json
{ "document": { "checks_timeout_seconds": 1800 } }
```

Default `1800`. Integers of 60 or more are accepted. Anything else warns and uses `1800`. Raise it for slow CI.

---

## Manual closeout (no `gh`)

Without `gh`, deliver commits and pushes and tells you to open the PR yourself (its body must contain `Closes #N`, the unpadded issue number). Document commits locally but does not push, so step 0 below pushes its commits. Replace `<default>` with your repository's default branch (often `main`, not assumed).

0. Push first. Assert `git branch --show-current` is `NNN-name`, then `git push origin HEAD:refs/heads/NNN-name`.
1. Open the PR page and confirm its head commit equals `git rev-parse HEAD`. Confirm checks, then squash-merge it.
2. Close issue #N if it is still open.
3. Sync and clean up. Delete the remote branch only if its head still equals the merged PR head, and the local branch only if `git rev-parse NNN-name` equals it:
   ```bash
   git checkout <default> && git pull --ff-only origin <default>
   git ls-remote origin refs/heads/NNN-name     # must show the merged PR head
   git push origin --delete NNN-name
   git rev-parse NNN-name                       # must equal the merged PR head
   git branch -d NNN-name                       # if it refuses after a squash merge, compare the heads and delete by hand only if they match
   git remote prune origin
   ```
4. Template repository only: `scripts/extract.sh --sync` (or `/aod.sync-upstream`).

---

## Origin

This came from the adopter project Kira. It delivered its first feature with one PR (deliver and document both committed to the feature branch, one merge at the end) and found it clearer to review and safer, since nothing is pushed straight to the default branch. It also fit its constitution rule that a human decides merges. Other adopters still rely on the split flow, so it is opt-in.
