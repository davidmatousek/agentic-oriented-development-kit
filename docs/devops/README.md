# DevOps Documentation - {{PROJECT_NAME}}

**Last Updated**: {{CURRENT_DATE}}
**Owner**: DevOps Agent
**Status**: Template

---

## Overview

This directory contains deployment and infrastructure documentation for {{PROJECT_NAME}}.

---

## Structure

### 01_Local/
Local development environment setup
- Docker Compose configuration
- Development database setup
- Environment variables
- Troubleshooting

### 02_Staging/
Staging environment documentation
- Staging infrastructure
- Deployment procedures
- Testing workflows
- Access credentials

### 03_Production/
Production environment documentation
- Production infrastructure
- Deployment procedures
- Monitoring and alerts
- Incident response
- Pre-deployment checklist

### CI_CD_GUIDE.md
CI/CD setup instructions for common platforms, plus PLSK's own native CI (manifest coverage) and the BATS test harness used by shell-scripted features.

---

## Quality Gates (CI)

### Manifest Coverage Workflow (PLSK-native)

`.github/workflows/manifest-coverage.yml` is the first CI workflow in PLSK itself. It runs on every push and pull request against `main` and asserts that every git-tracked file is categorized in `.aod/template-manifest.txt` — either with an explicit ownership rule or as `ignore`. This guarantees feature 129's 100% file-ownership invariant (FR-008) for all future template updates.

- **Validator**: `scripts/check-manifest-coverage.sh` (bash 3.2 compatible)
- **Execution**: runs inside the `bash:3.2` Docker image so CI enforces the same shell floor that macOS workstations use (KB Entry 6)
- **Exit code 0**: every tracked file matches a manifest entry
- **Exit code 1**: uncategorized files — stderr reports `<path>:1: uncategorized (no manifest entry or ignore match)` (compiler-diagnostic format; GitHub Actions annotators parse it automatically)
- **Local equivalent**: run `scripts/check-manifest-coverage.sh` before pushing, or install the opt-in pre-commit hook documented in `CONTRIBUTING.md`

See `docs/devops/CI_CD_GUIDE.md` for the full workflow walk-through and env-var contract.

---

## Deployment Policy (MANDATORY)

**ALL deployments MUST go through the devops agent.**

Before deploying to ANY environment:
1. Invoke devops agent (never run deploy commands directly)
2. DevOps reads: `docs/architecture/04_deployment_environments/{env}.md`
3. DevOps reads: `docs/devops/{01_Local|02_Staging|03_Production}/README.md`
4. DevOps outputs verification summary
5. Only then proceed with deployment

**Never deploy without verification** - Mismatched targets can cause data loss or service disruption.

---

## Environment Strategy

```
Development (Local):
  - Docker Compose for services
  - Local PostgreSQL
  - Fast iteration
  - Cost: $0

Staging ({{STAGING_PLATFORM}}):
  - Production-like configuration
  - Separate database
  - Auto-deploy on PR
  - Cost: {{STAGING_COST}}

Production ({{PRODUCTION_PLATFORM}}):
  - Auto-scaling
  - Monitoring and alerts
  - Manual promotion
  - Cost: {{PRODUCTION_COST}}
```

---

## Quick Links

- [Local Setup](01_Local/README.md)
- [Staging Deployment](02_Staging/README.md)
- [Production Deployment](03_Production/README.md)
- [CI/CD Guide](CI_CD_GUIDE.md) — includes manifest-coverage workflow, BATS harness, update-script env vars
- [Downstream Template Update Guide](../guides/DOWNSTREAM_UPDATE.md) — authoritative adopter walkthrough for `make update` / `/aod.update`

---

## Feature 129 Additions (2026-04-19)

The **Downstream Template Update Mechanism** (PR #131) introduced the first production-critical DevOps surfaces in PLSK itself:

- **First CI workflow**: `.github/workflows/manifest-coverage.yml` enforces 100% manifest coverage on every push and PR against `main` (see Quality Gates section above).
- **New developer dependency**: BATS (`bats-core`) is now required to run the bash test suite locally. Install instructions live in `CONTRIBUTING.md` (macOS: `brew install bats-core`; Linux: `apt-get install bats`; git-submodule fallback for CI or root-less environments).
- **Adopter update lifecycle**: `make update` / `/aod.update` pulls upstream template releases over HTTPS with no git remote required. Version pinning lives in `.aod/aod-kit-version`. Supply-chain defences include SHA-pinned GitHub Actions, manifest SHA-256 verification, and a retag tripwire (`FORCE_RETAG=1` override).
- **Concurrency model**: update-script acquires `.aod/update.lock` via `flock` on Linux (fast path) and atomic `noclobber` on macOS (PID + 16-char hex nonce + ISO-8601 timestamp). Liveness via `kill -0`, staleness threshold at 1 hour. Default timeout ~30 s; exits code 2 on contention. See `docs/guides/DOWNSTREAM_UPDATE.md` for full contract.
- **CI-aware safety default**: when `CI` env var is set, `scripts/update.sh` defaults to `--dry-run` mode (explicit `--apply` required for writes in CI).

---

**Maintained By**: DevOps Agent
