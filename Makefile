# Agentic-Oriented-Development-Kit - Common Commands

.PHONY: help init check update update-bootstrap spec plan tasks analyze review-spec review-plan

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

init: ## Initialize project (first-time setup)
	@./scripts/init.sh

check: ## Verify setup and prerequisites
	@./scripts/check.sh

update: ## Apply upstream template updates (upstream → downstream); pass flags via ARGS='...'
	@./scripts/update.sh $(ARGS)

update-bootstrap: ## Bootstrap pre-F129 adopter — writes .aod/aod-kit-version + .aod/personalization.env (Feature 134). YES=1 for non-interactive; pass extra flags via ARGS='...'
	@./scripts/update.sh --bootstrap $(if $(YES),--yes,) $(ARGS)

# Triad Workflow shortcuts
spec: ## Run /aod.spec
	@echo "Use /aod.spec in Claude Code (or /aod.plan router)"

plan: ## Run /aod.plan
	@echo "Use /aod.plan in Claude Code (router — auto-advances spec -> project-plan -> tasks)"

tasks: ## Run /aod.tasks
	@echo "Use /aod.tasks in Claude Code (or /aod.plan router)"

analyze: ## Run /aod.analyze
	@echo "Use /aod.analyze in Claude Code"

# Governance shortcuts
review-spec: ## Review spec.md with PM
	@echo "Use product-manager agent or /aod.spec for auto-review"

review-plan: ## Review plan.md with PM + Architect
	@echo "Use product-manager + architect agents or /aod.project-plan for auto-review"

# Extract-coverage validation (PRD 128)
extract-check: ## Validate extract-classification.txt is in sync with MANIFEST_DIRS
	@bash scripts/check-extract-coverage.sh

extract-classify: ## Regenerate extract-classification.txt snapshot (maintainer acknowledgement)
	@bash scripts/check-extract-coverage.sh --regenerate > scripts/extract-classification.txt
