# Delivery Document: Feature {FEATURE_NUMBER} — {FEATURE_NAME}

**Delivery Date**: {DATE}
**Branch**: `{BRANCH_NAME}`
**PR**: #{PR_NUMBER}

---

## What Was Delivered

{Bulleted list of 3-7 key accomplishments from completed user stories and major tasks. Focus on user-visible outcomes, not implementation details.}

---

## How to See & Test

{Numbered verification steps derived from acceptance criteria in spec.md, test/run commands from plan.md, and verification steps from tasks.md. Each step should include specific commands, file paths, or UI actions.}

---

## Delivery Metrics

| Metric | Value |
|--------|-------|
| Estimated Duration | {estimated_duration} |
| Actual Duration | {actual_duration} |
| Variance | {over/under/on-target with explanation} |

---

## Surprise Log

{What surprised the team during this feature. Captured during retrospective. Use "None" if nothing unexpected occurred.}

---

## Lessons Learned

| Category | Lesson | KB Entry |
|----------|--------|----------|
| {lesson_category} | {lesson_text} | Entry {N} in INSTITUTIONAL_KNOWLEDGE.md |

---

## Feedback Loop

**New Ideas**: {count or "None"}

{For each idea:}
- {idea_description} — Issue #{issue_number} (type:retro)

---

## Source Artifacts

| Artifact | Path |
|----------|------|
| Specification | specs/{NNN}-*/spec.md |
| Implementation Plan | specs/{NNN}-*/plan.md |
| Task Breakdown | specs/{NNN}-*/tasks.md |
| PRD | {prd_path from spec.md frontmatter} |

---

## Test Evidence

### E2E Validation Gate

| Field | Value |
|-------|-------|
| Status | {e2e_validation.status: pass/fail/skipped/error} |
| Gate Mode | {e2e_validation.gate_mode: soft/hard} |
| Gate Result | {e2e_validation.gate_result: pass/warn/block/skip} |
| Tests Passed | {e2e_validation.passed}/{e2e_validation.total} |
| Tests Failed | {e2e_validation.failed} |
| Tests Skipped | {e2e_validation.skipped} |

**Failure Details**: {Comma-separated list of e2e_validation.failing_scenarios[], or "None" if all passed, or "N/A" if skipped/error}

### Archived Artifacts

| Artifact | Path | Summary |
|----------|------|---------|
| {artifact_type} | test-results/{filename} | {brief_summary} |

**Archived Artifact Metrics**:
- Tests Run: {test_count}
- Passed: {passed_count}
- Failed: {failed_count}
- Coverage: {coverage_pct or "N/A"}

**Notes**: {testing_context, e.g., "E2E validated via Playwright MCP", "Unit tests via pytest", or "No test artifacts archived for this feature"}

---

## Documentation Updates

| Domain | Agent | Files Updated | Status |
|--------|-------|---------------|--------|
| Product | product-manager | {count} | {status} |
| Architecture | architect | {count} | {status} |
| DevOps | devops | {count} | {status} |

---

## Cleanup

- [ ] Feature branch deleted
- [ ] All tasks complete
- [ ] No TBD/TODO in docs
- [ ] Committed and pushed
- [ ] GitHub Issue closed (`stage:done`)

**Feature {FEATURE_NUMBER} is now officially CLOSED.**
