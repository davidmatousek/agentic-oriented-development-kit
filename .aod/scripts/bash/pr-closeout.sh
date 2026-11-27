#!/usr/bin/env bash

# pr-closeout.sh — single-PR-per-cycle closeout (Feature 204).
#
# ENTRY POINT with subcommands, and also SOURCEABLE: when sourced it defines
# the functions below and runs nothing (it never changes the caller's shell
# options; `set -u` is applied only when executed). Bash 3.2 compatible
# (macOS default): only indexed-free constructs (no associative arrays, no
# case-conversion expansions, no array-reading builtins, no pipe-stderr or
# append-both shorthands, no negative indexes, no external timeout command).
#
# Contract: specs/204-single-pr-per-cycle/contracts/pr-closeout-cli.md
# Halt record: specs/204-single-pr-per-cycle/contracts/document-halt-record.md
# Design: specs/204-single-pr-per-cycle/plan.md D-4, D-5, D-7
#
# Usage (run from the repo root):
#   pr-closeout.sh resolve    --feature <NNN|F> [--autonomous]
#   pr-closeout.sh verify     --feature <F> [--autonomous]
#   pr-closeout.sh prepare    --feature <F> [--autonomous]
#   pr-closeout.sh merge      --feature <F> --pr <N> --sha <SHA> [--autonomous]
#   pr-closeout.sh post-merge --feature <F> --pr <N>
#   pr-closeout.sh outcome    --feature <F> [--autonomous]
#
# NNN is ${F%%-*}. verify/prepare/merge run on the feature branch F (never the
# default branch); resolve/post-merge/outcome run from any branch.
#
# Exit codes:
#   0   success; key=value result on stdout
#   2   usage error / missing prerequisite (git, jq): no halt record
#   5   resolve only, interactive: more than one candidate (candidate= lines on stdout)
#   10  halt: record written to ${AOD_HALT_STATE_DIR}/document-<NNN>.halt.json and a
#       "Halted — document closeout: <reason> (PR #<n>)" line printed on stdout
#   (3 and 4 belong to aod-config.sh; 11 and 12 to the deliver lock.)
#
# Stdout on success:
#   resolve:    branch=<b|> pr=<N|> state=<OPEN|MERGED|CLOSED|NONE|UNKNOWN> default=<d>
#   verify:     verify=<pass|not_reverified|skipped> [command=<c>] [verified_sha=<sha>]
#   prepare:    pr=<N> sha=<sha> checks=<pass|none> default=<d> verify=<pass|not_reverified|skipped>
#   merge:      merged=<N> merge_commit=<sha> post_merge=<done|partial> [detail=<step>: <msg>]
#   post-merge: post_merge=<done|partial> default=<d> [detail=<step>: <msg>]
#   outcome:    outcome=<completed|failed|awaiting_merge> pr_url= merge_commit= reason= verify=
# All diagnostics go to stderr with the "[aod]" prefix.
#
# Environment overrides (tests; there is intentionally none for the test command):
#   AOD_CLOSEOUT_CHECKS_TIMEOUT   bound for pending checks (default: config
#                                 document.checks_timeout_seconds, validated, else 1800)
#   AOD_CLOSEOUT_CHECKS_INTERVAL  poll interval seconds (default 30)
#   AOD_CLOSEOUT_HEAD_POLLS       head-SHA propagation polls (default 10)
#   AOD_CLOSEOUT_HEAD_INTERVAL    seconds between head polls (default 3)
#   AOD_CLOSEOUT_BACKLOG_CMD      BACKLOG regeneration command
#                                 (default: bash .aod/scripts/bash/backlog-regenerate.sh)
#   AOD_HALT_STATE_DIR            halt record directory (default .aod/state)
#
# Safety invariants (asserted by tests/unit/pr-cycle-contracts.test.sh):
#   - The one and only merge call is `_prc_gh_merge_call`; it passes squash and
#     the head-commit guard and nothing else (no admin, auto-merge or branch
#     deletion flags). Label/heal filtering lives in other functions.
#   - verify/prepare/merge assert current branch == F != default before any
#     commit or push; pushes use an explicit HEAD:refs/heads/<F> refspec.
#   - Every clean-tree check is `git status --porcelain --untracked-files=no`.
#   - Commit trailers are generic (no model names).

_PRC_SELF="${BASH_SOURCE[0]}"
_PRC_DIR="$(cd "$(dirname "$_PRC_SELF")" && pwd)"

# shellcheck source=/dev/null
. "$_PRC_DIR/aod-config.sh"
# shellcheck source=/dev/null
. "$_PRC_DIR/halt-signal.sh"

_PRC_TRAILER="Co-Authored-By: Claude <noreply@anthropic.com>"
_PRC_ERR=""
_PRC_FEATDIR=""
_PRC_TESTCMD=""
_PRC_GH_AVAIL=0
_PRC_CAND_LINES=""
_PRC_SEP=$'\037'

# ============================================================================
# Small helpers
# ============================================================================

_prc_log() { printf '[aod] %s\n' "$*" >&2; }
_prc_warn() { printf '[aod] WARNING: %s\n' "$*" >&2; }

_prc_first_line() { printf '%s\n' "${1-}" | sed -n '1p'; }

# Digits-only value from the environment, else the default.
_prc_env_int() {
    local v
    eval "v=\${$1:-}"
    case "$v" in
        '' | *[!0-9]*) printf '%s' "$2" ;;
        *) printf '%s' "$((10#$v))" ;;
    esac
}

_prc_now() { date +%s; }

_prc_short() { printf '%s' "${1-}" | cut -c1-7; }

# Channel 1 + 2 of the halt protocol. Always returns 10 (callers `return 10`).
#   _prc_halt <feature> <reason> <pr|""> <sha|""> <detail>
_prc_halt() {
    local f="${1-}" reason="${2-}" pr="${3-}" sha="${4-}" detail="${5-}" nnn
    nnn="${f%%-*}"
    if ! write_document_halt_record "$f" "$reason" "$pr" "$sha" "$detail"; then
        _prc_warn "halt record could not be written (stdout and exit-code channels remain)"
    fi
    if [ -n "$pr" ]; then
        printf 'Halted — document closeout: %s (PR #%s); see %s/document-%s.halt.json\n' \
            "$reason" "$pr" "$AOD_HALT_STATE_DIR" "$nnn"
    else
        printf 'Halted — document closeout: %s; see %s/document-%s.halt.json\n' \
            "$reason" "$AOD_HALT_STATE_DIR" "$nnn"
    fi
    _prc_log "halted: ${reason}: ${detail}"
    return 10
}

_prc_remove_record() { # nnn
    rm -f "${AOD_HALT_STATE_DIR}/document-${1}.halt.json" 2>/dev/null || true
}

# Default branch: authoritative gh answer when gh works, else the gh-free helper.
_prc_default_branch() {
    local b=""
    if command -v gh >/dev/null 2>&1; then
        b=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null) || b=""
    fi
    if [ -z "$b" ]; then b=$(aod_default_branch); fi
    printf '%s\n' "$b"
}

# Host of origin (default github.com), for `gh auth status --hostname`.
_prc_origin_host() {
    local url h=""
    url=$(git remote get-url origin 2>/dev/null) || url=""
    case "$url" in
        *://*)
            h="${url#*://}"
            h="${h#*@}"
            h="${h%%/*}"
            h="${h%%:*}"
            ;;
        *@*:*)
            h="${url#*@}"
            h="${h%%:*}"
            ;;
    esac
    [ -n "$h" ] || h="github.com"
    printf '%s\n' "$h"
}

# gh >= 2.40 and authenticated for origin's host. rc 0 ok, 1 not (sets _PRC_ERR).
_prc_gh_check() {
    local ver_line re major minor host rc=0
    _PRC_ERR=""
    if ! command -v gh >/dev/null 2>&1; then
        _PRC_ERR="gh CLI not found"
        return 1
    fi
    ver_line=$(gh --version 2>/dev/null | sed -n '1p') || ver_line=""
    re='gh version ([0-9]+)\.([0-9]+)'
    if [[ "$ver_line" =~ $re ]]; then
        major="${BASH_REMATCH[1]}"
        minor="${BASH_REMATCH[2]}"
    else
        _PRC_ERR="cannot parse gh version"
        return 1
    fi
    if [ "$((10#$major))" -lt 2 ] || { [ "$((10#$major))" -eq 2 ] && [ "$((10#$minor))" -lt 40 ]; }; then
        _PRC_ERR="gh ${major}.${minor} is older than 2.40"
        return 1
    fi
    host=$(_prc_origin_host)
    gh auth status --hostname "$host" >/dev/null 2>&1 || rc=$?
    if [ "$rc" -ne 0 ]; then
        _PRC_ERR="gh is not authenticated for ${host}"
        return 1
    fi
    return 0
}

# The feature dir: unique specs/<NNN>-*/ that contains spec.md.
# Sets _PRC_FEATDIR (no trailing slash). rc 0 ok, 1 not (sets _PRC_ERR).
_prc_feature_dir() {
    local nnn="$1" d found="" count=0
    _PRC_FEATDIR=""
    for d in specs/"${nnn}"-*/; do
        [ -f "${d}spec.md" ] || continue
        count=$((count + 1))
        found="${found}${found:+, }${d%/}"
        _PRC_FEATDIR="${d%/}"
    done
    if [ "$count" -eq 1 ]; then
        return 0
    fi
    _PRC_FEATDIR=""
    if [ "$count" -eq 0 ]; then
        _PRC_ERR="no specs/${nnn}-*/ directory containing spec.md"
    else
        _PRC_ERR="feature dir is ambiguous: ${found}"
    fi
    return 1
}

# Current branch == F, F != default, tree clean (tracked files only). Sets _PRC_ERR.
_prc_assert_branch() { # F [default]
    local f="$1" cur default="${2-}" dirty
    _PRC_ERR=""
    cur=$(git branch --show-current 2>/dev/null) || cur=""
    [ -n "$default" ] || default=$(_prc_default_branch)
    if [ "$cur" != "$f" ]; then
        _PRC_ERR="current branch '${cur}' is not the feature branch '${f}'"
        return 1
    fi
    if [ "$f" = "$default" ]; then
        _PRC_ERR="feature branch '${f}' is the default branch"
        return 1
    fi
    dirty=$(git status --porcelain --untracked-files=no 2>/dev/null) || dirty="?"
    if [ -n "$dirty" ]; then
        _PRC_ERR="working tree has uncommitted changes to tracked files"
        return 1
    fi
    return 0
}

_prc_valid_nnn() { case "${1-}" in '' | *[!0-9]*) return 1 ;; *) return 0 ;; esac; }
_prc_valid_num() { case "${1-}" in '' | *[!0-9]*) return 1 ;; *) return 0 ;; esac; }

# ============================================================================
# Candidate PR/branch resolution (shared by resolve, prepare, outcome)
# ============================================================================

# Sets _PRC_GH_AVAIL (1 when gh answered) and _PRC_CAND_LINES: one line per
# candidate "<branch><US><pr|><US><state>" (US = unit separator).
# Rules (M7): base == default, head starts "<NNN>-", excluding PRs labelled
# with the heal label and heads containing "-heal-" or ending "-document-stage".
# One candidate per head (OPEN beats MERGED beats CLOSED, then the newest PR);
# unmerged CLOSED candidates are dropped when any OPEN or MERGED one remains.
# gh unavailable: gh-free fallback through aod_feature_branch_candidates (N1).
_prc_collect() { # nnn default
    local nnn="$1" default="$2" json rc=0 lines c
    _PRC_GH_AVAIL=0
    _PRC_CAND_LINES=""
    if command -v gh >/dev/null 2>&1; then
        json=$(gh pr list --state all --json number,headRefName,baseRefName,state,labels --limit 100 2>/dev/null) || rc=$?
        if [ "$rc" -eq 0 ]; then
            lines=$(printf '%s' "$json" | jq -r --arg d "$default" --arg p "${nnn}-" '
                def lbls: (.labels // []) | map(if type == "object" then .name else . end);
                [ .[]
                  | select(.baseRefName == $d)
                  | select(.headRefName | startswith($p))
                  | select((lbls | index("e2e-heal")) == null)
                  | select((.headRefName | contains("-heal-")) | not)
                  | select((.headRefName | endswith("-document-stage")) | not) ]
                | group_by(.headRefName)
                | map(sort_by([ (if .state == "OPEN" then 0 elif .state == "MERGED" then 1 else 2 end), (0 - .number) ]) | .[0])
                | (if any(.[]; .state != "CLOSED") then map(select(.state != "CLOSED")) else . end)
                | sort_by(.number) | .[]
                | [.headRefName, (.number | tostring), .state] | join("\u001f")' 2>/dev/null) || rc=$?
            if [ "$rc" -eq 0 ]; then
                _PRC_GH_AVAIL=1
                _PRC_CAND_LINES="$lines"
                return 0
            fi
        fi
    fi
    lines=""
    while IFS= read -r c; do
        [ -n "$c" ] || continue
        lines="${lines}${c}${_PRC_SEP}${_PRC_SEP}UNKNOWN
"
    done <<EOF
$(aod_feature_branch_candidates "$nnn")
EOF
    _PRC_CAND_LINES="${lines%
}"
    return 0
}

# Exact lookup for a known branch (L-6): `gh pr list --head F --state all`, so the
# 100-PR window of the prefix scan cannot hide the feature PR. Same filters as
# _prc_collect (base == default, no heal label). One candidate line: OPEN beats
# MERGED beats CLOSED, then the newest PR. Sets _PRC_GH_AVAIL and _PRC_CAND_LINES;
# no git fallback (callers fail closed or report gh unavailable).
_prc_collect_branch() { # F default
    local f="$1" default="$2" json rc=0 lines
    _PRC_GH_AVAIL=0
    _PRC_CAND_LINES=""
    command -v gh >/dev/null 2>&1 || return 0
    json=$(gh pr list --head "$f" --state all --json number,headRefName,baseRefName,state,labels --limit 100 2>/dev/null) || rc=$?
    [ "$rc" -eq 0 ] || return 0
    lines=$(printf '%s' "$json" | jq -r --arg d "$default" --arg h "$f" '
        def lbls: (.labels // []) | map(if type == "object" then .name else . end);
        [ .[]
          | select(.baseRefName == $d)
          | select(.headRefName == $h)
          | select((lbls | index("e2e-heal")) == null) ]
        | sort_by([ (if .state == "OPEN" then 0 elif .state == "MERGED" then 1 else 2 end), (0 - .number) ])
        | .[0:1] | .[]
        | [.headRefName, (.number | tostring), .state] | join("\u001f")' 2>/dev/null) || return 0
    _PRC_GH_AVAIL=1
    _PRC_CAND_LINES="$lines"
    return 0
}

_prc_cand_count() {
    local n=0 l
    while IFS= read -r l; do
        [ -n "$l" ] || continue
        n=$((n + 1))
    done <<EOF
$_PRC_CAND_LINES
EOF
    printf '%s' "$n"
}

# Prints "<pr><US><state>" for the candidate whose head is $1; rc 1 if none.
_prc_pick_for_branch() {
    local want="$1" l b p s
    while IFS= read -r l; do
        [ -n "$l" ] || continue
        b="${l%%"$_PRC_SEP"*}"
        l="${l#*"$_PRC_SEP"}"
        p="${l%%"$_PRC_SEP"*}"
        s="${l#*"$_PRC_SEP"}"
        if [ "$b" = "$want" ]; then
            printf '%s%s%s' "$p" "$_PRC_SEP" "$s"
            return 0
        fi
    done <<EOF
$_PRC_CAND_LINES
EOF
    return 1
}

# ============================================================================
# resolve
# ============================================================================

pr_closeout_resolve() { # feature autonomous
    local feature="$1" autonomous="$2" nnn default count l b p s detail
    nnn="${feature%%-*}"
    default=$(_prc_default_branch)
    _prc_collect "$nnn" "$default"
    count=$(_prc_cand_count)
    if [ "$count" -eq 0 ]; then
        if [ "$_PRC_GH_AVAIL" -eq 0 ]; then
            printf 'branch= pr= state=UNKNOWN default=%s\n' "$default"
        else
            printf 'branch= pr= state=NONE default=%s\n' "$default"
        fi
        return 0
    fi
    if [ "$count" -eq 1 ]; then
        l=$(printf '%s' "$_PRC_CAND_LINES" | sed -n '1p')
        b="${l%%"$_PRC_SEP"*}"
        l="${l#*"$_PRC_SEP"}"
        p="${l%%"$_PRC_SEP"*}"
        s="${l#*"$_PRC_SEP"}"
        printf 'branch=%s pr=%s state=%s default=%s\n' "$b" "$p" "$s" "$default"
        return 0
    fi
    detail=""
    while IFS= read -r l; do
        [ -n "$l" ] || continue
        b="${l%%"$_PRC_SEP"*}"
        l="${l#*"$_PRC_SEP"}"
        p="${l%%"$_PRC_SEP"*}"
        s="${l#*"$_PRC_SEP"}"
        detail="${detail}${detail:+; }${b} (pr=${p:-none} state=${s})"
        if [ "$autonomous" -eq 0 ]; then
            printf 'candidate=%s pr=%s state=%s\n' "$b" "$p" "$s"
        fi
    done <<EOF
$_PRC_CAND_LINES
EOF
    if [ "$autonomous" -eq 1 ]; then
        _prc_halt "$feature" precondition_failed "" "" "ambiguous feature PR/branch candidates: ${detail}"
        return 10
    fi
    _prc_log "more than one candidate for feature ${nnn}; choose one"
    return 5
}

# ============================================================================
# Shared classifier (N5, S-1): commits needing post-refactor verification
# ============================================================================

# True when a path is a code file. The extension list MIRRORS
# .claude/commands/aod.document.md Step 1a (code extensions):
#   `.py`, `.js`, `.ts`, `.jsx`, `.tsx`, `.sh`, `.go`, `.rs`, `.java`, `.rb`, `.swift`, `.kt`
# (tests/unit/pr-cycle-contracts.test.sh compares the two lists). Only the
# extension list is mirrored, not Step 1a's exclusions: verification fails
# closed, so a changed vendored or generated source file still counts.
_prc_is_code_file() {
    case "${1-}" in
        *.py | *.js | *.ts | *.jsx | *.tsx | *.sh | *.go | *.rs | *.java | *.rb | *.swift | *.kt) return 0 ;;
    esac
    return 1
}

# Prints, one per line (oldest first), the commits that need verification:
# non-merge commits in origin/<default>..HEAD after the newest commit whose
# subject matches the "docs: close Feature NNN" anchor (no anchor: the whole
# range), whose diff lists at least one code file. ONE function behind both
# `verify` and the `prepare` gate: never write a second classifier.
_commits_needing_verification() { # NNN default
    local nnn="$1" default="$2" base n re anchor="" sha subj f log files revs=""
    base="origin/${default}"
    n=$((10#$nnn))
    re="^docs: close Feature 0*${n} - update all documentation"
    if ! git rev-parse --verify --quiet "${base}^{commit}" >/dev/null 2>&1; then
        _prc_warn "${base} not found; classifying the whole branch history"
        base=""
    fi
    # Any git error returns non-zero (L-2): callers fail closed (tests_failed).
    if [ -n "$base" ]; then
        log=$(git log --no-merges --format='%H %s' "${base}..HEAD" 2>/dev/null) || return 1
    else
        log=$(git log --no-merges --format='%H %s' HEAD 2>/dev/null) || return 1
    fi
    while IFS=' ' read -r sha subj; do
        [ -n "$sha" ] || continue
        if [[ "$subj" =~ $re ]]; then
            anchor="$sha"
            break
        fi
    done <<EOF
$log
EOF
    if [ -n "$base" ] && [ -n "$anchor" ]; then
        revs=$(git rev-list --no-merges --reverse HEAD "^${base}" "^${anchor}" 2>/dev/null) || return 1
    elif [ -n "$base" ]; then
        revs=$(git rev-list --no-merges --reverse "${base}..HEAD" 2>/dev/null) || return 1
    elif [ -n "$anchor" ]; then
        revs=$(git rev-list --no-merges --reverse HEAD "^${anchor}" 2>/dev/null) || return 1
    else
        revs=$(git rev-list --no-merges --reverse HEAD 2>/dev/null) || return 1
    fi
    while IFS= read -r sha; do
        [ -n "$sha" ] || continue
        files=$(git diff-tree --root --no-commit-id --name-only -r "$sha" 2>/dev/null) || return 1
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            if _prc_is_code_file "$f"; then
                printf '%s\n' "$sha"
                break
            fi
        done <<EOF
$files
EOF
    done <<EOF
$revs
EOF
    return 0
}

# ============================================================================
# Test-command resolution (verify step 3; prepare gate)
# ============================================================================

# Sets _PRC_TESTCMD. rc 0 resolved | 1 no test command (no stack pack, or an active
# content pack: M-3) | 2 unresolvable
# (fail closed; reason in _PRC_ERR). stack-contract-lint.sh validates the pack's
# contract block (it prints nothing on stdout), then test_command is read from
# the same block.
# M-3: content packs have no test contract (the lint returns MISSING_BLOCK for them).
# The allowlist is read from stack-contract-lint.sh's own CONTENT_PACKS=(...) line
# (that script is not sourceable), never duplicated here.
_prc_is_content_pack() { # pack
    local line p
    line=$(sed -n 's/^CONTENT_PACKS=(\(.*\))[[:space:]]*$/\1/p' "$_PRC_DIR/stack-contract-lint.sh" 2>/dev/null | sed -n '1p')
    for p in $line; do
        p="${p#\"}"
        p="${p%\"}"
        [ "$p" != "$1" ] || return 0
    done
    return 1
}

_prc_resolve_test_command() {
    local pack lint_err rc=0 cmd file
    _PRC_TESTCMD=""
    _PRC_ERR=""
    [ -f .aod/stack-active.json ] || return 1
    pack=$(jq -r '.pack' .aod/stack-active.json 2>/dev/null) || {
        _PRC_ERR="cannot resolve test command: .aod/stack-active.json is malformed"
        return 2
    }
    case "$pack" in
        '' | null | */* | *..*)
            _PRC_ERR="cannot resolve test command: .aod/stack-active.json has no valid pack"
            return 2
            ;;
    esac
    if _prc_is_content_pack "$pack"; then
        _PRC_ERR="no test command available (content pack ${pack})"
        return 1
    fi
    file="stacks/${pack}/STACK.md"
    if [ ! -f "$file" ]; then
        _PRC_ERR="cannot resolve test command: ${file} not found"
        return 2
    fi
    lint_err=$(bash "$_PRC_DIR/stack-contract-lint.sh" "$file" 2>&1 >/dev/null) || rc=$?
    if [ "$rc" -ne 0 ]; then
        _PRC_ERR="cannot resolve test command: contract lint rc=${rc} for ${file}: $(_prc_first_line "$lint_err")"
        return 2
    fi
    cmd=$(awk '
        /<!-- BEGIN: aod-test-contract -->/ { f = 1; next }
        /<!-- END: aod-test-contract -->/ { f = 0 }
        f && /^[[:space:]]*test_command:/ {
            sub(/^[[:space:]]*test_command:[[:space:]]*/, "")
            sub(/[[:space:]]+$/, "")
            print
            exit
        }' "$file")
    case "$cmd" in
        \"*\") cmd="${cmd#\"}"; cmd="${cmd%\"}" ;;
        \'*\') cmd="${cmd#\'}"; cmd="${cmd%\'}" ;;
    esac
    if [ -z "$cmd" ]; then
        _PRC_ERR="cannot resolve test command: no test_command in ${file}"
        return 2
    fi
    _PRC_TESTCMD="$cmd"
    return 0
}

# ============================================================================
# verify
# ============================================================================

_prc_write_record() { # featdir feature sha result command reason
    local featdir="$1" feature="$2" sha="$3" result="$4" cmd="$5" reason="$6" dir path tmp ts
    dir="${featdir}/test-results"
    path="${dir}/post-refactor.json"
    tmp="${path}.tmp.$$"
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    mkdir -p "$dir" || return 1
    if ! jq -n --arg feature "$feature" --arg sha "$sha" --arg result "$result" \
        --arg cmd "$cmd" --arg reason "$reason" --arg ts "$ts" '{
            version: 1,
            feature: $feature,
            verified_sha: $sha,
            result: $result,
            command: (if $cmd == "" then null else $cmd end),
            reason: (if $reason == "" then null else $reason end),
            timestamp: $ts
        }' >"$tmp" 2>/dev/null; then
        rm -f "$tmp" 2>/dev/null
        return 1
    fi
    mv "$tmp" "$path" || {
        rm -f "$tmp" 2>/dev/null
        return 1
    }
    return 0
}

pr_closeout_verify() { # feature autonomous
    local feature="$1" nnn default commits head_sha rc=0 result="" cmd="" reason="" log last msg
    nnn="${feature%%-*}"
    default=$(_prc_default_branch)
    if ! _prc_assert_branch "$feature" "$default"; then
        _prc_halt "$feature" precondition_failed "" "" "$_PRC_ERR"
        return 10
    fi
    if ! _prc_feature_dir "$nnn"; then
        _prc_halt "$feature" precondition_failed "" "" "$_PRC_ERR"
        return 10
    fi
    git fetch --quiet origin "$default" >/dev/null 2>&1 || _prc_warn "git fetch origin failed; using the existing origin/<default>"
    if ! commits=$(_commits_needing_verification "$nnn" "$default"); then
        _prc_halt "$feature" tests_failed "" "" "cannot classify commits needing verification (git error)"
        return 10
    fi
    if [ -z "$commits" ]; then
        _prc_log "no code-touching commits need verification"
        printf 'verify=skipped\n'
        return 0
    fi
    head_sha=$(git rev-parse HEAD)
    _prc_resolve_test_command || rc=$?
    case "$rc" in
        0)
            cmd="$_PRC_TESTCMD"
            ;;
        1)
            result="not_reverified"
            reason="no test command available"
            ;;
        *)
            _prc_halt "$feature" tests_failed "" "$head_sha" "$_PRC_ERR"
            return 10
            ;;
    esac
    local test_rc=0
    if [ -n "$cmd" ]; then
        mkdir -p .aod/state
        log=".aod/state/post-refactor-${nnn}.log"
        _prc_log "running post-refactor tests: ${cmd}"
        bash -c "$cmd" >"$log" 2>&1 || test_rc=$?
        if [ "$test_rc" -eq 0 ]; then result="pass"; else result="fail"; fi
    fi
    if ! _prc_write_record "$_PRC_FEATDIR" "$feature" "$head_sha" "$result" "$cmd" "$reason"; then
        _prc_halt "$feature" precondition_failed "" "$head_sha" "cannot write post-refactor.json"
        return 10
    fi
    git add -f -- "${_PRC_FEATDIR}/test-results/post-refactor.json" || {
        _prc_halt "$feature" precondition_failed "" "$head_sha" "cannot stage post-refactor.json"
        return 10
    }
    if ! git diff --cached --quiet 2>/dev/null; then
        msg="test(${nnn}): record post-refactor verification

${_PRC_TRAILER}"
        if ! git commit -q -m "$msg" >/dev/null 2>&1; then
            _prc_halt "$feature" precondition_failed "" "$head_sha" "cannot commit post-refactor.json"
            return 10
        fi
    fi
    if [ "$result" = "fail" ]; then
        last=$(tail -n 1 "$log" 2>/dev/null) || last=""
        _prc_halt "$feature" tests_failed "" "$head_sha" "command: ${cmd}; rc=${test_rc}; last log line: ${last}"
        return 10
    fi
    if [ "$result" = "pass" ]; then
        printf 'verify=pass command=%s verified_sha=%s\n' "$cmd" "$head_sha"
    else
        printf 'verify=not_reverified verified_sha=%s\n' "$head_sha"
    fi
    return 0
}

# ============================================================================
# prepare helpers
# ============================================================================

# Verification gate (D-5 step 5). Sets _PRC_GATE (skipped|pass|not_reverified).
# rc 0 ok, 1 refuse (reason in _PRC_ERR).
_prc_gate() { # nnn featdir default
    local nnn="$1" featdir="$2" default="$3" commits rec sha result c rc=0
    _PRC_GATE="skipped"
    if ! commits=$(_commits_needing_verification "$nnn" "$default"); then
        _PRC_ERR="cannot classify commits needing verification (git error)"
        return 1
    fi
    [ -n "$commits" ] || return 0
    rec="${featdir}/test-results/post-refactor.json"
    if ! git cat-file -e "HEAD:${rec}" 2>/dev/null; then
        _PRC_ERR="code commits need verification but ${rec} is not tracked at HEAD (run verify)"
        return 1
    fi
    sha=$(git show "HEAD:${rec}" 2>/dev/null | jq -r '.verified_sha // ""' 2>/dev/null) || sha=""
    result=$(git show "HEAD:${rec}" 2>/dev/null | jq -r '.result // ""' 2>/dev/null) || result=""
    case "$sha" in
        '' | *[!0-9a-f]*)
            _PRC_ERR="post-refactor.json has no valid verified_sha"
            return 1
            ;;
    esac
    if ! git cat-file -e "${sha}^{commit}" 2>/dev/null || ! git merge-base --is-ancestor "$sha" HEAD 2>/dev/null; then
        _PRC_ERR="verified_sha $(_prc_short "$sha") is not an ancestor of HEAD"
        return 1
    fi
    while IFS= read -r c; do
        [ -n "$c" ] || continue
        if ! git merge-base --is-ancestor "$c" "$sha" 2>/dev/null; then
            _PRC_ERR="unverified commit $(_prc_short "$c") is not covered by verified_sha $(_prc_short "$sha")"
            return 1
        fi
    done <<EOF
$commits
EOF
    case "$result" in
        pass)
            _PRC_GATE="pass"
            return 0
            ;;
        not_reverified)
            _prc_resolve_test_command || rc=$?
            if [ "$rc" -eq 1 ]; then
                _PRC_GATE="not_reverified"
                return 0
            fi
            if [ "$rc" -eq 0 ]; then
                _PRC_ERR="record is not_reverified but a test command is now available (run verify)"
            fi
            return 1
            ;;
        fail)
            _PRC_ERR="post-refactor verification result is fail"
            return 1
            ;;
        *)
            _PRC_ERR="post-refactor.json has unknown result '${result}'"
            return 1
            ;;
    esac
}

# PR labels that forbid closeout. rc 0 ok | 1 forbidden (_PRC_ERR) | 2 gh error.
_prc_check_pr_labels() { # pr
    local pr="$1" json names l
    _PRC_ERR=""
    json=$(gh pr view "$pr" --json labels 2>/dev/null) || {
        _PRC_ERR="cannot read PR #${pr} labels"
        return 2
    }
    names=$(printf '%s' "$json" | jq -r '.labels[]? | (if type == "object" then .name else . end)' 2>/dev/null) || names=""
    while IFS= read -r l; do
        case "$l" in
            e2e-heal | requires-review)
                _PRC_ERR="PR #${pr} carries the '${l}' label"
                return 1
                ;;
        esac
    done <<EOF
$names
EOF
    return 0
}

# Open heal PRs targeting the feature branch. Prints numbers; rc 2 on gh error.
_prc_open_heal_prs() { # F
    local out
    out=$(gh pr list --state open --label e2e-heal --base "$1" --json number --jq '.[].number' 2>/dev/null) || return 2
    printf '%s' "$out" | tr '\n' ' ' | sed -e 's/[[:space:]]*$//'
    return 0
}

# Update from default (D-5 step 6). rc 0 ok | 1 conflict | 2 other failure (_PRC_ERR).
_prc_update_from_default() { # default
    local default="$1" out rc=0 paths p all_regen=1 n=0
    git fetch --quiet origin >/dev/null 2>&1 || {
        _PRC_ERR="git fetch origin failed"
        return 2
    }
    if ! git rev-parse --verify --quiet "origin/${default}^{commit}" >/dev/null 2>&1; then
        _PRC_ERR="origin/${default} not found"
        return 2
    fi
    out=$(git merge --no-edit "origin/${default}" 2>&1) || rc=$?
    [ "$rc" -ne 0 ] || return 0
    paths=$(git diff --name-only --diff-filter=U 2>/dev/null) || paths=""
    if [ -z "$paths" ]; then
        git merge --abort >/dev/null 2>&1 || true
        _PRC_ERR="merge of origin/${default} failed: $(_prc_first_line "$out")"
        return 2
    fi
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        n=$((n + 1))
        case "$p" in
            docs/product/_backlog/BACKLOG.md | scripts/extract-classification.txt) ;;
            *) all_regen=0 ;;
        esac
    done <<EOF
$paths
EOF
    if [ "$all_regen" -eq 1 ] && [ "$n" -gt 0 ]; then
        rc=0
        while IFS= read -r p; do
            [ -n "$p" ] || continue
            git checkout --ours -- "$p" >/dev/null 2>&1 && git add -- "$p" >/dev/null 2>&1 || rc=1
        done <<EOF
$paths
EOF
        if [ "$rc" -eq 0 ] && git commit --no-edit -q >/dev/null 2>&1; then
            _prc_log "resolved regenerable conflicts (rebuilt during finalize): $(printf '%s' "$paths" | tr '\n' ' ')"
            return 0
        fi
    fi
    git merge --abort >/dev/null 2>&1 || true
    _PRC_ERR="merge conflict with origin/${default} in: $(printf '%s' "$paths" | tr '\n' ' ')"
    return 1
}

# Finalize (D-5 step 8): stage:done, BACKLOG, classification snapshot, pin.
_prc_finalize_commit() { # nnn
    local nnn="$1" issue rc=0 backlog_cmd tmp msg p out
    issue=$((10#$nnn))
    (
        # shellcheck source=/dev/null
        . "$_PRC_DIR/github-lifecycle.sh"
        aod_gh_update_stage "$issue" done
    ) >&2 || rc=$?
    [ "$rc" -eq 0 ] || _prc_warn "stage:done label update on issue #${issue} returned rc=${rc}; continuing"
    backlog_cmd="${AOD_CLOSEOUT_BACKLOG_CMD:-bash .aod/scripts/bash/backlog-regenerate.sh}"
    rc=0
    bash -c "$backlog_cmd" >&2 || rc=$?
    [ "$rc" -eq 0 ] || _prc_warn "BACKLOG regeneration returned rc=${rc}; continuing"
    if [ -f scripts/check-extract-coverage.sh ]; then
        tmp=$(mktemp "${TMPDIR:-/tmp}/aod-extract.XXXXXX") || tmp=""
        if [ -n "$tmp" ]; then
            rc=0
            bash scripts/check-extract-coverage.sh --regenerate >"$tmp" 2>/dev/null || rc=$?
            if [ "$rc" -eq 0 ] && [ -s "$tmp" ]; then
                cat "$tmp" >scripts/extract-classification.txt
            else
                _prc_warn "extract classification regeneration returned rc=${rc}; left unchanged"
            fi
            rm -f "$tmp"
        fi
    fi
    for p in docs/product/_backlog/BACKLOG.md scripts/extract-classification.txt ".aod/pr-mode/${nnn}"; do
        [ -e "$p" ] || continue
        git add -- "$p" >/dev/null 2>&1 || _prc_warn "could not stage ${p}"
    done
    if git diff --cached --quiet 2>/dev/null; then
        _prc_log "nothing to commit at finalize"
        return 0
    fi
    msg="chore(${nnn}): closeout — stage:done, regenerate backlog

${_PRC_TRAILER}"
    out=$(git commit -q -m "$msg" 2>&1) || {
        _PRC_ERR="finalize commit failed: $(_prc_first_line "$out")"
        return 1
    }
    return 0
}

# Push HEAD to the feature ref only. rc 0 | 1 non-fast-forward | 2 other (_PRC_ERR).
_prc_push_feature() { # F
    local out rc=0
    out=$(git push origin "HEAD:refs/heads/$1" 2>&1) || rc=$?
    [ "$rc" -ne 0 ] || return 0
    case "$out" in
        *non-fast-forward* | *"[rejected]"* | *"fetch first"* | *"stale info"*)
            _PRC_ERR="push rejected: $(_prc_first_line "$out")"
            return 1
            ;;
    esac
    _PRC_ERR="push failed: $(_prc_first_line "$out")"
    return 2
}

# Head guard (D-5 step 9). rc 0 | 1 mismatch (_PRC_ERR).
_prc_head_guard() { # F pr sha
    local f="$1" pr="$2" sha="$3" remote polls interval i=0 oid
    remote=$(git ls-remote origin "refs/heads/${f}" 2>/dev/null | awk 'NR==1{print $1}')
    if [ "$remote" != "$sha" ]; then
        _PRC_ERR="remote head ${remote:-<none>} does not equal local HEAD ${sha}"
        return 1
    fi
    polls=$(_prc_env_int AOD_CLOSEOUT_HEAD_POLLS 10)
    interval=$(_prc_env_int AOD_CLOSEOUT_HEAD_INTERVAL 3)
    [ "$polls" -ge 1 ] || polls=1
    while [ "$i" -lt "$polls" ]; do
        oid=$(gh pr view "$pr" --json headRefOid --jq '.headRefOid' 2>/dev/null) || oid=""
        [ "$oid" != "$sha" ] || return 0
        i=$((i + 1))
        [ "$i" -ge "$polls" ] || sleep "$interval"
    done
    _PRC_ERR="PR #${pr} head ${oid:-<unknown>} did not reach ${sha} after ${polls} polls"
    return 1
}

# First line of $1 mentioning a failure, else its first line.
_prc_failing_line() { # text
    local l
    l=$(printf '%s\n' "$1" | grep -i -m1 'fail' 2>/dev/null) || l=""
    if [ -n "$l" ]; then printf '%s' "$l"; else _prc_first_line "$1"; fi
}

# Checks polling (D-5 step 10). Sets _PRC_CHECKS (pass|none). Returns 0 or 10
# (halt written). Tri-state checks plus mergeStateStatus plus reviewDecision.
_prc_wait_checks() { # F pr sha
    local f="$1" pr="$2" sha="$3" bound interval deadline now rc out cstate view vrc ms rd readied=0 sleep_for
    bound=$(_prc_env_int AOD_CLOSEOUT_CHECKS_TIMEOUT "")
    [ -n "$bound" ] || bound=$(aod_checks_timeout_seconds)
    interval=$(_prc_env_int AOD_CLOSEOUT_CHECKS_INTERVAL 30)
    [ "$interval" -ge 1 ] || interval=1
    deadline=$(($(_prc_now) + bound))
    ms=""
    cstate="pending"
    while :; do
        rc=0
        out=$(gh pr checks "$pr" --required 2>&1) || rc=$?
        case "$rc" in
            0) cstate="pass" ;;
            8) cstate="pending" ;;
            *)
                if printf '%s' "$out" | grep -qi "no required checks reported"; then
                    cstate="none"
                else
                    _prc_halt "$f" checks_failed "$pr" "$sha" "gh pr checks rc=${rc}: $(_prc_failing_line "$out")"
                    return 10
                fi
                ;;
        esac
        vrc=0
        view=$(gh pr view "$pr" --json mergeStateStatus,reviewDecision 2>/dev/null) || vrc=$?
        ms=""
        rd=""
        if [ "$vrc" -eq 0 ]; then
            ms=$(printf '%s' "$view" | jq -r '.mergeStateStatus // ""' 2>/dev/null) || ms=""
            rd=$(printf '%s' "$view" | jq -r '.reviewDecision // ""' 2>/dev/null) || rd=""
        fi
        if [ "$ms" = "DIRTY" ]; then
            _prc_halt "$f" conflict "$pr" "$sha" "mergeStateStatus is DIRTY (merge conflict with the default branch)"
            return 10
        fi
        if [ "$cstate" = "pass" ] || [ "$cstate" = "none" ]; then
            case "$rd" in
                REVIEW_REQUIRED | CHANGES_REQUESTED)
                    _prc_halt "$f" not_merged "$pr" "$sha" "review required (reviewDecision=${rd}, checks=${cstate})"
                    return 10
                    ;;
            esac
            case "$ms" in
                CLEAN | HAS_HOOKS | UNSTABLE)
                    _PRC_CHECKS="$cstate"
                    return 0
                    ;;
                DRAFT)
                    if [ "$readied" -eq 0 ]; then
                        readied=1
                        gh pr ready "$pr" >/dev/null 2>&1 || _prc_warn "gh pr ready ${pr} failed while polling"
                    fi
                    ;;
            esac
        fi
        now=$(_prc_now)
        if [ "$now" -ge "$deadline" ]; then
            if [ "$cstate" = "pass" ] || [ "$cstate" = "none" ]; then
                _prc_halt "$f" checks_failed "$pr" "$sha" "checks ${cstate} but PR not mergeable after ${bound}s (mergeStateStatus=${ms:-unknown}); if BEHIND, re-run prepare to update from the default branch; if BLOCKED, check branch protection"
            else
                _prc_halt "$f" checks_failed "$pr" "$sha" "timed out after ${bound}s waiting for required checks (checks=${cstate}, mergeStateStatus=${ms:-unknown})"
            fi
            return 10
        fi
        sleep_for="$interval"
        if [ $((deadline - now)) -lt "$sleep_for" ]; then sleep_for=$((deadline - now)); fi
        [ "$sleep_for" -ge 1 ] || sleep_for=1
        sleep "$sleep_for"
    done
}

# ============================================================================
# prepare
# ============================================================================

pr_closeout_prepare() { # feature autonomous
    local feature="$1" nnn default pick pr state sha rc=0 delivered ts hp out_ready
    nnn="${feature%%-*}"
    default=$(_prc_default_branch)
    # Step 0: stale record
    if [ -f "${AOD_HALT_STATE_DIR}/document-${nnn}.halt.json" ]; then
        _prc_log "removing stale ${AOD_HALT_STATE_DIR}/document-${nnn}.halt.json (prepare re-evaluates from scratch)"
        _prc_remove_record "$nnn"
    fi
    # Step 1: branch assertions
    if ! _prc_assert_branch "$feature" "$default"; then
        _prc_halt "$feature" precondition_failed "" "" "$_PRC_ERR"
        return 10
    fi
    # Step 2: gh
    if ! _prc_gh_check; then
        _prc_halt "$feature" gh_unavailable "" "" "$_PRC_ERR"
        return 10
    fi
    # Step 3: resolve the PR (exact head lookup, L-6)
    _prc_collect_branch "$feature" "$default"
    if [ "$_PRC_GH_AVAIL" -ne 1 ]; then
        _prc_halt "$feature" gh_unavailable "" "" "cannot list pull requests with gh"
        return 10
    fi
    if ! pick=$(_prc_pick_for_branch "$feature"); then
        _prc_halt "$feature" precondition_failed "" "" "no pull request found for branch ${feature} (base ${default})"
        return 10
    fi
    pr="${pick%%"$_PRC_SEP"*}"
    state="${pick#*"$_PRC_SEP"}"
    if [ "$state" != "OPEN" ]; then
        _prc_halt "$feature" precondition_failed "$pr" "" "PR #${pr} is ${state}, not OPEN (if MERGED, run post-merge)"
        return 10
    fi
    # Step 4: preconditions
    rc=0
    _prc_check_pr_labels "$pr" || rc=$?
    if [ "$rc" -eq 2 ]; then
        _prc_halt "$feature" gh_unavailable "$pr" "" "$_PRC_ERR"
        return 10
    elif [ "$rc" -ne 0 ]; then
        _prc_halt "$feature" precondition_failed "$pr" "" "$_PRC_ERR"
        return 10
    fi
    rc=0
    hp=$(_prc_open_heal_prs "$feature") || rc=$?
    if [ "$rc" -ne 0 ]; then
        _prc_halt "$feature" gh_unavailable "$pr" "" "cannot list heal PRs"
        return 10
    fi
    if [ -n "$hp" ]; then
        _prc_halt "$feature" heal_pr_open "$pr" "" "open heal PR(s) target ${feature}: ${hp}"
        return 10
    fi
    if [ -f "${AOD_HALT_STATE_DIR}/deliver-${nnn}.halt.json" ]; then
        ts=$(jq -r '.timestamp // "unknown time"' "${AOD_HALT_STATE_DIR}/deliver-${nnn}.halt.json" 2>/dev/null) || ts="unknown time"
        _prc_halt "$feature" precondition_failed "$pr" "" "deliver halt record ${AOD_HALT_STATE_DIR}/deliver-${nnn}.halt.json present (written ${ts}); if deliver has since succeeded, re-run /aod.deliver"
        return 10
    fi
    if ! _prc_feature_dir "$nnn"; then
        _prc_halt "$feature" precondition_failed "$pr" "" "$_PRC_ERR"
        return 10
    fi
    delivered="${_PRC_FEATDIR}/delivery.md"
    if ! git cat-file -e "HEAD:${delivered}" 2>/dev/null; then
        _prc_halt "$feature" precondition_failed "$pr" "" "${delivered} is not tracked at HEAD"
        return 10
    fi
    # Step 5: verification gate
    git fetch --quiet origin "$default" >/dev/null 2>&1 || _prc_warn "git fetch origin ${default} failed; gate uses the existing remote ref"
    if ! _prc_gate "$nnn" "$_PRC_FEATDIR" "$default"; then
        _prc_halt "$feature" tests_failed "$pr" "" "$_PRC_ERR"
        return 10
    fi
    local verify_state="$_PRC_GATE"
    # Step 6: update from default
    rc=0
    _prc_update_from_default "$default" || rc=$?
    if [ "$rc" -eq 1 ]; then
        _prc_halt "$feature" conflict "$pr" "" "$_PRC_ERR"
        return 10
    elif [ "$rc" -ne 0 ]; then
        _prc_halt "$feature" precondition_failed "$pr" "" "$_PRC_ERR"
        return 10
    fi
    # Step 7: mark ready (before the finalize push)
    rc=0
    out_ready=$(gh pr ready "$pr" 2>&1) || rc=$?
    if [ "$rc" -ne 0 ]; then
        _prc_halt "$feature" precondition_failed "$pr" "" "gh pr ready failed: $(_prc_first_line "$out_ready")"
        return 10
    fi
    # Step 8: finalize
    if ! _prc_finalize_commit "$nnn"; then
        _prc_halt "$feature" precondition_failed "$pr" "" "${_PRC_ERR:-finalize commit failed}"
        return 10
    fi
    rc=0
    _prc_push_feature "$feature" || rc=$?
    if [ "$rc" -eq 1 ]; then
        _prc_halt "$feature" head_mismatch "$pr" "" "$_PRC_ERR"
        return 10
    elif [ "$rc" -ne 0 ]; then
        _prc_halt "$feature" precondition_failed "$pr" "" "$_PRC_ERR"
        return 10
    fi
    # Step 9: head guard
    sha=$(git rev-parse HEAD)
    if ! _prc_head_guard "$feature" "$pr" "$sha"; then
        _prc_halt "$feature" head_mismatch "$pr" "$sha" "$_PRC_ERR"
        return 10
    fi
    # Step 10: checks
    _PRC_CHECKS=""
    rc=0
    _prc_wait_checks "$feature" "$pr" "$sha" || rc=$?
    [ "$rc" -eq 0 ] || return "$rc"
    # Step 11: output
    printf 'pr=%s sha=%s checks=%s default=%s verify=%s\n' "$pr" "$sha" "$_PRC_CHECKS" "$default" "$verify_state"
    return 0
}

# ============================================================================
# post-merge
# ============================================================================

# Sets _PM_STATUS (done|partial) and _PM_DETAIL (first failing step). Never
# writes a halt record: once MERGED is verified, problems are warnings (M5).
_prc_do_post_merge() { # F nnn pr merged_head default merge_commit
    local f="$1" nnn="$2" pr="$3" merged_head="$4" default="$5" mc="$6"
    local issue state out rc cur local_head
    _PM_STATUS="done"
    _PM_DETAIL=""
    issue=$((10#$nnn))
    # Issue close (issue number, never the PR number)
    rc=0
    state=$(gh issue view "$issue" --json state --jq '.state' 2>/dev/null) || rc=$?
    if [ "$rc" -ne 0 ]; then
        _prc_pm_fail "issue close" "cannot read issue #${issue}"
    elif [ "$state" = "OPEN" ]; then
        rc=0
        out=$(gh issue close "$issue" --comment "Delivered in PR #${pr}${mc:+ (merge $(_prc_short "$mc"))}." 2>&1) || rc=$?
        [ "$rc" -eq 0 ] || _prc_pm_fail "issue close" "$(_prc_first_line "$out")"
    fi
    # checkout + pull default
    cur=$(git branch --show-current 2>/dev/null) || cur=""
    if [ "$cur" != "$default" ]; then
        rc=0
        out=$(git checkout "$default" 2>&1) || rc=$?
        [ "$rc" -eq 0 ] || _prc_pm_fail "checkout" "$(_prc_first_line "$out")"
    fi
    cur=$(git branch --show-current 2>/dev/null) || cur=""
    if [ "$cur" = "$default" ]; then
        rc=0
        out=$(git pull --ff-only origin "$default" 2>&1) || rc=$?
        [ "$rc" -eq 0 ] || _prc_pm_fail "pull" "$(_prc_first_line "$out")"
    fi
    # remote branch: delete only if it still sits at the merged head (L-3);
    # tolerate an already-deleted ref, a lease rejection is a partial warning.
    if [ -z "$merged_head" ]; then
        _prc_pm_fail "delete remote branch" "merged head unknown; remote branch ${f} kept"
    else
        rc=0
        out=$(git push --force-with-lease="refs/heads/${f}:${merged_head}" origin --delete "$f" 2>&1) || rc=$?
        if [ "$rc" -ne 0 ]; then
            case "$out" in
                *"remote ref does not exist"* | *"unable to delete"*"does not exist"*) ;;
                *) _prc_pm_fail "delete remote branch" "$(_prc_first_line "$out") (remote branch ${f} kept; it may have commits after the merge)" ;;
            esac
        fi
    fi
    # local branch, only at the merged head
    if git show-ref --verify --quiet "refs/heads/${f}" 2>/dev/null; then
        local_head=$(git rev-parse "refs/heads/${f}")
        if [ "$cur" = "$f" ]; then
            _prc_warn "still on ${f}; local branch kept"
        elif [ -n "$merged_head" ] && [ "$local_head" = "$merged_head" ]; then
            rc=0
            out=$(git branch -D "$f" 2>&1) || rc=$?
            [ "$rc" -eq 0 ] || _prc_pm_fail "delete local branch" "$(_prc_first_line "$out")"
        else
            _prc_warn "local branch ${f} (${local_head}) is not at the merged head (${merged_head:-unknown}); kept"
        fi
    fi
    rc=0
    out=$(git remote prune origin 2>&1) || rc=$?
    [ "$rc" -eq 0 ] || _prc_pm_fail "prune" "$(_prc_first_line "$out")"
    return 0
}

_prc_pm_fail() { # step msg
    _prc_warn "post-merge ${1}: ${2}"
    if [ "$_PM_STATUS" = "done" ]; then
        _PM_STATUS="partial"
        _PM_DETAIL="${1}: ${2}"
    fi
}

pr_closeout_post_merge() { # feature pr
    local feature="$1" pr="$2" nnn default json state head mc rc=0
    nnn="${feature%%-*}"
    if ! _prc_gh_check; then
        _prc_halt "$feature" gh_unavailable "$pr" "" "$_PRC_ERR"
        return 10
    fi
    default=$(_prc_default_branch)
    json=$(gh pr view "$pr" --json state,headRefOid,mergeCommit 2>/dev/null) || rc=$?
    if [ "$rc" -ne 0 ]; then
        _prc_halt "$feature" precondition_failed "$pr" "" "cannot read PR #${pr}"
        return 10
    fi
    state=$(printf '%s' "$json" | jq -r '.state // ""')
    head=$(printf '%s' "$json" | jq -r '.headRefOid // ""')
    mc=$(printf '%s' "$json" | jq -r '.mergeCommit.oid // ""')
    if [ "$state" != "MERGED" ]; then
        _prc_halt "$feature" precondition_failed "$pr" "$head" "PR #${pr} is ${state:-unknown}, not MERGED"
        return 10
    fi
    _prc_do_post_merge "$feature" "$nnn" "$pr" "$head" "$default" "$mc"
    _prc_remove_record "$nnn"
    if [ "$_PM_STATUS" = "partial" ]; then
        printf 'post_merge=partial default=%s detail=%s\n' "$default" "$_PM_DETAIL"
    else
        printf 'post_merge=done default=%s\n' "$default"
    fi
    return 0
}

# ============================================================================
# merge
# ============================================================================

# THE merge call. Squash plus the head-commit guard and nothing else.
_prc_gh_merge_call() { # pr sha
    gh pr merge "$1" --squash --match-head-commit "$2"
}

# Merge-time re-assertion of prepare's authorization (H-1, KB 41): the same
# read-only preconditions and the same gate, plus one non-polling checks/mergeability
# read. rc 0 ok | 10 halt written.
_prc_merge_reassert() { # feature nnn default pr want
    local feature="$1" nnn="$2" default="$3" pr="$4" want="$5" rec reason ts delivered
    local out crc=0 cstate view ms draft
    rec="${AOD_HALT_STATE_DIR}/document-${nnn}.halt.json"
    if [ -f "$rec" ]; then
        reason=$(jq -r '.reason // "unknown"' "$rec" 2>/dev/null) || reason="unknown"
        _prc_halt "$feature" precondition_failed "$pr" "$want" "last closeout halted (${reason}); re-run /aod.document"
        return 10
    fi
    if [ -f "${AOD_HALT_STATE_DIR}/deliver-${nnn}.halt.json" ]; then
        ts=$(jq -r '.timestamp // "unknown time"' "${AOD_HALT_STATE_DIR}/deliver-${nnn}.halt.json" 2>/dev/null) || ts="unknown time"
        _prc_halt "$feature" precondition_failed "$pr" "$want" "deliver halt record ${AOD_HALT_STATE_DIR}/deliver-${nnn}.halt.json present (written ${ts}); if deliver has since succeeded, re-run /aod.deliver"
        return 10
    fi
    if ! _prc_feature_dir "$nnn"; then
        _prc_halt "$feature" precondition_failed "$pr" "$want" "$_PRC_ERR"
        return 10
    fi
    delivered="${_PRC_FEATDIR}/delivery.md"
    if ! git cat-file -e "HEAD:${delivered}" 2>/dev/null; then
        _prc_halt "$feature" precondition_failed "$pr" "$want" "${delivered} is not tracked at HEAD"
        return 10
    fi
    git fetch --quiet origin "$default" >/dev/null 2>&1 || _prc_warn "git fetch origin ${default} failed; gate uses the existing remote ref"
    if ! _prc_gate "$nnn" "$_PRC_FEATDIR" "$default"; then
        _prc_halt "$feature" tests_failed "$pr" "$want" "$_PRC_ERR"
        return 10
    fi
    out=$(gh pr checks "$pr" --required 2>&1) || crc=$?
    case "$crc" in
        0) cstate="pass" ;;
        8)
            _prc_halt "$feature" checks_failed "$pr" "$want" "required checks are still pending; re-run /aod.document"
            return 10
            ;;
        *)
            if printf '%s' "$out" | grep -qi "no required checks reported"; then
                cstate="none"
            else
                _prc_halt "$feature" checks_failed "$pr" "$want" "gh pr checks rc=${crc}: $(_prc_failing_line "$out")"
                return 10
            fi
            ;;
    esac
    view=$(gh pr view "$pr" --json mergeStateStatus,isDraft 2>/dev/null) || view=""
    ms=$(printf '%s' "$view" | jq -r '.mergeStateStatus // ""' 2>/dev/null) || ms=""
    draft=$(printf '%s' "$view" | jq -r '.isDraft // false' 2>/dev/null) || draft="true"
    if [ "$draft" != "false" ]; then
        _prc_halt "$feature" not_merged "$pr" "$want" "PR #${pr} is a draft (checks=${cstate}); re-run /aod.document"
        return 10
    fi
    case "$ms" in
        CLEAN | HAS_HOOKS | UNSTABLE) return 0 ;;
        DIRTY)
            _prc_halt "$feature" conflict "$pr" "$want" "mergeStateStatus is DIRTY (merge conflict with the default branch)"
            return 10
            ;;
        *)
            _prc_halt "$feature" not_merged "$pr" "$want" "PR #${pr} not mergeable (mergeStateStatus=${ms:-unknown}, checks=${cstate}); re-run /aod.document"
            return 10
            ;;
    esac
}

pr_closeout_merge() { # feature pr sha autonomous
    local feature="$1" pr="$2" sha_arg="$3" nnn default want local_head rc=0 hp
    local mrc=0 merr="" json state head mc polls i=0 detail pr_head_ref pr_base_ref
    nnn="${feature%%-*}"
    default=$(_prc_default_branch)
    if ! _prc_assert_branch "$feature" "$default"; then
        _prc_halt "$feature" precondition_failed "$pr" "" "$_PRC_ERR"
        return 10
    fi
    want=$(git rev-parse --verify --quiet "${sha_arg}^{commit}" 2>/dev/null) || want=""
    local_head=$(git rev-parse HEAD)
    if [ -z "$want" ] || [ "$want" != "$local_head" ]; then
        _prc_halt "$feature" head_mismatch "$pr" "$local_head" "local HEAD ${local_head} != --sha ${sha_arg}"
        return 10
    fi
    if ! _prc_gh_check; then
        _prc_halt "$feature" gh_unavailable "$pr" "$want" "$_PRC_ERR"
        return 10
    fi
    rc=0
    _prc_check_pr_labels "$pr" || rc=$?
    if [ "$rc" -eq 2 ]; then
        _prc_halt "$feature" gh_unavailable "$pr" "$want" "$_PRC_ERR"
        return 10
    elif [ "$rc" -ne 0 ]; then
        _prc_halt "$feature" precondition_failed "$pr" "$want" "$_PRC_ERR"
        return 10
    fi
    rc=0
    hp=$(_prc_open_heal_prs "$feature") || rc=$?
    if [ "$rc" -ne 0 ]; then
        _prc_halt "$feature" gh_unavailable "$pr" "$want" "cannot list heal PRs"
        return 10
    fi
    if [ -n "$hp" ]; then
        _prc_halt "$feature" heal_pr_open "$pr" "$want" "open heal PR(s) target ${feature}: ${hp}"
        return 10
    fi
    json=$(gh pr view "$pr" --json state,headRefOid,mergeCommit,headRefName,baseRefName 2>/dev/null) || json=""
    state=$(printf '%s' "$json" | jq -r '.state // ""' 2>/dev/null) || state=""
    # L-4: bind --pr to F and to the default branch.
    pr_head_ref=$(printf '%s' "$json" | jq -r '.headRefName // ""' 2>/dev/null) || pr_head_ref=""
    pr_base_ref=$(printf '%s' "$json" | jq -r '.baseRefName // ""' 2>/dev/null) || pr_base_ref=""
    if [ "$pr_head_ref" != "$feature" ] || [ "$pr_base_ref" != "$default" ]; then
        _prc_halt "$feature" precondition_failed "$pr" "$want" "PR #${pr} is ${pr_head_ref:-<unreadable>} -> ${pr_base_ref:-<unreadable>}, expected ${feature} -> ${default}"
        return 10
    fi
    case "$state" in
        CLOSED)
            _prc_halt "$feature" precondition_failed "$pr" "$want" "PR #${pr} is CLOSED"
            return 10
            ;;
        MERGED) _prc_log "PR #${pr} is already MERGED; skipping the merge call" ;;
        *)
            # H-1: merge re-asserts prepare's authorization (not already MERGED).
            if ! printf '%s' "$sha_arg" | grep -Eq '^[0-9a-f]{40}$'; then
                _prc_log "ERROR: --sha must be 40 lowercase hex characters"
                return 2
            fi
            rc=0
            _prc_merge_reassert "$feature" "$nnn" "$default" "$pr" "$want" || rc=$?
            [ "$rc" -eq 0 ] || return "$rc"
            merr=$(_prc_gh_merge_call "$pr" "$want" 2>&1 >/dev/null) || mrc=$?
            ;;
    esac
    # Verify the state regardless of the merge call's exit code.
    polls=3
    [ "$mrc" -eq 0 ] || polls=1
    while :; do
        json=$(gh pr view "$pr" --json state,headRefOid,mergeCommit 2>/dev/null) || json=""
        state=$(printf '%s' "$json" | jq -r '.state // ""' 2>/dev/null) || state=""
        [ "$state" != "MERGED" ] || break
        i=$((i + 1))
        [ "$i" -lt "$polls" ] || break
        sleep 2
    done
    head=$(printf '%s' "$json" | jq -r '.headRefOid // ""' 2>/dev/null) || head=""
    if [ "$state" != "MERGED" ]; then
        if [ -z "$state" ]; then
            _prc_halt "$feature" not_merged "$pr" "$want" "merge call rc=${mrc}; cannot read PR #${pr} state afterwards (re-run merge to confirm)"
        elif [ -n "$head" ] && [ "$head" != "$want" ]; then
            _prc_halt "$feature" head_mismatch "$pr" "$want" "PR head ${head} moved from ${want}"
        elif [ "$mrc" -eq 0 ]; then
            _prc_halt "$feature" not_merged "$pr" "$want" "detail=queued (merge accepted but PR is ${state:-not merged}; merge queue or auto-merge)"
        else
            detail=$(_prc_first_line "$merr")
            _prc_halt "$feature" not_merged "$pr" "$want" "${detail:-gh pr merge failed (rc=${mrc})}"
        fi
        return 10
    fi
    mc=$(printf '%s' "$json" | jq -r '.mergeCommit.oid // ""' 2>/dev/null) || mc=""
    # M-1: the merged head is gh's headRefOid, never --sha. A PR that was already
    # MERGED at another head keeps the local branch (and the remote lease fails).
    if [ -n "$head" ] && [ "$head" != "$want" ]; then
        _prc_warn "PR #${pr} was merged at ${head}, not at --sha ${want}; local branch kept"
    fi
    _prc_do_post_merge "$feature" "$nnn" "$pr" "$head" "$default" "$mc"
    _prc_remove_record "$nnn"
    if [ "$_PM_STATUS" = "partial" ]; then
        printf 'merged=%s merge_commit=%s post_merge=partial detail=%s\n' "$pr" "$mc" "$_PM_DETAIL"
    else
        printf 'merged=%s merge_commit=%s post_merge=done\n' "$pr" "$mc"
    fi
    return 0
}

# ============================================================================
# outcome (D-7)
# ============================================================================

# Prints the verify value recorded at the merge commit.
_prc_outcome_verify() { # feature nnn merge_commit default
    local feature="$1" nnn="$2" mc="$3" default="$4" featdir rc out res
    [ -n "$mc" ] || { printf 'unknown'; return 0; }
    git fetch --quiet origin "$default" >/dev/null 2>&1 || _prc_warn "git fetch origin ${default} failed"
    if ! git cat-file -e "${mc}^{commit}" 2>/dev/null; then
        printf 'unknown'
        return 0
    fi
    if _prc_feature_dir "$nnn"; then featdir="$_PRC_FEATDIR"; else featdir="specs/${feature}"; fi
    rc=0
    out=$(git show "${mc}:${featdir}/test-results/post-refactor.json" 2>/dev/null) || rc=$?
    if [ "$rc" -ne 0 ]; then
        printf 'skipped'
        return 0
    fi
    res=$(printf '%s' "$out" | jq -r '.result // ""' 2>/dev/null) || res=""
    case "$res" in
        pass | not_reverified) printf '%s' "$res" ;;
        *) printf 'unknown' ;;
    esac
}

pr_closeout_outcome() { # feature autonomous
    local feature="$1" autonomous="$2" nnn default rec reason pick pr="" state="" url="" mc="" head="" json rc=0 count v
    nnn="${feature%%-*}"
    default=$(_prc_default_branch)
    rec="${AOD_HALT_STATE_DIR}/document-${nnn}.halt.json"
    if [ "$feature" != "$nnn" ]; then
        _prc_collect_branch "$feature" "$default"   # branch known: exact lookup (L-6)
    else
        _prc_collect "$nnn" "$default"
    fi
    if [ "$_PRC_GH_AVAIL" -ne 1 ]; then
        # gh unavailable (interactive: awaiting_merge; autonomous: fail closed)
        if [ "$autonomous" -eq 1 ]; then
            if [ -f "$rec" ]; then
                reason=$(jq -r '.reason // "precondition_failed"' "$rec" 2>/dev/null) || reason="precondition_failed"
            else
                reason="gh_unavailable"
                write_document_halt_record "$feature" gh_unavailable "" "" "gh unavailable; cannot confirm the merge state" || true
            fi
            printf 'outcome=failed pr_url= merge_commit= reason=%s verify=unknown\n' "$reason"
        else
            _prc_log "gh unavailable; cannot confirm the merge state"
            printf 'outcome=awaiting_merge pr_url= merge_commit= reason= verify=unknown\n'
        fi
        return 0
    fi
    if pick=$(_prc_pick_for_branch "$feature"); then
        pr="${pick%%"$_PRC_SEP"*}"
        state="${pick#*"$_PRC_SEP"}"
    else
        count=$(_prc_cand_count)
        if [ "$count" -eq 1 ]; then
            pick=$(printf '%s' "$_PRC_CAND_LINES" | sed -n '1p')
            pick="${pick#*"$_PRC_SEP"}"
            pr="${pick%%"$_PRC_SEP"*}"
            state="${pick#*"$_PRC_SEP"}"
        elif [ "$count" -gt 1 ]; then
            state="AMBIGUOUS"
        else
            state="NONE"
        fi
    fi
    if [ -n "$pr" ]; then
        json=$(gh pr view "$pr" --json state,mergeCommit,url,headRefOid 2>/dev/null) || rc=$?
        if [ "$rc" -eq 0 ]; then
            state=$(printf '%s' "$json" | jq -r '.state // ""')
            url=$(printf '%s' "$json" | jq -r '.url // ""')
            mc=$(printf '%s' "$json" | jq -r '.mergeCommit.oid // ""')
            head=$(printf '%s' "$json" | jq -r '.headRefOid // ""')
        fi
    fi
    if [ "$state" = "MERGED" ]; then
        _prc_remove_record "$nnn"
        v=$(_prc_outcome_verify "$feature" "$nnn" "$mc" "$default")
        printf 'outcome=completed pr_url=%s merge_commit=%s reason= verify=%s\n' "$url" "$mc" "$v"
        return 0
    fi
    # Not merged
    if [ -f "$rec" ]; then
        reason=$(jq -r '.reason // "precondition_failed"' "$rec" 2>/dev/null) || reason="precondition_failed"
        printf 'outcome=failed pr_url=%s merge_commit= reason=%s verify=unknown\n' "$url" "$reason"
        return 0
    fi
    # L-7: a CLOSED (unmerged) PR, no PR, or an ambiguous match is a failure in
    # both modes (a record is written in autonomous mode only). awaiting_merge is
    # reserved for an OPEN PR with no record in interactive mode.
    case "$state" in
        CLOSED | NONE | AMBIGUOUS)
            if [ "$autonomous" -eq 1 ]; then
                write_document_halt_record "$feature" precondition_failed "$pr" "$head" "no mergeable PR for ${feature} (state=${state}); cannot confirm a merge" || true
            fi
            printf 'outcome=failed pr_url=%s merge_commit= reason=precondition_failed verify=unknown\n' "$url"
            return 0
            ;;
    esac
    if [ "$autonomous" -eq 1 ]; then
        write_document_halt_record "$feature" not_merged "$pr" "$head" "Document ended without a confirmed merge or a halt record" || true
        printf 'outcome=failed pr_url=%s merge_commit= reason=not_merged verify=unknown\n' "$url"
        return 0
    fi
    printf 'outcome=awaiting_merge pr_url=%s merge_commit= reason= verify=unknown\n' "$url"
    return 0
}

# ============================================================================
# Entry point
# ============================================================================

_prc_usage() {
    cat >&2 <<'USAGE'
usage: pr-closeout.sh <subcommand> [options]
  resolve    --feature <NNN|F> [--autonomous]
  verify     --feature <F> [--autonomous]
  prepare    --feature <F> [--autonomous]
  merge      --feature <F> --pr <N> --sha <SHA> [--autonomous]
  post-merge --feature <F> --pr <N>
  outcome    --feature <F> [--autonomous]
USAGE
}

pr_closeout_main() {
    local sub="${1-}" feature="" pr="" sha="" autonomous=0 arg root
    if [ -z "$sub" ]; then
        _prc_usage
        return 2
    fi
    shift
    case "$sub" in
        resolve | verify | prepare | merge | post-merge | outcome) ;;
        -h | --help)
            _prc_usage
            return 0
            ;;
        *)
            _prc_log "ERROR: unknown subcommand '${sub}'"
            _prc_usage
            return 2
            ;;
    esac
    while [ "$#" -gt 0 ]; do
        arg="$1"
        shift
        case "$arg" in
            --feature) feature="${1-}"; [ "$#" -eq 0 ] || shift ;;
            --feature=*) feature="${arg#*=}" ;;
            --pr) pr="${1-}"; [ "$#" -eq 0 ] || shift ;;
            --pr=*) pr="${arg#*=}" ;;
            --sha) sha="${1-}"; [ "$#" -eq 0 ] || shift ;;
            --sha=*) sha="${arg#*=}" ;;
            --autonomous) autonomous=1 ;;
            *)
                _prc_log "ERROR: unknown option '${arg}'"
                _prc_usage
                return 2
                ;;
        esac
    done
    if ! command -v git >/dev/null 2>&1; then
        _prc_log "ERROR: git is required"
        return 2
    fi
    if ! command -v jq >/dev/null 2>&1; then
        _prc_log "ERROR: jq is required"
        return 2
    fi
    if [ -z "$feature" ] || ! _prc_valid_nnn "${feature%%-*}"; then
        _prc_log "ERROR: --feature <NNN|NNN-name> is required (numeric NNN prefix)"
        return 2
    fi
    case "$sub" in
        merge | post-merge)
            if ! _prc_valid_num "$pr"; then
                _prc_log "ERROR: --pr <N> is required"
                return 2
            fi
            ;;
    esac
    if [ "$sub" = "merge" ] && [ -z "$sha" ]; then
        _prc_log "ERROR: --sha <SHA> is required"
        return 2
    fi
    root=$(git rev-parse --show-toplevel 2>/dev/null) || {
        _prc_log "ERROR: not inside a git repository"
        return 2
    }
    cd "$root" || return 2
    case "$sub" in
        resolve) pr_closeout_resolve "$feature" "$autonomous" ;;
        verify) pr_closeout_verify "$feature" "$autonomous" ;;
        prepare) pr_closeout_prepare "$feature" "$autonomous" ;;
        merge) pr_closeout_merge "$feature" "$pr" "$sha" "$autonomous" ;;
        post-merge) pr_closeout_post_merge "$feature" "$pr" ;;
        outcome) pr_closeout_outcome "$feature" "$autonomous" ;;
    esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    set -u
    pr_closeout_main "$@"
    exit $?
fi
