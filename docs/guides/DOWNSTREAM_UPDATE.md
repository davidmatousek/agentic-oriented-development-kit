# Downstream Update Guide

**Purpose**: Step-by-step guide for AOD template adopters to safely pull upstream PLSK template updates into their customized projects.

**Script**: `scripts/update.sh`
**Slash command**: `/aod.update`
**Make target**: `make update`

**Direction**: `PLSK → user` (opposite of `/aod.sync-upstream`, which is `user → PLSK`).

---

## What is this?

`/aod.update` applies the latest PLSK (product-led-spec-kit) template updates to your adopter project. It protects your customizations — product docs, architecture, brands, constitution, feature specs — and re-applies your placeholder values to personalized files so nothing leaks.

Running it regularly keeps your project aligned with new commands, skills, agents, governance rules, and security patches from upstream without manual merge work.

---

## When to run it

- **After a new PLSK release** — upstream tag changes trigger new `owned` + `personalized` file updates
- **Periodically** — a monthly cadence is typical; catches incremental improvements between major releases
- **Before starting a major new feature** — make sure your commands, skills, and rules reflect the latest best practices

Not required for routine daily development. PLSK releases are versioned, so you decide when to adopt.

---

## Prerequisites

- **git** >= 2.30 installed
- **bash** (macOS 3.2+ or Linux 4+)
- `.aod/aod-kit-version` exists (created by `scripts/init.sh` on fresh install)
- `.aod/personalization.env` exists (created by `scripts/init.sh`)
- `flock` is optional — a PID+nonce+timestamp fallback is used on macOS

If you installed AOD-kit before this mechanism shipped, you are a "pre-mechanism adopter" — `.aod/aod-kit-version` and `.aod/personalization.env` will be absent. A bootstrap workflow (PRD 129b) is planned to handle that case; until then, refresh your `.aod/` helper files manually from upstream.

---

## Quick start

```bash
make update
```

That's it. The script will:

1. Acquire a lock to prevent concurrent runs
2. Verify staging dir is on the same filesystem (atomicity requirement)
3. Fetch the latest upstream tag into a temp dir
4. Download and hash the upstream `.aod/template-manifest.txt`
5. Categorize every file in the upstream repo (owned / personalized / user / scaffold / merge / ignore)
6. Validate operations (guard list, symlinks, path traversal)
7. Stage files, running placeholder substitution on personalized files
8. Show a preview grouped by category
9. Prompt for confirmation (skip with `--yes`)
10. Apply atomically: each file is `mv`'d into place, `.aod/aod-kit-version` is updated last
11. Clean up staging on success; preserve it on failure for inspection

Expect the run to complete in under a minute for typical adopter projects (100-500 tracked files).

---

## Flags

| Flag | Default | Description |
|---|---|---|
| `--dry-run`, `-n` | false | Fetch + preview only. No writes outside the staging dir. Wins over `--apply`. |
| `--yes`, `-y` | false | Skip the confirmation prompt (still applies). |
| `--json` | false | Emit structured JSON (schema_version 1.0). No colors or progress. |
| `--edge` | false | Fetch upstream `main` HEAD instead of the latest tag. |
| `--force-retag` | false | Proceed even if the upstream tag SHA changed (supply-chain tripwire override; logs a warning). |
| `--upstream-url=<url>` | read from pin | Override the recorded upstream URL. Must be `https://` unless `--force-retag` is also passed. |
| `--apply` | context-dependent | Explicit apply flag. Default in interactive TTY when `CI` env is unset. `--dry-run` wins if both are passed. |
| `--help`, `-h` | — | Print help and exit. |

### Default behavior (when no explicit `--apply` / `--dry-run`)

- **Interactive TTY, `CI` env unset**: interactive confirm-then-apply (preview, prompt, user approves or declines)
- **`CI` env set**: `--dry-run` (automation safety net — pass `--apply` to override)
- **`--yes` passed**: skip the prompt but still apply (unless `--dry-run` is also passed)
- **stdin is NOT a TTY** (piped, redirected, cron): treat as `--dry-run` (fail-safe)

### Flag precedence

1. `--dry-run` ALWAYS wins: `--dry-run` + `--apply` = dry-run
2. `--yes` is orthogonal: it suppresses the confirmation prompt but does not force apply
3. `CI` env set + no explicit `--apply` / `--dry-run` → treat as `--dry-run`
4. Non-TTY stdin + no `--yes` / `--dry-run` → treat as `--dry-run` (cannot prompt)

---

## Exit codes

| Code | Meaning | What to do |
|---|---|---|
| 0 | Success (or dry-run completed) | Nothing — you're done |
| 1 | Generic failure | Read the error message; re-run with `--dry-run` to investigate |
| 2 | Lock contention | Another `/aod.update` is running, or a stale lock could not be cleared. Wait and retry, or remove `.aod/update.lock` manually if stale |
| 3 | Missing prerequisites | `.aod/aod-kit-version` or `.aod/personalization.env` absent. Follow the pre-mechanism bootstrap guide |
| 4 | Cross-filesystem staging | Staging dir is on a different filesystem than project root. Override with `AOD_UPDATE_TMP_DIR=<path-on-same-fs>` |
| 5 | Manifest coverage violation | Upstream has an uncategorized file. File a bug report against PLSK upstream |
| 6 | Guard-list violation | Upstream manifest tried to write a user-owned path (e.g., `docs/product/**`). Supply-chain red flag — inspect upstream before retrying |
| 7 | Retag detected | Upstream tag SHA differs from recorded SHA (possible adversarial retag). Inspect, then retry with `--force-retag` if benign |
| 8 | Residual placeholder | Personalized file has `{{VAR}}` left after substitution. Add the missing placeholder to `.aod/personalization.env` and retry |
| 9 | Network failure | Check your network and upstream URL. Run with `--upstream-url=<url>` to override |
| 10 | User declined preview | Not an error — you said no at the prompt. Nothing written |

---

## Safety guarantees

- **Zero user-owned file writes**: files under `docs/product/**`, `docs/architecture/**`, `brands/**`, `.aod/memory/**`, `specs/**`, and `roadmap.md` / `okrs.md` / `CHANGELOG.md` are protected by a hardcoded guard list embedded directly in `scripts/update.sh`. Even a malicious or buggy upstream manifest cannot override this — the script halts with exit 6 if it tries.
- **Atomic version pin**: `.aod/aod-kit-version` is written last, via temp + `mv` on the same filesystem. Any mid-run failure leaves the pin either pre-update or post-update — never partial.
- **Lock contention safety**: primary concurrency path uses PID + nonce + timestamp (works without `flock`, which is absent on macOS). Nonce re-verify before lock removal prevents zombie-PID-reuse from deleting another runner's lock. Liveness probe (`kill -0`) + >1h staleness window handles crash recovery.
- **No symlinks**: neither the fetched upstream tree nor the staged tree may contain symlinks. Rejected at validate phase.
- **No path traversal**: `..`, `~`, and absolute paths are rejected in manifest entries at parse time.
- **Retag detection**: upstream tag SHA is recorded in `.aod/aod-kit-version`. If the resolved SHA changes, the run halts (supply-chain defense against adversarial retagging) unless `--force-retag` is passed.
- **Staging preserved on failure**: `.aod/update-tmp/<uuid>/` is kept for inspection when any phase after fetch fails. Clean it manually after you've investigated.
- **Fail-safe automation**: non-TTY stdin or `CI` env set defaults to `--dry-run`. You cannot accidentally write from a cron job or piped script.

---

## FAQ

### Can I roll back an update?

Yes — `.aod/aod-kit-version` records the previous tag + SHA before each update. To roll back:

1. Use `git` to revert the files that were changed (your repo is a git repo, right?)
2. Restore the previous `.aod/aod-kit-version` from git history

Because every update advances the pin atomically, a roll-back is just a git revert of the commits the update produced.

### What if my local changes conflict with upstream?

`/aod.update` NEVER touches files in the user-owned guard list (product docs, architecture, brands, constitution, specs, roadmap/OKRs/CHANGELOG). So your personal customizations are safe by construction.

For `owned` files (commands, skills, agents, scripts), upstream wins — if you've locally customized a file marked `owned`, your changes are overwritten. If you want to keep customizations, fork the file to a different path or discuss with PLSK maintainers about marking it `personalized` or `merge`.

For `personalized` files, the upstream template ships with `{{PLACEHOLDER}}` tokens and your `.aod/personalization.env` values are re-applied on each update — so your project-specific content survives intact.

### Where does it download upstream from?

The recorded URL in `.aod/aod-kit-version` is the canonical source. By default, `scripts/init.sh` points it at the public PLSK repo on GitHub. Override per-run with `--upstream-url=<url>` (must be `https://`; add `--force-retag` to change the recorded URL).

### How does it know which files are mine vs PLSK's?

Upstream ships a `.aod/template-manifest.txt` that categorizes every file in the PLSK repo (`owned`, `personalized`, `user`, `scaffold`, `merge`, `ignore`). `/aod.update` fetches this manifest fresh on every run, hashes it, and compares to the hash recorded in `.aod/aod-kit-version`. Any `user → owned|personalized|scaffold|merge` transitions (which would expand what upstream owns) are flagged as security warnings in the preview.

On top of the manifest, the hardcoded guard list in `scripts/update.sh` unconditionally protects your most sensitive paths — the manifest cannot override it.

### Can I run it in CI?

Yes. `CI` env set defaults to `--dry-run`, which is the automation-safe mode. If you want to auto-apply in CI (e.g., a scheduled bot), pass `--apply --yes`. Use `--json` for machine-readable output.

### What's the `merge` category?

Files marked `merge` (e.g., `Makefile`, `.gitignore`) require human judgment when they change — P0 behavior is "warn and skip" (the preview lists the change, the apply phase leaves your local copy alone). A future release will add interactive merge assistance; for now, after each update run, inspect merge-category files with `git diff upstream/main` (via `/aod.sync-upstream`) and apply changes manually.

### How long does a typical run take?

Under 1 minute for 100-500 tracked files (SC-001 target: <5 minutes). Preview renders in under 30 seconds. The staging + apply phase is dominated by filesystem `mv` calls, which are fast on local disks.

---

## Troubleshooting

| Problem | Solution |
|---|---|
| "Missing .aod/aod-kit-version" | You're a pre-mechanism adopter. See the bootstrap guide (PRD 129b) or refresh `.aod/` manually from upstream |
| "Cross-filesystem staging" (exit 4) | Set `AOD_UPDATE_TMP_DIR=<path-on-same-fs-as-project-root>` and retry |
| "Lock contention" (exit 2) | Another run is active, or a stale lock exists. Check `cat .aod/update.lock` for holder PID; remove the lock if stale |
| "Guard-list violation" (exit 6) | Upstream is trying to write a user-owned path. Inspect the manifest, report to PLSK upstream, retry once resolved |
| "Retag detected" (exit 7) | Upstream tag SHA changed. Investigate first (`git log` on upstream); retry with `--force-retag` if benign |
| "Residual placeholder" (exit 8) | Upstream introduced a new placeholder. Add it to `.aod/personalization.env` and retry |
| "Network failure" (exit 9) | Check network; verify upstream URL is reachable; retry |
| Preview shows unexpected changes | Run `make update --dry-run --json | jq` for full detail; inspect staging dir under `.aod/update-tmp/<uuid>/` |

---

## Full walkthrough example

```bash
# Fresh adopter, ran init.sh a week ago; new PLSK tag released yesterday.
cd my-project
cat .aod/aod-kit-version           # pins v2.0.0

make update --dry-run              # preview v2.0.0 -> v2.1.0
# See 8 changes: 6 owned (new commands), 2 personalized (rule updates).

make update                        # interactive: preview, confirm, apply
# [apply] .claude/commands/aod.foo.md         (copy)
# [apply] .claude/rules/scope.md              (substitute)
# [skip ] CLAUDE.md                           (merge category, P0 defer)
# [apply] .aod/aod-kit-version                (atomic write)
# [done ] Update complete in 23 seconds.

cat .aod/aod-kit-version           # now pins v2.1.0
git diff .claude/commands/         # inspect what changed
git commit -am "chore: update PLSK template to v2.1.0"
```

---

## Terminology

- `/aod.sync-upstream` — direction: `user → PLSK` (for PLSK maintainers contributing back to the template)
- `/aod.update` — direction: `PLSK → user` (for adopters pulling updates from the template)

These are two separate commands serving opposite directions. Do NOT confuse them.

---

## Recommended update cadence

- **Monthly**: Check for upstream changes on the first week of each month (`make update --dry-run`)
- **On-demand**: When upstream releases important bug fixes or new features
- **Before new features**: Update before starting major new feature work

---

## Reference

- **Script source**: `scripts/update.sh`
- **Slash command**: `.claude/commands/aod.update.md`
- **Make target**: `Makefile` (search for `update:`)
- **CLI contract**: [`specs/129-downstream-template-update/contracts/cli-contract.md`](../../specs/129-downstream-template-update/contracts/cli-contract.md)
- **Manifest schema**: [`specs/129-downstream-template-update/contracts/manifest-schema.md`](../../specs/129-downstream-template-update/contracts/manifest-schema.md)
- **Version pin schema**: [`specs/129-downstream-template-update/contracts/version-schema.md`](../../specs/129-downstream-template-update/contracts/version-schema.md)
- **JSON output schema**: [`specs/129-downstream-template-update/contracts/json-output-schema.md`](../../specs/129-downstream-template-update/contracts/json-output-schema.md)
- **Opposite direction**: [`UPSTREAM_SYNC.md`](UPSTREAM_SYNC.md) — the `user → PLSK` guide
