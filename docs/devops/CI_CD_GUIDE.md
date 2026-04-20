# CI/CD Setup Guide - {{PROJECT_NAME}}

**Last Updated**: {{CURRENT_DATE}}
**Owner**: DevOps Agent

---

## Overview

This guide provides instructions for setting up CI/CD pipelines for {{PROJECT_NAME}}. Choose your platform based on your hosting provider.

---

## When to Add CI/CD

Add CI/CD after you have:
1. ✅ Working local development environment
2. ✅ At least one deployable feature
3. ✅ Basic test coverage (unit tests)
4. ✅ Defined deployment environments

---

## PLSK-Native CI: Manifest Coverage Workflow

**Added in Feature 129** (downstream template update mechanism).

`.github/workflows/manifest-coverage.yml` is the first CI workflow in the PLSK repository itself. It enforces the file-ownership invariant required by feature 129's update mechanism: every tracked file in the repo must appear in `.aod/template-manifest.txt` (either with an explicit ownership rule or as an `ignore` entry).

### Workflow Summary

| Property | Value |
|----------|-------|
| Workflow file | `.github/workflows/manifest-coverage.yml` |
| Validator script | `scripts/check-manifest-coverage.sh` (bash 3.2 compatible) |
| Trigger | `push` and `pull_request` against `main` |
| Runner | `ubuntu-latest` |
| Execution shell | `bash:3.2` Docker image (matches macOS workstation floor) |
| Permissions | `contents: read` (principle of least privilege) |
| Concurrency | `cancel-in-progress: true` on same ref (force-push safe) |
| Action pinning | `actions/checkout` pinned by SHA, NOT by tag (retag-defense) |

### Exit Contract

| Exit | Meaning | Stderr |
|------|---------|--------|
| 0 | Every `git ls-files` entry matches a manifest entry | (empty) |
| 1 | Manifest missing, malformed, or any file uncategorized | `<path>:1: uncategorized (no manifest entry or ignore match)` per offending file (compiler-diagnostic format — GitHub Actions annotators parse it automatically) |

### Why bash:3.2 in Docker

The validator runs inside `bash:3.2` so CI enforces the same shell constraints that bind adopter workstations on macOS (GPLv3 licensing means Apple ships `/bin/bash` 3.2.57). GitHub's `ubuntu-latest` ships bash 5.x — without Docker isolation, bash 4+ regressions (associative arrays, `readarray`, case-modification parameter expansion, etc.) would pass CI and break macOS adopters. See `docs/INSTITUTIONAL_KNOWLEDGE.md` KB Entry 6 for background.

### Action Pinning Convention

All third-party GitHub Actions are pinned by full commit SHA, never by floating tag. The workflow file carries a maintainer-friendly comment that records which tag the SHA corresponds to:

```yaml
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

When upgrading, bump both the SHA and the comment together. This mirrors the same retag-defense philosophy the update script enforces against upstream PLSK releases.

### Running Locally

Before pushing, run the validator directly:

```bash
scripts/check-manifest-coverage.sh
```

Exit code `0` means you're clean. A non-zero exit prints uncategorized paths in the compiler-diagnostic format listed above.

### Optional Pre-Commit Hook

Strongly recommended for maintainers — the snippet is documented authoritatively in `CONTRIBUTING.md` under "Manifest Coverage Check". Install with:

```bash
cat > .git/hooks/pre-commit <<'EOF'
#!/usr/bin/env bash
set -e
scripts/check-manifest-coverage.sh
EOF
chmod +x .git/hooks/pre-commit
```

---

## BATS Test Harness Setup (Feature 129+)

**Added in Feature 129.** The bash test suite for shell-scripted features uses [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System). Tests live in `tests/unit/*.bats` and `tests/integration/*.bats`.

### Install

| Platform | Command |
|----------|---------|
| macOS (Homebrew) | `brew install bats-core` |
| Linux (Debian/Ubuntu) | `sudo apt-get install bats` |
| Any (no-root / CI fallback) | `git submodule add https://github.com/bats-core/bats-core.git tests/vendor/bats-core` then invoke via `tests/vendor/bats-core/bin/bats` |

Verify with `bats --version` (expected: 1.x or newer).

See `CONTRIBUTING.md` for the authoritative install guide and the full `bash 3.2` compatibility rules.

### CI Integration (current status)

BATS is **not yet wired into** `manifest-coverage.yml` — the existing workflow's sole job is the coverage check. BATS tests are run locally during development and before PRs. A future CI workflow can opt in by adding a `bats tests/unit/ tests/integration/` step; the `bash:3.2` image already contains `bats` via `apk add bats` (Alpine base).

---

## Update-Script Environment Variables

**Added in Feature 129.** `scripts/update.sh` (invoked by `make update` / `/aod.update`) respects the following environment variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `CI` | unset | When set (e.g., by GitHub Actions), update.sh defaults to `--dry-run` mode. Explicit `--apply` required to write. Safety guard to prevent accidental writes in automation. |
| `AOD_UPDATE_TMP_DIR` | `.aod/update-tmp` under adopter root | Staging directory override. Must be on the same filesystem as the project root (atomicity via `rename(2)` within the same mount). |
| `FORCE_RETAG` | unset | Override the retag-detection tripwire. Proceeds even if an upstream tag's SHA changed since the last pin. Logs a WARN. Paired with `--force-retag` CLI flag. |
| `AOD_COVERAGE_FILES` | (derived from `git ls-files`) | Test-harness override for `scripts/check-manifest-coverage.sh`. Newline-separated file list. **NOT public contract — for BATS tests only.** |
| `AOD_COVERAGE_MANIFEST` | `<repo_root>/.aod/template-manifest.txt` | Test-harness override. **NOT public contract.** |
| `AOD_COVERAGE_REPO_ROOT` | `git rev-parse --show-toplevel` | Test-harness override. **NOT public contract.** |

### Lock Contention & Concurrency

The update script holds `.aod/update.lock` while applying changes. Concurrency mechanics:

- **Lock acquisition**: `flock` fast-path on Linux; atomic `set -o noclobber` create on macOS (and all POSIX systems lacking `flock`). Lock contents: `pid`, 16-char hex `nonce`, ISO-8601 `started_at`, `cmdline`.
- **Default timeout**: ~30 s total wait with bounded retries.
- **Exit code 2**: lock contention — another `/aod.update` is running.
- **Stale-lock handling**: if the recorded PID is dead (`kill -0` returns non-zero) AND the lock is older than 1 hour, the update script force-acquires with nonce re-verify. Dead + <1h returns exit code 2 with a hint to investigate.

Full contract and edge-case behaviour: see `docs/guides/DOWNSTREAM_UPDATE.md` — this is the single source of truth. Spec references: `specs/129-downstream-template-update/spec.md` FR-005 (atomicity) and FR-008 (manifest coverage); `specs/129-downstream-template-update/plan.md` concurrency + CI design.

---

## Platform Guides

### GitHub Actions (Recommended)

**Best For**: Projects hosted on GitHub, flexible workflow needs

**Setup**:
1. Create `.github/workflows/ci.yml`
2. Define workflow stages (lint, test, build, deploy)
3. Add repository secrets (Settings → Secrets and Variables)

**Example Workflow**:
```yaml
name: CI/CD

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'
      - run: npm ci
      - run: npm test
      - run: npm run lint

  deploy-staging:
    needs: test
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy to Staging
        run: |
          # Platform-specific deployment command
          echo "Deploy to staging"

  deploy-production:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v3
      - name: Deploy to Production
        run: |
          # Platform-specific deployment command
          echo "Deploy to production"
```

**Resources**:
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)

---

### Vercel (Frontend/Full-Stack)

**Best For**: Next.js, React, Vue, static sites

**Setup**:
1. Install Vercel CLI: `npm i -g vercel`
2. Link project: `vercel link`
3. Configure via `vercel.json` or dashboard

**Auto-Deploy**:
- **PR**: Auto-deploys to preview URL
- **main branch**: Auto-deploys to production

**Configuration** (`vercel.json`):
```json
{
  "buildCommand": "npm run build",
  "devCommand": "npm run dev",
  "installCommand": "npm install",
  "framework": "{{FRAMEWORK}}",
  "regions": ["{{REGION}}"]
}
```

**Resources**:
- [Vercel Documentation](https://vercel.com/docs)
- [GitHub Integration](https://vercel.com/docs/concepts/git/vercel-for-github)

---

### Railway (Backend/Full-Stack)

**Best For**: Node.js, Python, Go, Docker-based apps

**Setup**:
1. Connect GitHub repository
2. Configure build command
3. Set environment variables
4. Define services in `railway.toml`

**Resources**:
- [Railway Documentation](https://docs.railway.app/)

---

### GitLab CI

**Best For**: Projects on GitLab

**Setup**: Create `.gitlab-ci.yml`

**Example**:
```yaml
stages:
  - test
  - deploy

test:
  stage: test
  script:
    - npm ci
    - npm test

deploy:
  stage: deploy
  script:
    - echo "Deploy to production"
  only:
    - main
```

---

## Essential CI/CD Components

### 1. Linting
```yaml
- name: Lint Code
  run: npm run lint
```

### 2. Type Checking
```yaml
- name: Type Check
  run: npm run typecheck
```

### 3. Unit Tests
```yaml
- name: Run Tests
  run: npm test
```

### 4. Build Verification
```yaml
- name: Build Application
  run: npm run build
```

### 5. Security Scanning
```yaml
- name: Security Audit
  run: npm audit --audit-level=moderate
```

---

## Environment Variables in CI/CD

### GitHub Actions
```yaml
env:
  DATABASE_URL: ${{ secrets.DATABASE_URL }}
  API_KEY: ${{ secrets.API_KEY }}
```

### Vercel
- Set via dashboard: Settings → Environment Variables
- Or CLI: `vercel env add VARIABLE_NAME`

---

## Best Practices

### DO ✅
- Run tests before deployment
- Use separate workflows for staging and production
- Cache dependencies to speed up builds
- Set up failure notifications
- Use environment-specific secrets

### DON'T ❌
- Commit secrets to repository
- Skip tests in CI
- Deploy directly to production without staging
- Ignore failed builds
- Use hardcoded credentials

---

## Monitoring CI/CD

Track these metrics:
- **Build Time**: Target <5 minutes
- **Success Rate**: Target >95%
- **Deployment Frequency**: Measure velocity
- **Mean Time to Recovery**: Track incident response

---

## Troubleshooting

### Build Fails on CI but Works Locally
- Check Node.js versions match
- Verify all dependencies in package.json
- Check environment variables are set
- Review CI logs for specific errors

### Slow Builds
- Enable dependency caching
- Parallelize test suites
- Optimize build commands
- Use smaller Docker base images

---

## Next Steps

After setting up CI/CD:
1. ✅ Add status badges to README
2. ✅ Configure branch protection rules
3. ✅ Set up deployment notifications
4. ✅ Document deployment process in README
5. ✅ Train team on CI/CD workflows

---

**Template Instructions**: Choose ONE platform and set up basic CI/CD. Expand with additional checks as project matures.
