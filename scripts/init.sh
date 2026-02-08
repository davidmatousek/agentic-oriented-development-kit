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

read -p "Primary Tech Stack (e.g., Node.js, Python, Go): " TECH_STACK
TECH_STACK=${TECH_STACK:-"Not yet defined"}

read -p "Cloud Provider (e.g., Vercel, AWS, GCP) [optional]: " CLOUD_PROVIDER
CLOUD_PROVIDER=${CLOUD_PROVIDER:-"Not yet defined"}

# Confirmation
echo ""
echo -e "${BLUE}Configuration Summary:${NC}"
echo "  Project Name:    $PROJECT_NAME"
echo "  Description:     $PROJECT_DESCRIPTION"
echo "  GitHub:          $GITHUB_ORG/$GITHUB_REPO"
echo "  AI Agent:        $AI_AGENT"
echo "  Tech Stack:      $TECH_STACK"
echo "  Cloud Provider:  $CLOUD_PROVIDER"
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
        -e "s/{{CLOUD_PROVIDER}}/$CLOUD_PROVIDER/g" \
        {} +
  fi
}

replace_in_files

echo -e "${GREEN}✓ Template variables replaced${NC}"

# Remove this init script (one-time use)
rm -f scripts/init.sh

echo ""
echo -e "${GREEN}🎉 Project initialized successfully!${NC}"
echo ""
echo -e "${BLUE}📝 Next steps:${NC}"
echo "  1. Review your product vision:"
echo "     docs/product/01_Product_Vision/README.md"
echo ""
echo "  2. Create your first PRD:"
echo "     /triad.prd <your-first-feature>"
echo ""
echo "  3. Follow the Triad workflow:"
echo "     /triad.specify  → Define requirements"
echo "     /triad.plan     → Create technical plan"
echo "     /triad.tasks    → Generate task list"
echo "     /triad.implement → Execute implementation"
echo ""
echo -e "${BLUE}📚 Key Documentation:${NC}"
echo "  - Getting Started:  docs/GETTING_STARTED.md"
echo "  - SDLC Triad:       docs/AOD_TRIAD.md"
echo "  - Constitution:     .aod/memory/constitution.md"
echo "  - Definition of Done: docs/standards/DEFINITION_OF_DONE.md"
echo ""
echo -e "${GREEN}Happy building! 🏗️${NC}"
