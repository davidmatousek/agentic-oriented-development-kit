---
name: aod-plan
description: Plan stage router that auto-detects artifact state and delegates to the correct sub-step (/aod.spec, /aod.project-plan, or /aod.tasks) without the user needing to remember the sequence. Use this skill when you need to navigate the Plan stage, auto-route plan commands, or determine which planning sub-step comes next.
---

# Plan Stage Router Skill

## Purpose

Stateless router that reads frontmatter from spec.md, plan.md, and tasks.md to determine which Plan sub-step to invoke next. Reduces cognitive load by auto-detecting progress through the Plan stage's 3 sub-steps.

## How It Works

### Step 1: Determine Feature Context

1. Get branch: `git branch --show-current` → extract NNN prefix
2. Derive specs directory: `specs/{NNN}-*/`
3. If no specs directory found, check `.aod/spec.md` as fallback
4. If no feature context found: warn and suggest `/aod.define` first

### Step 2: Read Artifact States

For each artifact (spec.md, plan.md, tasks.md), determine its approval status:

1. **Check file existence** — if file cannot be read (missing, permissions, encoding), treat as "does not exist"
2. **Parse YAML frontmatter** — extract the `triad:` block between `---` delimiters
3. **Extract sign-off status** — read `triad.{role}_signoff.status` for the required reviewers

### Step 3: Evaluate Frontmatter (with error handling)

For each artifact file, apply these rules in order:

1. **File does not exist** → status = `missing`
2. **File exists but has no `---` frontmatter delimiters** → status = `not_approved`, emit: "Note: {file} has no frontmatter. Running {sub-step} for review."
3. **File has frontmatter but no `triad:` key** → status = `not_approved`, emit: "Note: {file} frontmatter missing triad block. Running {sub-step} for review."
4. **`triad:` exists but required sign-off field is null or missing** → status = `not_approved`
5. **Sign-off status is not a recognized value** → status = `not_approved`, emit: "Warning: Unexpected status '{value}' in {file}. Re-running {sub-step}."
6. **YAML parse error** → status = `not_approved`, emit: "Warning: Could not parse frontmatter in {file}. Re-running {sub-step}."

**Recognized approved statuses**: `APPROVED`, `APPROVED_WITH_CONCERNS`, `BLOCKED_OVERRIDDEN`

### Step 3b: Read Governance Tier

Read `.aod/memory/constitution.md` and extract the governance tier:

1. Look for the `## Governance Tiers` section
2. Find the configuration block: `governance:` → `tier:` value
3. Valid values: `light`, `standard`, `full`
4. If not found or invalid: default to `standard`

**Tier affects Step 4 decision table** — specifically the spec PM sign-off check.

### Step 4: Apply Decision Table

**Standard and Full tiers** (default behavior):

| spec.md exists? | spec PM approved? | plan.md exists? | plan dual-approved? | tasks.md exists? | tasks triple-approved? | Action |
|-----------------|-------------------|-----------------|---------------------|------------------|------------------------|--------|
| No | — | — | — | — | — | Invoke `/aod.spec` |
| Yes | No | — | — | — | — | Invoke `/aod.spec` (needs PM sign-off) |
| Yes | Yes | No | — | — | — | Invoke `/aod.project-plan` |
| Yes | Yes | Yes | No | — | — | Invoke `/aod.project-plan` (needs dual sign-off) |
| Yes | Yes | Yes | Yes | No | — | Invoke `/aod.tasks` |
| Yes | Yes | Yes | Yes | Yes | No | Invoke `/aod.tasks` (needs triple sign-off) |
| Yes | Yes | Yes | Yes | Yes | Yes | Report "Plan stage complete" |

**Light tier** (reduced gates):

| spec.md exists? | plan.md exists? | plan dual-approved? | tasks.md exists? | tasks triple-approved? | Action |
|-----------------|-----------------|---------------------|------------------|------------------------|--------|
| No | — | — | — | — | Invoke `/aod.spec` |
| Yes | No | — | — | — | Invoke `/aod.project-plan` (skip PM spec sign-off) |
| Yes | Yes | No | — | — | Invoke `/aod.project-plan` (needs dual sign-off) |
| Yes | Yes | Yes | No | — | Invoke `/aod.tasks` |
| Yes | Yes | Yes | Yes | No | Invoke `/aod.tasks` (needs triple sign-off) |
| Yes | Yes | Yes | Yes | Yes | Report "Plan stage complete" |

In Light tier, when spec.md exists but has no PM sign-off, the router **skips** the PM spec sign-off check and proceeds directly to `/aod.project-plan`. Emit: "Note: Light governance tier — PM spec sign-off skipped."

**Full tier** uses the same table as Standard. The difference between Standard and Full is that Full requires a **separate** PM spec sign-off step (the PM reviews spec.md independently before plan creation). This distinction is enforced within `/aod.spec` itself, not in the router.

**Approval checks per artifact**:
- **spec.md** (Standard/Full): `triad.pm_signoff.status` is approved
- **spec.md** (Light): existence is sufficient — PM sign-off not required
- **plan.md**: `triad.pm_signoff.status` AND `triad.architect_signoff.status` are both approved
- **tasks.md**: `triad.pm_signoff.status` AND `triad.architect_signoff.status` AND `triad.techlead_signoff.status` are all approved

**Invariant**: Triple sign-off on tasks.md is the governance floor for ALL tiers, including Light.

### Step 5: Execute or Report

Based on decision table result:

- **Invoke sub-command**: Use the Skill tool to invoke the appropriate skill (`aod.spec`, `aod.project-plan`, or `aod.tasks`)
- **Plan stage complete**: Display completion message:
  ```
  Plan stage complete.

  All artifacts approved:
  - spec.md: PM sign-off ✓
  - plan.md: PM + Architect sign-off ✓
  - tasks.md: PM + Architect + Team-Lead sign-off ✓

  Next: Run /aod.build to start implementation.
  ```

## Edge Cases

### No PRD exists
If the user runs `/aod.plan` but there is no approved PRD for the current feature (no `docs/product/02_PRD/{NNN}-*.md`), warn:
```
No approved PRD found for this feature.

The Plan stage requires a PRD as input. Run /aod.define first to create one,
then return to /aod.plan.
```

### Direct sub-command invocation
The router does NOT block direct invocation of `/aod.spec`, `/aod.project-plan`, or `/aod.tasks`. Those commands work independently — the router is a convenience layer, not a gatekeeper.

### Re-run after rejection
If a governance gate rejects (e.g., PM requests changes to spec.md), the user fixes issues and re-runs `/aod.plan`. The router detects the missing/rejected sign-off and re-invokes the correct sub-step.

## Integration

### Reads
- `specs/{NNN}-*/spec.md` — check existence and PM sign-off
- `specs/{NNN}-*/plan.md` — check existence and dual sign-off
- `specs/{NNN}-*/tasks.md` — check existence and triple sign-off
- `docs/product/02_PRD/{NNN}-*.md` — check PRD existence (edge case)

### Invokes
- `/aod.spec` — when spec needs creation or PM approval
- `/aod.project-plan` — when plan needs creation or dual approval
- `/aod.tasks` — when tasks need creation or triple approval

### Updates
- None (stateless router — reads only)
