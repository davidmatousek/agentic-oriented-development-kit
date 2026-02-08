#!/bin/bash
# scripts/check.sh - Agentic-Oriented-Development-Kit Setup Verification

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Verifying Agentic-Oriented-Development-Kit Setup${NC}"
echo ""

ERRORS=0

# Check Node.js
if command -v node &> /dev/null; then
  NODE_VERSION=$(node -v)
  echo -e "${GREEN}✓ Node.js: $NODE_VERSION${NC}"
else
  echo -e "${RED}✗ Node.js: NOT FOUND${NC}"
  ERRORS=$((ERRORS + 1))
fi

# Check Git
if command -v git &> /dev/null; then
  GIT_VERSION=$(git --version)
  echo -e "${GREEN}✓ Git: $GIT_VERSION${NC}"
else
  echo -e "${RED}✗ Git: NOT FOUND${NC}"
  ERRORS=$((ERRORS + 1))
fi

# Check Claude Code (if selected)
if command -v claude &> /dev/null; then
  echo -e "${GREEN}✓ Claude Code: installed${NC}"
else
  echo -e "${YELLOW}⚠ Claude Code: not found (optional)${NC}"
fi

# Check project structure
if [[ -f ".aod/memory/constitution.md" ]]; then
  echo -e "${GREEN}✓ Constitution: found${NC}"
else
  echo -e "${RED}✗ Constitution: NOT FOUND${NC}"
  ERRORS=$((ERRORS + 1))
fi

if [[ -f "CLAUDE.md" ]]; then
  echo -e "${GREEN}✓ CLAUDE.md: found${NC}"
else
  echo -e "${RED}✗ CLAUDE.md: NOT FOUND${NC}"
  ERRORS=$((ERRORS + 1))
fi

if [[ -d ".claude/agents" ]]; then
  AGENT_COUNT=$(ls -1 .claude/agents/*.md 2>/dev/null | wc -l | tr -d ' ')
  echo -e "${GREEN}✓ Agents: $AGENT_COUNT found${NC}"
else
  echo -e "${RED}✗ Agents directory: NOT FOUND${NC}"
  ERRORS=$((ERRORS + 1))
fi

if [[ -d ".claude/commands" ]]; then
  COMMAND_COUNT=$(ls -1 .claude/commands/*.md 2>/dev/null | wc -l | tr -d ' ')
  echo -e "${GREEN}✓ Commands: $COMMAND_COUNT found${NC}"
else
  echo -e "${RED}✗ Commands directory: NOT FOUND${NC}"
  ERRORS=$((ERRORS + 1))
fi

echo ""
if [[ $ERRORS -eq 0 ]]; then
  echo -e "${GREEN}🎉 All checks passed! Ready to build.${NC}"
  exit 0
else
  echo -e "${RED}⚠ $ERRORS issue(s) found. Please resolve before proceeding.${NC}"
  exit 1
fi
