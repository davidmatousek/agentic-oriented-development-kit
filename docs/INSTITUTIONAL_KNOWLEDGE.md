# Institutional Knowledge - {{PROJECT_NAME}}

**Project**: {{PROJECT_NAME}} - {{PROJECT_DESCRIPTION}}
**Purpose**: Capture learnings, patterns, and solutions to prevent repeated mistakes
**Created**: {{PROJECT_START_DATE}}
**Last Updated**: {{CURRENT_DATE}}

**Entry Count**: 0 / 20 (KB System Upgrade triggers at 20)
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
