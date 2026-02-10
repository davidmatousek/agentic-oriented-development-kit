# Institutional Knowledge - {{PROJECT_NAME}}

**Project**: {{PROJECT_NAME}} - {{PROJECT_DESCRIPTION}}
**Purpose**: Capture learnings, patterns, and solutions to prevent repeated mistakes
**Created**: {{PROJECT_START_DATE}}
**Last Updated**: {{CURRENT_DATE}}

**Entry Count**: 2 / 20 (KB System Upgrade triggers at 20)
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
