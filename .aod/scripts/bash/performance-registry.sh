#!/usr/bin/env bash

# performance-registry.sh - Self-calibrating performance registry for budget tracking
# Provides calibrated defaults derived from historical feature delivery data
#
# Functions:
#   aod_registry_exists      - Check if registry file exists
#   aod_registry_read        - Read full registry JSON
#   aod_registry_get_default - Read single value with dot-path, fallback on error
#   aod_registry_append_feature - Extract from run-state, append to features[]
#   aod_registry_recalculate - Recompute calibrated_defaults from features[]
#
# Non-fatal: All reads return fallback values on error
# ADR-003: Bash 3.2 compatible, integer arithmetic only

set -euo pipefail

# Path Constants
REGISTRY_DIR="${AOD_MEMORY_DIR:-.aod/memory}"
REGISTRY_FILE="${REGISTRY_DIR}/performance-registry.json"

# Fallback Values (used when registry unavailable)
FALLBACK_USABLE_BUDGET_ORCH=120000
FALLBACK_USABLE_BUDGET_STANDALONE=60000
FALLBACK_SAFETY_MULTIPLIER="1.5"
FALLBACK_STAGE_ESTIMATE=5000

# FIFO cap
MAX_FEATURES=5

# ============================================================================
# Prerequisites
# ============================================================================

aod_registry_check_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "[aod] ERROR: jq is required but not installed." >&2
        echo "[aod] Install with: brew install jq (macOS) or apt-get install jq (Linux)" >&2
        return 1
    fi
}

# ============================================================================
# Core Functions
# ============================================================================

# Function: aod_registry_exists
# Check if registry file exists
# Returns: 0 if exists, 1 otherwise
aod_registry_exists() {
    [[ -f "$REGISTRY_FILE" ]]
}

# Function: aod_registry_read
# Read full registry JSON
# Returns: JSON to stdout, empty on failure
aod_registry_read() {
    # Silent failure if jq unavailable
    aod_registry_check_jq 2>/dev/null || return 1

    if ! aod_registry_exists; then
        return 1
    fi

    local content
    content=$(cat "$REGISTRY_FILE" 2>/dev/null) || return 1

    # Validate JSON
    if ! echo "$content" | jq . >/dev/null 2>&1; then
        return 1
    fi

    echo "$content"
}

# Function: aod_registry_get_default
# Read value by dot-path with fallback
# Args: $1 = field path (e.g., "usable_budget" or "per_stage_estimates.define")
#       $2 = optional fallback value (uses built-in defaults if not provided)
# Returns: value to stdout, fallback on error
aod_registry_get_default() {
    local field="$1"
    local fallback="${2:-}"

    # Determine default fallback based on field
    if [[ -z "$fallback" ]]; then
        case "$field" in
            usable_budget)
                fallback="$FALLBACK_USABLE_BUDGET_ORCH"
                ;;
            safety_multiplier)
                fallback="$FALLBACK_SAFETY_MULTIPLIER"
                ;;
            per_stage_estimates.*)
                fallback="$FALLBACK_STAGE_ESTIMATE"
                ;;
            *)
                fallback=""
                ;;
        esac
    fi

    # Try to read from registry
    local registry
    registry=$(aod_registry_read 2>/dev/null) || {
        echo "$fallback"
        return 0
    }

    # Build jq path: calibrated_defaults.{field}
    # Convert dot-path to jq notation: per_stage_estimates.define -> .calibrated_defaults.per_stage_estimates.define
    local jq_path=".calibrated_defaults"
    local part
    # Split field by dots and build path
    local IFS='.'
    for part in $field; do
        jq_path="${jq_path}.${part}"
    done

    local value
    value=$(echo "$registry" | jq -r "$jq_path // empty" 2>/dev/null)

    if [[ -z "$value" ]]; then
        echo "$fallback"
    else
        echo "$value"
    fi
}

# Function: aod_registry_append_feature
# Extract feature data from run-state and append to registry
# Args: $1 = path to run-state.json
# Returns: 0 on success, 1 on failure
aod_registry_append_feature() {
    local run_state_path="$1"

    aod_registry_check_jq 2>/dev/null || return 1

    # Validate run-state exists
    if [[ ! -f "$run_state_path" ]]; then
        echo "[aod] WARNING: Run-state not found at $run_state_path" >&2
        return 1
    fi

    # Read run-state
    local run_state
    run_state=$(cat "$run_state_path" 2>/dev/null) || return 1

    # Validate JSON
    if ! echo "$run_state" | jq . >/dev/null 2>&1; then
        echo "[aod] WARNING: Run-state is not valid JSON" >&2
        return 1
    fi

    # Check if token_budget exists with at least one stage having post > 0
    local has_budget
    has_budget=$(echo "$run_state" | jq -r '
        if .token_budget and .token_budget.stage_estimates then
            [.token_budget.stage_estimates | to_entries[] | select(.value.post > 0)] | length > 0
        else false end')

    if [[ "$has_budget" != "true" ]]; then
        echo "[aod] INFO: Run-state lacks valid token_budget data, skipping registry update" >&2
        return 0
    fi

    # Extract feature data
    local feature_entry
    feature_entry=$(echo "$run_state" | jq '{
        feature_id: .feature_id,
        feature_name: .feature_name,
        completed_at: (now | todate),
        session_count: ((.session_count // "1") | tonumber),
        total_estimated_tokens: (
            (.token_budget.estimated_total // 0) +
            (if .token_budget.prior_sessions then
                [.token_budget.prior_sessions[].estimated_total] | add // 0
            else 0 end)
        ),
        stage_actuals: (
            # Merge current session and all prior sessions
            reduce (
                [.token_budget.stage_estimates] +
                (if .token_budget.prior_sessions then [.token_budget.prior_sessions[].stage_estimates] else [] end)
            )[] as $session (
                {discover: {pre: 0, post: 0}, define: {pre: 0, post: 0}, plan: {pre: 0, post: 0}, build: {pre: 0, post: 0}, deliver: {pre: 0, post: 0}};
                . as $acc |
                reduce ($session | to_entries[]) as $stage ($acc;
                    .[$stage.key].pre = (.[$stage.key].pre + ($stage.value.pre // 0)) |
                    .[$stage.key].post = (.[$stage.key].post + ($stage.value.post // 0))
                )
            )
        )
    }')

    # Read or create registry
    local registry
    if aod_registry_exists; then
        registry=$(aod_registry_read) || {
            # Registry corrupted, create new
            registry='{"version":"1.0","updated_at":"","calibrated_defaults":{"usable_budget":60000,"safety_multiplier":1.5,"per_stage_estimates":{"discover":5000,"define":5000,"plan":5000,"build":5000,"deliver":5000}},"features":[]}'
        }
    else
        # Create new registry
        mkdir -p "$REGISTRY_DIR"
        registry='{"version":"1.0","updated_at":"","calibrated_defaults":{"usable_budget":60000,"safety_multiplier":1.5,"per_stage_estimates":{"discover":5000,"define":5000,"plan":5000,"build":5000,"deliver":5000}},"features":[]}'
    fi

    # Append feature with FIFO rotation (max 5)
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    registry=$(echo "$registry" | jq --argjson feat "$feature_entry" --arg ts "$now" '
        .features += [$feat] |
        if (.features | length) > 5 then .features = .features[-5:] else . end |
        .updated_at = $ts')

    # Write atomically
    local tmp_file="${REGISTRY_FILE}.tmp"
    echo "$registry" | jq . > "$tmp_file" || {
        rm -f "$tmp_file"
        return 1
    }
    mv "$tmp_file" "$REGISTRY_FILE" || return 1
    chmod 644 "$REGISTRY_FILE" 2>/dev/null || true

    return 0
}

# Function: aod_registry_recalculate
# Recompute calibrated_defaults from features[]
# Uses integer arithmetic per ADR-003 Bash 3.2 constraint
# Returns: 0 on success, 1 on failure
aod_registry_recalculate() {
    aod_registry_check_jq 2>/dev/null || return 1

    if ! aod_registry_exists; then
        return 1
    fi

    local registry
    registry=$(aod_registry_read) || return 1

    # Check if features array is empty
    local feature_count
    feature_count=$(echo "$registry" | jq '.features | length')
    if [[ "$feature_count" -eq 0 ]]; then
        return 0  # Nothing to recalculate
    fi

    # Recalculate calibrated_defaults
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    registry=$(echo "$registry" | jq --arg ts "$now" '
        # Per-stage estimates: average of (pre + post) across all features where post > 0
        .calibrated_defaults.per_stage_estimates = (
            ["discover", "define", "plan", "build", "deliver"] |
            map(. as $stage |
                [.features[] | .stage_actuals[$stage] | select(.post > 0) | (.pre + .post)] as $values |
                if ($values | length) > 0 then
                    ($values | add / length | floor)
                else 5000 end
            ) | {discover: .[0], define: .[1], plan: .[2], build: .[3], deliver: .[4]}
        ) |

        # Usable budget: average total_estimated_tokens, capped at 100000
        .calibrated_defaults.usable_budget = (
            ([.features[].total_estimated_tokens] | add / length | floor) as $avg_total |
            if $avg_total > 100000 then 100000
            elif $avg_total < 30000 then 30000
            else $avg_total end
        ) |

        # Safety multiplier: keep at 1.5 for MVP
        .calibrated_defaults.safety_multiplier = 1.5 |

        .updated_at = $ts
    ' 2>/dev/null) || return 1

    # Write atomically
    local tmp_file="${REGISTRY_FILE}.tmp"
    echo "$registry" | jq . > "$tmp_file" || {
        rm -f "$tmp_file"
        return 1
    }
    mv "$tmp_file" "$REGISTRY_FILE" || return 1
    chmod 644 "$REGISTRY_FILE" 2>/dev/null || true

    return 0
}
