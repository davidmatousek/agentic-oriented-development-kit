# User Stories - {{PROJECT_NAME}}

**Last Updated**: {{CURRENT_DATE}}
**Owner**: Product Manager (product-manager)
**Status**: Template - Complete after MVP launch

---

## When to Create This

**Create detailed user stories AFTER your MVP launches.**

Before MVP:
- High-level features in your PRD are sufficient
- Detailed stories emerge from real usage patterns
- You'll waste time on stories for features that change

**Pre-MVP**: Use PRD feature list → build MVP
**Post-MVP**: Break down backlog items into user stories based on actual needs

**Exception**: You can create user stories for complex MVP features that need detailed acceptance criteria.

> **AOD Lifecycle Note**: User stories generated during `/aod.discover` validation
> are stored in **GitHub Issue bodies**, not in this directory. GitHub Issues with
> `stage:*` labels are the source of truth for user stories. This directory serves
> as a reference for story format and prioritization guidance. See
> `docs/product/_backlog/BACKLOG.md` for the auto-generated backlog index.

---

## Overview

User stories describe features from the user's perspective. They follow the format:
> **As a** [persona], **I want** [capability], **so that** [benefit]

---

## User Story Template

```markdown
## US-NNN: [Story Title]

**As a** [persona from target-users.md],
**I want** [capability or action],
**so that** [business value or user benefit].

### Acceptance Criteria
- [ ] Given [context], when [action], then [expected result]
- [ ] Given [context], when [action], then [expected result]

### Related
- **Persona**: [Link to target-users.md]
- **PRD**: [Link to relevant PRD]
- **Priority**: [P0 Critical | P1 High | P2 Medium | P3 Low]

### Notes
[Additional context or constraints]
```

---

## User Story Prioritization

### P0 - Critical (Must Have)
- Blocks core user workflows
- Required for product to function
- Legal or security requirements

### P1 - High (Should Have)
- High user value
- Significant pain point resolution
- Competitive differentiation

### P2 - Medium (Nice to Have)
- Moderate user value
- Quality of life improvements
- Secondary workflows

### P3 - Low (Future)
- Low user value
- Edge cases
- Deferred for later phases

---

## Integration with PRDs

Each PRD should include relevant user stories:
- PRD functional requirements map to user stories
- User story acceptance criteria become PRD requirements
- User stories validated during spec creation

---

**Template Instructions**: Organize user stories by phase or feature area. Delete this message after creating your first user stories.

---

## Aggregated Feature Stories

> **Auto-populated by `/aod.deliver`**: When a feature is delivered, `/aod.deliver` extracts
> validated user stories from the feature's GitHub Issue body and appends them below under
> a `### Feature NNN: {feature-name}` heading. **GitHub Issues remain the source of truth**
> for user stories — this section provides a consolidated reference across delivered features.

<!-- Stories are appended below this line by /aod.deliver -->

### Feature 089: AOD Lifecycle Documentation Completeness

**PRD**: [089-aod-lifecycle-documentation-completeness](../02_PRD/089-aod-lifecycle-documentation-completeness-2026-03-12.md)
**Delivered**: 2026-03-12 | **PR**: #90 | **Tasks**: 16/16 complete | **Stories**: 7/7 passing

- **US-089-1** (P0): System Design Auto-Scaffolding from Plan - Auto-generate `docs/architecture/01_system_design/README.md` from approved plan.md content
- **US-089-2** (P0): Delivery File Change Validation - Validate that documentation agents produce actual file changes during `/aod.deliver`
- **US-089-3** (P1): User Story Export During Delivery - Extract validated user stories from GitHub Issues and append to `05_User_Stories/README.md`
- **US-089-4** (P1): Vision Placeholder Guard in Define - Warn on unresolved template placeholders in vision files during `/aod.define`
- **US-089-5** (P1): Template Placeholder Resolution in Scaffold - Auto-resolve `{{PROJECT_NAME}}` and `{{CURRENT_DATE}}` in `docs/` after `/aod.stack scaffold`
- **US-089-6** (P1): Closure Summary Relocation - Write closure summaries to `.aod/closures/` instead of `docs/architecture/`
- **US-089-7** (P2): Quarterly Planning Scaffolds - New `/aod.roadmap` and `/aod.okrs` commands for planning document scaffolding

### Feature 091: Delivery Document Generation

**PRD**: [091-delivery-document-generation](../02_PRD/091-delivery-document-generation-2026-03-13.md)
**Delivered**: 2026-03-13 | **PR**: #92 | **Tasks**: 10/10 complete | **Stories**: 3/3 passing

- **US-091-1** (P0): Automatic Delivery Document Generation - Auto-generate `specs/{NNN}-*/delivery.md` during `/aod.deliver` with all retrospective sections populated
- **US-091-2** (P0): Testing Instructions in Delivery Document - Step-by-step "How to See & Test" section with numbered verification steps mapping to acceptance criteria
- **US-091-3** (P1): Delivery Metrics Persistence - Estimated vs actual duration and variance in a consistent format across all delivery documents

### Feature 093: Relocate Governance Results

**PRD**: [093-relocate-governance-results](../02_PRD/093-relocate-governance-results-2026-03-19.md)
**Delivered**: 2026-03-19 | **PR**: #94 | **Tasks**: 16/16 complete | **Stories**: 2/2 passing

- **US-093-1** (P0): Uninterrupted Governance Reviews - Governance review results written to `.aod/results/` without triggering Claude Code permission prompts during `/aod.define`, `/aod.plan`, and `/aod.build`
- **US-093-2** (P0): Consistent Results Directory Convention - All agent/skill documentation references `.aod/results/` as the canonical results path in `_AGENT_BEST_PRACTICES.md` and `CLAUDE.md`

### Feature 100: Project Foundation Workshop

**PRD**: [100-project-foundation-workshop](../02_PRD/100-project-foundation-workshop-2026-03-28.md)
**Delivered**: 2026-03-28 | **PR**: #101 | **Tasks**: 32/32 complete | **Stories**: 6/6 passing

- **US-100-1** (P1): First-Run Vision Establishment - As a new adopter who has just run `make init`, answer guided questions about the product to get a fully populated product vision
- **US-100-2** (P1): Design Identity Selection - As a new adopter with no brand directory, be guided through selecting a visual identity so that all AI agents produce consistent, high-quality design output
- **US-100-3** (P1): Brand Token Generation - As a developer, get complete CSS custom property tokens generated from selected archetype so that UI components reference semantic design tokens
- **US-100-4** (P2): Post-Init Guidance Integration - As a new user, discover `/aod.foundation` naturally after running `make init` to establish project identity early
- **US-100-5** (P2): Idempotent Re-Run - As a returning user, re-run the workshop safely without losing existing content
- **US-100-6** (P2): Partial Workshop Execution - As a user, use `--vision` and `--design` flags to independently run only their respective part

### Feature 110: Archive Test Artifacts

**PRD**: [110-archive-test-artifacts](../02_PRD/110-archive-test-artifacts-2026-03-28.md)
**Delivered**: 2026-03-28 | **PR**: #111 | **Tasks**: 8/8 complete | **Stories**: 3/3 passing

- **US-110-1** (P0): Archive at Delivery - As a developer, have test artifacts automatically detected and archived to `specs/{NNN}-*/test-results/` during `/aod.deliver` so that test evidence is preserved alongside feature specs
- **US-110-2** (P1): Review Past Evidence - As a team member, browse archived test results in `specs/{NNN}-*/test-results/` to review historical test evidence for any delivered feature
- **US-110-3** (P1): Consistent Convention - As a contributor, follow documented testing conventions in `docs/testing/README.md` so that test artifact naming and archival is consistent across features

### Feature 113: Wire Tester Agent into aod.deliver

**PRD**: [113-wire-tester-agent-deliver](../02_PRD/113-wire-tester-agent-deliver-2026-03-28.md)
**Delivered**: 2026-03-28 | **PR**: #114 | **Tasks**: 20/20 complete | **Stories**: 5/5 passing

- **US-113-1** (P1): Automatic E2E Test Execution During Delivery - As a developer running `/aod.deliver`, have Playwright E2E tests automatically executed against acceptance criteria so the feature is validated end-to-end before marked as delivered
- **US-113-2** (P1): Soft Gate — Warn on Test Failure - As a developer, see a warning with failure details when E2E tests fail during delivery and choose whether to proceed or abort
- **US-113-3** (P1): Graceful Skip Without Test Infrastructure - As a developer on a project without Playwright configuration, have the test validation gate skip gracefully with an informational message
- **US-113-4** (P2): Hard Gate via --require-tests Flag - As a technical lead, block delivery on any E2E test failure when `--require-tests` is used, enforcing strict quality gates for critical features
- **US-113-5** (P2): Delivery Document Evidence Integration - As a developer, have tester-produced E2E results automatically feed into the delivery document's Test Evidence section with pass/fail status and gate mode

### Feature 108: Autonomous Document Stage

**PRD**: [108-autonomous-document-stage](../02_PRD/108-autonomous-document-stage-2026-03-28.md)
**Delivered**: 2026-03-28 | **PR**: #118 | **Tasks**: 37/37 complete | **Stories**: 4/4 passing

- **US-108-1** (P0): Autonomous Full Lifecycle Run - Start a feature with `/aod.run` and have all 6 stages including documentation complete autonomously, producing a single PR with code, delivery artifacts, and quality documentation
- **US-108-2** (P0): Session Resilience for Document Stage - Resume with `/aod.run --resume` after a session break during the document stage and pick up where left off without restarting the entire lifecycle
- **US-108-3** (P1): Direct Interactive Mode Preserved - Invoke `/aod.document` directly and retain the current interactive accept/reject prompts for manual human-judgment review
- **US-108-4** (P1): Stage Map Shows 6 Stages - See all 6 stages including Document in the orchestrator stage map to track progress through the complete lifecycle

### Feature 121: GitHub Issues Board Sync Fix

**PRD**: [121-github-issues-board-sync-fix](../02_PRD/121-github-issues-board-sync-fix-2026-04-04.md)
**Delivered**: 2026-04-04 | **PR**: #123 | **Tasks**: 15/15 complete | **Stories**: 3/3 passing

- **US-121-1** (P0): Agent Always Uses create-issue.sh - The `~aod-discover` SKILL.md has a top-level constraint section explicitly prohibiting direct `gh issue create` calls, ensuring every discovered idea appears on the project board automatically
- **US-121-2** (P0): Orphaned Issues Caught and Synced Automatically - Board reconciliation runs automatically during every `backlog-regenerate.sh` execution, detecting issues with `stage:*` labels missing from the project board and syncing them
- **US-121-3** (P1): All Lifecycle Scripts Maintain Board Sync - All lifecycle scripts (`create-issue.sh`, `aod_gh_update_stage`, `aod_gh_create_issue`) audited and confirmed to include board sync calls when adding or changing `stage:*` labels

### Feature 124: Fix /aod.deliver Retro Empty Bodies

**PRD**: [124-deliver-retro-empty-bodies](../02_PRD/124-deliver-retro-empty-bodies-2026-04-04.md)
**Delivered**: 2026-04-04 | **PR**: #126 | **Tasks**: 7/7 complete | **Stories**: 2/2 passing

- **US-124-1** (P1): Populated Retro Issue Body - Retrospective ideas captured during `/aod.deliver` produce GitHub Issues with structured body content (heading, ICE Score placeholders, Evidence, Metadata) instead of empty bodies
- **US-124-2** (P2): Command and Skill Definition Alignment - The `/aod.deliver` command definition includes `--body "$BODY"` in its `create-issue.sh` invocation, matching the skill definition to prevent the documented template from being silently ignored
