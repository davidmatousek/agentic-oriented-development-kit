# Contributing to the Agentic Oriented Development Kit

Thank you for contributing. This guide covers the development environment setup and quality gates required for patches to this repository.

## Development Environment

### BATS Test Framework

The bash test suite for feature 129 (downstream template update mechanism) and future shell-scripted features uses [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System).

**Install on macOS** (Homebrew):

```bash
brew install bats-core
```

**Install on Linux** (Debian/Ubuntu):

```bash
sudo apt-get update
sudo apt-get install bats
```

**Install from source (any platform — no root required, useful for CI)**:

```bash
git submodule add https://github.com/bats-core/bats-core.git tests/vendor/bats-core
# Invoke tests via: tests/vendor/bats-core/bin/bats tests/unit/*.bats
```

**Verify the installation**:

```bash
bats --version
# Expected: Bats 1.x or newer
```

### Running Tests

```bash
# Unit tests
bats tests/unit/*.bats

# Integration tests
bats tests/integration/*.bats

# Full suite (unit + integration)
bats tests/unit/ tests/integration/
```

### Bash 3.2 Compatibility

All `.sh` scripts in this repo MUST be bash 3.2 compatible — macOS ships bash 3.2.57 at `/bin/bash` due to GPLv3 licensing.

**Avoid the following bash 4+ features**:

- `declare -A` (associative arrays) — use `case` lookup functions instead.
- `${var^}` / `${var^^}` / `${var,,}` (case modification) — use `tr` instead.
- `readarray` / `mapfile` — use `while IFS= read -r line; do ... done < file` instead.
- `|&` (pipe stderr) — use `2>&1 |` instead.
- `globstar` (`shopt -s globstar`) — use explicit recursion or `find` instead.

See `docs/INSTITUTIONAL_KNOWLEDGE.md` KB Entry #6 for background and examples.

## Quality Gates

### Manifest Coverage Check (feature 129)

Every tracked file in this repository must be categorized in `.aod/template-manifest.txt`. The CI workflow `.github/workflows/manifest-coverage.yml` validates 100% coverage on every push and pull request.

**Run the check locally before pushing**:

```bash
scripts/check-manifest-coverage.sh
```

Exit code `0` means every `git ls-files` entry has a matching manifest entry. A non-zero exit lists uncategorized paths.

**Optional pre-commit hook** (strongly recommended for maintainers):

```bash
cat > .git/hooks/pre-commit <<'EOF'
#!/usr/bin/env bash
set -e
scripts/check-manifest-coverage.sh
EOF
chmod +x .git/hooks/pre-commit
```

The hook runs the coverage validator on every `git commit`. If new files are staged without manifest entries, the commit is rejected with a list of the uncategorized paths.

## Commit Conventions

Use [Conventional Commits](https://www.conventionalcommits.org/) — `feat(NNN):`, `fix(NNN):`, `docs(NNN):`, `chore(NNN):`, `test(NNN):` where `NNN` is the GitHub Issue number.

## Branch Policy

All work happens on feature branches named `NNN-descriptive-name` — never commit to `main` directly. See `.claude/rules/git-workflow.md` for the full workflow.
