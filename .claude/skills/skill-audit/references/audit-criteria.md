# Skill Audit Criteria

Full rubric for auditing a skill. Mechanical checks (M-table) are produced by
`scripts/audit_skill.py`; judgment criteria (J1-J10) are evaluated by reading the
skill. Every finding cites an ID from this file.

Sources: Anthropic Agent Skills best practices (platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices),
Claude Code skills docs (code.claude.com/docs/en/skills), anthropics/skills skill-creator.
Compiled 2026-07-03.

## Contents
- Scoring model
- Mechanical checks (script findings reference)
- J1 Description and discovery
- J2 Context economy
- J3 Degrees of freedom
- J4 Progressive disclosure and structure
- J5 Workflows and feedback loops
- J6 Content quality
- J7 Scripts and bundled resources
- J8 Runtime fit and portability
- J9 Security posture
- J10 Testing and evals
- Severity calibration notes

## Scoring model

Score = 100 − Σ deductions, floored at 0. Every finding (mechanical + judgment) deducts by severity:

| Severity | Deduction | Meaning |
|----------|-----------|---------|
| CRITICAL | −25 | Skill fails to load, trigger, or violates a hard spec limit |
| HIGH | −10 | Violates an explicit documented best practice with real context or reliability cost |
| MEDIUM | −4 | Deviates from a recommended pattern; works but degrades efficiency or discoverability |
| LOW | −1 | Polish item |
| INFO | −0 | Observation, no deduction (e.g. intentional Claude Code-only fields) |

Duplicate cause, one deduction: if one root cause produces several findings (e.g. an oversized SKILL.md also lacks reference links), deduct the most severe once and list the rest as evidence.

| Band | Range | Read |
|------|-------|------|
| Exemplary | 90-100 | Reference-quality skill |
| Solid | 75-89 | Works well, visible inefficiencies |
| Needs work | 50-74 | Functional but violates core practices |
| Non-compliant | 0-49 | Restructure before relying on it |

**Ship gate:** score ≥ 90 AND zero CRITICAL/HIGH findings.

## Mechanical checks (script findings reference)

`scripts/audit_skill.py` emits these; do not re-derive them by eye — its line counts, char counts, and link checks are authoritative.

| ID | Sev | Rule |
|----|-----|------|
| S0/S1 | CRITICAL | Skill dir / SKILL.md missing |
| F0 | CRITICAL | Frontmatter missing or unparseable YAML |
| F1/F4 | CRITICAL | Missing name/description; description > 1024 chars; name > 64 chars |
| F2 | HIGH | Name not kebab-case, or contains reserved word (anthropic, claude). Dot-namespaced names (`x.y`) downgrade to MEDIUM: they work in Claude Code but fail the portable spec |
| F3 | MEDIUM | Name ≠ directory name |
| F5 | HIGH | Unknown frontmatter fields (not spec, not Claude Code) |
| F6 | HIGH | Description under 10 words (too vague to trigger) |
| F7 | MEDIUM | No explicit "Use when..." trigger language in description |
| F8 | LOW | First-person description |
| F9 | HIGH | compatibility > 500 chars |
| F10 | INFO | Claude Code-only fields present (fine locally, not API-portable) |
| F11 | MEDIUM | Generic name (helper, utils, tools...) |
| F12 | HIGH | description + when_to_use > 1536 chars (listing truncates) |
| B1/B2 | HIGH | Body > 500 lines / > 5k words |
| B3 | MEDIUM | "When to Use" section in body (body loads AFTER triggering — it can't help discovery) |
| B5 | LOW | Windows-style paths |
| S3 | HIGH | Extraneous docs (README, CHANGELOG, INSTALLATION_GUIDE, QUICK_REFERENCE...) |
| S4 | MEDIUM | references/ or scripts/ nested deeper than one level |
| S5 | LOW | Junk files, empty dirs |
| S6 | INFO | Non-standard top-level dir (evals/ is a legitimate case) |
| L1 | HIGH | SKILL.md links to a bundled file that doesn't exist |
| L2 | MEDIUM | Bundled file never mentioned in SKILL.md (undiscoverable) |
| L3 | MEDIUM | Reference file > 100 lines without a Contents section |
| L4 | MEDIUM | Reference file > 10k words without grep patterns in SKILL.md |

## J1 Description and discovery

The description is the skill's only always-loaded surface. It alone decides triggering.

- **J1.1 (HIGH)** Description missing either half: WHAT the skill does (specific capability) or WHEN to use it (trigger contexts, user phrasings). "Helps with documents" fails; "Extracts text and tables from PDF files... Use when working with PDFs or the user mentions forms" passes.
- **J1.2 (MEDIUM)** Missing the concrete keywords a user would actually say (file extensions, tool names, verbs). Test: write three realistic user requests; would this description match them?
- **J1.3 (MEDIUM)** Not third person, or contains markup/XML. Descriptions are injected into the system prompt; "I can help you..." breaks the pattern.
- **J1.4 (MEDIUM)** Key use case buried at the end. Listings truncate; lead with it.
- **J1.5 (LOW)** Overlaps another installed skill's trigger space without differentiation (say which skill wins when).

## J2 Context economy

The context window is a public good. Body tokens compete with the conversation.

- **J2.1 (HIGH)** Explains things Claude already knows (what a PDF is, how JSON works, generic coding advice). Challenge each paragraph: does it justify its token cost?
- **J2.2 (HIGH)** Same information stated in both SKILL.md and a reference file. One home per fact — prefer the reference; keep only workflow in SKILL.md.
- **J2.3 (MEDIUM)** Verbose explanation where a concise example would do. A 5-line code example beats a 150-token paragraph.
- **J2.4 (MEDIUM)** Scaffolding prose: signposts ("In the next section we will..."), restatements, summaries of what was just said. Delete whole sentences.
- **J2.5 (MEDIUM)** Detail that belongs in a reference file living in the body (variant matrices, full API tables, long examples) when the body is anywhere near its budget.

## J3 Degrees of freedom

Match specificity to fragility: narrow bridge → guardrails (script); open field → heuristics (prose).

- **J3.1 (HIGH)** Offers a menu where a default belongs: "You can use pypdf, pdfplumber, PyMuPDF, or..." → "Use pdfplumber. For OCR, use pytesseract instead." One default + explicit escape hatches.
- **J3.2 (MEDIUM)** Fragile/exact-sequence operation described in prose instead of a script (gets re-derived and mis-derived every run).
- **J3.3 (MEDIUM)** Rigid script or exact template forced onto a task that genuinely needs contextual judgment.
- **J3.4 (LOW)** Parameters/config the skill never varies — hardcode them.

## J4 Progressive disclosure and structure

Three tiers: metadata (always loaded) → body (on trigger) → bundled files (on demand, ~zero until read).

- **J4.1 (HIGH)** Everything crammed in SKILL.md when clear splits exist (by variant, by domain, by advanced-vs-core). The body should be navigation + core workflow.
- **J4.2 (HIGH)** Reference files exist but SKILL.md never says when to read them. Every bundled file needs a link plus a load condition: "For tracked changes, read references/redlining.md."
- **J4.3 (MEDIUM)** Chained references (SKILL.md → a.md → b.md). Claude may preview rather than fully load nested files; keep them one hop from SKILL.md.
- **J4.4 (MEDIUM)** Wrong-direction split: core workflow pushed into a reference while trivia stays in the body. The body must stand alone for the common case.
- **J4.5 (LOW)** Multi-domain skill not organized by domain (forces loading irrelevant context).

## J5 Workflows and feedback loops

- **J5.1 (MEDIUM)** Multi-step process with no numbered sequence or overview near the top of the body.
- **J5.2 (MEDIUM)** Quality-critical output with no feedback loop. Pattern: run validator → fix → re-run → proceed only on pass.
- **J5.3 (MEDIUM)** Branching task with no decision points ("Creating new? → workflow A. Editing? → workflow B.").
- **J5.4 (LOW)** Long checklist the model is meant to track without a copyable checklist block.
- **J5.5 (LOW)** One-shot phrasing for guidance that must persist across the session (skill bodies stay in context; write standing instructions, not one-time steps).

## J6 Content quality

- **J6.1 (HIGH)** Time-sensitive content presented as durable ("before/after version X", "as of March", schedule-dependent claims) with no dated marker or old-patterns section.
- **J6.2 (MEDIUM)** Inconsistent terminology for the same thing (endpoint/URL/route). Pick one term; use it everywhere.
- **J6.3 (MEDIUM)** Abstract placeholder examples where concrete input→output pairs are needed to pin down format or style.
- **J6.4 (LOW)** Non-imperative or vague directives ("you might want to consider...", "handle appropriately", "as needed" with no rule for when) → "Run X when Y".
- **J6.5 (LOW)** Marketing or self-praise prose ("this powerful skill...").

## J7 Scripts and bundled resources

- **J7.1 (HIGH)** Script punts instead of solving: bare exceptions bubbling up to Claude, silent failures, no fallback. Scripts must handle their own error paths.
- **J7.2 (MEDIUM)** Voodoo constants — unexplained magic numbers. Every constant carries a one-line rationale.
- **J7.3 (MEDIUM)** Unstated dependencies: imports a package without listing it, or assumes network access (API skills have none) or pre-installed tools.
- **J7.4 (MEDIUM)** Execute-vs-read intent unclear. "Run scripts/x.py" (output enters context) vs "See scripts/x.py for the algorithm" (code enters context). Say which.
- **J7.5 (LOW)** assets/ content (templates, boilerplate) misplaced in references/, or vice versa. References are read; assets are used.

## J8 Runtime fit and portability

- **J8.1 (MEDIUM)** Claims to target the Claude API but relies on Claude Code-only features (dynamic `!` injection, $ARGUMENTS, hooks, allowed-tools, ${CLAUDE_SKILL_DIR}). API reads only name + description.
- **J8.2 (MEDIUM)** Hardcoded absolute paths or user-specific locations; breaks on any other machine. Use ${CLAUDE_SKILL_DIR} or repo-relative paths, quoted if spaces are possible.
- **J8.3 (LOW)** Claude Code-only fields present but unlabeled in a skill meant for distribution (fine for local use — INFO from script).
- **J8.4 (LOW)** Argument handling absent: skill takes inputs but never mentions $ARGUMENTS/args, leaving invocation ambiguous.

## J9 Security posture

- **J9.1 (HIGH)** Instructs Claude to fetch and follow instructions from external URLs (prompt-injection channel), or exfiltrates data to external services beyond the skill's stated purpose.
- **J9.2 (MEDIUM)** allowed-tools broader than the workflow needs (e.g. blanket Bash when two commands would do).
- **J9.3 (MEDIUM)** Handles sensitive data with no note on where output lands (files, external calls).

## J10 Testing and evals

- **J10.1 (MEDIUM)** No evaluations at all for a skill whose output quality matters (Anthropic recommends 3+ scenarios built BEFORE extensive documentation, with a no-skill baseline).
- **J10.2 (LOW)** Evals exist but no record of a baseline comparison or iteration loop.
- **J10.3 (LOW)** Never tested against the weakest model it claims to support.

## Severity calibration notes

- A finding is CRITICAL only if the skill will not load/trigger or breaches a hard spec number. Everything else caps at HIGH.
- When a practice is violated deliberately and the skill documents why (e.g. an evals/ dir, a >500-line body with a justified reason), downgrade one level and note the justification.
- Small skills (body < 100 lines, no bundled files) skip J4/J5 checks that presuppose scale; do not reward padding a small skill to look structured.
- Do not stack J2 deductions per paragraph. Aggregate per criterion: one J2.1 finding listing the worst instances.
