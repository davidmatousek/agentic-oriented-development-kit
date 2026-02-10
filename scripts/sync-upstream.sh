#!/usr/bin/env bash
# scripts/sync-upstream.sh — Sync upstream AOD template changes into adopter projects
#
# Provides 4 subcommands:
#   setup    — Configure the upstream AOD template repository as a git remote
#   check    — Detect and display categorized upstream changes
#   merge    — Safely merge upstream changes with backup and .aod/memory/ protection
#   validate — Post-sync integrity checks (file existence, YAML, placeholders)
#
# Usage:
#   sync-upstream.sh <subcommand> [options]
#   sync-upstream.sh setup [--url <url>]
#   sync-upstream.sh check
#   sync-upstream.sh merge [--dry-run]
#   sync-upstream.sh validate
#
# Global flags:
#   --dry-run    Preview operations without modifying files
#   --json       Output in JSON format (where supported)
#   --help       Show this help message

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -f "$REPO_ROOT/.aod/scripts/bash/common.sh" ]]; then
    source "$REPO_ROOT/.aod/scripts/bash/common.sh"
fi

# Colors (defined locally per Architect review — common.sh does not export these)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Canonical upstream URL
CANONICAL_URL="https://github.com/spec-kit-ops/spec-kit.git"

# Global flags
DRY_RUN=false
JSON_OUTPUT=false

# ============================================================================
# FILE OWNERSHIP CATEGORIES
# ============================================================================

# Classify a file path into an ownership category.
# Uses case-statement pattern for bash 3.2 compatibility (no associative arrays).
file_category() {
    local path="$1"
    case "$path" in
        .claude/skills/*)       echo "Skills" ;;
        .claude/rules/*)        echo "Rules" ;;
        .claude/agents/*)       echo "Agents" ;;
        .claude/commands/*)     echo "Commands" ;;
        .claude/lib/*)          echo "Scripts" ;;
        .claude/config/*)       echo "Config" ;;
        scripts/*)              echo "Scripts" ;;
        .aod/scripts/*)         echo "Scripts" ;;
        .aod/templates/*)       echo "Templates" ;;
        docs/core_principles/*) echo "Docs" ;;
        docs/standards/*)       echo "Docs" ;;
        docs/architecture/*)    echo "Docs" ;;
        docs/devops/*)          echo "Docs" ;;
        docs/guides/*)          echo "Docs" ;;
        docs/product/*)         echo "Docs" ;;
        docs/testing/*)         echo "Docs" ;;
        docs/*)                 echo "Docs" ;;
        CLAUDE.md)              echo "Core" ;;
        Makefile)               echo "Core" ;;
        .gitignore)             echo "Core" ;;
        LICENSE)                echo "Core" ;;
        .env.example)           echo "Core" ;;
        MIGRATION.md)           echo "Core" ;;
        *)                      echo "Other" ;;
    esac
}

# ============================================================================
# USAGE / HELP
# ============================================================================

show_help() {
    cat <<'HELPEOF'
Usage: sync-upstream.sh <subcommand> [options]

Sync upstream AOD template changes into your project.

Subcommands:
  setup      Configure the upstream remote (one-time)
  check      Show what changed upstream since last sync
  merge      Safely merge upstream changes (creates backup)
  validate   Post-sync integrity checks

Global Options:
  --dry-run  Preview without making changes
  --json     Output in JSON format (where supported)
  --help     Show this help message

Examples:
  # First-time setup
  sync-upstream.sh setup

  # Setup with custom upstream URL
  sync-upstream.sh setup --url https://github.com/myorg/my-template.git

  # Check for upstream changes
  sync-upstream.sh check

  # Preview what a merge would do
  sync-upstream.sh merge --dry-run

  # Merge upstream changes
  sync-upstream.sh merge

  # Validate project integrity after merge
  sync-upstream.sh validate

Documentation:
  See docs/guides/UPSTREAM_SYNC.md for the full step-by-step guide.
HELPEOF
}

# ============================================================================
# SUBCOMMAND: setup
# ============================================================================

cmd_setup() {
    local custom_url=""

    # Parse setup-specific flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --url)
                if [[ $# -lt 2 ]]; then
                    echo -e "${RED}Error: --url requires a value${NC}" >&2
                    return 1
                fi
                custom_url="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}Error: Unknown option for setup: $1${NC}" >&2
                return 1
                ;;
        esac
    done

    local url="${custom_url:-$CANONICAL_URL}"

    # Validate URL format
    if [[ -n "$custom_url" ]]; then
        if [[ ! "$custom_url" =~ ^https:// ]] && [[ ! "$custom_url" =~ ^git@ ]]; then
            echo -e "${RED}Error: URL must start with https:// or git@${NC}" >&2
            echo "  Example: https://github.com/org/repo.git" >&2
            echo "  Example: git@github.com:org/repo.git" >&2
            return 1
        fi
    fi

    # Check if upstream remote already exists
    if git remote get-url upstream >/dev/null 2>&1; then
        local existing_url
        existing_url=$(git remote get-url upstream)
        echo -e "${GREEN}Upstream remote already configured${NC}"
        echo "  URL: $existing_url"

        # Check if URL matches
        if [[ -n "$custom_url" ]] && [[ "$existing_url" != "$custom_url" ]]; then
            echo -e "${YELLOW}Warning: Current URL differs from requested URL${NC}"
            echo "  Current:   $existing_url"
            echo "  Requested: $custom_url"
            echo ""
            echo "  To update: git remote set-url upstream $custom_url"
        fi
        return 0
    fi

    # Add upstream remote
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would add upstream remote:"
        echo "  git remote add upstream $url"
        echo "  git fetch upstream"
        return 0
    fi

    echo -e "${BLUE}Adding upstream remote...${NC}"
    echo "  URL: $url"
    git remote add upstream "$url"

    echo -e "${BLUE}Fetching upstream refs...${NC}"
    if ! git fetch upstream 2>&1; then
        echo -e "${RED}Error: Failed to fetch from upstream${NC}" >&2
        echo "  Check that the URL is correct and you have network access." >&2
        echo "  URL: $url" >&2
        echo ""
        echo "  To remove and retry: git remote remove upstream" >&2
        return 1
    fi

    echo -e "${GREEN}Upstream remote configured successfully${NC}"
    echo "  Remote: upstream"
    echo "  URL:    $url"
    echo ""
    echo "  Next: Run 'sync-upstream.sh check' to see available changes."

    # Add .gitattributes entries for adopter-owned paths
    _ensure_gitattributes
}

# ============================================================================
# SUBCOMMAND: check
# ============================================================================

cmd_check() {
    # Verify upstream remote exists
    if ! git remote get-url upstream >/dev/null 2>&1; then
        echo -e "${RED}Error: No 'upstream' remote configured${NC}" >&2
        echo "  Run: sync-upstream.sh setup" >&2
        return 1
    fi

    echo -e "${BLUE}Fetching upstream changes...${NC}"
    if ! git fetch upstream 2>&1; then
        echo -e "${RED}Error: Failed to fetch from upstream${NC}" >&2
        return 1
    fi

    # Determine sync point
    local sync_point=""
    if sync_point=$(git merge-base HEAD upstream/main 2>/dev/null); then
        : # sync_point is set
    else
        echo -e "${YELLOW}Warning: No shared history found (repo may have been cloned, not forked)${NC}"
        echo "  Using upstream/main directly for comparison."
        echo ""
        sync_point=""
    fi

    # Get changed files
    local diff_target="upstream/main"
    local diff_stat=""
    if [[ -n "$sync_point" ]]; then
        diff_stat=$(git diff --stat "${sync_point}..upstream/main" 2>/dev/null || true)
    else
        diff_stat=$(git diff --stat "upstream/main" 2>/dev/null || true)
    fi

    # Handle "already up to date"
    if [[ -z "$diff_stat" ]]; then
        local sync_date=""
        if [[ -n "$sync_point" ]]; then
            sync_date=$(git log -1 --format='%ci' "$sync_point" 2>/dev/null || echo "unknown")
        else
            sync_date="N/A"
        fi
        echo -e "${GREEN}Already up to date${NC}"
        echo "  Last sync point: $sync_date"
        return 0
    fi

    # Parse and categorize changed files
    local skills=0 rules=0 agents=0 commands=0 scripts=0 templates=0 docs=0 core=0 config=0 other=0
    local total=0

    while IFS= read -r line; do
        # Skip the summary line (e.g., "10 files changed, 50 insertions...")
        if echo "$line" | grep -q "files\? changed"; then
            continue
        fi
        # Skip empty lines
        if [[ -z "$line" ]]; then
            continue
        fi

        # Extract file path (first field, strip leading whitespace)
        local filepath
        filepath=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -d'|' -f1 | sed 's/[[:space:]]*$//')

        if [[ -z "$filepath" ]]; then
            continue
        fi

        local cat
        cat=$(file_category "$filepath")
        total=$((total + 1))

        case "$cat" in
            Skills)    skills=$((skills + 1)) ;;
            Rules)     rules=$((rules + 1)) ;;
            Agents)    agents=$((agents + 1)) ;;
            Commands)  commands=$((commands + 1)) ;;
            Scripts)   scripts=$((scripts + 1)) ;;
            Templates) templates=$((templates + 1)) ;;
            Docs)      docs=$((docs + 1)) ;;
            Core)      core=$((core + 1)) ;;
            Config)    config=$((config + 1)) ;;
            Other)     other=$((other + 1)) ;;
        esac
    done <<EOF
$diff_stat
EOF

    # Display categorized summary
    echo -e "${BLUE}Upstream changes available:${NC}"
    echo ""
    if [[ $skills -gt 0 ]];    then echo -e "  Skills:    ${GREEN}$skills files${NC}"; fi
    if [[ $rules -gt 0 ]];     then echo -e "  Rules:     ${GREEN}$rules files${NC}"; fi
    if [[ $agents -gt 0 ]];    then echo -e "  Agents:    ${GREEN}$agents files${NC}"; fi
    if [[ $commands -gt 0 ]];  then echo -e "  Commands:  ${GREEN}$commands files${NC}"; fi
    if [[ $scripts -gt 0 ]];   then echo -e "  Scripts:   ${GREEN}$scripts files${NC}"; fi
    if [[ $templates -gt 0 ]]; then echo -e "  Templates: ${GREEN}$templates files${NC}"; fi
    if [[ $docs -gt 0 ]];      then echo -e "  Docs:      ${GREEN}$docs files${NC}"; fi
    if [[ $core -gt 0 ]];      then echo -e "  Core:      ${GREEN}$core files${NC}"; fi
    if [[ $config -gt 0 ]];    then echo -e "  Config:    ${GREEN}$config files${NC}"; fi
    if [[ $other -gt 0 ]];     then echo -e "  Other:     ${GREEN}$other files${NC}"; fi
    echo ""
    echo -e "  ${BLUE}Total: $total files changed${NC}"
    echo ""
    echo "  Next: Run 'sync-upstream.sh merge --dry-run' to preview the merge."
}

# ============================================================================
# SUBCOMMAND: merge
# ============================================================================

cmd_merge() {
    # --- Pre-flight checks ---

    # Check for clean working tree
    local status_output
    status_output=$(git status --porcelain 2>/dev/null)
    if [[ -n "$status_output" ]]; then
        echo -e "${RED}Error: Working tree has uncommitted changes${NC}" >&2
        echo "  Please commit or stash your changes before merging." >&2
        echo "" >&2
        echo "  git stash       # Stash changes temporarily" >&2
        echo "  git add -A && git commit -m 'WIP: save before sync'" >&2
        return 1
    fi

    # Verify upstream remote
    if ! git remote get-url upstream >/dev/null 2>&1; then
        echo -e "${RED}Error: No 'upstream' remote configured${NC}" >&2
        echo "  Run: sync-upstream.sh setup" >&2
        return 1
    fi

    # Fetch latest
    echo -e "${BLUE}Fetching upstream...${NC}"
    if ! git fetch upstream 2>&1; then
        echo -e "${RED}Error: Failed to fetch from upstream${NC}" >&2
        return 1
    fi

    # Detect shared vs unrelated history
    local has_shared_history=true
    if ! git merge-base HEAD upstream/main >/dev/null 2>&1; then
        has_shared_history=false
    fi

    # --- Dry-run mode ---
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Previewing merge (no changes will be made)..."
        echo ""

        if $has_shared_history; then
            if git merge --no-commit upstream/main >/dev/null 2>&1; then
                git diff --cached --stat 2>/dev/null || true
                git merge --abort >/dev/null 2>&1 || true
            else
                echo -e "${YELLOW}Merge would produce conflicts:${NC}"
                git diff --name-only --diff-filter=U 2>/dev/null || true
                git merge --abort >/dev/null 2>&1 || true
            fi
        else
            echo -e "${YELLOW}Note: Unrelated histories — merge will use --allow-unrelated-histories${NC}"
            if git merge --no-commit --allow-unrelated-histories upstream/main >/dev/null 2>&1; then
                git diff --cached --stat 2>/dev/null || true
                git merge --abort >/dev/null 2>&1 || true
            else
                echo -e "${YELLOW}Merge would produce conflicts:${NC}"
                git diff --name-only --diff-filter=U 2>/dev/null || true
                git merge --abort >/dev/null 2>&1 || true
            fi
        fi

        echo ""
        echo -e "${YELLOW}[DRY-RUN]${NC} No files were modified."
        return 0
    fi

    # --- Create backup branch ---
    local backup_branch="pre-sync-backup-$(date +%Y%m%d-%H%M%S)"
    echo -e "${BLUE}Creating backup branch: ${backup_branch}${NC}"
    git branch "$backup_branch"

    # --- Backup .aod/memory/ (defense-in-depth) ---
    local memory_dir="$REPO_ROOT/.aod/memory"
    local memory_backup=""
    if [[ -d "$memory_dir" ]]; then
        memory_backup=$(mktemp -d)
        cp -R "$memory_dir/." "$memory_backup/"
        echo -e "${BLUE}Backed up .aod/memory/ to temporary location${NC}"
    fi

    # --- Merge ---
    local merge_result=0
    local merge_output=""

    echo -e "${BLUE}Merging upstream/main...${NC}"
    if $has_shared_history; then
        merge_output=$(git merge upstream/main --no-edit 2>&1) || merge_result=$?
    else
        echo -e "${YELLOW}Note: Using --allow-unrelated-histories (no shared git history)${NC}"
        merge_output=$(git merge upstream/main --allow-unrelated-histories --no-edit 2>&1) || merge_result=$?
    fi

    # --- Restore .aod/memory/ ---
    if [[ -n "$memory_backup" ]] && [[ -d "$memory_backup" ]]; then
        cp -R "$memory_backup/." "$memory_dir/"
        rm -rf "$memory_backup"
        # Stage the restored memory files to resolve any conflicts there
        git add "$memory_dir" 2>/dev/null || true
        echo -e "${GREEN}.aod/memory/ restored from backup${NC}"
    fi

    # --- Report results ---
    echo ""
    if [[ $merge_result -eq 0 ]]; then
        # Clean merge
        local files_changed
        files_changed=$(echo "$merge_output" | grep -c "file changed\|files changed" || echo "0")
        echo -e "${GREEN}Merge completed successfully${NC}"
        echo "$merge_output" | grep -E "file(s)? changed|insertion|deletion" || true
        echo ""
        echo "  Backup branch: $backup_branch"
        echo "  .aod/memory/:  preserved"
        echo ""
        echo "  Next: Run 'sync-upstream.sh validate' to check project integrity."
    else
        # Merge with conflicts
        local conflict_files
        conflict_files=$(git diff --name-only --diff-filter=U 2>/dev/null || true)
        local conflict_count=0
        if [[ -n "$conflict_files" ]]; then
            conflict_count=$(echo "$conflict_files" | wc -l | tr -d ' ')
        fi

        echo -e "${YELLOW}Merge completed with $conflict_count conflict(s)${NC}"
        echo ""
        echo "  Files with conflicts:"
        echo "$conflict_files" | while IFS= read -r f; do
            echo -e "    ${RED}$f${NC}"
        done
        echo ""
        echo "  Resolve conflicts:"
        echo "    1. Edit each conflicted file and resolve markers (<<<<<<< / ======= / >>>>>>>)"
        echo "    2. git add <resolved-file>"
        echo "    3. git commit (to complete the merge)"
        echo ""
        echo "  Or abort and restore:"
        echo "    git merge --abort"
        echo "    git checkout $backup_branch  # Restore pre-merge state"
        echo ""
        echo "  Backup branch: $backup_branch"
        echo "  .aod/memory/:  preserved"
    fi
}

# ============================================================================
# SUBCOMMAND: validate
# ============================================================================

cmd_validate() {
    echo -e "${BLUE}Validating project integrity...${NC}"
    echo ""

    local pass_count=0
    local fail_count=0
    local warn_count=0

    # --- Check 1: Expected AOD files exist ---
    echo -e "${BLUE}1. File existence checks${NC}"
    local expected_dirs=(".aod" ".claude" "docs/core_principles" "scripts")
    for dir in "${expected_dirs[@]}"; do
        if [[ -d "$REPO_ROOT/$dir" ]]; then
            echo -e "   ${GREEN}PASS${NC} $dir/ exists"
            pass_count=$((pass_count + 1))
        else
            echo -e "   ${RED}FAIL${NC} $dir/ missing"
            echo "         Remediation: Check if upstream merge removed this directory"
            fail_count=$((fail_count + 1))
        fi
    done

    local expected_files=("CLAUDE.md" "Makefile" ".gitignore")
    for file in "${expected_files[@]}"; do
        if [[ -f "$REPO_ROOT/$file" ]]; then
            echo -e "   ${GREEN}PASS${NC} $file exists"
            pass_count=$((pass_count + 1))
        else
            echo -e "   ${RED}FAIL${NC} $file missing"
            echo "         Remediation: Restore from backup branch or upstream"
            fail_count=$((fail_count + 1))
        fi
    done
    echo ""

    # --- Check 2: YAML frontmatter validation ---
    echo -e "${BLUE}2. YAML frontmatter checks${NC}"
    local yaml_files_checked=0
    while IFS= read -r specfile; do
        if [[ -z "$specfile" ]]; then
            continue
        fi
        yaml_files_checked=$((yaml_files_checked + 1))
        local relpath="${specfile#$REPO_ROOT/}"

        # Check for opening and closing --- delimiters
        local first_line
        first_line=$(head -1 "$specfile" 2>/dev/null || echo "")
        if [[ "$first_line" == "---" ]]; then
            # Look for closing ---
            local closing
            closing=$(tail -n +2 "$specfile" | grep -n "^---$" | head -1 | cut -d: -f1 || echo "")
            if [[ -n "$closing" ]] && [[ "$closing" -gt 0 ]]; then
                echo -e "   ${GREEN}PASS${NC} $relpath — valid frontmatter"
                pass_count=$((pass_count + 1))
            else
                echo -e "   ${RED}FAIL${NC} $relpath — missing closing --- delimiter"
                echo "         Remediation: Add closing --- after YAML frontmatter block"
                fail_count=$((fail_count + 1))
            fi
        else
            echo -e "   ${YELLOW}WARN${NC} $relpath — no YAML frontmatter found"
            warn_count=$((warn_count + 1))
        fi
    done < <(find "$REPO_ROOT/specs" -name "spec.md" -o -name "plan.md" -o -name "tasks.md" 2>/dev/null)

    if [[ $yaml_files_checked -eq 0 ]]; then
        echo -e "   ${YELLOW}WARN${NC} No spec/plan/tasks files found to validate"
        warn_count=$((warn_count + 1))
    fi
    echo ""

    # --- Check 3: Placeholder leak detection ---
    echo -e "${BLUE}3. Placeholder leak detection${NC}"
    local placeholder_found=false
    local scan_files=("CLAUDE.md" ".aod/memory/constitution.md" "Makefile" "scripts/init.sh")
    for file in "${scan_files[@]}"; do
        local fullpath="$REPO_ROOT/$file"
        if [[ ! -f "$fullpath" ]]; then
            continue
        fi
        local matches
        matches=$(grep -n '{{[A-Z_]*}}' "$fullpath" 2>/dev/null || true)
        if [[ -n "$matches" ]]; then
            placeholder_found=true
            echo -e "   ${YELLOW}WARN${NC} $file — placeholder(s) found:"
            echo "$matches" | while IFS= read -r match; do
                echo "         Line $match"
            done
            warn_count=$((warn_count + 1))
        fi
    done
    if ! $placeholder_found; then
        echo -e "   ${GREEN}PASS${NC} No leaked placeholders detected"
        pass_count=$((pass_count + 1))
    fi
    echo ""

    # --- Check 4: Constitution integrity ---
    echo -e "${BLUE}4. Constitution integrity${NC}"
    local constitution="$REPO_ROOT/.aod/memory/constitution.md"
    if [[ -f "$constitution" ]]; then
        local template_count
        template_count=$(grep -c '{{' "$constitution" 2>/dev/null || echo "0")
        local total_lines
        total_lines=$(wc -l < "$constitution" | tr -d ' ')
        if [[ "$template_count" -gt 0 ]]; then
            echo -e "   ${YELLOW}WARN${NC} constitution.md has $template_count unresolved template variable(s)"
            echo "         This may be expected if you haven't customized the constitution yet."
            echo "         Run: /aod.constitution to configure your project values"
            warn_count=$((warn_count + 1))
        else
            echo -e "   ${GREEN}PASS${NC} constitution.md — no template variables (customized)"
            pass_count=$((pass_count + 1))
        fi
    else
        echo -e "   ${RED}FAIL${NC} .aod/memory/constitution.md not found"
        echo "         Remediation: Restore from backup or re-run scripts/init.sh"
        fail_count=$((fail_count + 1))
    fi
    echo ""

    # --- Summary ---
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Validation Summary${NC}"
    echo -e "  ${GREEN}Passed:   $pass_count${NC}"
    echo -e "  ${RED}Failed:   $fail_count${NC}"
    echo -e "  ${YELLOW}Warnings: $warn_count${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [[ $fail_count -gt 0 ]]; then
        echo ""
        echo -e "${RED}Some checks failed. Review the issues above and apply remediations.${NC}"
        return 1
    elif [[ $warn_count -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}All critical checks passed. Review warnings above.${NC}"
        return 0
    else
        echo ""
        echo -e "${GREEN}All checks passed. Project integrity verified.${NC}"
        return 0
    fi
}

# ============================================================================
# HELPER: Ensure .gitattributes has adopter-owned path protections
# ============================================================================

_ensure_gitattributes() {
    local gitattributes="$REPO_ROOT/.gitattributes"
    local entry=".aod/memory/ merge=ours"

    if [[ -f "$gitattributes" ]]; then
        if grep -qF "$entry" "$gitattributes" 2>/dev/null; then
            return 0  # Already present
        fi
    fi

    echo -e "${BLUE}Adding .aod/memory/ merge protection to .gitattributes${NC}"
    if ! $DRY_RUN; then
        echo "$entry" >> "$gitattributes"
    fi
}

# ============================================================================
# ARGUMENT PARSING & DISPATCH
# ============================================================================

# Collect global flags and subcommand
SUBCOMMAND=""
SUBCOMMAND_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        setup|check|merge|validate)
            SUBCOMMAND="$1"
            shift
            # Collect remaining args, extracting global flags
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --dry-run) DRY_RUN=true; shift ;;
                    --json)    JSON_OUTPUT=true; shift ;;
                    *)         SUBCOMMAND_ARGS=("${SUBCOMMAND_ARGS[@]+"${SUBCOMMAND_ARGS[@]}"}" "$1"); shift ;;
                esac
            done
            break
            ;;
        *)
            echo -e "${RED}Error: Unknown command or option: $1${NC}" >&2
            echo "" >&2
            echo "Usage: sync-upstream.sh <subcommand> [options]" >&2
            echo "Run 'sync-upstream.sh --help' for details." >&2
            exit 1
            ;;
    esac
done

# Verify git is available
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo -e "${RED}Error: Not a git repository (or git is not installed)${NC}" >&2
    echo "  This script must be run from within a git repository." >&2
    exit 1
fi

# Dispatch
case "$SUBCOMMAND" in
    setup)    cmd_setup "${SUBCOMMAND_ARGS[@]+"${SUBCOMMAND_ARGS[@]}"}" ;;
    check)    cmd_check ;;
    merge)    cmd_merge ;;
    validate) cmd_validate ;;
    "")
        echo -e "${RED}Error: No subcommand specified${NC}" >&2
        echo "" >&2
        show_help
        exit 1
        ;;
    *)
        echo -e "${RED}Error: Unknown subcommand: $SUBCOMMAND${NC}" >&2
        exit 1
        ;;
esac
