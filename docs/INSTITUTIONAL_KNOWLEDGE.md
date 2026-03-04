# Institutional Knowledge - {{PROJECT_NAME}}

**Project**: {{PROJECT_NAME}} - {{PROJECT_DESCRIPTION}}
**Purpose**: Capture learnings, patterns, and solutions to prevent repeated mistakes
**Created**: {{PROJECT_START_DATE}}
**Last Updated**: {{CURRENT_DATE}}

**Entry Count**: 24 / 20 (KB System Upgrade triggers at 20 — schedule review)
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
- New ideas spawned: 1 (#32, later superseded by Feature 056)

**Tags**: #retrospective #context-efficiency #prompt-segmentation #orchestrator #performance

---

### Entry 13: Uniform Instruction Patterns Scale Across Command Files

## [Architecture] - Defining a pattern once and applying identically prevents drift

**Date**: 2026-02-12
**Context**: Feature 038 required adding identical instrumentation to 7 separate AOD command files.

**Problem**: When the same behavior needs to be added to multiple command files (markdown instruction files, not code), there's a risk of inconsistency -- each file gets slightly different instructions, leading to subtle behavioral drift across commands.

**Solution**: Define the pattern once in a reference document with exact instruction blocks, then copy them identically into each command file. The "pattern" is a ~30-line markdown instruction block, not a shared function -- it's duplicated intentionally because each command file must be self-contained (commands don't import shared partials).

**Key Insight**: For instruction-based systems (like Claude command files), duplication is preferable to abstraction. Each command file must work independently without referencing shared includes. The trade-off is maintenance cost (7 files to update) vs. reliability (each file is self-contained and won't break if shared infrastructure changes).

**Metrics**: 7 files instrumented, 0 behavioral inconsistencies during validation, pattern applied in 2 parallel waves.

**Why This Matters**: Establishes a reusable methodology for instrumenting command files at scale. Future cross-cutting concerns (logging, metrics, governance checks) can follow the same "define once, apply identically" pattern.

**Tags**: #architecture #pattern #methodology #command-files #scaling

---

### Entry 14: Non-Fatal Observability Pattern for Optional Enhancements

## [Architecture] - Error-swallowing guards ensure optional features never block critical workflows

**Date**: 2026-02-12
**Context**: When adding optional observability or enhancement features to existing workflows, failures in the optional code must never block the primary workflow. A corrupted JSON file or missing dependency should not prevent `/aod.deliver` from closing a feature.

**Problem**: When adding optional observability or calibration features to existing workflows, there's a risk that failures in the optional code could block the primary workflow. A corrupted JSON file or missing dependency shouldn't prevent core operations from completing.

**Solution**: Wrap all optional operations in non-fatal guards:
1. Every optional function returns a fallback value on failure (never throws)
2. All bash calls use `|| true` or `|| echo "fallback"` patterns
3. State file operations check existence before read/write
4. Missing data gracefully falls back to hardcoded defaults
5. Document clearly in ADRs which operations are "non-fatal"

**Key Insight**: For systems with optional enhancements, the enhancement data improves accuracy but is never required. Design the system so day-1 behavior (no data) is identical to pre-feature behavior, and enhancements progressively improve over time without ever becoming a dependency.

**Metrics**: Multiple fallback scenarios validated (file missing, JSON corrupted, jq unavailable), 0 blocking failures possible.

**Why This Matters**: Establishes a pattern for adding observability and optional enhancements to critical workflows without introducing new failure modes. Future self-improving features can follow the same "enhance but never block" principle.

**Tags**: #architecture #pattern #resilience #non-fatal #observability

---

### Entry 15: Feature 047 — Context Optimization for Single-Session Lifecycle

## [Architecture] - Four Optimizations Enable Single-Session Define+Plan Completion

**Date**: 2026-02-13
**Context**: Feature 047 optimized the `/aod.define` and `/aod.plan` stages to reduce context consumption by 40% and 25% respectively, enabling single-session lifecycle completion for typical features.

**Problem**:
The Define and Plan stages consumed too much context window, causing governance gate interruptions. Combined with system overhead, conversation history growth, and governance context loading, users frequently experienced mid-lifecycle session breaks even for lightweight features. This violated the PRD priority stack (Quality > Few Pauses > Speed).

**Solution**:
Implemented four context efficiency optimizations:

1. **Lazy Governance Loading** — Load governance rules at the gate checkpoint, not at skill start. Defers ~4K tokens of governance.md until actually needed.

2. **Serialized Triad Reviews** — Execute PM -> Architect -> Team-Lead reviews sequentially instead of in parallel. Reduces concurrent context from ~18K (3 reviewers loaded simultaneously) to ~6K (one reviewer at a time). Trade-off: +15-20 seconds per review cycle.

3. **Governance Verdict Caching** — Cache reviewer verdicts with mtime-based invalidation via `aod_state_cache_governance()`. Skip re-loading governance context when cached verdict is still valid. Saves ~4K tokens on repeated checks.

4. **Substage Context Unloading** — Use boundary markers (`--- CONTEXT BOUNDARY ---`) to signal context unloading opportunities between substages. Enables future Claude Code versions to reclaim context at well-defined points.

**Trade-offs**:

| Trade-off | Impact | Acceptability |
|-----------|--------|---------------|
| Wall-clock increase | +15-20s per review cycle | Acceptable (PRD: Few Pauses > Speed) |
| SKILL.md complexity | +50 lines for boundary markers | Manageable |
| governance.md complexity | +20 lines for lazy loading instructions | Manageable |

**Why This Matters**:
- **Single-session viability**: Define+Plan stages now have reduced context footprint for typical features
- **Validates optimization trade-offs**: Sequential reviews trade speed for context efficiency -- the right trade for single-session priorities
- **Establishes patterns**: Lazy loading, verdict caching, and boundary markers are reusable across other skills with governance gates

**Metrics**:
- Define stage: 40% context reduction
- Plan stage: 25% context reduction
- Note: Targets pending post-delivery validation

**Pattern**: **Context Optimization for Governance-Heavy Skills**. When a skill has multiple governance gates that load substantial context (reviewer agents, rule files, checklist templates), apply: (1) lazy loading at gate not at start, (2) sequential execution of concurrent checks, (3) verdict caching with invalidation, (4) boundary markers for unloading. Accept wall-clock trade-offs when context efficiency is the priority.

**Key Insight**: The serialization trade-off (ADR-005) demonstrates that "faster" is not always "better" in context-constrained environments. The 15-20 second delay per review cycle is invisible to users who would otherwise hit a full session break. Optimize for the constraint that matters most.

**Tags**: #architecture #context-optimization #governance #single-session #trade-offs #feature-047

### Related Files:
- `.claude/skills/~aod-run/SKILL.md` — Serialized review loop, boundary markers
- `.claude/rules/governance.md` — Lazy loading instructions
- `.aod/scripts/bash/run-state.sh` — `aod_state_cache_governance()` function
- `docs/architecture/02_ADRs/ADR-005-serialization-trade-off.md` — Sequential review decision
- `specs/047-optimize-define-plan-stages/` — Full spec, plan, tasks

---

### Entry 16: Feature 049 — Simple MVP Wins

## [Process] - Starting with minimal viable functionality enables faster delivery

**Date**: 2026-02-13
**Context**: Feature 049 implemented a simple logging utility for AOD orchestration scripts.

**Problem**: Teams often over-engineer initial implementations, adding features "just in case" that delay delivery and complicate testing.

**Solution**: Follow the MVP-first approach demonstrated in Feature 049:

1. **Define core value proposition first** — US-001 (timestamped logging) is the entire MVP
2. **Prioritize user stories by value, not complexity** — P1 delivers value, P2/P3 extend it
3. **Make each story independently testable** — Each can be validated in isolation
4. **Accept graceful degradation over completeness** — US-004's error handling is P3, not P1

**Example from Feature 049**:
- MVP scope: 7 tasks (T001-T007) — basic logging to default path
- Full scope: 24 tasks — adds configuration, integration, error handling
- MVP delivered core value; extensions were incremental improvements

**Why This Matters**: Feature 049 was "simpler than expected" precisely because the scope was ruthlessly minimized. Each user story added value without requiring prior stories to be complete. This made the feature easier to test, faster to deliver, and simpler to maintain.

**Tags**: #process #mvp #scope-management #feature-049 #best-practice

### Related Files:
- `specs/049-simple-logging-utility/spec.md` — User stories with priority rationale
- `specs/049-simple-logging-utility/tasks.md` — MVP vs full scope delineation
- `.aod/scripts/bash/logging.sh` — 41-line implementation

### Entry 17: Feature 056 — Remove Broken Features Early

## [Process] - Non-functional code accumulates faster than you'd expect; remove it at the first sign of breakage

**Date**: 2026-02-26
**Context**: Feature 056 removed the budget tracking and token logging system (~880+ lines across shell scripts, command files, orchestrator, docs, and ADRs) that had been non-functional for multiple releases.

**Problem**: The budget tracking system relied on heuristic token estimation that was never accurate enough to make blocking decisions. Despite being wrapped in non-fatal `|| true` guards, the dead code created maintenance burden, confused new adopters inspecting the codebase, and undermined trust in the toolkit's quality. By the time removal was prioritized, the budget code had spread across 15+ files with interleaved logic in the orchestrator Core Loop.

**Solution**: Structured leaf-first removal in 8 phases:
1. Delete pure leaf nodes first (performance registry — zero non-budget consumers)
2. Remove functions from shared files (budget functions in run-state.sh)
3. Clean callers (command files, orchestrator)
4. Update documentation (ADRs, KB entries, patterns catalog)
5. Sweep for stragglers with comprehensive term list

**Key Insight**: The hardest part was confidence in completeness — knowing you got it all. The comprehensive FR-017 sweep term list (28 budget-specific terms) was essential for final verification. Without an explicit "done" checklist, residual references would have slipped through.

**Why This Matters**: Every release that ships with known-broken code makes the next removal harder. The non-fatal wrapper pattern (`|| true`) that prevented runtime failures also masked the growing scope of dead code. Remove broken features at the first sign of breakage, before they spread.

**Tags**: #process #technical-debt #code-removal #feature-056 #retrospective

### Related Files:
- `specs/056-budget-tracking-removal/spec.md` — 5 user stories, 17 functional requirements
- `specs/056-budget-tracking-removal/tasks.md` — 45 tasks across 8 phases
- `docs/product/02_PRD/056-budget-tracking-removal-2026-02-26.md` — PRD

---

### Entry 18: Feature 058 — Checkpoint Validation Catches Issues Early

## [Process] - Multi-phase features benefit from structured checkpoint reviews at phase boundaries

**Date**: 2026-02-27
**Context**: Feature 058 (Stack Packs) implemented 38 tasks across 8 phases, shipping a stack pack system with convention contracts, persona supplements, scaffold templates, and lifecycle management.

**Problem**: Large features with many parallel content files (8 persona supplements, 2 rule files, 12 scaffold templates, 2 STACK.md files) risk accumulating subtle issues — missing files, wrong paths, inconsistent references — that compound if not caught early.

**Solution**: Structured checkpoint validation at 3 phase boundaries (P0: Waves 1-2, P1: Waves 3-5, P2: Wave 6) with dedicated Architect, Code Review, and Security review gates. The code review at P2 surfaced 5 warnings:
1. Missing `globals.css` in scaffold (build-breaking import)
2. Wrong filename casing (`with-auth.ts` → `withAuth.ts`)
3. Missing `lib/services/` in STACK.md File Structure
4. Missing `rules/.gitkeep` in swiftui-cloudkit pack
5. Missing `next.config.ts` in STACK.md File Structure

All 5 were fixed before merge. Without the checkpoint, these would have shipped as bugs.

**Key Insight**: The cost of a checkpoint review (~5 min) is negligible compared to debugging downstream failures. Content-heavy features especially benefit because each file is correct in isolation but may be inconsistent with its siblings.

**Why This Matters**: Phase-boundary validation transforms "review everything at the end" into "catch issues as they emerge." This is especially valuable for features with high parallelism where independent streams may drift.

**Tags**: #process #quality #code-review #checkpoint #feature-058 #retrospective

### Related Files:
- `specs/058-prd-058-stack/spec.md` — 5 user stories, 15 functional requirements
- `specs/058-prd-058-stack/tasks.md` — 38 tasks across 8 phases
- `docs/product/02_PRD/058-stack-packs-2026-02-27.md` — PRD

---

### Entry 19: Feature 062 — Build Phase Must End With a Commit

## [Process] - Uncommitted implementation is invisible to delivery and creates confusion at closure

**Date**: 2026-03-01
**Context**: Feature 062 (Auto-Create GitHub Projects Board) completed the full Triad workflow — Define, Spec, Plan, Tasks, Build — with all 13 tasks marked complete. However, the build output was never committed. When `/aod.deliver 062` ran, validation failed because no merge/PR existed despite the work being done.

**Problem**: The build phase produced working code in `scripts/init.sh` (~54 lines) but the session ended without committing. The feature branch pointed to the same commit as main, making it appear that implementation hadn't started. All spec artifacts (`specs/062-prd-062-auto/`) were also uncommitted.

**Solution**: The delivery process had to pause, investigate the state of the feature across branches and working directory, then retroactively commit and merge before closure could proceed. This added an unplanned recovery step.

**Key Insight**: `/aod.build` should always end with at least one commit. Uncommitted work is invisible to git-based validation (branch comparison, PR checks, task verification). A build phase that completes without committing creates a gap between "done" (tasks marked [X]) and "delivered" (code in version control).

**Prevention**: Add a checkpoint at the end of `/aod.build` that verifies uncommitted changes don't exist. If `git status` shows modifications, prompt for a commit before declaring the build phase complete.

**Tags**: #process #git #build #delivery #feature-062 #retrospective

### Related Files:
- `specs/062-prd-062-auto/tasks.md` — 13 tasks, all complete
- `scripts/init.sh` — Implementation target (single file)
- `docs/product/02_PRD/062-auto-create-github-projects-board-2026-02-28.md` — PRD

---

### Entry 20: Board Column Drift — Labels and Board Status Can Diverge

## [RCA] - Bypassing /aod.deliver leaves GitHub Projects board cards in wrong column

**Date**: 2026-03-02
**Context**: Feature 062 was fully implemented and merged (`3fb72fe`), but Issue #62 still appeared in the Define column on the GitHub Projects board with `stage:define` label. The feature was closed via a manual commit (`6178109 docs: close Feature 062`) instead of through `/aod.deliver`.

**Problem**: The board showed a delivered feature stuck in Define, undermining trust in the lifecycle dashboard. Attempts to fix via `gh issue edit --add-label stage:done` and `gh project item-edit` appeared to succeed (API confirmed Status=Done) but the board UI didn't reflect the change. Only deleting and re-adding the card with the correct status forced the UI to update.

**Root Cause Analysis (5 Whys)**:
1. Why was #62 in the wrong column? → The board Status field was never updated to Done.
2. Why wasn't it updated? → The feature was closed manually, not via `/aod.deliver`.
3. Why didn't manual closure update the board? → `aod_gh_update_stage` is the ONLY function that updates both labels AND board columns in sync. Manual commits bypass it entirely.
4. Why didn't the "Item closed" workflow catch it? → The workflow was **disabled** on the board — closing an issue had no effect on the board column.
5. Why was the workflow disabled? → It was never enabled during initial board setup (`aod_gh_setup_board` creates columns but doesn't configure workflows).

**Solution Implemented**:
1. Deleted stale card and re-added with correct Done status
2. Fixed issue label from `stage:define` to `stage:done`
3. Closed the issue properly
4. **Prevention**: Enable the "Item closed" → Done workflow on the Projects board (must be done via UI: Board → Workflows → "Item closed" → On → Status: Done)

**Why This Matters**: The board is the primary visual dashboard for lifecycle tracking. A single stale card erodes confidence in the entire system. Two layers of protection are needed: (1) always use `/aod.deliver` to close features, and (2) enable the "Item closed" workflow as a safety net for when the process is bypassed.

**Prevention Checklist**:
- [ ] Enable "Item closed" → Done workflow on GitHub Projects board (UI only — not automatable via API)
- [ ] Always use `/aod.deliver` to close features — never close manually
- [ ] If `gh project item-edit` doesn't visually update the board, delete and re-add the card
- [ ] Consider adding `aod_gh_setup_board` enhancement to auto-document workflow configuration

**Tags**: #rca #github-projects #board #lifecycle #process #feature-062

### Related Files:
- `.aod/scripts/bash/github-lifecycle.sh` — `aod_gh_update_stage()` (single authority for label+board sync)
- `.claude/skills/~aod-deliver/SKILL.md` — Proper feature closure flow
- `scripts/init.sh` — Board setup during init

---

### Entry 21: Feature 065 — AOD System Tends to Over-Engineer Simple Integrations

## [Process] - Wiring a built-in skill into a command is simpler than the AOD process assumed

**Date**: 2026-03-03
**Feature**: 065 — Add /simplify Command to AOD Process
**Category**: Process / Agent Behavior

**What Happened**: Feature 065 was conceived as "wire the built-in /simplify skill into /aod.build" — a simple Markdown edit to add a new step to an existing command file. However, the AOD planning system initially oriented toward creating a new wrapper command and building scaffolding around the skill invocation, rather than recognizing that the entire implementation was a ~100-line edit to one Markdown file. User intervention was required to redirect toward the simpler path.

**Lesson**: When integrating a built-in platform capability (like a Claude Code skill) into an existing command, the default AOD instinct is to treat it as a "new command" feature with its own file, entry point, and lifecycle. In reality, wiring a built-in is an **edit** task, not a **create** task. The correct framing is: "What lines do I add to the existing command file?" not "What new file do I create?"

**Signal for Over-Engineering**:
- AOD starts discussing creating new files when the target is an existing one
- Planning mentions "new command" for what is really a "new step in an existing command"
- Task count exceeds ~5 for what should be a simple sequential edit

**Prevention**:
- Before planning, explicitly ask: "Is this a new file or an edit to an existing file?"
- If the implementation target is a single existing file, limit task count proportionally (~1 task per logical section)
- Apply the Golden Mean lens: minimum viable implementation first, complexity only if needed

**Tags**: #process #over-engineering #simplicity #agent-behavior #feature-065

---

### Entry 22: Feature 061 — Template Scope Analysis Before File Replacement

## [Pattern] - Count hardcoded strings before assuming replacement scope

**Date**: 2026-03-03
**Feature**: 061 — init.sh Personalize All Template Files
**Category**: Pattern / Template Management

**What Happened**: Feature 061 aimed to replace "Agentic Oriented Development Kit" references across template files with `{{PROJECT_NAME}}`. During baseline verification (T001), 20+ occurrences were found across 11 files — more than expected. Critically, the `scope.md` file contained `{{PROJECT_DESCRIPTION}}` on line 15 that needed to be preserved as an invariant while still replacing the project name on 4 other lines in the same file. Additionally, `scripts/init.sh` required zero changes — the script was already correct, only its target files were wrong.

**Lesson**: Before a template variable replacement task, run a comprehensive grep sweep to map ALL occurrence locations, variants (space-separated vs hyphenated), and any adjacent invariants that must survive unchanged. The grep baseline is not overhead — it is the primary risk-reduction step. File editing is mechanical once the map is complete.

**Surprise**: `init.sh` needed zero code changes. The script logic was correct; the template files were the problem. This is a reminder that "the script doesn't work" bugs often live in the script's inputs (template files), not the script itself.

**Pattern: Template Invariant Protection**:
1. Run grep baseline on all candidate files before touching anything
2. Identify both the replacement target AND any adjacent invariants (other `{{PLACEHOLDER}}` values)
3. Target replacements by line content, not line number (line numbers drift)
4. Add explicit verification tasks after each file edit to confirm invariants survived

**Prevention for Future Personalization Features**:
- Always grep for all placeholder variants (space, hyphen, underscore) before scoping work
- `scope.md` line 15 `{{PROJECT_DESCRIPTION}}` is now a known invariant — always protect it
- GitHub URL slugs in README.md are accepted limitations — document, don't attempt to fix

**Tags**: #pattern #templates #personalization #grep-baseline #invariants #feature-061

---

### Entry 23: Feature 064 — Core-Agent Supplement Pattern for Domain Stack Packs

## [Governance] - Stack packs can provide informational overlays for Core agents without modifying governance authority

**Date**: 2026-03-03
**Feature**: 064 — Knowledge System Stack Pack
**Category**: Governance / Stack Pack Architecture

**What Happened**: Feature 064 introduced the first domain-specific stack pack (knowledge-system) that needed to provide orchestration-design awareness to Core-tier Triad agents (product-manager, architect, team-lead). The challenge was that Core agents have governance authority (scope, technical decisions, timeline) that must never be overridden by a pack. The solution was the "informational overlay" pattern: supplements that provide domain context (e.g., command inventory validation, content architecture review, PII scanning) while explicitly disclaiming any authority override. This required a new FR-018 to document the pattern in `stacks/README.md` so future pack authors follow the same boundary.

**Lesson**: When a stack pack needs to influence Core-tier agents, use informational overlays with explicit disclaimers rather than behavioral overrides. The supplement's 4-section format (Stack Context, Conventions, Anti-Patterns, Guardrails) naturally enforces this boundary — the Guardrails section explicitly states what the supplement does NOT override.

**Pattern: Core-Agent Supplement Design**:
1. Supplements are additive context documents, never behavioral overrides
2. Core agent files in `.claude/agents/` are never modified by packs
3. Each supplement must include a Guardrails section disclaiming authority override
4. `stacks/README.md` documents the pattern so all pack authors follow it
5. The `persona-loader.md` generated during pack activation lists supplements for lazy loading

**Applicability**: Any future domain stack pack that provides specialized context for Triad reviews (e.g., API design packs informing architect reviews, compliance packs informing security reviews).

**Tags**: #governance #stack-packs #core-agents #supplements #informational-overlay #feature-064

---

### Entry 24: Feature 073 — Subagent Token Budget via Minimal-Return Architecture

## [Agent Architecture] - Governance subagents should write details to disk and return only a brief status summary

**Date**: 2026-03-04
**Feature**: 073 — Minimal-Return Architecture for Subagent Context Optimization
**Category**: Agent Architecture / Context Management

**What Happened**: Long-running AOD lifecycle sessions were exhausting the main agent's context window because Triad reviewers (PM, Architect, Team-Lead) returned multi-paragraph, code-heavy responses directly to the main context. Feature 073 established a Minimal-Return Architecture: each subagent writes its complete findings to `.claude/results/{agent-name}.md`, then returns only a brief status line (~15 lines / 200 tokens) to the main agent. Implementation was simpler than expected — adding a "Return Format (STRICT)" section to 5 agent files and one policy section to CLAUDE.md was sufficient.

**Lesson**: The pattern "write to disk, return only a pointer" is the right primitive for any long-running multi-agent workflow. It preserves governance quality (full details are always available) while preventing context exhaustion. The key insight: a subagent's output doesn't need to live in the main context — only its status does.

**Pattern: Minimal-Return Architecture**:
1. Subagent completes its full analysis/review
2. Writes complete findings to `.claude/results/{agent-name}.md` (overwrite semantics)
3. Returns to main agent: Status + item count + file path (max 15 lines)
4. Main agent reads results file only if escalation is needed
5. Results directory is gitignored — session-scoped ephemeral artifacts

**Applicability**: Any multi-agent workflow where subagents perform substantial analysis (spec reviews, code reviews, security audits, test runs). Especially valuable for Triad governance gates in `/aod.run` full lifecycle sessions.

**Tags**: #agent-architecture #context-management #subagents #token-budget #minimal-return #feature-073

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
