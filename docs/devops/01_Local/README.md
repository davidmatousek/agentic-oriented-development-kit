# Local Development Environment - {{PROJECT_NAME}}

**Last Updated**: {{CURRENT_DATE}}
**Owner**: DevOps Agent

---

## Prerequisites

### Required Software
- **Docker Desktop**: Version {{VERSION}}+
- **Node.js**: Version {{VERSION}} (LTS recommended)
- **Git**: Version {{VERSION}}+

### Optional Software
- **VS Code**: Recommended IDE
- **Postman/Insomnia**: API testing
- **jq**: JSON processor, required by `.aod/scripts/bash/run-state.sh` for the Full Lifecycle Orchestrator (`brew install jq` on macOS, `apt-get install jq` on Linux)
- **GitHub CLI (`gh`)**: Used by `make init` to auto-create a GitHub Projects board for backlog tracking. Requires the `project` OAuth scope (`gh auth refresh -s project`). If not installed or not authenticated, init continues without creating the board. Install via `brew install gh` on macOS or see [cli.github.com](https://cli.github.com)
- **BATS** (`bats-core`): Bash test framework used by the shell test suite introduced in feature 129. Install via `brew install bats-core` (macOS), `apt-get install bats` (Linux), or as a git submodule (`git submodule add https://github.com/bats-core/bats-core.git tests/vendor/bats-core`). Only required if you will run or contribute to the bash test suite. See `CONTRIBUTING.md` for the authoritative setup guide.

### make init Personalization

`make init` personalizes the following template files by replacing `{{PROJECT_NAME}}` and other template variables with your project values at setup time:

- `CLAUDE.md`
- `README.md`
- `.claude/README.md`
- `.claude/agents/_README.md`
- `.claude/rules/commands.md`
- `.claude/rules/context-loading.md`
- `.claude/rules/deployment.md`
- `.claude/rules/git-workflow.md`
- `.claude/rules/governance.md`
- `.claude/rules/scope.md`
- `docs/product/02_PRD/INDEX.md`

No manual edits to these files are needed before running `make init`. After initialization, these files will contain your project name and description in place of template placeholders.

---

## Quick Start

```bash
# Clone repository
git clone {{REPOSITORY_URL}}
cd {{PROJECT_NAME}}

# Install dependencies
npm install

# Start development environment
docker-compose up -d

# Run database migrations
npm run migrate

# Start development servers
npm run dev
```

---

## Docker Compose Services

```yaml
# docker-compose.yml structure
services:
  frontend:
    # Frontend development server with hot reload
    ports: ["{{FRONTEND_PORT}}:{{FRONTEND_PORT}}"]

  backend:
    # Backend API server
    ports: ["{{BACKEND_PORT}}:{{BACKEND_PORT}}"]

  database:
    # PostgreSQL (or your database)
    ports: ["{{DATABASE_PORT}}:{{DATABASE_PORT}}"]
```

---

## Environment Variables

Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

**Required Variables**:
```
DATABASE_URL=postgresql://localhost:{{DATABASE_PORT}}/{{PROJECT_NAME}}_dev
API_URL=http://localhost:{{BACKEND_PORT}}
FRONTEND_URL=http://localhost:{{FRONTEND_PORT}}
```

**Optional Variables**:
```
AOD_LOG_FILE=.aod/logs/aod.log
AOD_BOARD=3
CI=                      # when set, scripts/update.sh defaults to --dry-run
AOD_UPDATE_TMP_DIR=      # override staging dir for cross-filesystem environments
FORCE_RETAG=             # bypass the upstream retag tripwire (logs a WARN)
```

The `AOD_LOG_FILE` variable controls where the logging utility writes its output. If not specified, it defaults to `.aod/logs/aod.log`. You can override this to write logs to a different location.

The `AOD_BOARD` variable pins the GitHub Projects board number for issue-board sync. When set, `github-lifecycle.sh` skips title-based board discovery and targets this board directly. If not specified, the script discovers the board by matching the title pattern `{repo-name}-backlog` or `AOD Backlog`.

**Update-script variables** (feature 129 — downstream template update mechanism):

- `CI`: when set (any non-empty value), `scripts/update.sh` defaults to `--dry-run` as a safety guard. Explicit `--apply` is required to write in CI. Intended to prevent accidental writes from GitHub Actions, GitLab CI, and equivalent automation.
- `AOD_UPDATE_TMP_DIR`: overrides the default staging directory (`<adopter_root>/.aod/update-tmp`). Must live on the same filesystem as the project root — atomicity relies on `rename(2)` within the same mount. Primary use: containerized environments where the default path straddles a mount boundary.
- `FORCE_RETAG`: when `1`, suppresses the upstream retag tripwire. Use only when you have verified the upstream tag's content out-of-band. Logs a WARN and records the override in `.aod/aod-kit-version.json`.

See `docs/devops/CI_CD_GUIDE.md` → "Update-Script Environment Variables" and `docs/guides/DOWNSTREAM_UPDATE.md` for the full contract.

---

## Common Commands

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# View logs
docker-compose logs -f [service-name]

# Rebuild after changes
docker-compose up --build

# Reset database
docker-compose down -v
docker-compose up -d
npm run migrate
```

---

## Troubleshooting

### Port Already in Use
```bash
# Find process using port
lsof -i :{{PORT}}

# Kill process
kill -9 <PID>
```

### Database Connection Failed
```bash
# Check database is running
docker-compose ps

# Check logs
docker-compose logs database

# Reset database
docker-compose down -v && docker-compose up -d
```

### Hot Reload Not Working
- Ensure volumes are mounted correctly in docker-compose.yml
- Check file watcher limits (Linux: `sudo sysctl fs.inotify.max_user_watches=524288`)

---

**Template Instructions**: Replace all `{{TEMPLATE_VARIABLES}}` with your actual configuration.
