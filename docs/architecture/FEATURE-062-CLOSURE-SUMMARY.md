# Architecture Documentation Update - Feature 062 Closure

**Date**: 2026-02-28
**Feature**: 062 - Auto-Create GitHub Projects Board During Init
**Merge Commit**: 3fb72fe
**Tasks Completed**: 13

---

## Summary

Feature 062 integrates GitHub Projects board creation into `scripts/init.sh` as a non-blocking step during `make init`. The implementation adds ~54 lines to `init.sh`, wiring the existing `aod_gh_setup_board()` function from `.aod/scripts/bash/github-lifecycle.sh` with `gh` CLI detection, auth/scope validation, subshell isolation, and 5-path status reporting (created, already_exists, skipped_no_gh, skipped_no_scope, error). The feature is purely additive with graceful degradation on all failure paths.

---

## Documentation Review & Updates

### 1. Tech Stack Review (/docs/architecture/00_Tech_Stack/README.md)

**Status**: UPDATED

**Review Findings**:
- No new external dependencies added (reuses existing `gh` CLI and `aod_gh_setup_board()`)
- No new scripts created (modifies existing `scripts/init.sh`)
- No new function libraries added to `.aod/scripts/bash/`
- Bash 3.2 compatible (all changes use POSIX-safe constructs)
- No changes needed to frontend, backend, database, or infrastructure sections

**Changes Made**:
- Updated `gh` CLI entry in "CLI Dependencies" table to include `scripts/init.sh (optional)` as a consumer and expanded purpose description to mention Projects board creation during init
- Updated graceful degradation note to document init.sh's 5-path status reporting behavior

**File**: `/Users/david/Projects/product-led-spec-kit/docs/architecture/00_Tech_Stack/README.md`

---

### 2. Design Patterns Review (/docs/architecture/03_patterns/README.md)

**Status**: UPDATED

**Review Findings**:
- Feature 062 introduces a reusable pattern: "Subshell Isolation for Strict Shell Options"
- The pattern addresses the interaction between `set -e` in parent scripts and sourced function libraries that may fail
- This is distinct from the existing "Function Library Sourcing" pattern (which covers the `source` + call syntax) and from "Graceful CLI Degradation" (which covers the skip-if-missing strategy)
- The subshell isolation technique (`bash -c '...'` vs `$()` or `( )`) is non-obvious and has correctness implications worth documenting

**Changes Made**:

1. **Pattern Index** (Shell Script Patterns section):
   - Added link: `[Subshell Isolation for Strict Shell Options](#pattern-subshell-isolation-for-strict-shell-options)`

2. **Detailed Pattern Documentation**:
   - New pattern section documenting:
     - **Problem**: `set -e` propagates into sourced files, killing the parent before `|| true` can execute
     - **Solution**: Use `bash -c '...'` to spawn a child process with a clean shell environment
     - **Example**: Correct vs incorrect approaches from `scripts/init.sh`
     - **When to Use**: Calling function libraries from `set -e` scripts, isolating non-critical operations
     - **When NOT to Use**: Scripts without `set -e`, operations needing shared variable scope
     - **Related Patterns**: Links to Function Library Sourcing, Graceful CLI Degradation, Non-Fatal Observability Wrapper

**File**: `/Users/david/Projects/product-led-spec-kit/docs/architecture/03_patterns/README.md`

---

### 3. ADR Review

**Status**: NO ADR REQUIRED

**Rationale**:
- Feature 062 is a wiring/integration feature, not an architectural decision with competing alternatives
- The subshell isolation technique is an implementation detail, documented as a pattern rather than an ADR
- No new technology, integration patterns, or system-wide design changes introduced
- No trade-offs requiring formal decision documentation (all paths lead to graceful degradation)
- Reuses existing `aod_gh_setup_board()` without modification

**Guidelines Applied**:
- Per `docs/architecture/02_ADRs/ADR-000-template.md`, ADRs are for "significant technical decisions with context and trade-offs"
- Integration wiring and pattern application are documented in patterns/ instead

---

### 4. System Design & Deployment Review

**Status**: NO CHANGES REQUIRED

**System Design** (`docs/architecture/01_system_design/`):
- No new components, services, or data flows introduced
- Feature wires an existing function into an existing script -- no architectural changes
- No system diagrams require updates

**Deployment Environments** (`docs/architecture/04_deployment_environments/`):
- No new environment variables or configuration required
- No infrastructure changes
- `scripts/init.sh` is a one-time setup script deleted after first run -- no deployment impact
- Board creation uses existing `gh` CLI authentication, no new credentials needed

---

## Files Updated

| File | Changes |
|------|---------|
| `/docs/architecture/00_Tech_Stack/README.md` | Updated `gh` CLI entry to include `scripts/init.sh` as consumer; expanded graceful degradation note |
| `/docs/architecture/03_patterns/README.md` | Added "Subshell Isolation for Strict Shell Options" pattern (index link + full documentation) |
| `/docs/architecture/FEATURE-062-CLOSURE-SUMMARY.md` | This closure summary document |
| **Total Architecture Updates** | 2 existing files updated, 1 new pattern documented, 0 ADRs |

---

## Design Decisions Documented

### 1. Subshell Isolation via `bash -c` (vs. Direct Source)

**Decision**: Use `bash -c 'source lib.sh && func'` instead of direct `source` + call

**Rationale**:
- `scripts/init.sh` uses `set -e` for its own strict error handling
- `aod_gh_setup_board()` may fail on network errors, missing OAuth scope, or API issues
- `bash -c` creates a child process that does NOT inherit `set -e` from the parent
- This allows `|| true` to work correctly at the parent level
- Documented as a reusable pattern for future `set -e` scripts

### 2. 5-Path Status Reporting (vs. Binary Success/Fail)

**Decision**: Capture and display 5 distinct board status outcomes

**Rationale**:
- Each failure path has different remediation guidance (install gh, refresh scope, retry manually)
- Binary success/fail would lose actionable diagnostic information
- Adopters need specific commands to resolve their specific situation
- Follows the existing "Graceful CLI Degradation" pattern with enhanced user feedback

### 3. Post-Local-Operations Placement (vs. Early in Init)

**Decision**: Board creation runs after all local file operations (template substitution, vision seeding)

**Rationale**:
- Local operations are deterministic and fast -- they should never be blocked by a network call
- Board creation is network-dependent and optional -- placing it last ensures local setup always completes
- Matches the principle that non-critical operations should not gate critical ones

---

## Backward Compatibility

All updates are purely **additive**:
- New pattern documented (no modifications to existing patterns)
- Tech stack entry expanded (no modifications to existing CLI dependency behavior)
- No version bumps, migrations, or breaking changes
- Existing scripts and function libraries unaffected

---

## Validation Checklist

Per `/docs/DOCS_TO_UPDATE_AFTER_NEW_FEATURE.md` Section 2 (Architecture):

- [x] **Tech Stack** - Reviewed and updated (expanded `gh` CLI entry for init.sh usage)
- [x] **System Design** - Reviewed (no changes needed; no new components or data flows)
- [x] **ADRs** - Reviewed (no ADR needed; integration feature, not architectural decision)
- [x] **Patterns** - Updated (new "Subshell Isolation for Strict Shell Options" pattern documented)
- [x] **Deployment Environments** - Reviewed (no changes needed; one-time init script, no infrastructure impact)

---

## Sign-Off

**Documentation Updates Complete**: Yes

**Reviewed By**: Architect (Feature 062 closure)

**Date**: 2026-02-28

**Notes**: Minimal architecture changes for a wiring/integration feature. The subshell isolation pattern is the primary documentation contribution -- it captures a non-obvious Bash behavior that will apply to any future `set -e` script calling function libraries. No technical debt or follow-up ADRs required.

---

**Related Documentation**:
- Feature Spec: `/specs/062-prd-062-auto/spec.md`
- Implementation Plan: `/specs/062-prd-062-auto/plan.md`
- Task List: `/specs/062-prd-062-auto/tasks.md`
- PRD: `/docs/product/02_PRD/062-auto-create-github-projects-board-2026-02-28.md`
- Implementation: `/scripts/init.sh` (lines 188-262)
