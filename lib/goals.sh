#!/usr/bin/env bash
# shellcheck shell=bash
# goals.sh - Goal tracking and management for harm-cli
# Ported from: ~/.zsh/lib/goal_helpers.zsh
#
# This module provides:
# - Daily goal tracking (JSON Lines format)
# - Goal progress tracking
# - Goal completion marking
# - Time estimation and tracking

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_GOALS_LOADED:-}" ]] && return 0

# Source dependencies
GOALS_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly GOALS_SCRIPT_DIR

# shellcheck source=lib/common.sh
source "$GOALS_SCRIPT_DIR/common.sh"
# shellcheck source=lib/error.sh
source "$GOALS_SCRIPT_DIR/error.sh"
# shellcheck source=lib/logging.sh
source "$GOALS_SCRIPT_DIR/logging.sh"
# shellcheck source=lib/util.sh
source "$GOALS_SCRIPT_DIR/util.sh"

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════

HARM_GOALS_DIR="${HARM_GOALS_DIR:-${HOME}/.harm-cli/goals}"
readonly HARM_GOALS_DIR
export HARM_GOALS_DIR

# Initialize goals directory
ensure_dir "$HARM_GOALS_DIR"

# Mark as loaded
readonly _HARM_GOALS_LOADED=1

# ═══════════════════════════════════════════════════════════════
# Core Goal Functions
# ═══════════════════════════════════════════════════════════════

# goal_file_for_today: Get path to today's goal file (JSONL format)
# Usage: file=$(goal_file_for_today)
goal_file_for_today() {
  echo "${HARM_GOALS_DIR}/$(date '+%Y-%m-%d').jsonl"
}

# goal_exists_today: Check if any goals exist for today
# Usage: goal_exists_today && echo "has goals"
goal_exists_today() {
  local goal_file
  goal_file="$(goal_file_for_today)"
  [[ -f "$goal_file" && -s "$goal_file" ]]
}

# goal_set: Set a new goal for today
# Usage: goal_set "goal description" [estimated_minutes]
goal_set() {
  local goal="${1:?goal_set requires goal description}"
  local estimated_minutes="${2:-null}"

  # Parse and validate minutes if provided
  if [[ "$estimated_minutes" != "null" ]]; then
    validate_int "$estimated_minutes" || die "Estimated minutes must be an integer" "$EXIT_INVALID_ARGS"
  fi

  local goal_file
  goal_file="$(goal_file_for_today)"
  local timestamp
  timestamp="$(get_utc_timestamp)"

  # Create goal entry (JSONL format - compact, single line)
  jq -nc \
    --arg timestamp "$timestamp" \
    --arg goal "$goal" \
    --argjson estimated_minutes "$estimated_minutes" \
    '{timestamp: $timestamp, goal: $goal, estimated_minutes: $estimated_minutes, progress: 0, completed: false}' \
    >>"$goal_file"

  log_info "goals" "Goal set" "Goal: $goal"

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --arg goal "$goal" \
      --argjson estimated_minutes "$estimated_minutes" \
      '{status: "set", goal: $goal, estimated_minutes: $estimated_minutes}'
  else
    success_msg "Goal set for today"
    echo "  Goal: $goal"
    if [[ "$estimated_minutes" != "null" ]]; then
      local formatted
      formatted="$(format_duration $((estimated_minutes * 60)))"
      echo "  Estimated time: $formatted"
    fi
  fi
}

# goal_show: Show today's goals
# Usage: goal_show
goal_show() {
  local goal_file
  goal_file="$(goal_file_for_today)"

  if ! goal_exists_today; then
    if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
      jq -n '{goals: []}'
    else
      echo "No goals set for today"
      echo "  Set a goal with: harm-cli goal set \"your goal\""
    fi
    return 0
  fi

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    # Output all goals as JSON array
    jq -s '.' "$goal_file"
  else
    # Pretty print goals
    echo "Goals for $(date '+%Y-%m-%d'):"
    echo ""

    local line_num=0
    while IFS= read -r line; do
      ((++line_num)) # Pre-increment to avoid exit code 1 with set -e when line_num=0
      local goal progress completed
      goal="$(jq -r '.goal' <<<"$line")"
      progress="$(jq -r '.progress' <<<"$line")"
      completed="$(jq -r '.completed' <<<"$line")"

      if [[ "$completed" == "true" ]]; then
        echo "  ${SUCCESS_GREEN}✓${RESET} $goal (completed)"
      else
        echo "  ${line_num}. $goal (${progress}% complete)"
      fi
    done <"$goal_file"
  fi
}

# goal_update_progress: Update progress on a goal
# Usage: goal_update_progress <goal_number> <progress_percent>
goal_update_progress() {
  local goal_num="${1:?goal_update_progress requires goal number}"
  local progress="${2:?goal_update_progress requires progress}"

  validate_int "$goal_num" || die "Goal number must be an integer" "$EXIT_INVALID_ARGS"
  validate_int "$progress" || die "Progress must be an integer" "$EXIT_INVALID_ARGS"

  ((progress >= 0 && progress <= 100)) || die "Progress must be between 0-100" "$EXIT_INVALID_ARGS"

  local goal_file
  goal_file="$(goal_file_for_today)"
  require_file "$goal_file" "goals file"

  # Update the Nth goal's progress
  local temp_file="${goal_file}.tmp"
  local line_num=0

  while IFS= read -r line; do
    ((line_num++))
    if ((line_num == goal_num)); then
      # Update this goal
      local completed=false
      ((progress == 100)) && completed=true

      jq \
        --argjson progress "$progress" \
        --argjson completed "$completed" \
        '.progress = $progress | .completed = $completed' \
        <<<"$line"
    else
      echo "$line"
    fi
  done <"$goal_file" >"$temp_file"

  mv "$temp_file" "$goal_file"

  log_info "goals" "Goal progress updated" "Goal #$goal_num: ${progress}%"

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --argjson goal_num "$goal_num" \
      --argjson progress "$progress" \
      '{status: "updated", goal_number: $goal_num, progress: $progress}'
  else
    success_msg "Goal progress updated to ${progress}%"
  fi
}

# goal_complete: Mark a goal as completed
# Usage: goal_complete <goal_number>
goal_complete() {
  goal_update_progress "$1" 100
}

# goal_clear: Clear all goals for today
# Usage: goal_clear [--force]
goal_clear() {
  if [[ "${1:-}" != "--force" ]]; then
    warn_msg "This will delete all goals for today. Use --force to confirm."
    return 1
  fi

  local goal_file
  goal_file="$(goal_file_for_today)"

  rm -f "$goal_file"
  success_msg "Goals cleared for today"
}

# ═══════════════════════════════════════════════════════════════
# Exports
# ═══════════════════════════════════════════════════════════════

export -f goal_file_for_today goal_exists_today
export -f goal_set goal_show goal_update_progress goal_complete goal_clear
