---
name: ~aod-deliver
description: "Structured delivery retrospective for the AOD Lifecycle's Deliver stage. Validates Definition of Done, captures delivery metrics (estimated vs. actual duration), logs surprises, feeds new ideas back into discovery via GitHub Issues, and creates Institutional Knowledge entries. Use this skill when you need to close a feature, run a delivery retrospective, capture lessons learned, or complete the AOD lifecycle."
---

# AOD Deliver Skill

## Purpose

Close a completed feature with a structured retrospective that captures delivery metrics, surprises, and lessons learned. New ideas from the retrospective feed back into the Discover stage, completing the AOD Lifecycle loop.

**Entry point**: `/aod.deliver`

## Prerequisites

- A feature branch exists with completed work (typically after `/aod.build [--no-security] [--no-simplify] [--no-docs]`)
- `.aod/spec.md` exists with the feature specification
- `.aod/tasks.md` exists with task definitions
- `.aod/scripts/bash/github-lifecycle.sh` is available for GitHub operations

---

## Step 1: Validate Definition of Done

**GitHub Lifecycle Update (early)**: If a GitHub Issue exists for this feature, update its stage label to `stage:deliver` using `aod_gh_update_stage` from `.aod/scripts/bash/github-lifecycle.sh`. This moves the issue to the Deliver column on the Projects board at the *start* of the delivery retrospective. If `gh` is unavailable, skip silently (graceful degradation).

Check that the feature meets the Definition of Done criteria:

1. **Read `.aod/tasks.md`** and count incomplete tasks (lines matching `- [ ]`).
2. **Read `.aod/spec.md`** to extract the feature name and scope.
3. **Check for open blockers**: Search tasks.md for any items marked `BLOCKED`.

### Validation Results

**If incomplete tasks exist**: Display count and list them:

```
DEFINITION OF DONE — INCOMPLETE

Feature: {feature_name}
Incomplete Tasks: {count}

{list of incomplete task descriptions}

Options:
  (A) Mark remaining tasks as complete and proceed
  (B) Abort delivery — finish tasks first
```

Use AskUserQuestion to let the user choose.

**If all tasks complete**: Proceed to Step 2.

```
DEFINITION OF DONE — PASSED

Feature: {feature_name}
Tasks: {total} complete, 0 remaining
```

---

## Step 2: Capture Delivery Metrics

### Estimated Duration

Use AskUserQuestion:

```
Question: "How long did you originally estimate this feature would take?"
Header: "Estimate"
Options:
  - "1-2 days": "A quick feature or fix"
  - "3-5 days": "About a week of work"
  - "1-2 weeks": "A moderate feature spanning multiple days"
  - "3+ weeks": "A large feature requiring significant effort"
```

Allow "Other" for custom estimates (e.g., "4 sprints", "3 months").

### Actual Duration

Compute automatically from the feature branch creation date:

```bash
# Get the date of the first commit on this branch (not on main)
git log main..HEAD --reverse --format="%ai" | head -1
```

If the branch has no commits diverged from main, use the earliest commit date on the current branch.

Calculate the difference between the branch start date and today's date. Express as:
- "N days" if < 14 days
- "N weeks" if >= 14 days and < 60 days
- "N months" if >= 60 days

Store both `estimated_duration` and `actual_duration`.

---

## Step 3: Capture Surprise Log

Use AskUserQuestion:

```
Question: "What surprised you most during this feature? (One sentence minimum)"
Header: "Surprises"
Options:
  - "Scope was larger than expected": "The feature required more work than initially scoped"
  - "Dependencies were complex": "Integrations or dependencies added unexpected complexity"
  - "Smooth sailing": "Everything went roughly as planned — no major surprises"
```

Allow "Other" for custom surprise statements (required — must be at least 1 sentence).

**Validation**: If the user provides empty or very short text (<10 chars), re-prompt: "Please provide at least one sentence describing what surprised you."

Store as `surprise_log`.

---

## Step 4: Capture Next Ideas (Optional Feedback Loop)

Use AskUserQuestion:

```
Question: "Did this feature reveal any new ideas or follow-up work? (Optional — select 'None' to skip)"
Header: "Next ideas"
Options:
  - "Yes — let me describe": "I have one or more ideas for follow-up features or improvements"
  - "None": "No new ideas emerged from this feature"
```

**If "Yes"**: Ask the user to describe each idea. For each idea provided:

1. **MUST** use the standalone `create-issue.sh` script to create the GitHub Issue (do NOT call `gh issue create` directly — the script handles both issue creation and project board sync):
   ```bash
   bash .aod/scripts/bash/create-issue.sh \
     --title "{idea_description}" \
     --body "$BODY" \
     --stage discover \
     --type retro
   ```
   Where `$BODY` contains:
   ```markdown
   # {idea_description}

   ## ICE Score
   Impact: —, Confidence: —, Effort: — = **Not yet scored**

   ## Evidence
   Retrospective: Emerged during delivery of {feature_name}

   ## Metadata
   - Source: Retrospective
   - Priority: Not yet scored
   - Date: {YYYY-MM-DD}
   - Status: New (from retrospective)
   - Origin Feature: {feature_name}
   ```
   The script applies the `type:retro` label automatically and adds the issue to the Projects board with the correct Status column.

2. If `gh` is unavailable, log the idea to stdout with guidance:
   ```
   NEW IDEA FROM RETROSPECTIVE (GitHub unavailable — capture manually):
   Idea: {idea_description}
   Suggested next step: Run `/aod.idea {idea_description}` to formally capture and score.
   ```

Store ideas as `next_ideas[]`.

**If "None"**: Skip and proceed to Step 5.

---

## Step 5: Capture Lessons Learned

Use AskUserQuestion:

```
Question: "What is the key lesson learned from this feature that future developers should know?"
Header: "Lesson"
Options:
  - "Technical pattern": "A reusable technical approach or architecture decision worth documenting"
  - "Process improvement": "A workflow or process change that would help future features"
  - "Tooling insight": "A tool, library, or configuration finding worth preserving"
```

Allow "Other" for custom lesson descriptions.

After category selection, prompt for the full lesson text:
"Describe the lesson in 2-3 sentences. What was the problem, what did you learn, and how should it be applied?"

**Validation**: Require at least 20 characters of lesson text.

Store as `lesson_category` and `lesson_text`.

---

## Step 6: Write Institutional Knowledge Entry

Append a new entry to `docs/INSTITUTIONAL_KNOWLEDGE.md` in the `## Knowledge Entries` section.

Determine the next entry number by scanning existing `### Entry N:` headers and incrementing.

```markdown
### Entry {N}: {feature_name} — Delivery Retrospective

## [{lesson_category}] - {one_line_summary}

**Date**: {YYYY-MM-DD}
**Context**: Delivery retrospective for {feature_name}. Estimated: {estimated_duration}, Actual: {actual_duration}.

**Problem**:
{lesson_text — first sentence or clause describing the challenge}

**Solution**:
{lesson_text — remaining sentences describing the approach/learning}

**Why This Matters**:
Captured during structured delivery retrospective. {surprise_log}

**Tags**: #retrospective #delivery #{lesson_category_tag}

### Related Files:
- `.aod/spec.md` — Feature specification
- `.aod/tasks.md` — Task breakdown

---
```

Map `lesson_category` to tags:
- "Technical pattern" → `#architecture #pattern`
- "Process improvement" → `#process #workflow`
- "Tooling insight" → `#tooling #configuration`
- Other → `#general`

---

## Step 7: Post Delivery Metrics to GitHub Issue

If a GitHub Issue exists for this feature (search by feature name or branch):

1. Find the issue: `aod_gh_find_issue "{feature_name}"` or search by branch name
2. Add a comment with delivery metrics:
   ```markdown
   ## Delivery Metrics

   | Metric | Value |
   |--------|-------|
   | Delivery Date | {YYYY-MM-DD} |
   | Estimated Duration | {estimated_duration} |
   | Actual Duration | {actual_duration} |
   | Surprise Log | {surprise_log} |
   | Lessons Learned | {lesson_category}: {one_line_summary} |
   | New Ideas | {count of next_ideas or "None"} |
   ```
3. Note: The issue was already transitioned to `stage:deliver` in Step 1.

---

## Step 8: Regenerate BACKLOG.md

Run `.aod/scripts/bash/backlog-regenerate.sh` to update the backlog snapshot with the newly delivered item. If `gh` is unavailable, skip silently.

---

## Step 9: Run E2E Validation Gate

Run automated E2E validation against the feature's acceptance criteria before collecting test evidence. This step is **non-fatal** by default (ADR-006): if the tester agent fails to launch, crashes, or times out, log the error and proceed to Step 10. The E2E validation gate supports two modes:

- **Soft gate** (default): Warn on test failure, let the developer decide whether to proceed or abort
- **Hard gate** (`--require-tests`): Block delivery if any test fails

The gate decision is made in sub-step 9d based on the `require_tests` flag passed from the command's flag parsing (Step 0).

### 9a: Pre-check — Detect Playwright Configuration

Search the project root for Playwright configuration files:

1. Check for `playwright.config.ts`, `playwright.config.js`, or `playwright.config.mjs` at the project root
2. If `.aod/stack-active.json` exists, read it and check for stack-specific Playwright paths (the stack pack may define a custom config location)
3. Check for `playwright` in `package.json` dependencies (if `package.json` exists)

**If no Playwright configuration found**:
- Display: `"No Playwright configuration found — skipping E2E validation"`
- Store `e2e_validation.skipped = true` and `e2e_validation.skip_reason = "no_playwright_config"`
- Store `e2e_validation.status = "skipped"`
- Proceed directly to Step 10

**If Playwright configuration found**:
- Store the config file path for use in sub-step 9b
- Proceed to sub-step 9b

### 9b: Invoke Tester Agent

Launch the tester agent to generate and execute BDD/Gherkin E2E scenarios from the feature's acceptance criteria.

1. **Resolve spec path**: Find `specs/{NNN}-*/spec.md` using the feature number from the current branch
2. **Launch tester agent** via the Agent tool:
   ```
   Agent tool:
     subagent_type: "tester"
     prompt: |
       Generate and execute BDD/Gherkin E2E scenarios for the feature specification.

       Input:
       - Feature spec: {spec_path}
       - Output directory: .aod/test-results/

       Instructions:
       1. Read the feature spec and extract acceptance criteria from all user stories
       2. Generate Gherkin scenarios (.feature files) from the acceptance criteria
       3. Execute scenarios via Playwright
       4. Write test results to .aod/test-results/

       Subagent Return Policy:
       - Return ONLY: status (pass/fail/error), item count ({passed}/{total}), and results file path (.aod/results/tester.md)
       - Write detailed findings (failing scenario names, error details, execution logs) to .aod/results/tester.md BEFORE returning
       - Max return: 15 lines / ~200 tokens
     timeout: 300000  # 5 minutes
   ```
3. **Handle timeout**: If the agent does not return within 5 minutes:
   - Display: `"E2E validation timed out after 5 minutes ({elapsed}s elapsed)"`
   - Use AskUserQuestion: "(A) Continue waiting, (B) Abort E2E validation and proceed"
   - If Abort: store `e2e_validation.status = "error"`, `e2e_validation.error = "timeout"`, proceed to Step 10

4. **Handle agent failure**: If the agent fails to launch or crashes:
   - Display: `"E2E validation error: {error_message}"`
   - Store `e2e_validation.status = "error"`, `e2e_validation.error = "{error_message}"`
   - Proceed to Step 10 (non-fatal per ADR-006)

### 9c: Parse Test Results

Read and parse the tester agent's return value and detailed results.

1. **Parse agent return**: Extract status (`pass`/`fail`/`error`), item count (`{passed}/{total}`), and results file path
2. **Read detailed results**: If status is `fail`, read `.aod/results/tester.md` to extract:
   - Failing scenario names
   - Error messages for each failure
   - Total, passed, failed, and skipped counts
3. **Store results** in the `e2e_validation` data structure:
   - `e2e_validation.status`: `"pass"` | `"fail"` | `"error"` | `"skipped"`
   - `e2e_validation.total`: Total test count
   - `e2e_validation.passed`: Passed test count
   - `e2e_validation.failed`: Failed test count
   - `e2e_validation.skipped`: Skipped test count
   - `e2e_validation.failing_scenarios[]`: List of failing scenario names (empty if all pass)
4. **Display summary**:
   ```
   E2E Validation: {status}
   Tests: {passed}/{total} passed ({failed} failed, {skipped} skipped)
   ```
   If any failures, also display:
   ```
   Failing scenarios:
     - {scenario_name_1}
     - {scenario_name_2}
   ```
5. Proceed to sub-step 9d (Gate Decision)

### 9d: Gate Decision

Evaluate test results and determine whether delivery should proceed, based on gate mode and test outcome.

**Inputs**: `e2e_validation.status`, `e2e_validation.failed`, `e2e_validation.failing_scenarios[]`, `require_tests` flag (from command Step 0), `autonomous` flag (from command Step 0).

**Decision paths**:

1. **All tests pass** (`e2e_validation.status == "pass"`):
   - Display: `"E2E Validation Gate: PASSED — all tests passed"`
   - Store `e2e_validation.gate_mode = "soft"` or `"hard"` (based on `require_tests` flag)
   - Store `e2e_validation.gate_result = "pass"`
   - Proceed to Step 10

2. **Tests fail + Autonomous mode** (`autonomous == true`, regardless of `require_tests`):
   - Display:
     ```
     E2E Validation Gate: WARNING — {failed_count} test(s) failed (autonomous mode override)
     Failing scenarios:
       - {scenario_name_1}
       - {scenario_name_2}
     Proceeding with delivery (autonomous mode overrides gate).
     ```
   - Store `e2e_validation.gate_mode = require_tests ? "hard" : "soft"`
   - Store `e2e_validation.gate_result = "warn"`
   - Proceed to Step 10

3. **Tests fail + Soft gate** (`e2e_validation.status == "fail"` and `require_tests == false` and `autonomous == false`):
   - Display warning:
     ```
     E2E Validation Gate: WARNING — {failed_count} test(s) failed

     Failing scenarios:
       - {scenario_name_1}
       - {scenario_name_2}
     ```
   - Use AskUserQuestion:
     ```
     Question: "E2E tests failed. How would you like to proceed?"
     Header: "E2E Gate"
     Options:
       - "Proceed anyway": "Continue delivery despite test failures — failures will be recorded in the delivery document"
       - "Abort delivery": "Stop delivery to fix test failures — re-run /aod.deliver after fixing"
     ```
   - If "Proceed anyway": Store `e2e_validation.gate_result = "warn"`, proceed to Step 10
   - If "Abort delivery": Store `e2e_validation.gate_result = "block"`, display `"Delivery aborted. Fix failing tests and re-run /aod.deliver."`, halt workflow
   - Store `e2e_validation.gate_mode = "soft"`

4. **Tests fail + Hard gate** (`e2e_validation.status == "fail"` and `require_tests == true` and `autonomous == false`):
   - Display error:
     ```
     E2E Validation Gate: BLOCKED — {failed_count} test(s) failed (--require-tests enforced)

     Failing scenarios:
       - {scenario_name_1}
       - {scenario_name_2}

     Delivery blocked. Fix the failing tests and re-run `/aod.deliver --require-tests`.
     ```
   - Store `e2e_validation.gate_mode = "hard"`
   - Store `e2e_validation.gate_result = "block"`
   - Halt workflow — do NOT proceed to Step 10

5. **Status is "error" or "skipped"** (from sub-steps 9a-9c):
   - These statuses bypass the gate entirely — they were already handled in prior sub-steps
   - Store `e2e_validation.gate_mode = require_tests ? "hard" : "soft"`
   - Store `e2e_validation.gate_result = "skip"`
   - Proceed to Step 10

---

## Step 10: Collect Test Evidence

Collect and archive test artifacts for the delivery audit trail. This step is entirely **non-fatal** (ADR-006): if any sub-step fails, log the error and continue to Step 11. The delivery workflow must never be blocked by test evidence collection.

### 10a: Auto-Detect Test Artifacts

Scan these specific locations at the **project root only** (no recursive scanning):

1. `.aod/test-results/` — AOD convention directory
2. `test-results/` — project root test results
3. `coverage/` — project root coverage reports
4. Files matching `junit*.xml`, `test-report.*`, `coverage.*` in the project root

Collect all discovered files into a `detected_files` list with file paths and sizes.

### 10b: Confirm or Prompt

**If files found**: Display discovered files with sizes:

```
Test artifacts detected:
  - test-results/junit.xml (12 KB)
  - coverage/lcov.info (45 KB)

Archive these to specs/{NNN}-*/test-results/? (Y/n/add more)
```

Use AskUserQuestion with options:
- "Archive all" — proceed with detected files
- "Add more" — prompt for additional file paths, then archive all
- "Skip" — no test evidence archived

**If no files found**: Use AskUserQuestion:

```
Question: "No test artifacts found in standard locations. What would you like to do?"
Header: "Test evidence"
Options:
  - "Provide paths": "Enter custom file paths to archive"
  - "Skip": "No test evidence for this feature"
```

### 10c: File Size Check

Before copying, check file sizes:
- Warn if any individual file exceeds 10 MB
- Warn if total size exceeds 50 MB per feature
- Display warning but do NOT block archival — the developer decides

### 10d: Sensitive Data Warning

Display once before archival:
```
Reminder: Review test artifacts for sensitive data (API keys, tokens, PII) before archival.
```

### 10e: Copy Files to Archive

Copy confirmed files to `specs/{NNN}-*/test-results/`:
1. Create directory if needed: `mkdir -p specs/{NNN}-*/test-results/`
2. Copy each file preserving original filenames
3. If copy fails for any file, log the error and continue with remaining files

### 10f: Extract Summary Metrics (Best-Effort)

Extract metrics from recognized formats:

**JUnit XML**: Parse `<testsuites>` or `<testsuite>` root element attributes using `xmllint --xpath`:
```bash
xmllint --xpath "string(/testsuites/@tests)" file.xml 2>/dev/null || \
xmllint --xpath "string(/testsuite/@tests)" file.xml 2>/dev/null
```
Extract: `tests`, `failures`, `errors`, `skipped` attributes.

**LCOV (.info/.lcov)**: Sum `LF:` and `LH:` records:
```bash
LF=$(grep "^LF:" file.lcov 2>/dev/null | cut -d: -f2 | paste -sd+ | bc)
LH=$(grep "^LH:" file.lcov 2>/dev/null | cut -d: -f2 | paste -sd+ | bc)
```
Compute coverage: `(LH / LF) * 100`.

**Other formats**: Archive as-is. Summary = "Manual review required".

If parsing fails for any format, use "Manual review required" as the summary.

### 10g: Store Test Evidence Data

Store the following for use in Step 11 (delivery document generation):
- `test_evidence.files[]`: List of archived files with paths and summaries
- `test_evidence.metrics`: Aggregate metrics (tests run, passed, failed, coverage %)
- `test_evidence.skipped`: Boolean indicating if evidence was skipped
- `test_evidence.notes`: Context string for the Notes field

---

## Step 11: Generate Delivery Document

Generate a persistent delivery document from retrospective data collected in Steps 1-8, E2E validation results from Step 9, and test evidence from Step 10.

### 11a: Re-ground on Template

Re-read `.aod/templates/delivery-template.md` before generating the document (KB Entry 9 re-grounding). This ensures the output structure matches the standardized template exactly.

### 11b: Resolve Specs Directory

Resolve the specs directory from the branch name:
1. Get the feature number from the branch: `git branch --show-current` → extract NNN prefix
2. Find the specs directory: `specs/{NNN}-*/`
3. If the directory does not exist, create it: `mkdir -p specs/{NNN}-{feature_kebab_name}/`

Store the resolved path as `specs_dir`.

### 11c: Populate Delivery Document

Using the template structure from `.aod/templates/delivery-template.md`, populate all sections from retrospective data:

1. **Header**: Feature number, name, today's date, branch name, PR number (from draft PR or git log)
2. **What Was Delivered**: Read `.aod/spec.md` for completed user stories and `.aod/tasks.md` for major completed tasks. Summarize as 3-7 user-visible outcomes (not implementation details).
3. **How to See & Test**: Extract verification steps from three sources and merge into numbered steps a developer can follow immediately:
   - **From `.aod/spec.md`**: Read each acceptance scenario's **Then** clause — each maps to one or more verification steps.
   - **From `.aod/plan.md`**: Extract any test commands, run commands, or manual testing instructions mentioned in the plan.
   - **From `.aod/tasks.md`**: Extract verification steps from task descriptions and checkpoint criteria.
   - **Format**: Number each step. Include specific CLI commands, file paths, or UI actions. Avoid vague instructions like "verify it works" — instead specify *what* to check and *how* (e.g., "Run `/aod.deliver 091` and confirm `specs/091-*/delivery.md` exists").
4. **Delivery Metrics**: Table with estimated_duration, actual_duration, and variance (computed as over/under/on-target)
5. **Surprise Log**: From `surprise_log` captured in Step 3
6. **Lessons Learned**: Table with `lesson_category`, `lesson_text`, and KB entry reference from Step 6
7. **Feedback Loop**: Count of `next_ideas` and list of each idea with GitHub Issue number
8. **Source Artifacts**: Paths to spec.md, plan.md, tasks.md, and PRD (from spec.md frontmatter if available)
9. **Test Evidence**: Populate both subsections of the Test Evidence section:
   - **E2E Validation Gate**: Read `e2e_validation.status`, `e2e_validation.gate_mode`, `e2e_validation.gate_result`, `e2e_validation.total`, `e2e_validation.passed`, `e2e_validation.failed`, `e2e_validation.skipped`, and `e2e_validation.failing_scenarios[]` from Step 9 output. Populate the E2E Validation Gate table and Failure Details field. If `e2e_validation.status` is `"skipped"`, use "N/A" for counts and "E2E validation skipped" for Failure Details. If `e2e_validation.status` is `"error"`, use "Error" for Status and the error message for Failure Details.
   - **Archived Artifacts**: Populate from `test_evidence` data collected in Step 10. If `test_evidence.skipped` is true, use "No test artifacts archived for this feature." If metrics were parsed successfully, populate the artifact table and Archived Artifact Metrics (tests run, passed, failed, coverage). If metrics could not be parsed, use "Manual review required" for the summary column.
10. **Documentation Updates**: Agent table populated from Step 3 of the command (documentation agent results)
11. **Cleanup**: Checklist items (left unchecked — will be checked during command Steps 7-11)

### 11d: Write Delivery Document

Write the populated document to `{specs_dir}/delivery.md` using the Write tool.

Store the delivery document path in variable `delivery_doc_path` for use in Step 12.

### 11e: Non-Fatal Fallback Guard

If the file write in Step 11d fails (permissions, disk full, or any error), display the full delivery document content in the terminal as a fallback. The deliver workflow MUST NOT be blocked by a file write failure (FR-009, KB Entry 14).

**Missing optional data handling**: If `surprise_log`, `next_ideas`, or `lesson_text` are empty or unavailable, use "None" or "N/A" for those sections rather than leaving them blank or erroring.

### 11f: Mark Draft PR Ready

If a draft PR exists for the current branch, mark it ready for review:

```bash
# Find draft PR for current branch
PR_NUMBER=$(gh pr list --head "$(git branch --show-current)" --state open --json number --jq '.[0].number')

# Mark ready if found
if [ -n "$PR_NUMBER" ]; then
  gh pr ready "$PR_NUMBER"
fi
```

If `gh` is unavailable or no draft PR exists, skip silently (graceful degradation). If no draft PR exists, create a regular PR: `gh pr create --title "{NNN}: {Feature Name}" --body "..."`.

### 11g: Display Delivery Document

After writing (or after fallback display if write failed), show the full document content in the terminal so the developer can review it immediately.

```
AOD DELIVERY COMPLETE

Feature: {feature_name}
Delivery Document: {delivery_doc_path}

{Full content of the generated delivery.md}
```

---

## Step 12: Close Issue and Transition to Done

After all retrospective steps are complete, metrics posted, and KB entries created:

1. **Transition to `stage:done`**: Run `source .aod/scripts/bash/github-lifecycle.sh && aod_gh_update_stage "$issue_number" "done"` to move the label from `stage:deliver` to `stage:done`. This moves the issue to the Done column on the Projects board.
2. **Close the GitHub Issue**: Run `gh issue close "$issue_number" --comment "Feature delivered. Retrospective complete. See: specs/{NNN}-*/delivery.md"` where `{NNN}-*` is resolved from the `delivery_doc_path` variable set in Step 11d. This cross-references the delivery document from the GitHub Issue.
3. **Regenerate BACKLOG.md**: Run `.aod/scripts/bash/backlog-regenerate.sh` to remove the now-done item from the active backlog.
4. If `gh` is unavailable, skip silently (graceful degradation).

This step MUST be the very last GitHub operation, after all metrics, KB entries, and backlog regeneration from Step 8 are complete.

---

## Step 13: Prompt for /aod.document

After delivery is complete, prompt the user about the next lifecycle step:

```
Next step: Run `/aod.document` for post-delivery quality review.
This covers code simplification, docstrings, CHANGELOG, and API docs.

Run `/aod.document` now? (Y/n)
```

- If user selects "Y" or presses enter: Invoke `/aod.document`
- If user selects "n": Display: `"Skipped. Run /aod.document when ready for post-delivery quality review."`

---

## Edge Cases

- **No tasks.md**: Skip DoD validation, warn user
- **No spec.md**: Use branch name as feature name
- **Branch has no diverged commits**: Use today's date for actual duration calculation
- **gh CLI unavailable**: Skip all GitHub operations (issue creation, comments, label updates, backlog regeneration) — graceful degradation
- **Empty surprise log**: Re-prompt (required field)
- **Empty lesson text**: Re-prompt (required field)
- **INSTITUTIONAL_KNOWLEDGE.md missing**: Create it with standard header before appending
- **User selects "Mark remaining tasks as complete"**: Update tasks.md to mark all `- [ ]` as `- [x]` before proceeding
- **Multiple ideas from retrospective**: Create one GitHub Issue per idea

## Quality Checklist

- [ ] Definition of Done validated (all tasks complete or user override)
- [ ] Estimated duration captured from user
- [ ] Actual duration computed from branch creation date
- [ ] Surprise log captured (minimum 1 sentence)
- [ ] Next ideas prompted (optional; each creates GitHub Issue with `stage:discover`)
- [ ] Lessons learned captured with category and full description
- [ ] KB entry appended to INSTITUTIONAL_KNOWLEDGE.md with correct entry number
- [ ] Delivery metrics posted to GitHub Issue as comment
- [ ] Issue transitioned to `stage:deliver` label (start of retrospective)
- [ ] BACKLOG.md regenerated
- [ ] Test evidence collected or skipped (non-fatal, per ADR-006)
- [ ] Retrospective summary displayed with all metrics
- [ ] Issue transitioned to `stage:done` label (end of retrospective)
- [ ] GitHub Issue closed with closing comment
- [ ] User prompted to run `/aod.document` for post-delivery quality review
