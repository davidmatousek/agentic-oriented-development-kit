# Architecture Documentation Update - Feature 065 Closure

**Date**: 2026-03-03
**Feature**: 065 - Add /simplify Command to AOD Process
**PR**: #66
**Tasks Completed**: 10

---

## Summary

Feature 065 integrates the Claude Code built-in `/simplify` skill into `/aod.build` as Step 6 (Code Simplification). The step runs by default after all implementation tasks complete, with `--no-simplify` as an opt-out flag for contexts where simplification is inappropriate (methodology-only repos, CI pipelines, time-sensitive builds). No new external dependencies are introduced -- the feature reuses the existing Claude Code built-in `/simplify` skill and `git` CLI. All changes are Markdown command file modifications only.

---

## Documentation Review & Updates

### 1. Architecture README (/docs/architecture/README.md)

**Status**: UPDATED

**Changes Made**:
- Added ADR-008 to the ADRs index listing

**File**: `/Users/david/Projects/product-led-spec-kit/docs/architecture/README.md`

---

### 2. Tech Stack Review (/docs/architecture/00_Tech_Stack/README.md)

**Status**: NO CHANGES REQUIRED

**Review Findings**:
- No new external dependencies added
- `/simplify` is a Claude Code built-in skill -- no installation, no `brew install`, no CLI dependency entry needed
- `git` CLI (already a dependency for all `aod.build` git operations) is unchanged
- No new scripts created (command file modifications only)
- No new function libraries added to `.aod/scripts/bash/`
- No Bash compatibility concerns (no shell scripts modified)
- No changes needed to frontend, backend, database, infrastructure, or AOD Kit internal tooling sections

**Rationale**: Feature 065 is a pure command-file integration. The simplification capability comes from the platform (Claude Code), not from a new library or tool that must be tracked in the tech stack.

---

### 3. Design Patterns (/docs/architecture/03_patterns/README.md)

**Status**: UPDATED

**Review Findings**:
Feature 065 introduces two reusable patterns:

1. **Built-in Skill Invocation from a Command**: The pattern of wiring a platform built-in skill (not a custom `.claude/skills/` file) into a command workflow step with a parenthetical description, gated behind an opt-out flag. This is distinct from "On-Demand Reference File Segmentation" (which addresses custom skill files) and all existing patterns.

**Changes Made**:

1. **Pattern Index** (Command Patterns section):
   - Added link: `[Built-in Skill Invocation from a Command](#pattern-built-in-skill-invocation-from-a-command)`

2. **Detailed Pattern Documentation**:
   - New pattern section documenting:
     - **Problem**: Built-in skills are invisible in command files; no path to reference; blanket invocation lacks an escape hatch
     - **Solution**: Reference by slash-command name with description; gate behind `--no-X` opt-out flag; flag declared at top of file and in CLAUDE.md
     - **Example**: Pseudocode from `aod.build.md` and CLAUDE.md command reference
     - **When to Use**: Platform built-ins appropriate by default but not universally
     - **When NOT to Use**: Always-appropriate built-ins (invoke unconditionally), rarely-appropriate (use `--with-X` opt-in instead), custom skills
     - **Related Patterns**: Links to On-Demand Reference File Segmentation, Read-Only Dry-Run Preview

**File**: `/Users/david/Projects/product-led-spec-kit/docs/architecture/03_patterns/README.md`

---

### 4. ADR Review (/docs/architecture/02_ADRs/)

**Status**: NEW ADR CREATED

**Review Findings**:
The decision to make `/simplify` default-on with an `--no-simplify` opt-out (rather than opt-in, mandatory, or config-file-driven) is an architectural decision with:
- Competing alternatives with genuine trade-offs (opt-in vs. opt-out vs. mandatory vs. config file)
- Future applicability: other quality gate steps may face the same opt-in/opt-out question
- Documented rationale worth preserving (negative flags, quality-gate philosophy, CI compatibility)

**ADR Created**: `ADR-008-opt-out-flag-for-default-quality-gates.md`

**Decision**: Default-on with `--no-simplify` opt-out flag. Rationale: quality gates should be the norm; opt-in sacrifices the quality intent; mandatory blocks legitimate skip scenarios (CI, methodology-only repos); config file is over-engineered for a single boolean.

**File**: `/Users/david/Projects/product-led-spec-kit/docs/architecture/02_ADRs/ADR-008-opt-out-flag-for-default-quality-gates.md`

---

### 5. System Design & Deployment Review

**Status**: NO CHANGES REQUIRED

**System Design** (`docs/architecture/01_system_design/`):
- No new components, services, or data flows introduced
- Feature modifies a command file -- no architectural topology changes
- No system diagrams require updates

**Deployment Environments** (`docs/architecture/04_deployment_environments/`):
- No new environment variables or configuration required
- No infrastructure changes
- The built-in `/simplify` skill requires no deployment configuration -- it is a platform capability

---

### 6. CLAUDE.md and Commands Rule Verification

**Status**: ALREADY UP TO DATE -- NO ACTION REQUIRED

**Verification**:
- `CLAUDE.md` line 44: `/aod.define` → `/aod.spec` → `/aod.project-plan` → `/aod.tasks` → `/aod.build` (Triad workflow listing, no flag shown here -- correct, this is the flow overview)
- `.claude/rules/commands.md` line 23: `/aod.build [--no-simplify]  # Execute with auto architect checkpoints; --no-simplify skips code simplification step`

The commands rule file already reflects the `--no-simplify` flag per tasks.md T008. No further updates needed.

---

## Files Updated

| File | Changes |
|------|---------|
| `/docs/architecture/README.md` | Added ADR-008 to ADRs index |
| `/docs/architecture/03_patterns/README.md` | Added "Built-in Skill Invocation from a Command" pattern (index link + full documentation) |
| `/docs/architecture/02_ADRs/ADR-008-opt-out-flag-for-default-quality-gates.md` | New ADR documenting default-on + opt-out flag decision |
| `/docs/architecture/FEATURE-065-CLOSURE-SUMMARY.md` | This closure summary document |
| **Total Architecture Updates** | 2 existing files updated, 1 new ADR, 1 new pattern documented |

---

## Design Decisions Documented

### 1. Built-in Skill Wired as Default-On Step (vs. Opt-in or Mandatory)

**Decision**: `/simplify` is default-on with `--no-simplify` opt-out
**Rationale**: Quality gates should be the norm; opt-in sacrifices quality intent; mandatory blocks CI and methodology-only repos. See ADR-008 for full alternatives analysis.

### 2. Negative Flag Convention (`--no-simplify` vs. `--simplify`)

**Decision**: Use negative (`--no-X`) flags for default-on steps
**Rationale**: Negative flags communicate "this is the default path." Positive flags signal optionality. Using `--no-simplify` correctly sets user expectations. Consistent with existing `--dry-run` (Feature 027) flag convention.

### 3. No New Dependencies (vs. External Simplification Tool)

**Decision**: Use Claude Code built-in `/simplify`, not an external linter or formatter
**Rationale**: No installation burden on adopters, no Bash 3.2 compatibility risk, no version pinning, no new CLI dependency entry. The built-in understands context and code intent in ways a static formatter cannot.

---

## Backward Compatibility

All updates are purely **additive**:
- New pattern documented (no modifications to existing patterns)
- New ADR created (no modifications to existing ADRs)
- Architecture README index entry added
- `/aod.build` without `--no-simplify` behaves the same as before for users who want simplification; existing invocations without the flag now gain Step 6
- Users who need to skip: add `--no-simplify` to their invocation

**Breaking change assessment**: None. The new default step (simplification) is non-destructive and reversible via `git` if its output is undesirable.

---

## Validation Checklist

Per `/docs/DOCS_TO_UPDATE_AFTER_NEW_FEATURE.md` Section 2 (Architecture):

- [x] **Tech Stack** - Reviewed (no changes needed; no new dependencies)
- [x] **System Design** - Reviewed (no changes needed; no new components or data flows)
- [x] **ADRs** - Created ADR-008 (default-on + opt-out flag decision with alternatives)
- [x] **Patterns** - Updated (new "Built-in Skill Invocation from a Command" pattern)
- [x] **Deployment Environments** - Reviewed (no changes needed; no infrastructure impact)
- [x] **CLAUDE.md / commands.md** - Verified already up to date (T008 was completed)

---

## Sign-Off

**Documentation Updates Complete**: Yes

**Reviewed By**: Architect (Feature 065 closure)

**Date**: 2026-03-03

**Notes**: Minimal but meaningful architecture updates for a command-file integration feature. The primary documentation contributions are: (1) the ADR capturing the opt-out flag design decision, which will guide future quality gate step additions; and (2) the built-in skill invocation pattern, which generalizes the approach for future built-in integrations. No technical debt or follow-up ADRs required.

---

**Related Documentation**:
- Feature Spec: `/specs/065-add-simplify-command/spec.md`
- Implementation Plan: `/specs/065-add-simplify-command/plan.md`
- Task List: `/specs/065-add-simplify-command/tasks.md`
- PRD: `/docs/product/02_PRD/065-add-simplify-command-to-aod-process-2026-03-02.md`
- Command file modified: `.claude/commands/aod.build.md`
