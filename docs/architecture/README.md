# Architecture Documentation - {{PROJECT_NAME}}

**Last Updated**: {{CURRENT_DATE}}
**Owner**: Architect
**Status**: Template

---

## Overview

This directory contains all technical architecture documentation for {{PROJECT_NAME}}.

---

## Structure

### 00_Tech_Stack/
Technology choices and justifications
- `README.md` - Tech stack overview with {{TEMPLATE_VARIABLES}}

### 01_system_design/
High-level system design and component diagrams
- `README.md` - System architecture overview
- Component interaction diagrams
- Data flow diagrams

### 02_ADRs/ (Architecture Decision Records)
Significant technical decisions with context and trade-offs
- `ADR-000-template.md` - ADR template and example
- `ADR-NNN-decision-title.md` - Individual ADRs

### 03_patterns/
Reusable design patterns and best practices
- `README.md` - Pattern catalog
- Pattern documentation by category

### 04_deployment_environments/
Environment-specific configurations and documentation
- `README.md` - Environment overview
- `development.md` - Local development setup
- `staging.md` - Staging environment
- `production.md` - Production environment

---

## Key Principles

1. **Document Decisions**: Use ADRs for significant technical choices
2. **Keep Current**: Update docs alongside code changes
3. **Template Variables**: Use `{{TEMPLATE_VARIABLES}}` for project-specific values
4. **Version Control**: All architecture docs in git

---

## Quick Links

- [Tech Stack](00_Tech_Stack/README.md)
- [System Design](01_system_design/README.md)
- [ADRs](02_ADRs/ADR-000-template.md)
- [Patterns](03_patterns/README.md)
- [Environments](04_deployment_environments/README.md)

---

**Maintained By**: Architect
