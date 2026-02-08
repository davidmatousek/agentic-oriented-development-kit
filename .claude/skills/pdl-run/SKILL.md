---
name: pdl-run
description: "Full product discovery flow in one command — captures idea, scores with ICE, validates with PM, and adds to product backlog. Use this skill when you need to run complete discovery, evaluate a new idea end-to-end, or go from raw idea to backlog-ready in one step."
---

# PDL Full Discovery Flow Skill

## Purpose

Execute the complete Product Discovery Lifecycle in a single flow: capture an idea, score it with ICE, validate with PM, and (on approval) add a user story to the product backlog. All logic is inlined — this skill does NOT invoke other skills via the Skill tool.

## Inputs

- **Idea description**: Natural language description of the feature idea (from user arguments)

## Workflow

### Step 1: Auto-Create Backlog Files

Check if `docs/product/_backlog/01_IDEAS.md` exists. If not, create it with the table header:

```markdown
# Ideas Backlog

| ID | Idea | Source | Date | Status | ICE Score |
|----|------|--------|------|--------|-----------|
```

Check if `docs/product/_backlog/02_USER_STORIES.md` exists. If not, create it with:

```markdown
# Product Backlog - User Stories

| Priority | Story ID | Story | ICE Score | Source | Status |
|----------|----------|-------|-----------|--------|--------|
```

### Step 2: Capture Idea (Inlined from pdl-idea)

1. **Parse input**: Extract idea description from user arguments. If empty, ask the user to describe their idea.
2. **Generate IDEA-NNN ID**: Read `01_IDEAS.md`, find highest IDEA-NNN, increment by 1 (pad to 3 digits). Start at IDEA-001 if empty.
3. **Capture source**: Use AskUserQuestion:
   ```
   Question: "Where did this idea come from?"
   Options:
     - Brainstorm: "Generated during a brainstorming or planning session"
     - Customer Feedback: "Reported by a customer or based on user research"
     - Team Idea: "Suggested by a team member during development"
     - User Request: "Directly requested by a user or stakeholder"
   ```

### Step 3: ICE Scoring (Inlined from pdl-idea)

Present each ICE dimension using AskUserQuestion:

#### Impact — "How much value does this deliver to users?"

```
Options:
  - High (9): "Transformative — significant user value"
  - Medium (6): "Solid improvement — meaningful but incremental"
  - Low (3): "Minor enhancement — small quality-of-life fix"
```

#### Confidence — "How sure are we this will succeed?"

```
Options:
  - High (9): "Proven pattern — strong evidence it will work"
  - Medium (6): "Some unknowns — reasonable confidence with gaps"
  - Low (3): "Speculative — significant uncertainty"
```

#### Effort (Ease of Implementation) — "How easy is this to build?"

```
Options:
  - High (9): "Days of work — straightforward implementation"
  - Medium (6): "Weeks of work — moderate complexity"
  - Low (3): "Months of work — significant engineering effort"
```

Allow "Other" for custom numeric values (1-10) on each dimension.

Compute total: **ICE Total = Impact + Confidence + Effort** (range 3-30).

### Step 4: Auto-Defer Gate

Determine status and append to Ideas Backlog:

- **If total < 12**: Set status to "Deferred", append row to `01_IDEAS.md`, then **STOP the flow**:

```
IDEA CAPTURED — AUTO-DEFERRED

ID: IDEA-{NNN}
Idea: {description}
Source: {source}
ICE Score: {total} (I:{impact} C:{confidence} E:{effort})
Priority Tier: Deferred
Status: Deferred

This idea was auto-deferred (score < 12).
To request PM override: `/pdl.validate IDEA-{NNN}`
To re-score with new information: `/pdl.score IDEA-{NNN}`
```

**Do not proceed to PM validation.** Exit the flow here.

- **If total >= 12**: Set status to "Scoring", append row to `01_IDEAS.md`, continue to Step 5.

### Step 5: PM Validation (Inlined from pdl-validate)

Launch PM review using the Task tool with `product-manager` subagent_type:

```
Review this idea for product backlog inclusion:

Idea: {idea_description}
ICE Score: {total} (I:{impact} C:{confidence} E:{effort})
Priority Tier: {tier}
Current Status: Scoring
Auto-Deferred: No

Evaluate:
1. Does this idea align with the product vision and roadmap?
2. Is the ICE scoring reasonable given the idea description?
3. Does this idea deliver meaningful user value?
4. Should this idea enter the product backlog as a user story?

Respond with:
STATUS: [APPROVED | REJECTED]
RATIONALE: [Your detailed reasoning — 2-4 sentences]
```

**If PM REJECTS**:
1. Update idea status to "Rejected" in `01_IDEAS.md`
2. Display rejection result and exit:

```
PM VALIDATION: REJECTED

ID: IDEA-{NNN}
PM Rationale: {rationale}

Idea status updated to "Rejected" in 01_IDEAS.md.
```

**If PM APPROVES**: Continue to Step 6.

### Step 6: User Story Generation (Inlined from pdl-validate)

1. **Generate user story**: Transform idea into "As a [persona], I want [action], so that [benefit]" format.
   - Default persona: "Template Adopter" if not evident from idea.
2. **Present for confirmation**: Use AskUserQuestion:
   ```
   Options:
     - Accept: "Save this user story as-is"
     - Edit: "Let me modify the user story text"
   ```
3. **Generate US-NNN ID**: Read `02_USER_STORIES.md`, find highest US-NNN, increment by 1 (pad to 3 digits). Start at US-001 if empty.
4. **Determine priority**: Map ICE score to priority rank (P0→1, P1→2, P2→3).
5. **Append to 02_USER_STORIES.md**:
   ```
   | {priority} | US-{NNN} | {user_story_text} | {ice_total} | IDEA-{NNN} | Ready for PRD |
   ```
6. **Update idea status** to "Validated" in `01_IDEAS.md`.

### Step 7: Report Complete Flow Summary

```
PDL DISCOVERY COMPLETE

Idea Captured:
  ID: IDEA-{NNN}
  Description: {description}
  Source: {source}

ICE Scoring:
  Score: {total} (I:{impact} C:{confidence} E:{effort})
  Priority Tier: {tier}

PM Validation: APPROVED
  Rationale: {rationale}

User Story Created:
  ID: US-{NNN}
  Story: "{user_story_text}"
  Priority: {priority}
  Status: Ready for PRD

Next: Run `/triad.prd {topic}` to create a PRD from this user story.
```

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
| < 12 | Deferred | Auto-defer; requires PM override via `/pdl.validate` |

### Auto-Defer Gate

Ideas scoring below 12 are automatically deferred and the flow STOPS. The user must explicitly run `/pdl.validate IDEA-NNN` to request PM override.

## Edge Cases

- **Empty idea description**: Prompt user for description before proceeding
- **Auto-deferred**: Flow stops after Step 4 — no PM validation, no user story
- **PM rejects**: Flow stops after Step 5 — no user story created
- **User edits story to empty**: Re-prompt for user story text
- **Custom ICE score outside 1-10**: Clamp to valid range (1 minimum, 10 maximum)
- **Backlog files missing**: Auto-create with headers (Step 1)

## Quality Checklist

- [ ] Backlog files auto-created if missing
- [ ] Idea captured with IDEA-NNN ID, source, and ICE score
- [ ] Auto-defer gate stops flow for score < 12 with guidance
- [ ] PM validation invoked via Task tool (product-manager subagent)
- [ ] Rejection stops flow and updates idea status
- [ ] Approval generates user story in proper format
- [ ] User story presented for confirmation before saving
- [ ] US-NNN ID generated and row appended to 02_USER_STORIES.md
- [ ] Idea status updated to Validated on approval
- [ ] Complete flow summary displayed with next step
