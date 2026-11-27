#!/usr/bin/env bash

# aod-config.sh — LIBRARY: validated reads/writes of .aod/config.json and
# pr_per_cycle mode resolution (Feature 204).
#
# LIBRARY: source this file; do not execute it. It does NOT set -e/-u/pipefail
# (a sourced library must not change the caller's shell options) and is safe to
# source and call under `set -u` and `set -e` callers: no unbound variables, and
# every internal failure is captured as a return code. Calling a function that
# returns non-zero (rc 3/4) under `set -e` is the caller's concern: capture it
# with `|| rc=$?`.
# Bash 3.2 compatible (macOS default): no associative arrays, no ${var,,},
# no mapfile/readarray, no |&, no &>>, no negative indexes, no `wait -n`.
#
# Usage:
#   source .aod/scripts/bash/aod-config.sh
#   MODE=$(aod_pr_mode "$FEATURE" [--autonomous] [--no-pin]) || rc=$?
#
# Paths are relative to the current directory (repo root), like run-state.sh.
# All diagnostics go to stderr with the "[aod]" prefix. Requires jq for any
# read of an existing config file; git for branch/pin lookups. gh is never used.
#
# Functions and return codes:
#   aod_config_get <jq-path> <default>
#       Prints the value at <jq-path> (strings raw, other types as compact JSON),
#       or <default> when the file or key is absent / null. jq-path is trusted
#       program text from the caller, never user input.
#       rc 0 ok | 2 bad usage / invalid jq path | 3 jq missing, malformed JSON
#       or non-object root (default printed, warning on stderr).
#   aod_config_set_string <key> <value>
#       Top-level string key, jq merge, tmp + mv, other keys preserved, creates
#       .aod/config.json when absent. rc 0 ok | 2 bad usage | 3 jq missing,
#       malformed JSON or non-object root (file untouched) | 1 write failure.
#   aod_pr_mode_from_config
#       Prints single|split. rc 0 when valid or absent. rc 4 when the value is
#       invalid or the file is unreadable: prints split + "[aod] WARNING:" naming
#       the bad value. Never uses jq `//` (it conflates false/null with missing).
#   aod_pr_mode_pin_path <NNN|NNN-name>
#       Prints .aod/pr-mode/<NNN>. rc 2 when the prefix is not numeric.
#   aod_default_branch
#       gh-free: origin/HEAD (origin/ stripped), else main, else master.
#   aod_feature_branch_candidates <NNN|NNN-name>
#       Single implementation of feature-branch ref enumeration (N1). Prints
#       distinct short names, one per line, sorted: origin/ stripped, local and
#       origin of one branch count once, *-heal-* and *-document-stage excluded.
#   aod_feature_branch_ref <short-name>
#       Prints the full ref to read for a candidate: refs/heads/<n> when the
#       local branch exists, else refs/remotes/origin/<n>.
#   aod_pr_mode <feature> [--autonomous] [--no-pin]
#       The single entry point. Prints single|split.
#       Ambiguity (R-1): with no working-tree pin, two or more distinct
#       candidate names are ambiguous ONLY when HEAD is not one of them (e.g.
#       HEAD on the default or an unrelated branch): interactive resolves from
#       config with a warning, autonomous returns rc 6. When HEAD is itself a
#       candidate it is the feature branch: unambiguous, resolve from config and
#       write the pin; the split fallback never fires.
#       The pin is written only when HEAD is an <NNN>-* candidate branch for
#       that NNN (never on the default branch, a detached HEAD, or an unrelated
#       branch).
#       rc 0 ok | 1 pin write failure | 2 bad usage
#       | 4 autonomous: invalid pin or invalid config (callers: invalid_config)
#       | 6 autonomous: ambiguous feature branch (callers: precondition_failed).
#   aod_checks_timeout_seconds
#       Prints document.checks_timeout_seconds when a base-10 integer >= 60,
#       else warns and prints 1800. Always rc 0.
#
# Contract: specs/204-single-pr-per-cycle/contracts/config-contract.md

# Plain assignments (not readonly) so re-sourcing under `set -u` is harmless.
_AOD_CONFIG_FILE=".aod/config.json"
_AOD_PR_MODE_DIR=".aod/pr-mode"
_AOD_NNN_RE='^[0-9]+$'

# ============================================================================
# Internal helpers
# ============================================================================

_aod_cfg_warn() { printf '[aod] WARNING: %s\n' "$*" >&2; }
_aod_cfg_err() { printf '[aod] ERROR: %s\n' "$*" >&2; }

# _aod_config_check: classify the config file.
#   rc 0  present, valid JSON, object root
#   rc 10 file absent (not an error)
#   rc 3  jq missing / malformed / non-object (warning already emitted)
_aod_config_check() {
    local kind
    [ -f "$_AOD_CONFIG_FILE" ] || return 10
    if ! command -v jq >/dev/null 2>&1; then
        _aod_cfg_warn "jq not found; cannot read .aod/config.json"
        return 3
    fi
    if ! kind=$(jq -s -r 'if length == 1 then (.[0] | type) else "none" end' \
        "$_AOD_CONFIG_FILE" 2>/dev/null); then
        _aod_cfg_warn ".aod/config.json is not valid JSON"
        return 3
    fi
    if [ "$kind" != "object" ]; then
        _aod_cfg_warn ".aod/config.json root is not a JSON object"
        return 3
    fi
    return 0
}

# _aod_pin_is_valid <content>
_aod_pin_is_valid() {
    case "${1-}" in
        single | split) return 0 ;;
    esac
    return 1
}

# _aod_nnn_of <feature>: prints the numeric prefix; rc 2 when not numeric.
_aod_nnn_of() {
    local nnn="${1-}"
    nnn="${nnn%%-*}"
    if [ -z "$nnn" ] || ! [[ "$nnn" =~ $_AOD_NNN_RE ]]; then
        _aod_cfg_err "feature '${1-}' does not start with a numeric NNN"
        return 2
    fi
    printf '%s\n' "$nnn"
}

# _aod_pin_write <NNN> <mode>: atomic tmp + mv, creates the directory.
_aod_pin_write() {
    local nnn="$1" mode="$2" path tmp
    path="$_AOD_PR_MODE_DIR/$nnn"
    tmp="$path.tmp.$$"
    if ! mkdir -p "$_AOD_PR_MODE_DIR" 2>/dev/null; then
        _aod_cfg_err "cannot create $_AOD_PR_MODE_DIR"
        return 1
    fi
    if ! printf '%s\n' "$mode" >"$tmp" 2>/dev/null; then
        rm -f "$tmp" 2>/dev/null
        _aod_cfg_err "cannot write pin $path"
        return 1
    fi
    if ! mv "$tmp" "$path" 2>/dev/null; then
        rm -f "$tmp" 2>/dev/null
        _aod_cfg_err "cannot move pin into place at $path"
        return 1
    fi
    return 0
}

# ============================================================================
# Config read / write
# ============================================================================

aod_config_get() {
    local path="${1-}" default="${2-}" rc=0 out
    if [ -z "$path" ]; then
        _aod_cfg_err "aod_config_get: jq path required"
        printf '%s\n' "$default"
        return 2
    fi
    _aod_config_check || rc=$?
    if [ "$rc" -eq 10 ]; then
        printf '%s\n' "$default"
        return 0
    fi
    if [ "$rc" -ne 0 ]; then
        printf '%s\n' "$default"
        return 3
    fi
    # "N" = absent/null, "V<value>" = present. Avoids jq `//` (false/"" stay values).
    if ! out=$(jq -r "[try (${path}) catch null] | .[0]
        | if . == null then \"N\"
          else \"V\" + (if type == \"string\" then . else tojson end) end" \
        "$_AOD_CONFIG_FILE" 2>/dev/null); then
        _aod_cfg_err "aod_config_get: invalid jq path '$path'"
        printf '%s\n' "$default"
        return 2
    fi
    case "$out" in
        V*) printf '%s\n' "${out#V}" ;;
        *) printf '%s\n' "$default" ;;
    esac
    return 0
}

aod_config_set_string() {
    local key="${1-}" value="${2-}" rc=0 tmp="${_AOD_CONFIG_FILE}.tmp"
    if [ -z "$key" ]; then
        _aod_cfg_err "aod_config_set_string: key required"
        return 2
    fi
    if ! command -v jq >/dev/null 2>&1; then
        _aod_cfg_err "jq not found; cannot update .aod/config.json (file untouched)"
        return 3
    fi
    _aod_config_check || rc=$?
    case "$rc" in
        0)
            if ! jq --arg k "$key" --arg v "$value" '. + {($k): $v}' \
                "$_AOD_CONFIG_FILE" >"$tmp" 2>/dev/null; then
                rm -f "$tmp" 2>/dev/null
                _aod_cfg_err "failed to update .aod/config.json (file untouched)"
                return 1
            fi
            ;;
        10)
            if ! mkdir -p "$(dirname "$_AOD_CONFIG_FILE")" 2>/dev/null ||
                ! jq -n --arg k "$key" --arg v "$value" '{($k): $v}' \
                    >"$tmp" 2>/dev/null; then
                rm -f "$tmp" 2>/dev/null
                _aod_cfg_err "failed to create .aod/config.json"
                return 1
            fi
            ;;
        *)
            _aod_cfg_err "refusing to modify .aod/config.json (file untouched)"
            return 3
            ;;
    esac
    if ! mv "$tmp" "$_AOD_CONFIG_FILE" 2>/dev/null; then
        rm -f "$tmp" 2>/dev/null
        _aod_cfg_err "failed to move .aod/config.json into place"
        return 1
    fi
    return 0
}

aod_pr_mode_from_config() {
    local rc=0 raw
    _aod_config_check || rc=$?
    if [ "$rc" -eq 10 ]; then
        printf 'split\n'
        return 0
    fi
    if [ "$rc" -ne 0 ]; then
        _aod_cfg_warn "pr_per_cycle cannot be read from .aod/config.json; using split"
        printf 'split\n'
        return 4
    fi
    if ! raw=$(jq -r 'if has("pr_per_cycle") then (.pr_per_cycle | tojson) else "ABSENT" end' \
        "$_AOD_CONFIG_FILE" 2>/dev/null); then
        raw="<unreadable>"
    fi
    case "$raw" in
        ABSENT)
            printf 'split\n'
            return 0
            ;;
        '"single"')
            printf 'single\n'
            return 0
            ;;
        '"split"')
            printf 'split\n'
            return 0
            ;;
    esac
    _aod_cfg_warn "pr_per_cycle=${raw} is invalid (expected \"single\" or \"split\"); using split"
    printf 'split\n'
    return 4
}

aod_checks_timeout_seconds() {
    local raw rc=0 num
    raw=$(aod_config_get '.document.checks_timeout_seconds' 1800) || rc=$?
    if [ "$rc" -ne 0 ]; then
        printf '1800\n'
        return 0
    fi
    # Base-10 integer check on the string before any arithmetic (L3).
    case "$raw" in
        '' | *[!0-9]*) ;;
        *)
            if [ "${#raw}" -le 9 ]; then
                num=$((10#$raw))
                if [ "$num" -ge 60 ]; then
                    printf '%s\n' "$num"
                    return 0
                fi
            fi
            ;;
    esac
    _aod_cfg_warn "document.checks_timeout_seconds=${raw} is invalid; using 1800"
    printf '1800\n'
    return 0
}

# ============================================================================
# Git helpers (gh-free)
# ============================================================================

aod_pr_mode_pin_path() {
    local nnn
    nnn=$(_aod_nnn_of "${1-}") || return 2
    printf '%s/%s\n' "$_AOD_PR_MODE_DIR" "$nnn"
}

aod_default_branch() {
    local ref
    if ref=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null) &&
        [ -n "$ref" ]; then
        printf '%s\n' "${ref#origin/}"
        return 0
    fi
    if git show-ref --verify --quiet refs/heads/main 2>/dev/null ||
        git show-ref --verify --quiet refs/remotes/origin/main 2>/dev/null; then
        printf 'main\n'
    else
        printf 'master\n'
    fi
    return 0
}

aod_feature_branch_candidates() {
    local nnn="${1-}" ref name
    nnn="${nnn%%-*}"
    [ -n "$nnn" ] || return 2
    {
        git for-each-ref --format='%(refname)' refs/heads refs/remotes/origin 2>/dev/null |
            while IFS= read -r ref; do
                case "$ref" in
                    refs/heads/*) name="${ref#refs/heads/}" ;;
                    refs/remotes/origin/*) name="${ref#refs/remotes/origin/}" ;;
                    *) continue ;;
                esac
                case "$name" in
                    "${nnn}"-*) ;;
                    *) continue ;;
                esac
                case "$name" in
                    *-heal-* | *-document-stage) continue ;;
                esac
                printf '%s\n' "$name"
            done
    } | sort -u || true
    return 0
}

aod_feature_branch_ref() {
    local name="${1-}"
    [ -n "$name" ] || return 2
    if git show-ref --verify --quiet "refs/heads/$name" 2>/dev/null; then
        printf 'refs/heads/%s\n' "$name"
    else
        printf 'refs/remotes/origin/%s\n' "$name"
    fi
    return 0
}

# ============================================================================
# Mode resolution
# ============================================================================

aod_pr_mode() {
    local feature="" autonomous=0 no_pin=0 arg nnn
    for arg in "$@"; do
        case "$arg" in
            --autonomous) autonomous=1 ;;
            --no-pin) no_pin=1 ;;
            -*)
                _aod_cfg_err "aod_pr_mode: unknown option '$arg'"
                return 2
                ;;
            *) [ -n "$feature" ] || feature="$arg" ;;
        esac
    done
    if [ -z "$feature" ]; then
        _aod_cfg_err "aod_pr_mode: feature required"
        return 2
    fi
    nnn=$(_aod_nnn_of "$feature") || return 2

    local pinfile="$_AOD_PR_MODE_DIR/$nnn"
    local current default on_default=0 detached=0
    current=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) || current=""
    default=$(aod_default_branch)
    [ -n "$current" ] || detached=1
    if [ -n "$current" ] && [ "$current" = "$default" ]; then on_default=1; fi

    # --- Pin lookup: working tree first, else the feature branch ref ---------
    local pin_state="none" pin="" cands count=0 first="" c ref ambiguous=0
    if [ -f "$pinfile" ]; then
        pin=$(cat "$pinfile" 2>/dev/null) || pin=""
        if _aod_pin_is_valid "$pin"; then pin_state="valid"; else pin_state="invalid"; fi
    else
        cands=$(aod_feature_branch_candidates "$nnn")
        while IFS= read -r c; do
            [ -n "$c" ] || continue
            count=$((count + 1))
            [ -n "$first" ] || first="$c"
        done <<EOF
$cands
EOF
        if [ -n "$current" ] && [ "$count" -ge 2 ] && printf '%s\n' "$cands" | grep -Fxq -- "$current"; then
            # HEAD is itself a candidate: it is THE feature branch, so stray
            # sibling candidates are irrelevant. No pin in the working tree
            # means "feature branch found, no pin" (never the rule-3 fallback).
            count=1
            first="$current"
        elif [ "$count" -eq 1 ] && [ "$first" = "$current" ]; then
            :  # same: HEAD is the sole candidate and has no working-tree pin
        elif [ "$count" -eq 1 ]; then
            ref=$(aod_feature_branch_ref "$first")
            if pin=$(git show "${ref}:${pinfile}" 2>/dev/null); then
                if _aod_pin_is_valid "$pin"; then pin_state="valid"; else pin_state="invalid"; fi
            else
                pin=""
            fi
        elif [ "$count" -ge 2 ]; then
            ambiguous=1
            _aod_cfg_warn "ambiguous feature branches for ${nnn}: $(printf '%s' "$cands" | tr '\n' ' ')"
        fi
    fi

    # 1. valid pin wins; config is not read
    if [ "$pin_state" = "valid" ]; then
        printf '%s\n' "$pin"
        return 0
    fi

    # 2. invalid pin
    if [ "$pin_state" = "invalid" ]; then
        if [ "$autonomous" -eq 1 ]; then
            _aod_cfg_warn "pin for ${nnn} has invalid content; halting (invalid_config)"
            return 4
        fi
        _aod_cfg_warn "pin for ${nnn} has invalid content; resolving from config"
    fi

    # R-1: ambiguity is not "no feature branch"; rule 3 never fires for it
    if [ "$ambiguous" -eq 1 ]; then
        if [ "$autonomous" -eq 1 ]; then
            _aod_cfg_warn "cannot choose a feature branch for ${nnn} unattended; halting"
            return 6
        fi
        _aod_cfg_warn "resolving mode for ${nnn} from config (no pin lookup)"
    fi

    # 3. delivered before pinning: no pin, no feature branch, on the default branch
    if [ "$pin_state" = "none" ] && [ "$ambiguous" -eq 0 ] && [ "$count" -eq 0 ] &&
        [ "$on_default" -eq 1 ]; then
        _aod_cfg_warn "no pin and no feature branch for ${nnn}; assuming split (delivered before pinning)"
        printf 'split\n'
        return 0
    fi

    # 4. config
    local mode rc=0
    mode=$(aod_pr_mode_from_config) || rc=$?
    if [ "$rc" -eq 4 ]; then
        if [ "$autonomous" -eq 1 ]; then
            return 4
        fi
        mode="split"
    fi

    # 5. pin (L-1: only when HEAD is an <NNN>-* candidate branch for this NNN;
    #    never on the default branch, a detached HEAD, an unrelated branch, or
    #    with --no-pin)
    local head_is_cand=0
    if [ -n "$current" ] && [ "$on_default" -eq 0 ] &&
        printf '%s\n' "$(aod_feature_branch_candidates "$nnn")" | grep -Fxq -- "$current"; then
        head_is_cand=1
    fi
    if [ "$no_pin" -eq 0 ] && [ "$head_is_cand" -eq 1 ]; then
        _aod_pin_write "$nnn" "$mode" || return 1
    fi
    printf '%s\n' "$mode"
    return 0
}
