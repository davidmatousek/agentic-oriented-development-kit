#!/bin/bash
# scripts/init.sh - Agentic-Oriented-Development-Kit Initialization

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Agentic-Oriented-Development-Kit - Project Initialization${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
command -v node >/dev/null 2>&1 || { echo -e "${RED}Node.js is required but not installed.${NC}" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo -e "${RED}Git is required but not installed.${NC}" >&2; exit 1; }
echo -e "${GREEN}✓ All prerequisites met${NC}"
echo ""

# Interactive prompts
read -p "Project Name: " PROJECT_NAME
read -p "Project Description: " PROJECT_DESCRIPTION
read -p "GitHub Organization: " GITHUB_ORG
read -p "GitHub Repository [$PROJECT_NAME]: " GITHUB_REPO
GITHUB_REPO=${GITHUB_REPO:-$PROJECT_NAME}

echo ""
echo "Select AI Agent:"
echo "  1) Claude Code (recommended)"
echo "  2) Cursor"
echo "  3) GitHub Copilot"
read -p "Choice [1]: " AI_CHOICE
case $AI_CHOICE in
  2) AI_AGENT="cursor" ;;
  3) AI_AGENT="copilot" ;;
  *) AI_AGENT="claude" ;;
esac

# Discover available stack packs
echo ""
echo "Select Tech Stack:"
STACK_PACKS=()
STACK_INDEX=1
for pack_dir in stacks/*/; do
  pack_name=$(basename "$pack_dir")
  # Skip if not a directory or no STACK.md
  [ -f "$pack_dir/STACK.md" ] || continue
  # Extract display name from first line (strip leading "# ")
  display_name=$(head -1 "$pack_dir/STACK.md" | sed 's/^# //')
  STACK_PACKS+=("$pack_name")
  echo "  $STACK_INDEX) $display_name ($pack_name)"
  STACK_INDEX=$((STACK_INDEX + 1))
done
echo "  $STACK_INDEX) Other / Not yet defined"
OTHER_INDEX=$STACK_INDEX

read -p "Choice [$OTHER_INDEX]: " STACK_CHOICE
STACK_CHOICE=${STACK_CHOICE:-$OTHER_INDEX}

if [ "$STACK_CHOICE" -ge 1 ] 2>/dev/null && [ "$STACK_CHOICE" -lt "$OTHER_INDEX" ] 2>/dev/null; then
  SELECTED_PACK="${STACK_PACKS[$((STACK_CHOICE - 1))]}"
  # Extract display name for TECH_STACK placeholder
  TECH_STACK=$(head -1 "stacks/$SELECTED_PACK/STACK.md" | sed 's/^# //' | sed 's/ Stack$//')
  # Load all defaults from pack (database, auth, vector, cloud provider, etc.)
  if [ -f "stacks/$SELECTED_PACK/defaults.env" ]; then
    source "stacks/$SELECTED_PACK/defaults.env"
    echo -e "  ${GREEN}✓ Loaded defaults from $SELECTED_PACK pack${NC}"
  fi
else
  # Custom stack — ask the essentials only
  read -p "Tech Stack (e.g., Python + FastAPI, Go + Gin): " TECH_STACK
  TECH_STACK=${TECH_STACK:-"Not yet defined"}
  read -p "Database (e.g., PostgreSQL, MySQL, SQLite): " TECH_STACK_DATABASE
  TECH_STACK_DATABASE=${TECH_STACK_DATABASE:-"Not yet defined"}
  read -p "Cloud Provider (e.g., Vercel, AWS, GCP) [optional]: " CLOUD_PROVIDER
fi

# Fill any remaining placeholders not set by pack or user
TECH_STACK_DATABASE=${TECH_STACK_DATABASE:-"Not yet defined"}
TECH_STACK_VECTOR=${TECH_STACK_VECTOR:-"Not yet defined"}
TECH_STACK_AUTH=${TECH_STACK_AUTH:-"Not yet defined"}
CLOUD_PROVIDER=${CLOUD_PROVIDER:-"Not yet defined"}
RATIFICATION_DATE=$(date +%Y-%m-%d)

# Confirmation
echo ""
echo -e "${BLUE}Configuration Summary:${NC}"
echo "  Project Name:    $PROJECT_NAME"
echo "  Description:     $PROJECT_DESCRIPTION"
echo "  GitHub:          $GITHUB_ORG/$GITHUB_REPO"
echo "  AI Agent:        $AI_AGENT"
if [ -n "$SELECTED_PACK" ]; then
  echo "  Stack Pack:      $SELECTED_PACK ($TECH_STACK)"
  echo "  Database:        $TECH_STACK_DATABASE"
  echo "  Auth:            $TECH_STACK_AUTH"
  echo "  Cloud Provider:  $CLOUD_PROVIDER"
else
  echo "  Tech Stack:      $TECH_STACK"
  echo "  Database:        $TECH_STACK_DATABASE"
  echo "  Cloud Provider:  $CLOUD_PROVIDER"
fi
echo ""
read -p "Proceed with initialization? [Y/n]: " CONFIRM
if [[ $CONFIRM =~ ^[Nn]$ ]]; then
  echo "Initialization cancelled."
  exit 0
fi

echo ""
echo -e "${YELLOW}🔄 Replacing template variables...${NC}"

# Function to replace in files (cross-platform)
replace_in_files() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    find . -type f \
      -not -path "./.git/*" \
      -not -path "./node_modules/*" \
      -not -name "*.png" -not -name "*.jpg" -not -name "*.ico" \
      -exec sed -i '' \
        -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
        -e "s/{{PROJECT_DESCRIPTION}}/$PROJECT_DESCRIPTION/g" \
        -e "s/{{GITHUB_ORG}}/$GITHUB_ORG/g" \
        -e "s/{{GITHUB_REPO}}/$GITHUB_REPO/g" \
        -e "s/{{AI_AGENT}}/$AI_AGENT/g" \
        -e "s/{{TECH_STACK}}/$TECH_STACK/g" \
        -e "s/{{TECH_STACK_DATABASE}}/$TECH_STACK_DATABASE/g" \
        -e "s/{{TECH_STACK_VECTOR}}/$TECH_STACK_VECTOR/g" \
        -e "s/{{TECH_STACK_AUTH}}/$TECH_STACK_AUTH/g" \
        -e "s/{{RATIFICATION_DATE}}/$RATIFICATION_DATE/g" \
        -e "s/{{CLOUD_PROVIDER}}/$CLOUD_PROVIDER/g" \
        {} +
  else
    # Linux
    find . -type f \
      -not -path "./.git/*" \
      -not -path "./node_modules/*" \
      -not -name "*.png" -not -name "*.jpg" -not -name "*.ico" \
      -exec sed -i \
        -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
        -e "s/{{PROJECT_DESCRIPTION}}/$PROJECT_DESCRIPTION/g" \
        -e "s/{{GITHUB_ORG}}/$GITHUB_ORG/g" \
        -e "s/{{GITHUB_REPO}}/$GITHUB_REPO/g" \
        -e "s/{{AI_AGENT}}/$AI_AGENT/g" \
        -e "s/{{TECH_STACK}}/$TECH_STACK/g" \
        -e "s/{{TECH_STACK_DATABASE}}/$TECH_STACK_DATABASE/g" \
        -e "s/{{TECH_STACK_VECTOR}}/$TECH_STACK_VECTOR/g" \
        -e "s/{{TECH_STACK_AUTH}}/$TECH_STACK_AUTH/g" \
        -e "s/{{RATIFICATION_DATE}}/$RATIFICATION_DATE/g" \
        -e "s/{{CLOUD_PROVIDER}}/$CLOUD_PROVIDER/g" \
        {} +
  fi
}

replace_in_files

echo -e "${GREEN}✓ Template variables replaced${NC}"

# Clean up instructional text from constitution (contains literal {{ examples)
CONSTITUTION=".aod/memory/constitution.md"
if [ -f "$CONSTITUTION" ]; then
  echo -e "${YELLOW}🔄 Cleaning up constitution template instructions...${NC}"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # Remove HTML comment block at top (lines starting with <!-- through -->)
    sed -i '' '/^<!--$/,/^-->$/d' "$CONSTITUTION"
    # Remove "Template Instructions" section at bottom (## Template Instructions to EOF)
    sed -i '' '/^## Template Instructions$/,$d' "$CONSTITUTION"
  else
    sed -i '/^<!--$/,/^-->$/d' "$CONSTITUTION"
    sed -i '/^## Template Instructions$/,$d' "$CONSTITUTION"
  fi
  echo -e "${GREEN}✓ Constitution template instructions removed${NC}"
fi

# Remove this init script (one-time use)
rm -f scripts/init.sh

echo ""
echo -e "${GREEN}🎉 Project initialized successfully!${NC}"
echo ""
echo -e "${BLUE}📝 Next steps:${NC}"
echo "  1. Activate a stack pack (optional):"
echo "     /aod.stack list                    → See available packs"
echo "     /aod.stack use nextjs-supabase     → Activate conventions"
echo "     /aod.stack scaffold                → Scaffold project files"
echo ""
echo "  2. Review your product vision:"
echo "     docs/product/01_Product_Vision/README.md"
echo ""
echo "  3. Create your first PRD:"
echo "     /aod.define <your-first-feature>"
echo ""
echo "  4. Follow the AOD workflow:"
echo "     /aod.spec          → Define requirements"
echo "     /aod.project-plan  → Create technical plan"
echo "     /aod.tasks         → Generate task list"
echo "     /aod.build         → Execute implementation"
echo ""
echo -e "${BLUE}📚 Key Documentation:${NC}"
echo "  - Getting Started:  docs/GETTING_STARTED.md"
echo "  - SDLC Triad:       docs/AOD_TRIAD.md"
echo "  - Constitution:     .aod/memory/constitution.md"
echo "  - Definition of Done: docs/standards/DEFINITION_OF_DONE.md"
echo ""
echo -e "${GREEN}Happy building! 🏗️${NC}"
