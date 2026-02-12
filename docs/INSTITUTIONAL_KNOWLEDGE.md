# Institutional Knowledge - {{PROJECT_NAME}}

**Project**: {{PROJECT_NAME}} - {{PROJECT_DESCRIPTION}}
**Purpose**: Capture learnings, patterns, and solutions to prevent repeated mistakes
**Created**: {{PROJECT_START_DATE}}
**Last Updated**: {{CURRENT_DATE}}

**Entry Count**: 18 / 20 (KB System Upgrade triggers at 20)
**Last Review**: {{CURRENT_DATE}}
**Status**: ✅ Manual mode (file-based)

---

## Overview

This file stores institutional knowledge for {{PROJECT_NAME}} development. It's used by:
- `kb-create` skill - Add new learnings
- `kb-query` skill - Search existing patterns
- `root-cause-analyzer` skill - Document root causes

### When to Upgrade to KB System

**Trigger Conditions** (upgrade when ANY is true):
- Entry count reaches **20**
- File size exceeds **2,000 lines**
- Search takes **>5 minutes** (currently <5 seconds with Cmd+F)
- Major project milestone complete

**Current Status**: Manual file working well. No upgrade needed yet.
**Next Review**: When entry count reaches 15

---

## How to Add Entries

Use the `kb-create` skill or manually add entries following this template:

```markdown
### Entry N: [Short Title]

## [Category] - [One-line Description]

**Date**: YYYY-MM-DD
**Context**: [What were you working on when you encountered this?]

**Problem**:
[Describe the issue, challenge, or question that arose]

**Solution**:
[Document the solution, approach, or answer]
```markdown
[Code examples if applicable]
```

**Why This Matters**:
[Explain the impact and importance]

**Tags**: #tag1 #tag2 #category

### Alternative Approaches Rejected:
[If you tried other solutions first, document why they didn't work]

### Related Files:
[List relevant file paths]

---
```

---

## Knowledge Entries

### Entry 1: Example - Database Schema Migration Best Practice

## [Architecture] - Safe Database Migration Pattern

**Date**: 2025-01-15
**Context**: During Phase 1 implementation, we needed to add a new column to an existing production table without downtime.

**Problem**:
- Adding columns with `NOT NULL` constraints causes deployment failures
- Existing production data doesn't have values for new required fields
- Backfilling data during migration causes long table locks

**Solution**:
Use a three-phase migration approach:

Phase 1: Add column as nullable
```sql
ALTER TABLE users ADD COLUMN email VARCHAR(255);
```

Phase 2: Backfill data
```sql
UPDATE users SET email = legacy_email WHERE email IS NULL;
```

Phase 3: Add constraint after backfill complete
```sql
ALTER TABLE users ALTER COLUMN email SET NOT NULL;
```

**Why This Matters**:
- Prevents production outages during schema changes
- Allows gradual data migration without table locks
- Maintains zero-downtime deployment capability

**Tags**: #database #migration #best-practice #production

### Alternative Approaches Rejected:
Adding `NOT NULL` constraint immediately:
```sql
ALTER TABLE users ADD COLUMN email VARCHAR(255) NOT NULL;
```
**Rejected because**: Fails for existing rows without data.

### Related Files:
- `backend/prisma/migrations/` - Migration files
- `docs/architecture/patterns/zero-downtime-migrations.md` - Full pattern documentation

---

### Entry 2: Example - API Rate Limiting Implementation

## [Performance] - Rate Limiting with Sliding Window Algorithm

**Date**: 2025-02-01
**Context**: Implementing API rate limiting to prevent abuse and ensure fair usage across all clients.

**Problem**:
- Fixed window rate limiting allows bursts at window boundaries (e.g., 100 requests at 11:59:59, 100 more at 12:00:01)
- Need to enforce smooth request distribution
- Must track rate limits across multiple server instances

**Solution**:
Implement sliding window rate limiter using Redis:

```typescript
async function checkRateLimit(userId: string): Promise<boolean> {
  const key = `ratelimit:${userId}`;
  const now = Date.now();
  const windowMs = 60000; // 1 minute
  const maxRequests = 100;

  // Remove old entries outside window
  await redis.zremrangebyscore(key, 0, now - windowMs);

  // Count requests in current window
  const count = await redis.zcard(key);

  if (count >= maxRequests) {
    return false; // Rate limit exceeded
  }

  // Add current request
  await redis.zadd(key, now, `${now}-${Math.random()}`);
  await redis.expire(key, Math.ceil(windowMs / 1000));

  return true; // Within limit
}
```

**Why This Matters**:
- Prevents burst traffic from overwhelming the system
- Provides fair usage across all time windows
- Scales across multiple server instances via Redis
- Reduces abuse and improves service reliability

**Tags**: #api #rate-limiting #redis #performance #scaling

### Alternative Approaches Rejected:
1. **Fixed window counters**: Allows boundary bursts (2x limit possible)
2. **In-memory counters**: Doesn't work across multiple servers
3. **Token bucket**: More complex to implement, similar results

### Related Files:
- `backend/src/middleware/rate-limiter.ts` - Implementation
- `docs/architecture/patterns/api-rate-limiting.md` - Design documentation

---

### Entry 3: Example - Root Cause Analysis - Deployment Failure

## [DevOps] - Environment Variable Validation Root Cause

**Date**: 2025-02-15
**Context**: Production deployment failed with "DATABASE_URL is undefined" error after successful staging deployment.

**Problem**:
Application crashed on startup in production but worked perfectly in staging. Error logs showed missing environment variable despite being configured in deployment platform.

**Root Cause Analysis (5 Whys)**:

1. **Why did production crash?** → DATABASE_URL environment variable was undefined
2. **Why was it undefined?** → Variable was set in wrong environment scope (Preview instead of Production)
3. **Why was it set in wrong scope?** → Deployment platform UI doesn't show clear visual difference between scopes
4. **Why didn't we catch this in testing?** → Pre-deployment checklist didn't include environment variable verification
5. **Why was verification not in checklist?** → Assumed deployment platform would prevent scope misconfigurations

**Solution Implemented**:

1. **Immediate Fix**: Set DATABASE_URL in Production scope
2. **Process Improvement**: Added environment variable verification to deployment checklist:
   ```bash
   # Verify production environment variables
   vercel env ls --scope production | grep DATABASE_URL
   vercel env ls --scope production | grep JWT_SECRET
   ```
3. **Prevention**: Created automated pre-deployment script that validates all required vars exist in target environment
4. **Documentation**: Updated deployment runbook with clear screenshots of scope selection

**Why This Matters**:
- Prevents production outages from configuration errors
- Reduces MTTR (Mean Time To Recovery) from hours to minutes
- Establishes pattern for catching configuration issues before deployment

**Tags**: #devops #deployment #environment-variables #root-cause-analysis #production

### Related Documents:
- `docs/devops/03_Production/pre-deployment-checklist.md` - Updated checklist
- `scripts/validate-env-vars.sh` - Automated validation script

---

### Entry 4: Feature 010 — AOD Lifecycle Formalization Retrospective

## [Process] - Large-Scale Namespace Unification with AI-Assisted Development

**Date**: 2026-02-09
**Context**: Feature 010 formalized the AOD Lifecycle (5 stages, governance tiers, unified `/aod.*` namespace) across 86 tasks, 140+ files, and 1,196+ reference occurrences.

**Problem**:
- Two separate command namespaces (`/pdl.*` + `/triad.*`) for a single unified lifecycle created a false mental model
- Discovery stage lacked evidence collection, making prioritization decisions indefensible
- No feedback loop from delivery back to discovery (open-loop system)
- Plan stage required users to remember 3 sequential commands across sessions

**Solution**:
1. **Unified namespace**: All lifecycle commands under `/aod.*` via systematic find-and-replace in 4 sub-waves (longest patterns first to prevent partial matches)
2. **Plan stage router**: `/aod.plan` auto-detects artifact state and delegates to correct sub-step
3. **Evidence-enriched discovery**: `/aod.discover` prompts for evidence alongside ICE scoring
4. **Delivery retrospective**: `/aod.deliver` captures metrics, surprises, and feeds new ideas back to discovery
5. **GitHub-backed tracking**: GitHub Issues with `stage:*` labels + auto-regenerated BACKLOG.md

**Delivery Metrics**:
- Estimated: 2-3 sprints (Team-Lead review, assuming human-paced development)
- Actual: ~2.5 hours (AI-assisted, 6 implementation waves)
- Tasks: 86/86 complete
- PR: #9 (merged 2026-02-09)

**What Surprised Us**:
- GitHub integration scope was more involved than expected (shared bash utilities, duplicate detection, pagination warnings, defensive parsing)
- Skill merge (3 PDL skills → aod-discover, ~675 lines) was the highest-risk single task but completed cleanly
- The scale of the rename (140+ files) was manageable thanks to wave-based approach with verification between waves
- Overall, planning phase accurately predicted the work — no blocking surprises

**Key Learning**: Wave-based find-and-replace with longest-patterns-first ordering prevents partial match corruption. Always verify with grep between sub-waves.

**Why This Matters**:
- Validates that AI-assisted development can compress multi-sprint features into hours when planning is thorough
- Demonstrates that the AOD methodology (discover → define → plan → build → deliver) works end-to-end
- The 6-wave agent strategy (A-F) kept context manageable across the large task set

**Tags**: #process #namespace-unification #ai-assisted #retrospective #feature-010

### Related Files:
- `specs/010-aod-lifecycle-formalization/` - Full spec, plan, and tasks
- `docs/product/02_PRD/010-pdlc-sdlc-formalization-2026-02-08.md` - PRD
- `docs/guides/AOD_LIFECYCLE.md` - Primary lifecycle reference (created in this feature)
- `docs/guides/AOD_MIGRATION.md` - Command migration reference (created in this feature)

---

### Entry 5: Feature 011 — GitHub Projects Lifecycle Board Retrospective

## [Process] - GitHub Projects v2 Integration with Graceful Degradation

**Date**: 2026-02-09
**Context**: Feature 011 added a visual kanban board (GitHub Projects v2) over the existing Issue+label lifecycle tracking system, with 5 columns matching AOD lifecycle stages.

**Problem**:
- Teams using AOD had no visual board view for daily standups or sprint planning
- The only way to see lifecycle state was to read BACKLOG.md or query Issues with label filters
- Needed to integrate with GitHub Projects v2 API without breaking existing workflows

**Solution**:
1. **6 new bash functions** in `github-lifecycle.sh` (879 lines) with session-scoped caching
2. **7-level graceful degradation hierarchy** — board failures never block core lifecycle
3. **Automatic board sync** wired into 4 lifecycle commands (`/aod.define`, `/aod.spec`, `/aod.build`, `/aod.deliver`)
4. **First-run detection** with one-time setup hint and marker file suppression

**Delivery Metrics**:
- Estimated: 12-17 hours (Team-Lead: optimistic 12h, realistic 15h, pessimistic 20h)
- Actual: ~3-4 hours (AI-assisted, 2 main commits + 1 fix)
- Tasks: 22/22 complete (T003 removed during planning)
- PR: #12

**What Surprised Us**:
- Had to re-authenticate `gh` CLI and run a setup script to actually create the board — the `project` OAuth scope wasn't included by default
- The jq parse bug with control characters in issue body JSON was unexpected — `gh project item-add` output became unparseable when the issue body contained newlines

**Key Learning**: When integrating with GitHub's Projects v2 API, always account for authentication scope requirements (`gh auth refresh -s project`) as a first-class setup step. Users will need explicit instructions. Also, always handle JSON output from `gh` commands defensively — issue bodies can contain arbitrary characters that break jq parsing.

**Why This Matters**:
- Validates the "view layer, not load-bearing" architecture principle — board never blocks core workflow
- Demonstrates that graceful degradation with 7 explicit levels makes integrations resilient
- The re-authentication requirement highlights the importance of clear first-run setup docs for upstream users

**Tags**: #process #github-projects #api-integration #graceful-degradation #retrospective #feature-011

### Related Files:
- `specs/011-github-projects-lifecycle/` — Full spec, plan, and tasks
- `docs/product/02_PRD/011-github-projects-lifecycle-board-2026-02-09.md` — PRD
- `.aod/scripts/bash/github-lifecycle.sh` — Implementation (board functions)
- `specs/011-github-projects-lifecycle/quickstart.md` — User-facing setup guide

---

### Entry 6: Bash 3.2 Compatibility — macOS Default Shell

## [RCA] - Scripts using bash 4+ features fail on macOS default bash 3.2

**Date**: 2026-02-09
**Context**: `backlog-regenerate.sh` failed when sourcing `github-lifecycle.sh` after Feature 011 added GitHub Projects board integration.

**Problem**:
`backlog-regenerate.sh` crashed with `"discover: unbound variable"` because `github-lifecycle.sh` used `declare -A` (associative arrays) — a bash 4.0+ feature. macOS ships bash 3.2.57 as `/bin/bash` due to GPLv3 licensing.

**Root Cause Analysis (5 Whys)**:

1. Why did `backlog-regenerate.sh` fail? → It sourced `github-lifecycle.sh` which crashed at line 42
2. Why did `github-lifecycle.sh` crash? → `declare -A AOD_STAGE_TO_COLUMN=(...)` is invalid in bash 3.2
3. Why is `declare -A` invalid? → macOS ships bash 3.2.57; associative arrays require bash 4.0+
4. Why does the script run under bash 3.2? → `#!/usr/bin/env bash` resolves to `/bin/bash` (3.2) on macOS
5. Why wasn't this caught earlier? → Feature 011 added the `declare -A` but board functions were only tested via Claude Code's shell (which may resolve to a different bash); `backlog-regenerate.sh` was the first script to `source` the entire file unconditionally

**Secondary issue found**: `${stage^}` (capitalize first letter) in `backlog-regenerate.sh` is also bash 4+ syntax.

**Solution Implemented**:

1. Replaced `declare -A AOD_STAGE_TO_COLUMN` with a POSIX-compatible `case` function:
```bash
aod_stage_to_column() {
    case "$1" in
        discover) echo "Discover" ;;
        define)   echo "Define" ;;
        # ...
    esac
}
```

2. Replaced `${stage^}` with bash 3.2-compatible capitalization:
```bash
stage_title="$(echo "${stage:0:1}" | tr '[:lower:]' '[:upper:]')${stage:1}"
```

3. Updated all call sites to use `column_name=$(aod_stage_to_column "$stage")` instead of `${AOD_STAGE_TO_COLUMN[$stage]:-}`.

**Prevention Rule**: All `.sh` scripts in this project MUST be bash 3.2 compatible. Avoid:
- `declare -A` (associative arrays)
- `${var^}` / `${var,,}` (case modification)
- `readarray` / `mapfile`
- `|&` (pipe stderr)
- `&>` (redirect both streams — use `>file 2>&1` instead)

**Why This Matters**:
- AOD is a template used by adopters on various systems; macOS is a primary target
- Apple will never ship bash 4+ due to GPLv3 licensing
- Scripts that work in CI (often Ubuntu with bash 5) will silently fail on macOS

**Tags**: #rca #bash #compatibility #macos #root-cause-analysis #feature-011

### Related Files:
- `.aod/scripts/bash/github-lifecycle.sh` — Fixed associative array
- `.aod/scripts/bash/backlog-regenerate.sh` — Fixed capitalize syntax
- `specs/011-github-projects-lifecycle/NEXT-SESSION.md` — Originally noted as known issue

---

### Entry 7: Feature 013 — Manual Upstream Sync (IDEA-005 E2E Test Vehicle)

## [Process] - Single-File Bash Features Complete 25x Faster Than Estimated

**Date**: 2026-02-10
**Context**: Feature 013 (Manual Upstream Sync) was implemented as the test vehicle for Feature 012's E2E Lifecycle Test, exercising all 5 AOD lifecycle stages on a real backlog item (IDEA-005).

**Problem**:
- Template adopters had no automated way to pull upstream AOD improvements into their customized projects
- Manual diffing and patching was error-prone and time-consuming
- No protection for adopter-owned files (`.aod/memory/`, constitution) during upstream merges

**Solution**:
Created `scripts/sync-upstream.sh` with 4 subcommands:
1. `setup` — Configure upstream remote (idempotent, URL validation)
2. `check` — Categorized file change detection (8 categories, "up to date" handling)
3. `merge` — Safe merge with backup branch, `.aod/memory/` dual protection (gitattributes + backup-restore), dry-run mode, conflict reporting
4. `validate` — Post-sync integrity checks (file existence, YAML frontmatter, placeholder leak detection, constitution integrity)

Plus `docs/guides/UPSTREAM_SYNC.md` step-by-step adopter guide and cross-references.

**Delivery Metrics**:
- Estimated: 3.5 hours (Team-Lead realistic, 26 tasks, 4 waves)
- Actual: ~8 minutes (all 26 tasks, single build session)
- Tasks: 26/26 complete
- Architect Review: APPROVED (3 minor findings, none blocking)

**What Surprised Us**:
The 25x speed difference between estimate and actual highlights that Team-Lead estimates assume human-paced development with context switching. For single-file features with clear specs, AI-assisted implementation can compress dramatically. The spec and plan quality (9 FRs, 3 user stories, 26 tasks) meant zero ambiguity during build — no time spent asking clarification questions.

**Key Learning**: Single-file bash features with clear specifications are ideal candidates for rapid AI-assisted implementation. The bottleneck is planning quality, not implementation speed. Invest time in spec/plan; the build phase will be fast.

**Why This Matters**:
- Validates that the AOD planning pipeline (discover → define → spec → plan → tasks) produces specifications detailed enough for near-instant implementation
- Demonstrates that Team-Lead time estimates need a separate calibration factor for AI-assisted vs human-paced work
- The E2E lifecycle test (Feature 012) proved all 5 AOD stages work end-to-end with a real feature

**Tags**: #process #bash #e2e-lifecycle #ai-assisted #retrospective #feature-013

### Related Files:
- `scripts/sync-upstream.sh` — Implementation (4 subcommands)
- `docs/guides/UPSTREAM_SYNC.md` — Step-by-step adopter guide
- `specs/013-manual-upstream-sync/` — Full spec, plan, tasks, research
- `docs/product/02_PRD/013-manual-upstream-sync-2026-02-10.md` — PRD

### Entry 8: Feature 012 — E2E Lifecycle Test Retrospective

## [Process] - AOD Lifecycle Validated End-to-End: 8/8 Success Criteria Passed

**Date**: 2026-02-10
**Context**: Feature 012 ran a complete E2E test of the AOD lifecycle (Discover → Define → Plan → Build → Deliver) using IDEA-005 (Manual Upstream Sync) as the test vehicle, exercising every `/aod.*` command in sequence on a real backlog item.

**Problem**:
- The AOD methodology had never been validated as a complete system — each command worked in isolation but the end-to-end flow was untested
- No evidence existed that stage outputs could be consumed by the next stage without manual transformation
- No friction data existed to prioritize improvements

**Solution**:
Executed all 5 lifecycle stages for IDEA-005 using only `/aod.*` commands, capturing friction at every stage transition. Produced three deliverables:
1. **Lifecycle walkthrough** — All 5 stages completed, 66 tasks tracked, GitHub Issue #14 transitioned through all `stage:*` labels
2. **Friction log** — 3 entries (all minor, 0 blockers, 0 major), structured with severity/resolution
3. **Happy-path quickstart** — Publishable reference for new adopters with command sequences, timing, artifact links, and lessons learned

**Delivery Metrics**:
- Estimated: 4-6 hours (Team-Lead estimate)
- Actual: ~1.6 hours total (including all 7 phases)
- Tasks: 66/66 complete
- Success criteria: 8/8 PASSED

**What Surprised Us**:
The entire lifecycle completed in ~1.6 hours vs. the 4-6 hour estimate. The Build stage (90-min scope cap) finished in 8 minutes. The biggest friction wasn't in the commands themselves but in running one feature's lifecycle on another feature's branch — a meta-testing edge case, not a real-world problem.

**Key Learnings**:
1. Branch-based feature detection assumes 1:1 mapping (3 minor friction items from same root cause)
2. Triad governance catches real issues without blocking velocity (parallel reviews)
3. AI-assisted builds with good specs compress dramatically (25x faster)
4. The friction log pattern (inline capture + severity framework) is lightweight and effective

**Tags**: #process #e2e-testing #lifecycle #retrospective #feature-012 #validation

### Related Files:
- `specs/012-e2e-lifecycle-test/quickstart.md` — Happy-path reference (publishable)
- `specs/012-e2e-lifecycle-test/friction-log.md` — Structured friction log (3 minor entries)
- `specs/012-e2e-lifecycle-test/spec.md` — Feature spec (8 FRs, 8 SCs)
- `specs/012-e2e-lifecycle-test/tasks.md` — Master task list (66 tasks)
- `docs/product/02_PRD/012-e2e-lifecycle-test-2026-02-09.md` — PRD

---

### Entry 9: Post-Review Output Re-grounding — Preventing Template Drift

**Date**: 2026-02-11
**Category**: Pattern
**Severity**: Medium
**Feature**: 022 (Full Lifecycle Orchestrator)
**Discovery**: 5 Whys root cause analysis

**Problem**: After processing variable-length Triad review outputs (PM, Architect, Team-Lead), the agent composed the `/aod.define` completion report from memory instead of re-reading the Step 8 template. The `Next:` line was contaminated by reviewer recommendations (`/aod.spec` after spike) instead of the template's correct value (`/aod.plan PRD: {prd_number} - {topic}`).

**Root Cause**: Command completion steps lacked an explicit "re-read this template" instruction. After processing large review outputs (often 1000+ words per reviewer), the agent relied on memory for the final output format, making it susceptible to reviewer-framing contamination.

**Solution**: Added a **re-grounding instruction** to every `/aod.*` command's completion step:

```
**Re-ground before output**: Re-read the template below exactly. Do not paraphrase
or substitute reviewer recommendations for the `Next:` line.
```

Applied to all 7 commands: `aod.define`, `aod.spec`, `aod.project-plan`, `aod.tasks`, `aod.build`, `aod.deliver`, `aod.sync-upstream`.

**Pattern**: When a workflow step follows variable-length agent output (reviews, research, analysis), always include an explicit re-grounding instruction before the templated output step. The longer and more opinionated the preceding content, the higher the drift risk.

**Key Insight**: This is analogous to "prompt injection via review output" — reviewer recommendations about next steps can override the command's own template if the executor doesn't re-read the template. The fix is defensive: force a re-read at the output boundary.

**Tags**: #pattern #agent-drift #template-output #re-grounding #5-whys #commands

### Related Files:
- `.claude/commands/aod.define.md` — Step 8 (original fix)
- `.claude/commands/aod.spec.md` — Step 7
- `.claude/commands/aod.project-plan.md` — Step 7
- `.claude/commands/aod.tasks.md` — Step 7
- `.claude/commands/aod.build.md` — Step 6
- `.claude/commands/aod.deliver.md` — Step 10
- `.claude/commands/aod.sync-upstream.md` — Step 8

### Entry 10: Feature 022 — Full Lifecycle Orchestrator Retrospective

**Date**: 2026-02-11
**Category**: Retrospective
**Severity**: Low
**Feature**: 022 (Full Lifecycle Orchestrator)
**PR**: #26

**Summary**: Implemented `/aod.run` — a full lifecycle orchestrator that chains all 5 AOD stages (Discover → Define → Plan → Build → Deliver) with disk-persisted state for session resilience and governance gates at every boundary. 37 tasks across 9 waves, all checkpoints passed, 8/8 quickstart scenarios verified.

**Surprise**: The Triad governance process (PM + Architect + Team-Lead sign-offs) worked smoothly with no blocking issues across all artifacts, validating the governance model designed in earlier features.

**Key Lesson**: The skill chaining pattern — where one skill invokes another skill via the Skill tool, passing arguments and reading results from disk artifacts — proved viable for complex multi-stage workflows. The AOD orchestrator successfully delegates to 7 different stage skills (`~aod-discover`, `aod.define`, `aod.spec`, `aod.project-plan`, `aod.tasks`, `aod.build`, `aod.deliver`) without needing to understand their internals, only their input/output contracts.

**Pattern**: When composing skills into a pipeline, define clear contracts at each boundary: (1) what arguments the skill expects, (2) what artifact it produces on disk, (3) how success/failure is signaled (e.g., YAML frontmatter `triad.*.status`). This enables loose coupling — the orchestrator only reads frontmatter, never parses skill internals.

**Metrics**:
- Estimated: 1 day | Actual: 1 day
- Tasks: 37/37 | Waves: 9/9
- New ideas spawned: 2 (#27 dry-run mode, #28 multi-feature orchestration)

**Tags**: #retrospective #orchestrator #skill-chaining #governance #state-management

---

### Entry 11: Feature 027 — Orchestrator Dry-Run Mode Retrospective

**Date**: 2026-02-11
**Category**: Retrospective
**Severity**: Medium
**Feature**: 027 (Orchestrator Dry-Run Mode)
**PR**: #29

**Summary**: Added `--dry-run` flag to `/aod.run` that previews the full orchestration plan without executing any writes. Supports 3 sub-modes (issue, idea, resume) with 4 edge cases. 23 tasks across 5 waves.

**Surprise**: The implementation failed halfway through execution. The `/aod.run` command consumed too much context window, preventing completion of the full lifecycle within a single session. This highlighted that context efficiency is a critical constraint for single-session orchestration features.

**Key Lesson**: Single-session context management needs dedicated research. The current `/aod.run` skill is too context-hungry — it loads full skill content, governance rules, and detection logic simultaneously. Future improvements should explore lazy loading, context compression, or skill segmentation to stay within window limits.

**Pattern**: When building read-only preview modes (dry-run), separate detection logic from mutation logic in the original skill design. If detection and mutation are already cleanly separated, dry-run becomes a natural extension — reuse detection, replace mutation with display, exit immediately. See the "Read-Only Dry-Run Preview" pattern in `docs/architecture/03_patterns/README.md`.

**Metrics**:
- Estimated: 2 hours | Actual: 1 day (implementation succeeded, but aod.run execution failed midway)
- Tasks: 23/23 | Waves: 5/5
- New ideas spawned: 1 (#30 improve context efficiency of aod.run)

**Tags**: #retrospective #dry-run #context-management #orchestrator #read-only-preview

### Entry 12: Feature 030 — Context Efficiency of /aod.run Retrospective

**Date**: 2026-02-11
**Category**: Retrospective
**Severity**: High
**Feature**: 030 (Context Efficiency of /aod.run)
**PR**: #31

**Summary**: Reduced `/aod.run` orchestrator context consumption by splitting the 1,884-line monolithic SKILL.md into a ~405-line core plus 4 on-demand reference files, adding compound state helpers for incremental reads, and implementing governance result caching. Core SKILL.md tokens dropped from ~25,800 to ~5,690 (78% reduction). Pre-Build total context from ~149,300 to ~122,536 tokens.

**Surprise**: Context gains were larger than expected — the 78% reduction in core SKILL.md exceeded the <8,000 token target significantly (actual ~5,690). The segmentation split was cleaner than anticipated because the original SKILL.md had natural section boundaries that mapped directly to reference files.

**Key Lesson**: Prompt segmentation is high-ROI — splitting large skill files yields disproportionate context savings for moderate effort. The key insight is that most skill content is conditionally needed (governance rules only at gates, entry modes only once, error recovery only on failure), so moving conditional content to reference files loaded via Read tool dramatically reduces persistent context load.

**Pattern**: Three new patterns documented in `docs/architecture/03_patterns/README.md`: (1) On-Demand Reference File Segmentation — split monolithic skills into core + references, (2) Compound State Helpers — extract targeted fields instead of full JSON reads, (3) Governance Result Caching — cache verdicts to avoid redundant artifact reads. See also ADR-002 in `docs/architecture/02_ADRs/`.

**Metrics**:
- Estimated: 2-3 sessions | Actual: 3 sessions (1 day)
- Tasks: 47/47 | Waves: 3/3 | Phases: 8/8
- New ideas spawned: 1 (#32 real-time token budget tracking)

**Tags**: #retrospective #context-efficiency #prompt-segmentation #orchestrator #performance

---

### Entry 13: Feature 032 — Real-time Token Budget Tracking Retrospective

**Date**: 2026-02-11
**Category**: Retrospective
**Severity**: Medium
**Feature**: 032 (Real-time Token Budget Tracking)

**Summary**: Added heuristic token consumption estimation to the `/aod.run` orchestrator. Extends `run-state.sh` with 4 budget functions, enhances the stage map with utilization percentages, introduces adaptive context loading when budget exceeds 80% threshold, and adds proactive resume recommendations when remaining budget is insufficient for the next stage. All changes are additive — pre-032 state files continue to work without error.

**Key Lesson**: Budget tracking for LLM orchestrators is inherently heuristic since actual token counts are not exposed. The critical design choice was overestimating via a 1.5x safety multiplier — triggering adaptive mode early is far better than triggering it late. The 6-layer backward compatibility approach (every function checks for `token_budget` existence) ensures zero regression risk for existing state files.

**Pattern**: Additive optional state fields with graceful degradation. Every new function that reads `token_budget` has a default fallback (returns safe defaults if absent). This pattern enables incremental feature adoption without schema version bumps or migration scripts.

**Surprise**: The adaptive context loading and resume recommendation could be consolidated cleanly into the existing Core Loop structure. Adding a new step 12 (resume recommendation) between post-stage checkpoint and GitHub label update was architecturally clean — no existing step numbering was fragile because all cross-references are by description, not step number.

**Metrics**:
- Estimated: 2-3 sessions | Actual: 2 sessions
- Tasks: 26/26 | Waves: 3/3 | Phases: 6/6
- Files modified: 3 (run-state.sh, SKILL.md, entry-modes.md) + 1 (governance.md)

**Tags**: #retrospective #token-budget #adaptive-loading #orchestrator #heuristic-estimation

---

### Entry 14: Feature 034 — Cross-Session Budget History Retrospective

**Date**: 2026-02-11
**Category**: Retrospective
**Severity**: Medium
**Feature**: 034 (Cross-Session Budget History)

**Summary**: Added trend analysis and session predictions to the `/aod.run` orchestrator by mining the `prior_sessions` array introduced in Feature 032. A single compound `aod_state_get_trend_summary` jq function computes per-stage averages, predicted sessions remaining, and confidence levels. The Stage Map Display and Resume Entry now show trend lines with historical context. Core Loop step 12 (resume recommendation) now uses a 3-tier fallback chain: historical per-stage average → current-session average → 15,000 default.

**Key Lesson**: Lightweight features that modify only markdown skill files and shell scripts can still hit session limits when the orchestrator itself consumes significant context during the build stage. The irony: a feature designed to predict session splits itself needed a session split. This validates the feature's value proposition — without trend data, users have no visibility into when splits will occur.

**Pattern**: Compound jq state helpers with pipe-delimited output. The `aod_state_get_trend_summary` function returns 9 fields in a single call, avoiding multiple round-trips. This pattern (established by `aod_state_get_budget_summary` in Feature 032) is efficient for skill files that need to parse multiple values from state.

**Surprise**: The build stage hit context limits despite being a lightweight 3-file feature. The orchestrator's own context (SKILL.md, governance.md, entry-modes.md reference files) consumes substantial budget, making even small features span 2 sessions.

**Metrics**:
- Estimated: 1 session | Actual: 2 sessions
- Tasks: 15/15 | Waves: 4/4 | Phases: 6/6
- Files modified: 3 (run-state.sh, SKILL.md, entry-modes.md) + 2 (INDEX.md, spec.md)
- New ideas spawned: 2 (#35 visual budget dashboard, #36 auto-pause at predicted limits)

**Tags**: #retrospective #trend-analysis #session-prediction #orchestrator #cross-session

---

### Entry 15: Budget Tracker Underestimates Actual Context by ~2.5x

**Date**: 2026-02-12
**Category**: Root Cause Analysis
**Severity**: High
**Feature**: 032/034/038 (Token Budget Tracking lineage)

**Problem**: The budget tracker estimated ~72K tokens (60% of 120K usable budget) at the point of pausing, but `/context` showed actual consumption was ~181K tokens (90% of 200K window). The tracker underestimated by approximately 2.5x.

**Root Cause Analysis (5 Whys)**:
1. Why was the estimate so far off? → The tracker only measures content explicitly loaded by skill instructions, not total conversation context.
2. Why doesn't it measure total context? → Claude Code does not expose a runtime token consumption API — all estimation is heuristic (ADR-003).
3. Why is heuristic estimation insufficient? → It misses system overhead (~28K: system prompt, tool definitions, MCP, memory files, skill descriptions) and conversation history growth (~155K of accumulated messages).
4. Why does conversation history grow so much? → Every tool call and response accumulates in the message history. A session with ~50+ tool calls generates substantial history that the tracker never sees.
5. Why wasn't the `usable_budget` calibrated for this? → The 120K assumption (60% of 200K) was set conservatively but didn't account for message accumulation being the dominant consumer, not skill content loading.

**Key Data Points**:
- System overhead (invisible to tracker): ~28K tokens (system prompt 4.3K, tools 15.4K, MCP 562, agents 586, memory 4.7K, skills 2K)
- Message history: ~155K tokens (77% of total)
- Budget tracker estimate: 72K | Actual: 181K | Ratio: 2.5x underestimate
- `usable_budget: 120K` vs real available: ~172K (200K - 28K overhead)

**Solution**: The pause recommendation at 60% estimated was correct in practice — it triggered at ~90% actual. However, the displayed percentage is misleading to users. Recommended calibration for future features:
1. Reduce `usable_budget` from 120K to 60K to account for message accumulation
2. OR increase `safety_multiplier` from 1.5x to 3x
3. OR track tool call count as a proxy for conversation growth (~3K tokens per tool roundtrip average)
4. Display should convey directional signal, not false precision (e.g., "budget: moderate" vs exact "~60%")

**Why This Matters**: Feature 038 extends budget tracking to standalone skills. If the tracker shows "~15% used" after a standalone `/aod.spec` run but actual consumption is ~40%, users will make poor session planning decisions. The tracking infrastructure works but needs recalibration to be useful as a planning tool.

**Tags**: #rca #budget-tracking #token-estimation #context-window #calibration #orchestrator

---

### Entry 16: Universal Budget Tracking Pattern for Standalone Skills

**Date**: 2026-02-12
**Category**: Architecture Pattern
**Severity**: Medium
**Feature**: 038 (Universal Session Budget Tracking)

**Problem**: Token budget tracking only worked when skills ran inside the `/aod.run` orchestrator. Standalone skill invocations (e.g., `/aod.spec` run directly) produced no budget data, giving developers no visibility into context window consumption.

**Solution**: Implemented a uniform "budget initialization guard" pattern across all 7 AOD lifecycle command files (`/aod.discover`, `/aod.define`, `/aod.spec`, `/aod.project-plan`, `/aod.tasks`, `/aod.build`, `/aod.deliver`). The pattern consists of two blocks:

1. **Entry Guard (Step 1b)** — inserted after prerequisite validation:
   - Check state file existence (`aod_state_exists`)
   - Detect active orchestrator via `updated_at` recency (5-minute threshold)
   - If orchestrator active → skip budget writes (prevents double-counting)
   - If standalone → validate feature ID match, create state if needed, write pre-estimate

2. **Exit Display (Report section)** — appended to completion output:
   - Write post-estimate
   - Read budget summary
   - Display `(~N% budget used)` if data exists

**Key Design Decisions**:
- **Implicit orchestrator detection**: Uses `updated_at` recency instead of an explicit flag. Avoids stuck-flag problems if the orchestrator crashes — stale timestamps gracefully degrade to standalone mode.
- **Non-fatal error wrapping**: All budget operations use `|| true` or `|| echo "fallback"` so budget failures never block skill execution.
- **`usable_budget: 60000`** for standalone state creation (calibrated per Entry 15 — tracker underestimates by ~2.5x).
- **Additive accumulation**: Plan substages (`/aod.spec`, `/aod.project-plan`, `/aod.tasks`) all write to `stage_estimates.plan`. The `aod_state_update_budget` function is additive, so values accumulate correctly.

**Implementation Pattern** (reference: `specs/038-universal-session-budget-tracking/budget-guard-pattern.md`):
- 7 files modified with identical ~30-line instruction blocks each
- No new shell functions needed — existing `run-state.sh` API sufficient
- Stage mapping: discover, define, plan (x3), build, deliver

**Why This Matters**: Establishes budget visibility across all development workflows, not just orchestrated ones. Developers running individual skills now see cumulative context consumption, enabling better session planning. The pattern is designed for safe extensibility — new skills can be instrumented by copying the same guard blocks.

**Tags**: #architecture #pattern #budget-tracking #token-estimation #context-window #orchestrator

---

### Entry 17: Uniform Instruction Patterns Scale Across Command Files

## [Architecture] - Defining a pattern once and applying identically prevents drift

**Date**: 2026-02-12
**Context**: Feature 038 required adding identical budget tracking instrumentation to 7 separate AOD command files.

**Problem**: When the same behavior needs to be added to multiple command files (markdown instruction files, not code), there's a risk of inconsistency — each file gets slightly different instructions, leading to subtle behavioral drift across commands.

**Solution**: Define the pattern once in a reference document (`specs/038-*/budget-guard-pattern.md`) with exact instruction blocks, then copy them identically into each command file. The "pattern" is a ~30-line markdown instruction block, not a shared function — it's duplicated intentionally because each command file must be self-contained (commands don't import shared partials).

**Key Insight**: For instruction-based systems (like Claude command files), duplication is preferable to abstraction. Each command file must work independently without referencing shared includes. The trade-off is maintenance cost (7 files to update) vs. reliability (each file is self-contained and won't break if shared infrastructure changes).

**Metrics**: 7 files instrumented, 0 behavioral inconsistencies during validation, pattern applied in 2 parallel waves.

**Why This Matters**: Establishes a reusable methodology for instrumenting command files at scale. Future cross-cutting concerns (logging, metrics, governance checks) can follow the same "define once, apply identically" pattern.

**Tags**: #architecture #pattern #methodology #command-files #scaling

---

### Entry 18: Non-Fatal Budget Tracking Pattern for Self-Calibrating Systems

## [Architecture] - Error-swallowing guards ensure optional features never block critical workflows

**Date**: 2026-02-12
**Context**: Feature 042 implemented a performance registry that provides calibrated budget defaults. The registry is valuable but not essential — skills must work even if the registry is missing, corrupted, or jq is unavailable.

**Problem**: When adding optional observability/calibration features to existing workflows, there's a risk that failures in the optional code could block the primary workflow. A corrupted JSON file or missing dependency shouldn't prevent `/aod.deliver` from closing a feature.

**Solution**: Wrap all optional operations in non-fatal guards:
1. Every registry function returns a fallback value on failure (never throws)
2. All bash calls use `|| true` or `|| echo "fallback"` patterns
3. State file operations check existence before read/write
4. Missing registry gracefully falls back to hardcoded defaults
5. Document clearly in ADRs which operations are "non-fatal"

**Key Insight**: For self-calibrating systems, the calibration data improves accuracy but is never required. Design the system so day-1 behavior (no data) is identical to pre-feature behavior, and calibration progressively improves over time without ever becoming a dependency.

**Metrics**: 5 registry functions, 3 fallback scenarios validated (file missing, JSON corrupted, jq unavailable), 0 blocking failures possible.

**Why This Matters**: Establishes a pattern for adding observability and calibration to critical workflows without introducing new failure modes. Future self-improving features can follow the same "enhance but never block" principle.

**Tags**: #architecture #pattern #resilience #self-calibrating #non-fatal

---

---

## Entry Templates by Category

### [Architecture] Template
```markdown
### Entry N: [Pattern/Decision Name]

## [Architecture] - [One-line Description]

**Date**: YYYY-MM-DD
**Context**: [What you were building]

**Problem**: [Technical challenge]
**Solution**: [Architectural approach with code/diagrams]
**Why This Matters**: [Impact on system]
**Tags**: #architecture #pattern

### Alternative Approaches Rejected:
[Other options considered and why not chosen]
```

### [Performance] Template
```markdown
### Entry N: [Optimization Name]

## [Performance] - [One-line Description]

**Date**: YYYY-MM-DD
**Context**: [Performance issue encountered]

**Problem**: [Bottleneck description with metrics]
**Solution**: [Optimization approach with before/after metrics]
**Why This Matters**: [User impact]
**Tags**: #performance #optimization

### Benchmarks:
- Before: [metrics]
- After: [metrics]
```

### [Security] Template
```markdown
### Entry N: [Security Issue/Pattern]

## [Security] - [One-line Description]

**Date**: YYYY-MM-DD
**Context**: [Security concern discovered]

**Problem**: [Vulnerability or risk]
**Solution**: [Mitigation approach]
**Why This Matters**: [Security impact]
**Tags**: #security #vulnerability

### Security Checklist:
- [ ] Tested in staging
- [ ] Reviewed by security team
- [ ] Documented in security audit log
```

### [DevOps] Template
```markdown
### Entry N: [Deployment/Infrastructure Issue]

## [DevOps] - [One-line Description]

**Date**: YYYY-MM-DD
**Context**: [Deployment or infrastructure work]

**Problem**: [Deployment/infrastructure issue]
**Solution**: [Resolution approach]
**Why This Matters**: [Operational impact]
**Tags**: #devops #deployment #infrastructure
```

### [Root Cause Analysis] Template
```markdown
### Entry N: [Incident Name]

## [RCA] - [One-line Description]

**Date**: YYYY-MM-DD
**Context**: [What went wrong]

**Problem**: [Incident description]

**Root Cause Analysis (5 Whys)**:
1. Why #1? → Answer #1
2. Why #2? → Answer #2
3. Why #3? → Answer #3
4. Why #4? → Answer #4
5. Why #5? → Root Cause

**Solution Implemented**: [Fixes and preventions]
**Why This Matters**: [Learning and prevention]
**Tags**: #rca #incident #root-cause-analysis
```

---

## Search Tips

### By Tag
Search for `#tag-name` to find all entries in a category.

Common tags:
- `#architecture` - System design decisions
- `#performance` - Optimization patterns
- `#security` - Security issues and mitigations
- `#devops` - Deployment and infrastructure
- `#rca` - Root cause analyses
- `#best-practice` - Recommended approaches
- `#production` - Production-specific learnings

### By Date
Search for `YYYY-MM` to find entries from a specific month.

### By Problem Domain
Use Cmd+F / Ctrl+F to search for keywords like:
- "race condition"
- "migration"
- "rate limit"
- "deployment"
- "performance"

---

## Maintenance Guidelines

### Review Cadence
- **Monthly**: Review new entries for accuracy
- **Quarterly**: Archive outdated entries to `docs/archive/institutional-knowledge/`
- **Annually**: Consider upgrading to knowledge base system if file >1500 lines

### When to Archive
Archive entries when:
- ✅ Technology/approach no longer used
- ✅ Problem solved by later pattern
- ✅ Superseded by better solution

Mark archived entries with:
```markdown
### Entry N: [Title] ⚠️ ARCHIVED

**Archived**: YYYY-MM-DD
**Reason**: [Why no longer relevant]
**Superseded By**: [Link to newer entry/pattern]
```

### Quality Standards
All entries must include:
- ✅ Date (for context)
- ✅ Problem description
- ✅ Solution with code/examples
- ✅ Impact explanation
- ✅ Relevant tags

---

## Related Skills and Tools

**Skills**:
- `kb-create` - Add new knowledge entries
- `kb-query` - Search existing patterns
- `root-cause-analyzer` - Structured root cause analysis

**Commands**:
- `make kb-search QUERY="rate limit"` - Search knowledge base
- `make kb-add TITLE="..."` - Add new entry (interactive)

**Related Documentation**:
- `docs/core_principles/FIVE_WHYS_METHODOLOGY.md` - Root cause analysis guide
- `.claude/skills/kb-create/` - Knowledge creation skill
- `.claude/skills/kb-query/` - Knowledge search skill

---

**Template Instructions**: Replace all `{{TEMPLATE_VARIABLES}}` during project initialization. Delete these three example entries and add your own learnings as you build {{PROJECT_NAME}}.

**Last Updated**: {{CURRENT_DATE}}
**Maintained By**: All team members
**Review Trigger**: When entry count reaches 15 or quarterly
