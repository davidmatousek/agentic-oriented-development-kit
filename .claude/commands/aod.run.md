---
description: Run the full AOD lifecycle orchestrator — chains all 5 stages (Discover → Define → Plan → Build → Deliver) with session-resilient state and governance gates
---

## User Input

```text
$ARGUMENTS
```

## Overview

Single-command lifecycle orchestrator. Accepts 4 input modes and delegates to the `~aod-run` skill.

**Usage**: `/aod.run <idea | #NNN | --resume | --status>`

**Entry Points**:

| Command | Mode | What It Does |
|---------|------|-------------|
| `/aod.run "Add dark mode toggle"` | New idea | Starts full lifecycle at Discover stage |
| `/aod.run #22` or `/aod.run 22` | Issue | Reads GitHub Issue, resumes from current stage |
| `/aod.run --resume` | Resume | Continues from last state checkpoint on disk |
| `/aod.run --status` | Status | Read-only display of current orchestration state |
| `/aod.run --status #22` | Status | Inferred status for a specific issue (no state file needed) |

**State File**: `.aod/run-state.json` — persisted after every stage transition for session resilience.

**Skill Reference**: `.claude/skills/~aod-run/SKILL.md` — full orchestration logic.

## Step 1: Parse Input Mode

Read `$ARGUMENTS` and determine the entry mode:

1. **Status mode**: Arguments start with `--status`
   - If followed by `#NNN` or `NNN`: set mode = `status`, issue = NNN
   - If no number: set mode = `status`, issue = null

2. **Resume mode**: Arguments equal `--resume`
   - Set mode = `resume`

3. **Issue mode**: Arguments match `#NNN` or are a bare number `NNN` (1-4 digits)
   - Set mode = `issue`, issue = NNN (strip `#` prefix if present)

4. **New idea mode**: Arguments are a quoted or unquoted text string (anything else)
   - Set mode = `idea`, idea = the full argument text (strip surrounding quotes if present)

5. **No arguments**: Display usage help and exit:
   ```
   Usage: /aod.run <idea | #NNN | --resume | --status>

   Examples:
     /aod.run "Add dark mode toggle"    Start new lifecycle from idea
     /aod.run #22                        Resume from GitHub Issue #22
     /aod.run --resume                   Continue from last checkpoint
     /aod.run --status                   View current orchestration state
     /aod.run --status #22               View status for issue #22

   Lifecycle stages: Discover → Define → Plan (spec → plan → tasks) → Build → Deliver
   Governance gates pause at each stage boundary for Triad sign-offs.
   State is persisted to .aod/run-state.json for session resilience.
   ```

## Step 2: Invoke Orchestrator Skill

Use the Skill tool to invoke `~aod-run` with the parsed mode and arguments:

- Pass the determined mode (`idea`, `issue`, `resume`, `status`) and relevant data (idea text, issue number) as context in the skill invocation
- The skill handles all orchestration logic, state management, and stage delegation

Format the invocation as:
```
Mode: {mode}
Issue: {issue_number or "none"}
Idea: {idea_text or "none"}
```

The `~aod-run` skill will take over from here.

## Expected Behavior by Mode

### New Idea (`"text"`)
1. Creates initial state file with `current_stage: "discover"`
2. Chains through: Discover → Define → Plan → Build → Deliver
3. Pauses at governance gates for Triad sign-offs
4. On session overflow: state is on disk, resume with `--resume`

### Issue (`#NNN`)
1. Reads GitHub Issue labels to detect current stage
2. Scans disk for existing artifacts (PRD, spec, plan, tasks)
3. Creates state file with completed stages pre-filled
4. Resumes from the first incomplete stage

### Resume (`--resume`)
1. Reads `.aod/run-state.json` and validates schema
2. Checks artifact consistency (warns if files are missing)
3. Detects stale state (>7 days) and asks for confirmation
4. Continues from the last completed stage boundary

### Status (`--status`)
1. Read-only display — never modifies state or artifacts
2. Shows stage map, feature name, governance gate results
3. With `#NNN`: infers status from GitHub label + disk artifacts if no state file
