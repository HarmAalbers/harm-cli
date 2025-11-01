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
# Input Validation
# ═══════════════════════════════════════════════════════════════

# validate_goal_text: Validate and sanitize goal description
# SECURITY FIX (MEDIUM-1): Prevents control character injection and enforces limits
# Usage: goal=$(validate_goal_text "$user_input")
validate_goal_text() {
  local goal="${1:-}"

  [[ -z "$goal" ]] && die "Goal description cannot be empty" "$EXIT_INVALID_ARGS"

  # Length check (max 500 chars)
  if [[ ${#goal} -gt 500 ]]; then
    die "Goal too long (max 500 characters, got ${#goal})" "$EXIT_INVALID_ARGS"
  fi

  # Remove control characters (prevents injection, corruption)
  goal=$(echo "$goal" | tr -d '\000-\037\177')

  # Trim whitespace
  goal=$(echo "$goal" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

  # Final empty check
  [[ -z "$goal" ]] && die "Goal invalid (only whitespace/control chars)" "$EXIT_INVALID_ARGS"

  echo "$goal"
}

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

  # SECURITY: Validate and sanitize goal text
  goal=$(validate_goal_text "$goal")

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

    # PERFORMANCE OPTIMIZATION (PERF-1):
    # Instead of 3 jq processes per goal (30 processes for 10 goals = 450ms),
    # use a single jq call with TSV output (1 process = 50ms = 90% faster)
    local line_num=0
    jq -r '.goal + "\t" + (.progress | tostring) + "\t" + (.completed | tostring)' "$goal_file" \
      | while IFS=$'\t' read -r goal progress completed; do
        ((++line_num)) # Pre-increment to avoid exit code 1 with set -e when line_num=0

        if [[ "$completed" == "true" ]]; then
          echo "  ${SUCCESS_GREEN}✓${RESET} $goal (completed)"
        else
          echo "  ${line_num}. $goal (${progress}% complete)"
        fi
      done
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
  local goal_num="${1:-}"
  local progress="${2:-}"

  # Interactive mode if arguments missing and TTY available
  if [[ (-z "$goal_num" || -z "$progress") ]] && [[ -t 0 ]] && [[ -t 1 ]] && [[ "${HARM_CLI_FORMAT:-text}" == "text" ]]; then
    # Load interactive module if available
    if [[ -f "$GOALS_SCRIPT_DIR/interactive.sh" ]]; then
      # shellcheck source=lib/interactive.sh
      source "$GOALS_SCRIPT_DIR/interactive.sh"
    fi

    # Check if interactive functions available
    if type interactive_choose >/dev/null 2>&1 && goal_exists_today; then
      log_debug "goals" "Starting interactive goal progress update"

      echo "📊 Update Goal Progress"
      echo ""

      # Build goal options (if goal_num not provided)
      if [[ -z "$goal_num" ]]; then
        local -a goal_options=()
        local goal_file
        goal_file=$(goal_file_for_today)
        local line_num=0

        # PERFORMANCE OPTIMIZATION (PERF-2): Use single jq call with TSV output
        # Before: 3 jq processes per goal × N goals = 30 processes for 10 goals (~300ms)
        # After: 1 jq process total (~50ms) = 83% faster
        #
        # Single jq invocation extracts all fields at once as tab-separated values
        # This is the same pattern successfully used in work.sh (line 244)
        jq -r 'select(.completed == false) | [.goal, .progress] | @tsv' "$goal_file" \
          | while IFS=$'\t' read -r goal_text current_progress; do
            ((++line_num))
            goal_options+=("${line_num}. ${goal_text} (${current_progress}%)")
          done

        if [[ ${#goal_options[@]} -eq 0 ]]; then
          echo "No incomplete goals to update"
          return 0
        fi

        # Interactive selection
        if selection=$(interactive_choose "Select goal to update" "${goal_options[@]}" 2>/dev/null); then
          # Extract number from selection
          goal_num="${selection%%.*}"
          log_debug "goals" "Selected goal" "Number: $goal_num"
        else
          error_msg "Goal selection cancelled"
          return "$EXIT_ERROR"
        fi
      fi

      # Prompt for progress (if not provided)
      if [[ -z "$progress" ]]; then
        if ! progress=$(interactive_input "New progress (0-100)" 2>/dev/null); then
          error_msg "Progress input cancelled"
          return "$EXIT_ERROR"
        fi
      fi
    fi
  fi

  # Validate inputs
  [[ -z "$goal_num" ]] && die "Goal number required" "$EXIT_INVALID_ARGS"
  [[ -z "$progress" ]] && die "Progress value required" "$EXIT_INVALID_ARGS"

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

# goal_reopen: Reopen a goal with new progress
#
# Description:
#   Reopens any goal by setting completed=false and updating progress.
#   Works on both completed and in-progress goals, providing flexibility
#   to fix mistakes or restart work on previously completed tasks.
#
# Arguments:
#   $1 - goal_number (integer): Goal position to reopen
#   $2 - progress (integer): New progress percentage (0-100)
#
# Returns:
#   0 - Goal reopened successfully
#   2 - Invalid arguments (non-integer or out of range)
#   5 - Goals file not found
#
# Outputs:
#   stdout: Success message (text) or JSON response
#   stderr: Log entry via log_info()
#
# Examples:
#   goal_reopen 1 0              # Restart first goal from scratch
#   goal_reopen 2 50             # Reopen second goal at 50% progress
#   goal_reopen 3 75             # Fix accidental completion, was at 75%
#
# Use Cases:
#   - Undo accidental completion: marked done too early
#   - Restart completed goal: need to revisit work
#   - Fix progress mistakes: set wrong percentage
#
# Performance:
#   - O(n) where n = number of goals in file
#   - Uses awk for efficient single-pass processing
#   - Atomic write via temp file prevents corruption
#   - Typical: <5ms for files with <100 goals
#
# Notes:
#   - Works on ANY goal (completed or not) for maximum flexibility
#   - Progress must be between 0-100 (inclusive)
#   - Sets completed=false regardless of previous state
#   - Uses compact JSON (-c flag) to maintain JSONL format
goal_reopen() {
  local goal_num="${1:?goal_reopen requires goal number}"
  local progress="${2:?goal_reopen requires progress}"

  validate_int "$goal_num" || die "Goal number must be an integer (got: '$goal_num')" "$EXIT_INVALID_ARGS"
  validate_int "$progress" || die "Progress must be an integer (got: '$progress')" "$EXIT_INVALID_ARGS"

  ((progress >= 0 && progress <= 100)) || die "Progress must be between 0-100 (got: $progress)" "$EXIT_INVALID_ARGS"

  local goal_file
  goal_file="$(goal_file_for_today)"
  require_file "$goal_file" "goals file"

  # Update the Nth goal: set completed=false and update progress
  local temp_file="${goal_file}.tmp"

  # Use awk for efficient line-by-line JSON update
  awk -v goal_num="$goal_num" -v progress="$progress" '
    NR == goal_num {
      # Parse and update this line using jq (compact output for JSONL)
      # Always set completed=false when reopening
      cmd = sprintf("jq -c --argjson progress %d --argjson completed false '\''.progress = $progress | .completed = $completed'\'' 2>/dev/null",
                    progress)
      print $0 | cmd
      close(cmd)
      next
    }
    {print}
  ' "$goal_file" >"$temp_file"

  mv "$temp_file" "$goal_file"

  log_info "goals" "Goal reopened" "Goal #$goal_num: ${progress}%, completed=false"

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --argjson goal_num "$goal_num" \
      --argjson progress "$progress" \
      '{status: "reopened", goal_number: $goal_num, progress: $progress, completed: false}'
  else
    success_msg "Goal #${goal_num} reopened at ${progress}%"
  fi
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
  ai_query "$prompt" --no-cache

  log_info "goals" "Goal validation completed"
  return 0
}

# ═══════════════════════════════════════════════════════════════
# AI Command Validation
# ═══════════════════════════════════════════════════════════════

# Configuration for command validation
HARM_GOAL_VALIDATION_ENABLED="${HARM_GOAL_VALIDATION_ENABLED:-1}"
readonly HARM_GOAL_VALIDATION_ENABLED

# Validation frequency (seconds) - throttle to avoid too many API calls
HARM_GOAL_VALIDATION_FREQUENCY="${HARM_GOAL_VALIDATION_FREQUENCY:-60}"
readonly HARM_GOAL_VALIDATION_FREQUENCY

# Track last validation time
declare -g _GOAL_LAST_VALIDATION=0

# Significant commands that should be validated
declare -a GOAL_SIGNIFICANT_COMMANDS=(
  git npm yarn pnpm docker compose poetry python pip pytest
  make cmake cargo go mvn gradle kubectl helm
  vim nvim code emacs
)

# Always ignore these commands (navigation, viewing)
declare -a GOAL_IGNORE_COMMANDS=(
  ls ll la cd pwd tree cat less more head tail
  grep rg ag find fd echo printf clear reset
  history man help which
)

# goal_is_significant_command: Check if command is work-related
#
# Description:
#   Determines if a command is significant enough to validate
#   against the active goal.
#
# Arguments:
#   $1 - cmd (string): Command to check
#
# Returns:
#   0 - Command is significant
#   1 - Command should be ignored
goal_is_significant_command() {
  local cmd="${1:?Command required}"
  local first_word="${cmd%% *}"

  # Check ignore list first
  local ignored
  for ignored in "${GOAL_IGNORE_COMMANDS[@]}"; do
    [[ "$first_word" == "$ignored" ]] && return 1
  done

  # Check significant commands
  local significant
  for significant in "${GOAL_SIGNIFICANT_COMMANDS[@]}"; do
    [[ "$first_word" == "$significant" ]] && return 0
  done

  # Check for file editing patterns (editing code files)
  if [[ "$cmd" =~ (vim|nvim|code|emacs)[[:space:]].+\.(sh|py|js|ts|go|rs|java|rb|php|c|cpp|h) ]]; then
    return 0
  fi

  return 1
}

# goal_get_active: Get currently active goal
#
# Description:
#   Returns the first incomplete goal for today.
#
# Returns:
#   0 - Active goal found
#   1 - No active goal
#
# Outputs:
#   stdout: Active goal text
goal_get_active() {
  if ! goal_exists_today; then
    return 1
  fi

  local goal_file active_goal
  goal_file="$(goal_file_for_today)"

  # Get first incomplete goal
  active_goal=$(jq -r 'select(.completed == false) | .goal' "$goal_file" 2>/dev/null | head -1)

  if [[ -z "$active_goal" ]]; then
    return 1
  fi

  echo "$active_goal"
  return 0
}

# goal_validate_command_async: Validate command against goal (async)
#
# Description:
#   Uses AI to check if a command aligns with the active goal.
#   Runs asynchronously to avoid blocking command execution.
#   Throttled to avoid excessive API calls.
#
# Arguments:
#   $1 - cmd (string): Command to validate
#
# Returns:
#   0 - Always succeeds (runs in background)
goal_validate_command_async() {
  local cmd="$1"

  # Skip if validation disabled
  [[ $HARM_GOAL_VALIDATION_ENABLED -eq 1 ]] || return 0

  # Skip if no work session
  if type work_is_active >/dev/null 2>&1; then
    work_is_active || return 0
  else
    return 0
  fi

  # Throttle validation - don't check too frequently
  local now
  now=$(date +%s)
  local elapsed=$((now - _GOAL_LAST_VALIDATION))

  if [[ $elapsed -lt $HARM_GOAL_VALIDATION_FREQUENCY ]]; then
    return 0
  fi

  _GOAL_LAST_VALIDATION=$now

  # Get active goal
  local goal
  goal=$(goal_get_active 2>/dev/null) || return 0

  # Run validation in background (non-blocking)
  (
    local prompt
    prompt="Quick alignment check:\n\n"
    prompt+="Active Goal: $goal\n"
    prompt+="Command: $cmd\n\n"
    prompt+="Does this command help achieve the goal?\n"
    prompt+="Answer with: YES, NO, or UNSURE\n"
    prompt+="If NO, briefly explain why (one sentence)."

    local response
    response=$(ai_query "$prompt" --no-cache 2>/dev/null) || exit 0

    # Check response
    if echo "$response" | grep -qi "^NO"; then
      echo "" >&2
      echo "🤔 Goal Alignment Check:" >&2
      echo "   Goal: $goal" >&2
      echo "   Command: $cmd" >&2
      echo "" >&2
      echo "   AI: $response" >&2
      echo "" >&2
    fi
  ) &

  return 0
}

# goal_preexec_hook: Hook for command validation
#
# Description:
#   Preexec hook that validates significant commands against goal.
#
# Arguments:
#   $1 - cmd (string): Command about to execute
#
# Returns:
#   0 - Always succeeds
goal_preexec_hook() {
  local cmd="$1"

  # Skip meta-commands
  [[ "$cmd" =~ ^(harm-cli|goal|work|focus|insights|activity) ]] && return 0

  # Check if command is significant
  if goal_is_significant_command "$cmd"; then
    goal_validate_command_async "$cmd"
  fi

  return 0
}

# ═══════════════════════════════════════════════════════════════
# Hook Registration
# ═══════════════════════════════════════════════════════════════

# Register goal validation hook if enabled
if [[ $HARM_GOAL_VALIDATION_ENABLED -eq 1 ]] && type harm_add_hook >/dev/null 2>&1; then
  harm_add_hook preexec goal_preexec_hook 2>/dev/null || true
  log_debug "goals" "AI goal validation enabled" "frequency=${HARM_GOAL_VALIDATION_FREQUENCY}s"
fi

# ═══════════════════════════════════════════════════════════════
# Exports
# ═══════════════════════════════════════════════════════════════

export -f goal_file_for_today goal_exists_today
export -f goal_set goal_show goal_update_progress goal_complete goal_reopen goal_clear
export -f goal_validate validate_goal_text
export -f goal_is_significant_command goal_get_active
export -f goal_validate_command_async goal_preexec_hook
