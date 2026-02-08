# Product Backlog

**Purpose**: Centralized product backlog with structured idea management and prioritized user stories.

---

## PDL Table-Based Backlog (Recommended)

The Product Discovery Lifecycle (PDL) provides structured backlog management through two consolidated tables:

| File | Purpose | Managed By |
|------|---------|------------|
| `01_IDEAS.md` | All captured ideas with ICE scores and status | `/pdl.idea`, `/pdl.run`, `/pdl.score` |
| `02_USER_STORIES.md` | PM-validated user stories prioritized for development | `/pdl.validate`, `/pdl.run` |

### How It Works

1. **Capture**: Run `/pdl.idea` or `/pdl.run` to add ideas with ICE scoring
2. **Score**: Ideas are scored on Impact, Confidence, and Effort (1-10 each)
3. **Validate**: Run `/pdl.validate` to submit ideas for PM review
4. **Backlog**: Approved ideas become user stories in `02_USER_STORIES.md`
5. **Handoff**: Run `/triad.prd` to create a PRD from a backlog item

### Single-User Assumption

PDL assumes single-user/single-agent editing of backlog files. No concurrent editing safeguards are in place. If multiple users need to edit backlog files simultaneously, coordinate manually to avoid conflicts.

### Migration from Individual Files

Existing individual backlog files (e.g., `feature-idea-name.md`) are preserved alongside the new table-based files. To migrate:

1. Run `/pdl.idea` for each existing backlog item to add it to `01_IDEAS.md`
2. Run `/pdl.validate` for items ready for development to add them to `02_USER_STORIES.md`
3. Optionally archive or delete the original individual files after migration

New ideas should use `/pdl.idea` or `/pdl.run` to add entries directly to the consolidated tables.

---

## Individual Backlog Files (Legacy)

For projects not using PDL, individual backlog files are still supported.

## What Goes Here

- Features identified during `/triad.prd` that are "nice to have"
- Ideas from `/triad.prd` that were descoped from MVP
- User requests that align with vision but aren't prioritized yet
- Technical improvements that aren't urgent

## Naming Convention

```
_backlog/
├── README.md (this file)
├── feature-idea-name.md
├── deferred-from-mvp-001.md
└── future-enhancement-name.md
```

## Template for Backlog Items

```markdown
# [Feature Name]

**Added**: YYYY-MM-DD
**Source**: [/triad.prd | User Request | Team Idea]
**Priority**: [High | Medium | Low]
**Effort Estimate**: [Small | Medium | Large | Unknown]

## Description
[1-3 sentences describing the feature]

## Why It Was Deferred
[Why this didn't make the current cut]

## When to Revisit
[Trigger or timeframe for reconsidering this feature]

## Notes
[Any additional context]
```

## Moving Items Out of Backlog

When a backlog item is ready to build:

1. Create a PRD: `/triad.prd <feature-name>`
2. Reference the backlog item in the PRD
3. Move or delete the backlog file
4. Follow normal Triad workflow

## Review Cadence

Review the backlog:
- **Quarterly**: During OKR planning — re-score deferred ideas with `/pdl.score`
- **After MVP Launch**: Prioritize next wave of features from `02_USER_STORIES.md`
- **When Capacity Opens**: Look for quick wins — check P2 items in `01_IDEAS.md`
- **Monthly**: Review deferred ideas for changed circumstances

---

*The backlog is where good ideas wait for their time.*
