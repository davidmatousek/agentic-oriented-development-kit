---
name: skill-audit
description: Audits a Claude skill against Anthropic skill best practices and scores it 0-100 with prioritized fixes. Checks frontmatter spec compliance, description trigger quality, context economy and progressive disclosure, structure, bundled scripts, security posture, and content anti-patterns. Use when asked to audit a skill, review a skill, check a skill against best practices, make a skill more token-efficient, or diagnose why a skill is not triggering. Supports --fix to apply safe fixes and --output to save the report.
---

# Skill Audit

Audit a skill (a SKILL.md directory) for best-practice compliance and context efficiency, score it, and deliver prioritized fixes. Two layers: a deterministic scanner for everything mechanical, then a judgment review against the rubric.

## Usage

```
/skill-audit <skill-name-or-path> [--fix] [--output]
/skill-audit --all
```

- `$ARGUMENTS[0]` — skill name (resolved per Step 1) or explicit path to the skill directory
- `--fix` — after reporting, apply the safe fixes (Step 6)
- `--output` — also save the report to `.aod/results/`
- `--all` — bulk triage across every installed skill (see Bulk triage), then full audits on request

## Workflow

1. Locate and inventory the target skill
2. Run the deterministic scanner (`scripts/audit_skill.py`)
3. Judgment review against `references/audit-criteria.md`
4. Score and assemble the report
5. Deliver report (and save if `--output`)
6. If `--fix`: apply safe fixes, re-scan, report before/after

Audit by reading the target's files. Never invoke the target skill — invocation can have side effects and proves nothing about compliance.

### Step 1: Locate and inventory

Resolve a bare name in this order, first hit wins:

1. Explicit path if given
2. `.claude/skills/<name>/` (project)
3. `~/.claude/skills/<name>/` (personal)
4. Search installed plugin skill directories

List every file in the skill directory (`find <dir> -type f`) before judging anything. If the target is in a managed/plugin location, treat it as read-only: audit fully, but `--fix` becomes propose-only.

If the user scoped the audit (a specific concern like "why isn't it triggering" or "cut its token cost"), weight those criteria first and say so in the report. If the request is ambiguous and the session is interactive, ask one or two scoping questions before starting; otherwise run the full rubric.

### Step 2: Deterministic scan

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/audit_skill.py" "<skill-dir>"
```

The JSON output contains mechanical findings (spec limits, structure, broken links, orphans) plus context-cost stats (startup / trigger / full-bundle token estimates). Scanner findings are authoritative for their IDs — do not re-derive counts or link checks by eye. If `python3` is unavailable, perform the M-table checks from the criteria file manually and say so in the report.

### Step 3: Judgment review

Read `references/audit-criteria.md` (the rubric — criteria J1-J10, severities, scoring model), then read the target's SKILL.md fully and every bundled file the criteria require (references for duplication and disclosure checks, scripts for solve-don't-punt and constants, frontmatter against runtime claims).

Evaluate J1-J10. Each violation becomes a finding citing its criterion ID, with evidence (quote or file:line) and a concrete fix. Follow the rubric's aggregation and calibration notes — one finding per root cause, small-skill exemptions, documented-deviation downgrades.

### Step 4: Score

Compute the score exactly as specified in the rubric's Scoring model section (100 minus severity deductions, banded, with the ship gate: ≥90 and zero CRITICAL/HIGH). Merge scanner and judgment findings before scoring.

### Step 5: Report

ALWAYS use this structure:

```markdown
# Skill Audit: {name}

**Score: {NN}/100 — {band}** | Ship gate: {PASS | FAIL}
**Context cost:** {startup} tok at startup / {trigger} tok on trigger / {bundle} tok full bundle
**Scanned:** {file count} files on {date}

## Findings ({N} — {counts by severity})

| Sev | ID | Finding | Fix |
|-----|----|---------|-----|
{all findings, severity order, criterion IDs cited}

## Do these first
{1-3 highest-impact fixes, imperative}

## Keep as-is
{2-4 things the skill already does right, so fixes do not regress them}
```

With `--output`, also save to `.aod/results/{skill-name}_skill-audit_{NNN}.md` (three-digit version, increment from existing reports). Never write the report into the audited skill's directory — that would add the extraneous files this audit flags.

### Step 6: `--fix` mode

Apply only text-safe fixes, highest severity first: frontmatter repairs, description rewrites (show before/after in the report), folding a "When to Use" section into the description, splitting an oversized body into linked reference files, adding Contents sections, linking orphaned files with load conditions, fixing broken paths, deleting junk files (.DS_Store class only).

Propose, never auto-apply: deleting or renaming content files, renaming the skill, changing script logic. List these with rationale for the user to decide.

After applying, re-run the scanner and end with: score before → after, and any findings that remain.

## Bulk triage (`--all` or multiple targets)

The judgment layer needs a deep read per skill, so full audits stay one at a time. For a whole library, run the scanner over every skill in one call:

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/audit_skill.py" .claude/skills/*/ ~/.claude/skills/*/
```

The output ranks skills by `mechanical_score` (100 minus raw mechanical deductions — a triage signal only; judgment findings can lower the real score further). Present the ranking as a table (skill, score, finding IDs, trigger tokens), then offer full audits starting with the worst. If a root does not exist, drop it from the glob rather than failing.

## Limitations

- Scores measure best-practice compliance and context efficiency, not whether the skill actually improves task outcomes — only evals show that (J10, and the hand-offs below).
- Token figures are chars/4 estimates, good for budgets, not billing.
- Judgment findings (J-codes) are calibrated opinions; cite evidence so the author can dispute them.

## Hand-offs

| Situation | Action |
|-----------|--------|
| User wants a new skill built | Use the skill-creator skill |
| Author disputes a finding | Show the criterion text and the evidence; downgrade per the rubric's calibration notes if justified |
| Skill passes but underperforms | Recommend evals (3+ scenarios, no-skill baseline) per J10 |
| Cross-skill pipeline audit (seams in a skill library) | Out of scope for the rubric — audit each skill, then check handoffs: does each skill's output format name what the next skill expects as input? |
