#!/bin/bash
# scripts/extract.sh - Agentic Oriented Development Kit Extraction Manifest
#
# Manifest-driven extraction from private repo to public template repo.
# Supports initial extraction and ongoing synchronization (--sync).
#
# Usage:
#   ./scripts/extract.sh [OPTIONS]
#
# Options:
#   --sync       Re-sync from private repo (re-applies content resets)
#   --dry-run    Preview operations without copying files
#   --dest DIR   Override destination directory (default: ../agentic-oriented-development-kit)
#
# This script is the single source of truth for what constitutes template content.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Defaults
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEST_DIR="${SOURCE_DIR}/../agentic-oriented-development-kit"
DRY_RUN=false
SYNC_MODE=false

# Counters
FILES_COPIED=0
FILES_RESET=0
FILES_CREATED=0
FILES_SKIPPED=0

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --sync)     SYNC_MODE=true; shift ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --dest)     DEST_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--sync] [--dry-run] [--dest DIR]"
      echo ""
      echo "Options:"
      echo "  --sync       Re-sync (re-applies content resets)"
      echo "  --dry-run    Preview operations without copying"
      echo "  --dest DIR   Override destination directory"
      exit 0
      ;;
    *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
  esac
done

# ============================================================================
# MANIFEST: Template files and directories to extract
# This is the canonical definition of what constitutes template content.
# ============================================================================

MANIFEST_DIRS=(
  # Core Agent Infrastructure
  ".claude/agents"
  ".claude/skills"
  ".claude/commands"
  ".claude/rules"
  ".claude/lib"
  ".claude/config"

  # Core Principles & Standards
  "docs/core_principles"
  "docs/standards"

  # Architecture Templates
  "docs/architecture"

  # DevOps Templates (subdirectories)
  "docs/devops/01_Local"
  "docs/devops/02_Staging"
  "docs/devops/03_Production"

  # Product Templates (subdirectories)
  "docs/product/03_Product_Roadmap"
  "docs/product/04_Journey_Maps"
  "docs/product/05_User_Stories"
  "docs/product/06_OKRs"

  # Guides
  "docs/guides"

  # Testing
  "docs/testing"

  # AOD Scripts & Templates
  ".aod/scripts/bash"
  ".aod/templates"
)

MANIFEST_FILES=(
  # .claude root files
  ".claude/README.md"
  ".claude/INFRASTRUCTURE_SETUP_SUMMARY.md"
  ".claude/mcp-config.json"

  # Product templates (specific files only)
  "docs/product/01_Product_Vision/README.md"
  "docs/product/02_PRD/000-example-feature.md"
  "docs/product/02_PRD/INDEX.md"
  "docs/product/_backlog/README.md"
  "docs/product/_backlog/01_IDEAS.md"
  "docs/product/_backlog/02_USER_STORIES.md"

  # DevOps root files
  "docs/devops/README.md"
  "docs/devops/CI_CD_GUIDE.md"
  "docs/devops/FEATURE_MATRIX.md"

  # Doc root files
  "docs/AOD_TRIAD.md"
  "docs/DOCS_TO_UPDATE_AFTER_NEW_FEATURE.md"
  "docs/INSTITUTIONAL_KNOWLEDGE.md"

  # AOD memory
  ".aod/memory/constitution.md"

  # Scripts
  "scripts/init.sh"
  "scripts/check.sh"

  # Root files
  "CLAUDE.md"
  "Makefile"
  ".env.example"
  ".gitignore"
  "MIGRATION.md"
  "LICENSE"
)

# Files that need content reset after copy (FR-2)
# These are copied first, then overwritten with template-clean content
CONTENT_RESET_FILES=(
  "docs/product/02_PRD/INDEX.md"
  "docs/product/_backlog/01_IDEAS.md"
  "docs/product/_backlog/02_USER_STORIES.md"
)

# ============================================================================
# FUNCTIONS
# ============================================================================

log_action() {
  local action="$1"
  local path="$2"
  if $DRY_RUN; then
    echo -e "  ${YELLOW}[DRY-RUN]${NC} ${action}: ${path}"
  else
    echo -e "  ${GREEN}${action}${NC}: ${path}"
  fi
}

copy_file() {
  local src="$1"
  local dest="$2"
  if [[ ! -f "$src" ]]; then
    echo -e "  ${RED}MISSING${NC}: $src"
    FILES_SKIPPED=$((FILES_SKIPPED + 1))
    return
  fi
  log_action "COPY" "$dest"
  if ! $DRY_RUN; then
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
  fi
  FILES_COPIED=$((FILES_COPIED + 1))
}

copy_dir() {
  local src="$1"
  local dest="$2"
  if [[ ! -d "$src" ]]; then
    echo -e "  ${RED}MISSING DIR${NC}: $src"
    FILES_SKIPPED=$((FILES_SKIPPED + 1))
    return
  fi
  log_action "COPY DIR" "$dest"
  if ! $DRY_RUN; then
    mkdir -p "$dest"
    # Copy all files preserving structure
    while IFS= read -r f; do
      local target="$dest/$f"
      mkdir -p "$(dirname "$target")"
      cp "$src/$f" "$target"
      FILES_COPIED=$((FILES_COPIED + 1))
    done < <(cd "$src" && find . -type f)
  else
    # Count files for dry-run
    local count
    count=$(find "$src" -type f | wc -l | tr -d ' ')
    FILES_COPIED=$((FILES_COPIED + count))
  fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

echo -e "${BLUE}Agentic Oriented Development Kit — Extraction${NC}"
echo ""
echo "  Source:      $SOURCE_DIR"
echo "  Destination: $DEST_DIR"
echo "  Mode:        $(if $SYNC_MODE; then echo 'SYNC'; else echo 'EXTRACT'; fi)"
echo "  Dry Run:     $DRY_RUN"
echo ""

# Create destination if needed
if ! $DRY_RUN; then
  mkdir -p "$DEST_DIR"
fi

# --- Step 1: Copy directories ---
echo -e "${BLUE}Step 1: Copying template directories...${NC}"
for dir in "${MANIFEST_DIRS[@]}"; do
  copy_dir "$SOURCE_DIR/$dir" "$DEST_DIR/$dir"
done

# --- Step 2: Copy individual files ---
echo ""
echo -e "${BLUE}Step 2: Copying individual template files...${NC}"
for file in "${MANIFEST_FILES[@]}"; do
  copy_file "$SOURCE_DIR/$file" "$DEST_DIR/$file"
done

# --- Step 3: Create .gitkeep for empty directories ---
echo ""
echo -e "${BLUE}Step 3: Creating .gitkeep for empty directories...${NC}"

GITKEEP_DIRS=(
  "specs"
  "docs/agents"
  "docs/architecture/01_system_design"
)

for dir in "${GITKEEP_DIRS[@]}"; do
  log_action "GITKEEP" "$dir/.gitkeep"
  if ! $DRY_RUN; then
    mkdir -p "$DEST_DIR/$dir"
    touch "$DEST_DIR/$dir/.gitkeep"
  fi
  FILES_CREATED=$((FILES_CREATED + 1))
done

# --- Step 4: Content resets (FR-2) ---
# Always run on --sync; on initial extract these will be overwritten later in Phase 3B
if $SYNC_MODE; then
  echo ""
  echo -e "${BLUE}Step 4: Applying content resets (sync mode)...${NC}"

  # INDEX.md: Reset to show only example feature
  if ! $DRY_RUN; then
    cat > "$DEST_DIR/docs/product/02_PRD/INDEX.md" << 'RESET_EOF'
# PRD Index

| # | Feature | Status | Date |
|---|---------|--------|------|
| 000 | [Example Feature](000-example-feature.md) | Template | — |
RESET_EOF
  fi
  log_action "RESET" "docs/product/02_PRD/INDEX.md"
  FILES_RESET=$((FILES_RESET + 1))

  # IDEAS.md: Reset to empty table
  if ! $DRY_RUN; then
    cat > "$DEST_DIR/docs/product/_backlog/01_IDEAS.md" << 'RESET_EOF'
# Ideas Backlog

| ID | Idea | ICE Score | Status | Date |
|----|------|-----------|--------|------|
RESET_EOF
  fi
  log_action "RESET" "docs/product/_backlog/01_IDEAS.md"
  FILES_RESET=$((FILES_RESET + 1))

  # USER_STORIES.md: Reset to empty table
  if ! $DRY_RUN; then
    cat > "$DEST_DIR/docs/product/_backlog/02_USER_STORIES.md" << 'RESET_EOF'
# User Stories Backlog

| ID | User Story | Priority | Status | Feature |
|----|-----------|----------|--------|---------|
RESET_EOF
  fi
  log_action "RESET" "docs/product/_backlog/02_USER_STORIES.md"
  FILES_RESET=$((FILES_RESET + 1))
fi

# --- Summary ---
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Extraction Summary${NC}"
echo "  Files copied:  $FILES_COPIED"
echo "  Files reset:   $FILES_RESET"
echo "  Files created: $FILES_CREATED"
echo "  Files skipped: $FILES_SKIPPED"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ $FILES_SKIPPED -gt 0 ]]; then
  echo -e "${YELLOW}Warning: $FILES_SKIPPED files were not found in source.${NC}"
  exit 1
fi

if $SYNC_MODE && ! $DRY_RUN; then
  echo ""
  echo -e "${YELLOW}Sync complete. Run verification suite before committing:${NC}"
  echo "  cd $DEST_DIR && grep -rn 'product-led-spec-kit\|Spec Kit\|spec-kit\|SPEC_KIT' ."
fi

echo ""
echo -e "${GREEN}Done.${NC}"
