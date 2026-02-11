---
name: ~aod-discover
description: "Unified discovery skill with 3 entry points: /aod.discover (full flow: capture + score + validate), /aod.idea (capture + score only), /aod.validate (PM validation for existing idea). Use this skill when you need to capture ideas, run discovery, validate ideas with PM, generate user stories, log feature requests, or add items to the ideas backlog."
---

# AOD Discover Skill

## Purpose

Unified discovery skill for the AOD Lifecycle's **Discover** stage. Handles idea capture, ICE scoring, evidence gathering, and PM validation with 3 entry points:

- **`/aod.discover`** — Full flow: capture idea + ICE score + evidence + PM validation + user story
- **`/aod.idea`** — Capture only: capture idea + ICE score + evidence (no PM validation)
- **`/aod.validate`** — Validate only: submit existing idea for PM review + user story generation

## Entry Point Detection

Determine the entry point from the invoking command:
- If invoked via `/aod.discover` → run **Full Flow** (Steps 1-8)
- If invoked via `/aod.idea` → run **Capture Only** (Steps 1-5)
- If invoked via `/aod.validate` → run **Validate Only** (Steps 6-8)

## Source of Truth

**GitHub Issues are the sole source of truth for backlog items.** All idea state (ICE scores, status, evidence) is stored in the GitHub Issue body. BACKLOG.md is an auto-generated view regenerated from Issues.

---

## Step 1: Parse Input (Capture + Full Flow)

Extract the idea description from user arguments. If no description is provided, ask the user to describe their idea.

## Step 2: ID Assignment

The GitHub Issue number is the canonical idea ID. There is no separate `IDEA-NNN` numbering scheme.

- The ID is assigned automatically when `gh issue create` runs in Step 5a
- Refer to ideas by their GitHub Issue number using `#NNN` format (e.g., `#42`)
- No scanning, parsing, or incrementing is needed — GitHub handles ID assignment

## Step 3: Capture Source and ICE Score

### Source

Use AskUserQuestion to determine the idea source:

```
Question: "Where did this idea come from?"
Options:
  - Brainstorm: "Generated during a brainstorming or planning session"
  - Customer Feedback: "Reported by a customer or based on user research"
  - Team Idea: "Suggested by a team member during development"
  - User Request: "Directly requested by a user or stakeholder"
```

### ICE Scoring

Present each ICE dimension using AskUserQuestion:

#### Impact — "How much value does this deliver to users?"

```
Options:
  - High (9): "Transformative — significant user value"
  - Medium (6): "Solid improvement — meaningful but incremental"
  - Low (3): "Minor enhancement — small quality-of-life fix"
```

Allow "Other" for custom numeric values (1-10).

#### Confidence — "How sure are we this will succeed?"

```
Options:
  - High (9): "Proven pattern — strong evidence it will work"
  - Medium (6): "Some unknowns — reasonable confidence with gaps"
  - Low (3): "Speculative — significant uncertainty"
```

Allow "Other" for custom numeric values (1-10).

#### Effort (Ease of Implementation) — "How easy is this to build?"

```
Options:
  - High (9): "Days of work — straightforward implementation"
  - Medium (6): "Weeks of work — moderate complexity"
  - Low (3): "Months of work — significant engineering effort"
```

Allow "Other" for custom numeric values (1-10).

**Compute**: ICE Total = Impact + Confidence + Effort (range 3-30)

## Step 4: Evidence Prompt (Capture + Full Flow)

After ICE scoring, prompt the user for evidence supporting this idea.

Use AskUserQuestion:

```
Question: "Who has this problem, and how do you know?"
Header: "Evidence"
Options:
  - Customer Feedback: "Based on direct customer reports, support tickets, or user research"
  - Team Observation: "Noticed by the team during development, testing, or internal usage"
  - Analytics Data: "Supported by usage metrics, error rates, or behavioral analytics"
  - User Request: "Explicitly requested by a user, stakeholder, or partner"
```

Allow "Other" for free-text evidence statements.

**Store the response** as the `evidence` field. This value is used in:
- Step 5a: GitHub Issue body (`## Evidence` section)
- Step 6: PM validation (evidence quality evaluation)
- BACKLOG.md Discover section (Evidence column)

**If the user selects a predefined category**: Store as `"{Category}: {any additional detail}"` if they provide detail, or just `"{Category}"` if not.

**If the user provides free text via "Other"**: Store the full text as-is.

## Step 5: Apply Auto-Defer Gate

Determine status based on ICE total:

- **Total < 12**: Set status to **"Deferred"** (auto-deferred)
- **Total >= 12**: Set status to **"Scoring"**

**If auto-deferred AND entry point is Full Flow (`/aod.discover`)**:
- Create GitHub Issue (Step 5a) and regenerate BACKLOG.md (Step 5b), then **STOP**. Do not proceed to PM validation.
- Display result with guidance:

```
IDEA CAPTURED — AUTO-DEFERRED

ID: #{NNN}
Idea: {description}
Source: {source}
Evidence: {evidence}
ICE Score: {total} (I:{impact} C:{confidence} E:{effort})
Priority Tier: Deferred
Status: Deferred

This idea was auto-deferred (score < 12).
To request PM override: `/aod.validate #{NNN}`
To re-score with new information: `/aod.score #{NNN}`
```

**If auto-deferred AND entry point is Capture Only (`/aod.idea`)**: Create GitHub Issue, display same result, exit.

**If NOT auto-deferred AND entry point is Capture Only (`/aod.idea`)**: Create GitHub Issue, display result and exit:

```
IDEA CAPTURED

ID: #{NNN}
Idea: {description}
Source: {source}
Evidence: {evidence}
Date: {YYYY-MM-DD}
ICE Score: {total} (I:{impact} C:{confidence} E:{effort})
Priority Tier: {tier}
Status: Scoring

Next: Run `/aod.validate #{NNN}` to submit for PM review, or continue capturing ideas with `/aod.idea`.
```

**If NOT auto-deferred AND entry point is Full Flow (`/aod.discover`)**: Continue to Step 5a, then Step 5c.

## Step 5a: GitHub Issue Creation (All Entry Points)

Create a GitHub Issue for lifecycle tracking:

1. Build the issue body using the structured format from `github-lifecycle.sh`:
   ```markdown
   ## Idea

   {idea_description}

   ## ICE Score
   Impact: {impact}, Confidence: {confidence}, Effort: {effort} = **{total}**

   ## Evidence
   {evidence}

   ## Metadata
   - Source: {source}
   - Priority: {priority_tier}
   - Date: {YYYY-MM-DD}
   - Status: {status}
   ```

2. Call `aod_gh_create_issue` (from `.aod/scripts/bash/github-lifecycle.sh`):
   - Title: `{idea_description}` (clean title, no prefix)
   - Body: structured markdown above
   - Stage: `discover`
   - Issue type: `"idea"` (applies `type:idea` label automatically)

3. Capture the returned issue number — this becomes the canonical idea ID (`#NNN`).

4. If `gh` is unavailable, skip silently (graceful degradation).

## Step 5b: Regenerate BACKLOG.md

After GitHub Issue creation, run `.aod/scripts/bash/backlog-regenerate.sh` to update the backlog snapshot. If `gh` is unavailable, skip silently.

## Step 5c: Check Governance Tier (Full Flow only)

Before proceeding to PM validation in the Full Flow (`/aod.discover`), check the governance tier:

1. Read `.aod/memory/constitution.md`
2. Find the governance tier configuration (`governance:` → `tier:` value)
3. Valid values: `light`, `standard`, `full`. Default: `standard`

**If tier is `light`**:
- PM validation is **optional** — skip Steps 6-7 in the Full Flow
- Display note: "Note: Light governance tier — PM validation skipped. Run `/aod.validate #NNN` to manually request PM review."
- Exit. The user can still manually invoke `/aod.validate #NNN` at any time

**If tier is `standard` or `full`**: Continue to Step 6 as normal.

**Note**: The `/aod.validate` entry point always runs PM validation regardless of tier — it is an explicit user request for PM review.

## Step 6: PM Validation (Validate + Full Flow)

### For `/aod.validate` entry point: Parse and find idea

Extract the idea identifier from user arguments. Accept three formats:
- **`NNN`** (bare number, e.g., `21`): Direct GitHub Issue lookup
- **`#NNN`** (hash-prefixed, e.g., `#21`): Strip `#` prefix, direct lookup
- **`IDEA-NNN`** (legacy, e.g., `IDEA-009`): Search issue titles for `[IDEA-NNN]` bracket tag

If invalid or missing, display: `Usage: /aod.validate NNN` (or `#NNN` or `IDEA-NNN`)

Find the matching GitHub Issue:

For numeric input (`NNN` or `#NNN`):
```bash
source .aod/scripts/bash/github-lifecycle.sh && aod_gh_find_issue NNN
```

For legacy `IDEA-NNN` input:
```bash
source .aod/scripts/bash/github-lifecycle.sh && aod_gh_find_issue "[IDEA-NNN]"
```

**Error conditions**:
- Issue not found: `"Error: No GitHub Issue found for {identifier}"`
- Issue already has `stage:define` or later: `"Error: #{issue_number} has already progressed past discovery"`

Read the issue body to extract idea details (description, ICE score, evidence, source, status).

Display idea for review:

```
IDEA FOR PM VALIDATION

ID: #{issue_number}
Idea: {description}
Source: {source}
Evidence: {evidence}
Date: {date}
Status: {status}
ICE Score: {total} (I:{impact} C:{confidence} E:{effort})
Priority Tier: {tier}
Auto-Deferred: {Yes if status is Deferred, otherwise No}
```

### Launch PM Review

Use the Task tool with `product-manager` subagent_type:

```
Review this idea for product backlog inclusion:

Idea: {idea_description}
ICE Score: {total} (I:{impact} C:{confidence} E:{effort})
Priority Tier: {tier}
Current Status: {status}
Auto-Deferred: {yes/no}
Evidence: {evidence}

Evaluate:
1. Does this idea align with the product vision and roadmap?
2. Is the ICE scoring reasonable given the idea description?
3. Does this idea deliver meaningful user value?
4. Should this idea enter the product backlog as a user story?
5. Is the evidence sufficient to justify pursuing this idea? Evaluate the quality and
   specificity of the evidence provided.

If evidence is empty or "No evidence provided", flag this:
"No evidence provided — recommend gathering evidence before proceeding."
You may still approve if the idea has strong merit despite missing evidence, but note
the evidence gap in your rationale.

If auto-deferred (score < 12), provide additional justification for why this idea
should or should not override the auto-defer gate.

Respond with:
STATUS: [APPROVED | REJECTED]
EVIDENCE_QUALITY: [Strong | Adequate | Weak | Missing]
RATIONALE: [Your detailed reasoning — 2-4 sentences]
```

### Handle Rejection

If PM returns **REJECTED**:
1. Update the GitHub Issue: add a comment with PM rejection rationale and update the `Status:` line in the body to "Rejected"
2. Display rejection and exit:

```
PM VALIDATION: REJECTED

ID: #{issue_number}
Idea: {description}
PM Rationale: {rationale}

The idea has been marked as Rejected on GitHub Issue #{issue_number}.
To re-submit: re-score with `/aod.score #{issue_number}`, then run `/aod.validate #{issue_number}` again.
```

### Handle Approval

If PM returns **APPROVED**: Continue to Step 7.

## Step 7: User Story Generation

1. **Generate user story**: Transform idea into "As a [persona], I want [action], so that [benefit]" format.
   - Default persona: "Template Adopter" if not evident from idea.
2. **Present for confirmation**: Use AskUserQuestion:
   ```
   Options:
     - Accept: "Save this user story as-is"
     - Edit: "Let me modify the user story text"
   ```
3. **Determine priority**: Map ICE score to priority rank:
   - P0 (25-30): Priority = 1
   - P1 (18-24): Priority = 2
   - P2 (12-17): Priority = 3
   - Deferred (<12, PM override): Priority = 4

## Step 8: Update GitHub Issue and Report

### Update GitHub Issue

1. Update the GitHub Issue body to include the user story in a new `## User Story` section
2. Update `Status:` in the body to "Validated"
3. Add a comment documenting PM approval with rationale and evidence quality
4. If idea was auto-deferred and PM approved, add PM override note as a comment:
   ```
   **PM Override**: #{issue_number} was auto-deferred (ICE score {total} < 12) but approved by PM. Rationale: {pm_rationale}
   ```

### Regenerate BACKLOG.md

Run `.aod/scripts/bash/backlog-regenerate.sh` to update the backlog snapshot.

### Report result

**For `/aod.validate` entry point**:
```
PM VALIDATION: APPROVED

ID: #{issue_number}
Idea: {description}
Evidence Quality: {evidence_quality}
PM Rationale: {rationale}

User Story Created:
  Story: "{user_story_text}"
  Priority: {priority}
  Status: Validated

GitHub Issue #{issue_number} updated with user story and PM approval.

Next: Run `/aod.define {topic}` to create a PRD from this user story.
```

**For `/aod.discover` entry point (full flow)**:
```
AOD DISCOVERY COMPLETE

Idea Captured:
  ID: #{issue_number}
  Description: {description}
  Source: {source}
  Evidence: {evidence}

ICE Scoring:
  Score: {total} (I:{impact} C:{confidence} E:{effort})
  Priority Tier: {tier}

PM Validation: APPROVED
  Evidence Quality: {evidence_quality}
  Rationale: {rationale}

User Story Created:
  Story: "{user_story_text}"
  Priority: {priority}
  Status: Validated

Next: Run `/aod.define {topic}` to create a PRD from this user story.
```

---

## ICE Scoring Reference

### Quick-Assessment Anchors

| Dimension | High (9) | Medium (6) | Low (3) |
|-----------|----------|------------|---------|
| **Impact** | Transformative | Solid improvement | Minor enhancement |
| **Confidence** | Proven pattern | Some unknowns | Speculative |
| **Effort (Ease)** | Days of work | Weeks of work | Months of work |

### Priority Tiers

| Score Range | Priority | Action |
|-------------|----------|--------|
| 25-30 | P0 (Critical) | Fast-track to development |
| 18-24 | P1 (High) | Queue for next sprint |
| 12-17 | P2 (Medium) | Consider when capacity allows |
| < 12 | Deferred | Auto-defer; requires PM override via `/aod.validate` |

### Auto-Defer Gate

Ideas scoring below 12 are automatically deferred. In the full flow (`/aod.discover`), the flow stops and no PM validation occurs. Use `/aod.validate #NNN` to request PM override for deferred ideas.

---

## Edge Cases

- **No description provided**: Prompt user for idea description
- **Custom ICE score outside 1-10**: Clamp to valid range (1 minimum, 10 maximum)
- **Duplicate idea text**: Allow it — GitHub assigns a unique issue number automatically
- **Issue not found** (validate): Search GitHub Issues by number, display error if not found
- **Already Rejected** (validate): Cannot re-validate directly — user must re-score first with `/aod.score`
- **Already past discovery** (validate): Cannot re-validate — idea has progressed
- **PM timeout or error**: Report the error and suggest retrying
- **User edits story to empty string**: Re-prompt for user story text
- **PM approves auto-deferred idea**: Document override rationale as GitHub Issue comment
- **Auto-deferred in full flow**: Flow stops — no PM validation, no user story
- **`gh` unavailable**: Skip GitHub Issue creation silently (graceful degradation)

## Quality Checklist

- [ ] Entry point correctly detected (discover/idea/validate)
- [ ] Idea ID is the GitHub Issue number (`#NNN`), assigned by `gh issue create`
- [ ] Source captured from user selection
- [ ] Evidence prompted after ICE scoring (predefined categories + free text)
- [ ] Evidence included in GitHub Issue body and display outputs
- [ ] ICE score computed correctly (additive I+C+E)
- [ ] Auto-defer gate applied (< 12 = Deferred, flow stops in full flow)
- [ ] GitHub Issue created with structured body, `stage:discover` label, and `type:idea` label
- [ ] BACKLOG.md regenerated after Issue creation
- [ ] Governance tier read from constitution (light/standard/full, default: standard)
- [ ] Light tier: PM validation skipped in full flow, with note to user
- [ ] PM validation includes evidence quality evaluation (Strong/Adequate/Weak/Missing)
- [ ] PM validation invoked via Task tool (product-manager subagent)
- [ ] Rejection: GitHub Issue updated, flow exits
- [ ] Approval: User story generated in proper format
- [ ] User story presented for confirmation
- [ ] GitHub Issue updated with user story and PM approval
- [ ] PM override documented if idea was auto-deferred
- [ ] BACKLOG.md regenerated after validation
- [ ] Result reported with next step guidance
