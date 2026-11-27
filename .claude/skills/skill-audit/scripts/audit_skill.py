#!/usr/bin/env python3
"""Deterministic skill audit: mechanical best-practice checks for a Claude skill.

Checks only what is mechanically decidable (spec limits, structure, links,
size budgets). Qualitative judgment (description quality, degrees of freedom,
anti-pattern prose) is the calling agent's job, guided by
references/audit-criteria.md.

Usage:
    python3 audit_skill.py <skill-directory>            # full JSON: findings + stats
    python3 audit_skill.py <dir> <dir> ...              # bulk triage: ranked summary per skill

Output: findings + stats (single) or ranked summary (bulk).
Exit codes: 2 = critical findings anywhere, 1 = high, 0 = clean/medium/low.
No third-party dependencies required (PyYAML used if available, fallback parser otherwise).
"""

import json
import re
import sys
from pathlib import Path

# --- Spec constants (source: Anthropic skill spec / skill-creator validator) ---
NAME_MAX = 64
DESC_MAX = 1024
COMPAT_MAX = 500
BODY_LINE_LIMIT = 500          # skill-creator: "keep SKILL.md under 500 lines"
BODY_WORD_LIMIT = 5000         # progressive disclosure: body loaded on trigger < 5k words
REF_TOC_LINE_THRESHOLD = 100   # reference files > 100 lines should carry a TOC
REF_GREP_WORD_THRESHOLD = 10000  # files > 10k words need grep patterns in SKILL.md
CHARS_PER_TOKEN = 4            # rough token estimate

# Portable fields per the Anthropic skill spec (API uses only name + description).
PORTABLE_FIELDS = {"name", "description", "license", "metadata", "compatibility", "version", "allowed-tools"}
# Claude Code additionally supports these (valid, but not portable to API/other runtimes).
CLAUDE_CODE_FIELDS = {
    "when_to_use", "argument-hint", "arguments", "model", "effort", "context", "agent",
    "hooks", "paths", "shell", "user-invocable", "disable-model-invocation",
    "disallowed-tools", "mode",
}
COMBINED_DISCOVERY_MAX = 1536  # description + when_to_use budget in the skill listing
NAME_RESERVED = ("anthropic", "claude")
VAGUE_NAMES = {"helper", "utils", "tools", "documents", "data", "files", "skill", "misc"}

# Keep in sync with references/audit-criteria.md "Scoring model" (the SSOT).
# mechanical_score = 100 - raw mechanical deductions: a triage signal for ranking,
# NOT the final score (that adds judgment findings and duplicate-cause dedup).
SEVERITY_DEDUCTION = {"CRITICAL": 25, "HIGH": 10, "MEDIUM": 4, "LOW": 1, "INFO": 0}

EXTRANEOUS_FILES = {
    "readme.md", "changelog.md", "installation_guide.md", "installation.md",
    "quick_reference.md", "quickstart.md", "contributing.md", "todo.md",
    "notes.md", "license.md",  # license belongs in frontmatter `license:` or a LICENSE file at repo level
}
JUNK_FILES = {".ds_store", "thumbs.db", "desktop.ini"}
STANDARD_DIRS = {"scripts", "references", "assets"}


def estimate_tokens(text: str) -> int:
    return max(1, len(text) // CHARS_PER_TOKEN)


def parse_frontmatter(text: str):
    """Return (dict|None, error|None, raw_block|None)."""
    if not text.startswith("---"):
        return None, "SKILL.md does not start with YAML frontmatter (---)", None
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n?", text, re.DOTALL)
    if not m:
        return None, "Frontmatter opened with --- but never closed", None
    block = m.group(1)
    try:
        import yaml  # type: ignore
        data = yaml.safe_load(block)
        if not isinstance(data, dict):
            return None, "Frontmatter is not a YAML mapping", block
        return data, None, block
    except ImportError:
        pass
    except Exception as e:  # yaml parse error
        return None, f"Invalid YAML in frontmatter: {e}", block
    # Fallback: minimal key: value parser (top-level keys only)
    data = {}
    current_key = None
    for line in block.splitlines():
        if re.match(r"^\s", line) and current_key:
            data[current_key] = str(data.get(current_key, "")) + " " + line.strip()
            continue
        kv = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if kv:
            current_key = kv.group(1)
            data[current_key] = kv.group(2).strip().strip("'\"")
    if not data:
        return None, "Could not parse frontmatter (no keys found)", block
    return data, None, block


class Audit:
    def __init__(self, skill_dir: Path):
        self.dir = skill_dir
        self.findings = []
        self.stats = {"skill_dir": str(skill_dir), "files": []}

    def add(self, fid, severity, category, message, evidence=None, fix=None):
        self.findings.append({
            "id": fid, "severity": severity, "category": category,
            "message": message, "evidence": evidence, "fix": fix,
        })

    # ---------- checks ----------

    def run(self):
        if not self.dir.is_dir():
            self.add("S0", "CRITICAL", "structure", f"Skill directory not found: {self.dir}")
            return self
        skill_md = self.dir / "SKILL.md"
        if not skill_md.exists():
            self.add("S1", "CRITICAL", "structure", "SKILL.md not found (required)",
                     fix="Create SKILL.md with YAML frontmatter (name, description) and body instructions")
            return self

        text = skill_md.read_text(encoding="utf-8", errors="replace")
        fm, err, block = parse_frontmatter(text)
        body = text[len(re.match(r"^---\s*\n.*?\n---\s*\n?", text, re.DOTALL).group(0)):] if (block is not None and err is None) else text

        if err:
            self.add("F0", "CRITICAL", "frontmatter", err,
                     fix="Frontmatter must be a valid YAML mapping delimited by --- lines")
            fm = fm or {}

        self.check_frontmatter(fm or {})
        self.check_body(body, skill_md)
        self.check_tree()
        self.check_links_and_orphans(text)
        self.collect_stats(text, body, fm or {})
        return self

    def check_frontmatter(self, fm: dict):
        name = fm.get("name")
        desc = fm.get("description")

        if not name:
            self.add("F1", "CRITICAL", "frontmatter", "Missing required field: name")
        elif isinstance(name, str):
            n = name.strip()
            if re.match(r"^[a-z0-9.-]+$", n) and "." in n:
                # dot-namespacing works in Claude Code but fails the portable spec ([a-z0-9-] only)
                self.add("F2", "MEDIUM", "portability",
                         f"Name '{n}' uses dots — valid in Claude Code, rejected by the portable spec and marketplace validators",
                         fix="Keep if the skill stays local to Claude Code; rename with hyphens before distributing")
            elif not re.match(r"^[a-z0-9-]+$", n) or n.startswith("-") or n.endswith("-") or "--" in n:
                self.add("F2", "HIGH", "frontmatter",
                         f"Name '{n}' is not valid kebab-case (lowercase letters, digits, single hyphens)",
                         fix="Rename to kebab-case, e.g. 'processing-pdfs'")
            if len(n) > NAME_MAX:
                self.add("F2", "CRITICAL", "frontmatter", f"Name exceeds {NAME_MAX} chars ({len(n)})")
            for word in NAME_RESERVED:
                if word in n.lower():
                    self.add("F2", "HIGH", "frontmatter",
                             f"Name contains reserved word '{word}' (disallowed by the spec)",
                             fix="Rename without the reserved word")
            if n in VAGUE_NAMES:
                self.add("F11", "MEDIUM", "frontmatter",
                         f"Name '{n}' is generic — provides no discovery signal",
                         fix="Use a specific name, ideally gerund form (e.g. 'processing-pdfs')")
            if n != self.dir.name:
                self.add("F3", "MEDIUM", "frontmatter",
                         f"Name '{n}' does not match directory name '{self.dir.name}'",
                         fix="Make frontmatter name and folder name identical")

        if not desc:
            self.add("F4", "CRITICAL", "frontmatter", "Missing required field: description",
                     fix="Add a third-person description covering what the skill does AND when to use it")
        elif isinstance(desc, str):
            d = desc.strip()
            if len(d) > DESC_MAX:
                self.add("F4", "CRITICAL", "frontmatter", f"Description exceeds {DESC_MAX} chars ({len(d)})",
                         fix="Trim below 1024 chars; move detail into the body")
            if "<" in d or ">" in d:
                self.add("F4", "HIGH", "frontmatter", "Description contains angle brackets (< or >), which break the spec")
            wc = len(d.split())
            if wc < 10:
                self.add("F6", "HIGH", "description",
                         f"Description is only {wc} words — too vague to trigger reliably",
                         evidence=d,
                         fix="State what the skill does + concrete 'Use when...' triggers (target 30-80 words)")
            if not re.search(r"\b([Uu]se (this skill |it )?(when|for|before|after|instead)|[Rr]un (when|before|after)|[Tt]rigger|[Ww]hen (the )?users?\b|[Ww]hen (asked|you)\b|should be used when)\b", d):
                self.add("F7", "MEDIUM", "description",
                         "Description has no explicit 'when to use' trigger language",
                         fix="Append 'Use when ...' with the user phrasings that should activate the skill")
            # strip double-quoted spans first: trigger examples like "study my voice" are user
            # utterances, not skill voice (single quotes skipped — possessives like Matousek's break pairing)
            unquoted = re.sub(r"[\"“][^\"”]*[\"”]", "", d)
            if re.search(r"\b(I|me|my|we|our)\b", unquoted):
                self.add("F8", "LOW", "description",
                         "Description uses first person — spec recommends third person",
                         fix="Rewrite in third person ('Analyzes...', 'Use when...')")

        combined = len(str(desc or "")) + len(str(fm.get("when_to_use", "") or ""))
        if combined > COMBINED_DISCOVERY_MAX:
            self.add("F12", "HIGH", "description",
                     f"description + when_to_use is {combined} chars (listing budget {COMBINED_DISCOVERY_MAX}) — will be truncated",
                     fix="Trim so the combined discovery text fits the budget; lead with the key use case")

        compat = fm.get("compatibility")
        if compat is not None and isinstance(compat, str) and len(compat) > COMPAT_MAX:
            self.add("F9", "HIGH", "frontmatter", f"compatibility exceeds {COMPAT_MAX} chars ({len(compat)})")

        unknown = set(fm.keys()) - PORTABLE_FIELDS - CLAUDE_CODE_FIELDS
        if unknown:
            self.add("F5", "HIGH", "frontmatter",
                     f"Unknown frontmatter field(s): {', '.join(sorted(unknown))}",
                     fix=f"Remove or move under metadata:. Portable fields: {', '.join(sorted(PORTABLE_FIELDS))}")
        cc_only = set(fm.keys()) & CLAUDE_CODE_FIELDS
        if cc_only:
            self.add("F10", "INFO", "frontmatter",
                     f"Claude Code-only field(s) (fine in Claude Code, not portable to other runtimes): {', '.join(sorted(cc_only))}")

    def check_body(self, body: str, skill_md: Path):
        lines = body.splitlines()
        words = len(body.split())
        if len(lines) > BODY_LINE_LIMIT:
            self.add("B1", "HIGH", "context-economy",
                     f"SKILL.md body is {len(lines)} lines (limit {BODY_LINE_LIMIT})",
                     fix="Move detail into references/ files linked from SKILL.md (progressive disclosure)")
        if words > BODY_WORD_LIMIT:
            self.add("B2", "HIGH", "context-economy",
                     f"SKILL.md body is {words} words (guideline < {BODY_WORD_LIMIT})",
                     fix="Split variant/detail content into references/")
        m = re.search(r"^#{1,4}\s*(When to [Uu]se|When [Nn]ot to [Uu]se).*$", body, re.MULTILINE)
        if m:
            self.add("B3", "MEDIUM", "description",
                     f"Body contains a '{m.group(1)}' section — the body only loads AFTER triggering, so this can't help Claude decide to use the skill",
                     evidence=m.group(0),
                     fix="Fold triggering conditions into the frontmatter description; delete the body section")
        if re.search(r"[A-Za-z]:\\\\|[A-Za-z]:\\[A-Za-z]", body):
            self.add("B5", "LOW", "portability", "Windows-style paths found in body",
                     fix="Use forward-slash relative paths")

    def check_tree(self):
        for p in sorted(self.dir.rglob("*")):
            rel = p.relative_to(self.dir)
            if p.is_file():
                base = p.name.lower()
                if base in JUNK_FILES:
                    self.add("S5", "LOW", "structure", f"Junk file: {rel}", fix="Delete it")
                elif base in EXTRANEOUS_FILES and len(rel.parts) == 1:
                    self.add("S3", "HIGH", "structure",
                             f"Extraneous documentation file: {rel} — skills must contain only what the agent needs",
                             fix="Delete it (or fold truly needed content into SKILL.md/references)")
                # depth: files under references/ or scripts/ should be one level deep
                if len(rel.parts) > 2 and rel.parts[0] in {"references", "scripts"}:
                    self.add("S4", "MEDIUM", "structure",
                             f"Nested bundled file: {rel} — keep references one level deep from SKILL.md",
                             fix="Flatten into references/ with a descriptive filename")
            elif p.is_dir():
                if not any(p.iterdir()):
                    self.add("S5", "LOW", "structure", f"Empty directory: {rel}", fix="Delete it")
                if len(rel.parts) == 1 and rel.parts[0] not in STANDARD_DIRS:
                    self.add("S6", "INFO", "structure",
                             f"Non-standard top-level directory: {rel}/ (standard: scripts/, references/, assets/)")

    def check_links_and_orphans(self, skill_text: str):
        # referenced bundle paths in SKILL.md: markdown links + backtick paths.
        # Only paths into the bundle (references/scripts/assets) are checkable claims;
        # other link targets are examples or repo files outside the skill. Fenced code
        # blocks are demonstrations by construction — exclude them from link claims.
        prose = re.sub(r"```.*?```", "", skill_text, flags=re.DOTALL)
        links = set(re.findall(r"\]\(((?:\./)?(?:references|scripts|assets)/[^)\s]+)\)", prose))
        ticks = set(re.findall(r"`((?:\./)?(?:references|scripts|assets)/[^`\s]+)`", prose)) - links
        for c in sorted(links):
            if not (self.dir / c.split("#")[0]).resolve().exists():
                self.add("L1", "HIGH", "links", f"SKILL.md links to a bundled file that does not exist: {c}",
                         fix="Fix the path or create the file")
        for c in sorted(ticks):
            if not (self.dir / c.split("#")[0]).resolve().exists():
                # inline code is often illustrative ("e.g. references/finance.md"), so this
                # needs a human/LLM look rather than an automatic HIGH
                self.add("L1", "MEDIUM", "links",
                         f"SKILL.md mentions a bundle path that does not exist: {c} — confirm it is illustrative, not a broken reference",
                         fix="If it names a real resource, fix the path; if illustrative, make that unmistakable or drop the path form")
        # orphans: bundled files never mentioned in SKILL.md
        for sub in ("references", "scripts"):
            d = self.dir / sub
            if not d.is_dir():
                continue
            for f in sorted(d.rglob("*")):
                if f.is_file() and f.name not in skill_text:
                    self.add("L2", "MEDIUM", "links",
                             f"Bundled file never mentioned in SKILL.md: {f.relative_to(self.dir)} — Claude cannot discover it",
                             fix="Link it from SKILL.md and say when to read/run it, or delete it")
        # reference file size hygiene
        refs = self.dir / "references"
        if refs.is_dir():
            for f in sorted(refs.rglob("*.md")):
                t = f.read_text(encoding="utf-8", errors="replace")
                n_lines = len(t.splitlines())
                n_words = len(t.split())
                if n_lines > REF_TOC_LINE_THRESHOLD:
                    head = "\n".join(t.splitlines()[:40]).lower()
                    if "contents" not in head:
                        self.add("L3", "MEDIUM", "context-economy",
                                 f"{f.relative_to(self.dir)} is {n_lines} lines with no table of contents in the first 40 lines",
                                 fix="Add a Contents section at the top so the full scope is visible on preview")
                if n_words > REF_GREP_WORD_THRESHOLD:
                    self.add("L4", "MEDIUM", "context-economy",
                             f"{f.relative_to(self.dir)} is {n_words} words (>10k) — too large to read whole",
                             fix="Include grep search patterns for it in SKILL.md, or split by domain")

    def collect_stats(self, full_text: str, body: str, fm: dict):
        meta_tokens = estimate_tokens(str(fm.get("name", "")) + " " + str(fm.get("description", "")))
        total = 0
        for f in sorted(self.dir.rglob("*")):
            if not f.is_file():
                continue
            try:
                t = f.read_text(encoding="utf-8", errors="replace")
                tok = estimate_tokens(t)
                self.stats["files"].append({
                    "path": str(f.relative_to(self.dir)),
                    "lines": len(t.splitlines()), "words": len(t.split()), "tokens_est": tok,
                })
                total += tok
            except Exception:
                self.stats["files"].append({"path": str(f.relative_to(self.dir)), "binary": True})
        self.stats["context_cost"] = {
            "startup_metadata_tokens": meta_tokens,
            "trigger_body_tokens": estimate_tokens(body),
            "full_bundle_tokens": total,
            "body_lines": len(body.splitlines()),
            "body_words": len(body.split()),
        }

    # ---------- output ----------

    def result(self):
        order = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3, "INFO": 4}
        self.findings.sort(key=lambda x: (order.get(x["severity"], 9), x["id"]))
        counts = {}
        for f in self.findings:
            counts[f["severity"]] = counts.get(f["severity"], 0) + 1
        score = max(0, 100 - sum(SEVERITY_DEDUCTION.get(f["severity"], 0) for f in self.findings))
        return {"findings": self.findings, "summary": counts,
                "mechanical_score": score, "stats": self.stats}


def exit_code(all_findings):
    sevs = {f["severity"] for f in all_findings}
    return 2 if "CRITICAL" in sevs else (1 if "HIGH" in sevs else 0)


def main():
    dirs = [Path(a).expanduser() for a in sys.argv[1:] if a != "--json"]
    if not dirs:
        print("Usage: audit_skill.py <skill-directory> [<skill-directory> ...]", file=sys.stderr)
        sys.exit(64)
    if len(dirs) == 1:
        res = Audit(dirs[0]).run().result()
        print(json.dumps(res, indent=2))
        sys.exit(exit_code(res["findings"]))
    # bulk triage: one summary row per skill, worst mechanical_score first
    rows, all_findings = [], []
    for d in dirs:
        r = Audit(d).run().result()
        all_findings.extend(r["findings"])
        rows.append({
            "skill": d.name,
            "mechanical_score": r["mechanical_score"],
            "summary": r["summary"],
            "finding_ids": sorted({f["id"] for f in r["findings"]}),
            "trigger_body_tokens": r["stats"].get("context_cost", {}).get("trigger_body_tokens"),
        })
    rows.sort(key=lambda x: (x["mechanical_score"], x["skill"]))
    print(json.dumps({"skills": rows, "scanned": len(rows)}, indent=2))
    sys.exit(exit_code(all_findings))


if __name__ == "__main__":
    main()
