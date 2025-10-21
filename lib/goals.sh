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
# Goal File Management
# ═══════════════════════════════════════════════════════════════

# goal_file_for_today: Get path to today's goal file (JSONL format)
#
# Description:
#   Generates the file path for today's goals file using JSONL format.
#   Files are organized by date for easy archival and retrieval.
#
# Arguments:
#   None
#
# Returns:
#   0 - Always succeeds
#
# Outputs:
#   stdout: Path to today's goals file (e.g., ~/.harm-cli/goals/2025-10-19.jsonl)
#
# Examples:
#   file=$(goal_file_for_today)
#   echo "Goals stored in: $file"
#
# Notes:
#   - Uses JSONL (JSON Lines) format: one JSON object per line
#   - File is created on first goal_set() call
goal_file_for_today() {
  echo "${HARM_GOALS_DIR}/$(date '+%Y-%m-%d').jsonl"
}

# goal_exists_today: Check if any goals exist for today
#
# Description:
#   Checks if today's goal file exists and contains at least one goal.
#   Useful for conditional logic and status displays.
#
# Arguments:
#   None
#
# Returns:
#   0 - Goals file exists and is non-empty
#   1 - No goals file or file is empty
#
# Examples:
#   if goal_exists_today; then
#     goal_show
#   else
#     echo "No goals for today"
#   fi
#
# Notes:
#   - Uses both -f (file exists) and -s (file non-empty) checks
goal_exists_today() {
  local goal_file
  goal_file="$(goal_file_for_today)"
  [[ -f "$goal_file" && -s "$goal_file" ]]
}

# goal_set: Set a new goal for today
#
# Description:
#   Creates a new goal entry for today with optional time estimation.
#   Goals are appended to today's JSONL file, allowing multiple goals per day.
#   Supports both duration formats (30m, 4h, 2h30m) and plain integers.
#
# Arguments:
#   $1 - goal (string): Description of the goal
#   $2 - estimated_time (duration|integer, optional): Estimated time to complete
#        Accepts: duration formats (30m, 4h, 2h30m) or plain integers (minutes)
#
# Returns:
#   0 - Goal created successfully
#   2 - Invalid arguments (invalid duration format or non-positive value)
#
# Outputs:
#   stdout: Success message (text) or JSON response
#   stderr: Log entry via log_info()
#
# Examples:
#   goal_set "Write comprehensive tests"
#   goal_set "Fix critical bug #42" "2h"
#   goal_set "Deploy to production" "30m"
#   goal_set "Code review" 45
#   HARM_CLI_FORMAT=json goal_set "Refactor" "4h"
#
# Notes:
#   - Goals start at 0% progress and completed=false
#   - Timestamps are UTC (ISO 8601 format)
#   - Multiple goals per day are supported and numbered sequentially
#   - Duration parsing uses parse_duration() from lib/util.sh
#   - Internally stores estimated time as minutes (integer)
goal_set() {
  local goal="${1:?goal_set requires goal description}"
  local estimated_minutes="${2:-null}"

  # Parse and validate minutes if provided
  if [[ "$estimated_minutes" != "null" ]]; then
    # If not a plain integer, try parsing as duration (e.g., "30m", "4h", "2h30m")
    if ! validate_int "$estimated_minutes"; then
      local seconds
      seconds="$(parse_duration "$estimated_minutes" 2>/dev/null)"

      # Check if parse_duration returned 0 due to invalid format
      # (parse_duration returns 0 for invalid input, not an error code)
      if [[ $seconds -eq 0 && "$estimated_minutes" != "0" ]]; then
        die "Invalid duration format: '$estimated_minutes'" "$EXIT_INVALID_ARGS"
      fi

      # Convert seconds to minutes
      estimated_minutes=$((seconds / 60))
    fi

    # Validate result is a positive integer
    validate_int "$estimated_minutes" || die "Estimated minutes must be a positive integer" "$EXIT_INVALID_ARGS"
    [[ $estimated_minutes -gt 0 ]] || die "Estimated minutes must be greater than 0" "$EXIT_INVALID_ARGS"
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
#
# Description:
#   Displays all goals for today with their progress status.
#   Supports both text (human-readable) and JSON output formats.
#
# Arguments:
#   None
#
# Returns:
#   0 - Always succeeds (even if no goals)
#
# Outputs:
#   stdout: Goal list (formatted based on HARM_CLI_FORMAT)
#     - Text: Numbered list with progress percentages and completion marks
#     - JSON: Array of goal objects with full metadata
#
# Examples:
#   goal_show
#   HARM_CLI_FORMAT=json goal_show | jq '.[]'
#
# Notes:
#   - Completed goals show with ✓ symbol
#   - In-progress goals show as numbered items with percentage
#   - Goals are numbered from 1 (for use with goal_update_progress)
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

# ═══════════════════════════════════════════════════════════════
# Goal Update Operations
# ═══════════════════════════════════════════════════════════════

# goal_update_progress: Update progress on a goal
#
# Description:
#   Updates the progress percentage for a specific goal identified by number.
#   Automatically marks goal as completed when progress reaches 100%.
#   Uses efficient awk+jq processing for atomic JSONL file updates.
#
# Arguments:
#   $1 - goal_number (integer): Goal position (from goal_show numbering)
#   $2 - progress (integer): Progress percentage (0-100)
#
# Returns:
#   0 - Progress updated successfully
#   2 - Invalid arguments (non-integer or out of range)
#   5 - Goals file not found
#
# Outputs:
#   stdout: Success message (text) or JSON response
#   stderr: Log entry via log_info()
#
# Examples:
#   goal_update_progress 1 50    # Set first goal to 50%
#   goal_update_progress 2 100   # Mark second goal complete
#
# Performance:
#   - O(n) where n = number of goals in file
#   - Uses awk for efficient single-pass processing
#   - Atomic write via temp file prevents corruption
#   - Typical: <5ms for files with <100 goals
#
# Notes:
#   - Progress must be between 0-100 (inclusive)
#   - Setting to 100% automatically sets completed=true
#   - Uses compact JSON (-c flag) to maintain JSONL format
goal_update_progress() {
  local goal_num="${1:?goal_update_progress requires goal number}"
  local progress="${2:?goal_update_progress requires progress}"

  validate_int "$goal_num" || die "Goal number must be an integer (got: '$goal_num')" "$EXIT_INVALID_ARGS"
  validate_int "$progress" || die "Progress must be an integer (got: '$progress')" "$EXIT_INVALID_ARGS"

  ((progress >= 0 && progress <= 100)) || die "Progress must be between 0-100 (got: $progress)" "$EXIT_INVALID_ARGS"

  local goal_file
  goal_file="$(goal_file_for_today)"
  require_file "$goal_file" "goals file"

  # Update the Nth goal's progress
  local temp_file="${goal_file}.tmp"
  local line_num=0

  # Use awk for efficient line-by-line JSON update
  awk -v goal_num="$goal_num" -v progress="$progress" '
    NR == goal_num {
      # Parse and update this line using jq (compact output for JSONL)
      cmd = sprintf("jq -c --argjson progress %d --argjson completed %s '\''.progress = $progress | .completed = $completed'\'' 2>/dev/null",
                    progress, (progress == 100 ? "true" : "false"))
      print $0 | cmd
      close(cmd)
      next
    }
    {print}
  ' "$goal_file" >"$temp_file"

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
#
# Description:
#   Convenience wrapper that marks a goal as 100% complete.
#   Delegates to goal_update_progress with progress=100.
#
# Arguments:
#   $1 - goal_number (integer): Goal position to mark complete
#
# Returns:
#   0 - Goal marked complete successfully
#   2 - Invalid arguments
#   5 - Goals file not found
#
# Outputs:
#   stdout: Success message from goal_update_progress
#   stderr: Log entry via goal_update_progress
#
# Examples:
#   goal_complete 1              # Mark first goal complete
#   goal_complete 3              # Mark third goal complete
#
# Notes:
#   - This is a convenience function for better semantics
#   - Internally calls: goal_update_progress "$1" 100
#   - Inherits all validation from goal_update_progress
goal_complete() {
  goal_update_progress "$1" 100
}

# goal_clear: Clear all goals for today
#
# Description:
#   Removes today's goals file, deleting all goals.
#   Requires --force flag as a safety measure to prevent accidental deletion.
#
# Arguments:
#   $1 - --force (flag, required): Confirms deletion intent
#
# Returns:
#   0 - Goals cleared successfully
#   1 - Missing --force flag (safety check)
#
# Outputs:
#   stdout: Success message
#   stderr: Warning message if --force not provided
#
# Examples:
#   goal_clear --force           # Clears all goals (with confirmation)
#   goal_clear                   # Fails with warning (safety)
#
# Notes:
#   - Requires explicit --force to prevent accidents
#   - File is deleted permanently (no backup created)
#   - Safe to call even if no goals exist
#   - Consider backing up if goals contain important data
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
# AI Goal Validation
# ═══════════════════════════════════════════════════════════════

# goal_validate: Validate goal with AI assistance
#
# Description:
#   Uses AI to validate if a goal is realistic, well-defined, and
#   appropriately scoped. Provides suggestions for improvement and
#   time estimates.
#
# Arguments:
#   $1 - goal (string): Goal description to validate
#
# Returns:
#   0 - Validation completed
#   EXIT_INVALID_ARGS - No goal provided
#   EXIT_AI_NO_KEY - AI not available
#
# Outputs:
#   stdout: AI validation feedback
#   stderr: Log messages
#
# Examples:
#   goal_validate "Complete Phase 6"
#   goal_validate "Fix all bugs"
#   harm-cli goal validate "Build new feature"
#
# Notes:
#   - Requires lib/ai.sh loaded
#   - Uses AI to analyze goal
#   - Provides realistic time estimates
#   - Suggests breaking down large goals
#
# Performance:
#   - 2-5s (AI latency)
goal_validate() {
  local goal="${1:?goal_validate requires goal description}"

  log_info "goals" "Validating goal with AI" "Goal: $goal"

  # Check if AI module available
  if ! type ai_query >/dev/null 2>&1; then
    error_msg "AI module not available"
    echo "Load AI module first or use: harm-cli goal validate"
    return "$EXIT_DEPENDENCY_MISSING"
  fi

  # Build validation prompt
  local prompt
  prompt="Validate this goal and provide feedback:\n\n"
  prompt+="Goal: \"$goal\"\n\n"
  prompt+="Analyze:\n"
  prompt+="1. **Clarity**: Is it specific and well-defined?\n"
  prompt+="2. **Scope**: Is it appropriately sized (not too big/small)?\n"
  prompt+="3. **Realistic**: Can it be completed?\n"
  prompt+="4. **Time Estimate**: How long will it take?\n"
  prompt+="5. **Suggestions**: How to improve this goal?\n\n"
  prompt+="Be honest and helpful. If too large, suggest breaking it down."

  echo "🤖 Validating goal with AI..."

  # Query AI (bypass cache)
  local context="Goal Validation Request"
  ai_query "$prompt" --no-cache

  log_info "goals" "Goal validation completed"
  return 0
}

# ═══════════════════════════════════════════════════════════════
# Exports
# ═══════════════════════════════════════════════════════════════

export -f goal_file_for_today goal_exists_today
export -f goal_set goal_show goal_update_progress goal_complete goal_clear
export -f goal_validate
