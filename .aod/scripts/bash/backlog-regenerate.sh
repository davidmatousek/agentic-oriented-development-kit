#!/usr/bin/env bash

# BACKLOG.md regeneration from GitHub Issues
#
# Queries GitHub Issues with stage:* labels and generates a grouped
# Markdown file at docs/product/_backlog/BACKLOG.md.
#
# Usage: ./backlog-regenerate.sh [--json]
#
# Options:
#   --json    Output summary as JSON instead of text
#
# Algorithm:
#   1. gh issue list with structured JSON fields
#   2. Warn if exactly 100 items returned (pagination limit)
#   3. Group by stage:* label
#   4. Extract stage-specific fields from issue body (defensive parsing)
#   5. Render Markdown tables per stage
#   6. Items without stage:* label → "Untracked" section
#   7. Idempotent: same GitHub state → identical output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/github-lifecycle.sh"

JSON_MODE=false
for arg in "$@"; do
    case "$arg" in
        --json) JSON_MODE=true ;;
    esac
done

REPO_ROOT=$(get_repo_root)
BACKLOG_DIR="$REPO_ROOT/docs/product/_backlog"
BACKLOG_FILE="$BACKLOG_DIR/BACKLOG.md"

# Ensure output directory exists
mkdir -p "$BACKLOG_DIR"

# Check gh availability
if ! aod_gh_check_available; then
    echo "[aod] Cannot regenerate BACKLOG.md without GitHub access." >&2
    exit 0
fi

# Fetch all issues (open and closed) with stage:* labels
RAW_JSON=$(gh issue list --json number,title,labels,updatedAt,state,body --state all --limit 100 2>/dev/null) || {
    echo "[aod] Warning: Failed to fetch GitHub Issues. BACKLOG.md not updated." >&2
    exit 0
}

# Pagination warning (T061)
ISSUE_COUNT=$(echo "$RAW_JSON" | grep -o '"number"' | wc -l | tr -d ' ')
if [[ "$ISSUE_COUNT" -eq 100 ]]; then
    echo "[aod] Warning: Backlog may be truncated (100 item limit). Consider implementing pagination or archiving old items." >&2
fi

# Helper: extract a section value from issue body (defensive, T062)
# Args: $1 = body text, $2 = section header (e.g., "## ICE Score")
# Returns: first non-empty line after header, or "—" if not found
extract_section() {
    local body="$1"
    local header="$2"
    local value

    # Find content after the header, take first non-empty line
    value=$(echo "$body" | sed -n "/^${header}/,/^##/{/^${header}/d;/^##/d;/^$/d;p;}" | head -1 | sed 's/^[[:space:]]*//')

    if [[ -z "$value" ]]; then
        echo "—"
    else
        echo "$value"
    fi
}

# Helper: extract field from Metadata section
# Args: $1 = body text, $2 = field name (e.g., "Source")
extract_metadata() {
    local body="$1"
    local field="$2"
    local value

    value=$(echo "$body" | grep -o "- ${field}: .*" | head -1 | sed "s/- ${field}: //")

    if [[ -z "$value" ]]; then
        echo "—"
    else
        echo "$value"
    fi
}

# Generate BACKLOG.md
generate_backlog() {
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat <<HEADER
# Backlog

> Auto-generated from GitHub Issues on ${timestamp}.
> Source of truth: GitHub Issues with \`stage:*\` labels.
> Regenerate: \`/aod.status\` or \`.aod/scripts/bash/backlog-regenerate.sh\`

HEADER

    # Process each stage
    for stage in discover define plan build deliver; do
        local label="stage:${stage}"

        echo "## ${stage^}"
        echo ""

        # Filter issues for this stage using label name matching
        local stage_issues
        stage_issues=$(echo "$RAW_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for issue in data:
    labels = [l['name'] for l in issue.get('labels', [])]
    if '${label}' in labels:
        # Escape pipe chars in title for markdown table
        title = issue['title'].replace('|', '\\\\|')
        body = issue.get('body', '') or ''
        updated = issue.get('updatedAt', '—')[:10]
        number = issue['number']
        print(f'{number}|{title}|{updated}|{body}')
" 2>/dev/null) || stage_issues=""

        # Stage-specific table headers
        case "$stage" in
            discover)
                echo "| # | Title | ICE | Evidence | Updated |"
                echo "|---|-------|-----|----------|---------|"
                ;;
            define)
                echo "| # | Title | PRD | Updated |"
                echo "|---|-------|-----|---------|"
                ;;
            plan)
                echo "| # | Title | Spec | Plan | Tasks | Updated |"
                echo "|---|-------|------|------|-------|---------|"
                ;;
            build)
                echo "| # | Title | Progress | Updated |"
                echo "|---|-------|----------|---------|"
                ;;
            deliver)
                echo "| # | Title | Delivered | Retro | Updated |"
                echo "|---|-------|-----------|-------|---------|"
                ;;
        esac

        if [[ -z "$stage_issues" ]]; then
            echo "| — | *No items in this stage* | | |"
        else
            while IFS='|' read -r num title updated body; do
                case "$stage" in
                    discover)
                        local ice
                        ice=$(extract_section "$body" "## ICE Score")
                        local evidence
                        evidence=$(extract_section "$body" "## Evidence")
                        # Truncate evidence for table display
                        if [[ ${#evidence} -gt 60 ]]; then
                            evidence="${evidence:0:57}..."
                        fi
                        echo "| #${num} | ${title} | ${ice} | ${evidence} | ${updated} |"
                        ;;
                    define)
                        local prd
                        prd=$(extract_metadata "$body" "PRD")
                        echo "| #${num} | ${title} | ${prd} | ${updated} |"
                        ;;
                    plan)
                        echo "| #${num} | ${title} | — | — | — | ${updated} |"
                        ;;
                    build)
                        echo "| #${num} | ${title} | In progress | ${updated} |"
                        ;;
                    deliver)
                        echo "| #${num} | ${title} | ${updated} | — | ${updated} |"
                        ;;
                esac
            done <<< "$stage_issues"
        fi

        echo ""
    done

    # Untracked section: issues without any stage:* label
    local untracked
    untracked=$(echo "$RAW_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
stage_labels = {'stage:discover', 'stage:define', 'stage:plan', 'stage:build', 'stage:deliver'}
for issue in data:
    labels = {l['name'] for l in issue.get('labels', [])}
    if not labels.intersection(stage_labels):
        title = issue['title'].replace('|', '\\\\|')
        updated = issue.get('updatedAt', '—')[:10]
        number = issue['number']
        state = issue.get('state', 'OPEN')
        print(f'{number}|{title}|{state}|{updated}')
" 2>/dev/null) || untracked=""

    if [[ -n "$untracked" ]]; then
        echo "## Untracked"
        echo ""
        echo "> These issues have no \`stage:*\` label. Add a label to track them in the lifecycle."
        echo ""
        echo "| # | Title | State | Updated |"
        echo "|---|-------|-------|---------|"
        while IFS='|' read -r num title state updated; do
            echo "| #${num} | ${title} | ${state} | ${updated} |"
        done <<< "$untracked"
        echo ""
    fi
}

# Write to file
OUTPUT=$(generate_backlog)
echo "$OUTPUT" > "$BACKLOG_FILE"

# Summary
if $JSON_MODE; then
    # Count items per stage
    python3 -c "
import json, sys
data = json.load(sys.stdin)
counts = {'discover': 0, 'define': 0, 'plan': 0, 'build': 0, 'deliver': 0, 'untracked': 0}
stage_labels = {'stage:discover', 'stage:define', 'stage:plan', 'stage:build', 'stage:deliver'}
for issue in data:
    labels = {l['name'] for l in issue.get('labels', [])}
    matched = labels.intersection(stage_labels)
    if matched:
        stage = list(matched)[0].split(':')[1]
        counts[stage] += 1
    else:
        counts['untracked'] += 1
print(json.dumps({'file': '${BACKLOG_FILE}', 'total': len(data), 'stages': counts}))
" <<< "$RAW_JSON"
else
    echo "[aod] BACKLOG.md regenerated at ${BACKLOG_FILE}"
    echo "[aod] Total issues: ${ISSUE_COUNT}"
fi
