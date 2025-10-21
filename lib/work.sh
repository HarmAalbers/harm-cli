#!/usr/bin/env bash
# shellcheck shell=bash
# work.sh - Work session management for harm-cli
# Ported from: ~/.zsh/40_work_sessions.zsh
#
# This module provides:
# - Work session tracking (start, stop, pause, resume)
# - Session state persistence (JSON format)
# - Time tracking and reporting
# - Work session validation

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_WORK_LOADED:-}" ]] && return 0

# Source dependencies
WORK_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly WORK_SCRIPT_DIR

# shellcheck source=lib/common.sh
source "$WORK_SCRIPT_DIR/common.sh"
# shellcheck source=lib/error.sh
source "$WORK_SCRIPT_DIR/error.sh"
# shellcheck source=lib/logging.sh
source "$WORK_SCRIPT_DIR/logging.sh"
# shellcheck source=lib/util.sh
source "$WORK_SCRIPT_DIR/util.sh"

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════

HARM_WORK_DIR="${HARM_WORK_DIR:-${HOME}/.harm-cli/work}"
readonly HARM_WORK_DIR
export HARM_WORK_DIR

HARM_WORK_STATE_FILE="${HARM_WORK_STATE_FILE:-${HARM_WORK_DIR}/current_session.json}"
readonly HARM_WORK_STATE_FILE
export HARM_WORK_STATE_FILE

# Initialize work directory
ensure_dir "$HARM_WORK_DIR"

# Mark as loaded
readonly _HARM_WORK_LOADED=1

# ═══════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════

# parse_iso8601_to_epoch: DEPRECATED - Use iso8601_to_epoch from lib/util.sh instead
#
# This function is kept for backward compatibility but delegates to the new
# unified time handling function in lib/util.sh which properly handles UTC.
parse_iso8601_to_epoch() {
  iso8601_to_epoch "$@"
}

# ═══════════════════════════════════════════════════════════════
# Work Session State Management
# ═══════════════════════════════════════════════════════════════

# work_is_active: Check if work session is currently active
#
# Description:
#   Checks if a work session is currently active by verifying
#   the state file exists and contains status="active".
#
# Arguments:
#   None
#
# Returns:
#   0 - Work session is active
#   1 - No active work session
#
# Examples:
#   if work_is_active; then
#     echo "Currently working"
#   fi
#   work_is_active && work_status
#
# Notes:
#   - Checks file existence and parses JSON status field
#   - Safe to call multiple times (no side effects)
work_is_active() {
  [[ -f "$HARM_WORK_STATE_FILE" ]] \
    && json_get "$(cat "$HARM_WORK_STATE_FILE")" ".status" | grep -q "active"
}

# work_get_state: Get current work session state
# Usage: state=$(work_get_state)
work_get_state() {
  if [[ ! -f "$HARM_WORK_STATE_FILE" ]]; then
    echo "inactive"
    return 0
  fi

  json_get "$(cat "$HARM_WORK_STATE_FILE")" ".status"
}

# work_save_state: Save work session state
# Usage: work_save_state "active" "start_time" "goal"
work_save_state() {
  local status="${1:?work_save_state requires status}"
  local start_time="${2:?work_save_state requires start_time}"
  local goal="${3:-}"
  local paused_duration="${4:-0}"

  local current_time
  current_time="$(get_utc_timestamp)"

  jq -n \
    --arg status "$status" \
    --arg start_time "$start_time" \
    --arg current_time "$current_time" \
    --arg goal "$goal" \
    --argjson paused_duration "$paused_duration" \
    '{
      status: $status,
      start_time: $start_time,
      last_updated: $current_time,
      goal: $goal,
      paused_duration: $paused_duration
    }' | atomic_write "$HARM_WORK_STATE_FILE"
}

# work_load_state: Load work session state as JSON
# Usage: state_json=$(work_load_state)
work_load_state() {
  require_file "$HARM_WORK_STATE_FILE" "work session state"
  cat "$HARM_WORK_STATE_FILE"
}

# ═══════════════════════════════════════════════════════════════
# Work Session Commands
# ═══════════════════════════════════════════════════════════════

# work_start: Start a new work session
#
# Description:
#   Starts a new work session with optional goal description.
#   Creates state file to track session duration and metadata.
#
# Arguments:
#   $1 - goal (string, optional): Description of what you're working on
#
# Returns:
#   0 - Session started successfully
#   1 - Session already active (cannot start new one)
#
# Outputs:
#   stdout: Success message (text) or JSON response
#   stderr: Log entry via log_info()
#
# Examples:
#   work_start
#   work_start "Implementing authentication"
#   HARM_CLI_FORMAT=json work_start "Bug fix #123"
#
# Notes:
#   - Only one session can be active at a time
#   - Timestamp is recorded in UTC (ISO 8601)
#   - Session persists across shell restarts
work_start() {
  local goal="${1:-}"

  # Check if already active
  if work_is_active; then
    error_msg "Work session already active" "$EXIT_ERROR"
    return "$EXIT_ERROR"
  fi

  local start_time
  start_time="$(get_utc_timestamp)"

  # Save session state
  work_save_state "active" "$start_time" "$goal" 0

  log_info "work" "Work session started" "Goal: ${goal:-none}"

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --arg start_time "$start_time" \
      --arg goal "$goal" \
      '{status: "started", start_time: $start_time, goal: $goal}'
  else
    success_msg "Work session started"
    [[ -n "$goal" ]] && echo "  Goal: $goal"
  fi
}

# work_stop: Stop current work session
#
# Description:
#   Stops the active work session, calculates duration, and archives to monthly log.
#   Removes the active session state file.
#
# Arguments:
#   None
#
# Returns:
#   0 - Session stopped successfully
#   1 - No active session to stop
#
# Outputs:
#   stdout: Duration summary (text) or JSON response
#   stderr: Log entry via log_info()
#   file: Appends session to monthly archive (JSONL format)
#
# Examples:
#   work_stop
#   HARM_CLI_FORMAT=json work_stop
#
# Notes:
#   - Calculates total duration from start to stop
#   - Archives to ~/.harm-cli/work/sessions_YYYY-MM.jsonl
#   - State file is removed after archiving
#   - Duration shown in human-readable format (text mode)
work_stop() {
  if ! work_is_active; then
    error_msg "No active work session" "$EXIT_ERROR"
    return "$EXIT_ERROR"
  fi

  local state
  state="$(work_load_state)"
  local start_time
  start_time="$(json_get "$state" ".start_time")"
  local goal
  goal="$(json_get "$state" ".goal")"
  local paused_duration
  paused_duration="$(json_get "$state" ".paused_duration")"

  local end_time
  end_time="$(get_utc_timestamp)"

  # Calculate duration
  local start_epoch end_epoch
  start_epoch="$(iso8601_to_epoch "$start_time")"
  end_epoch="$(get_utc_epoch)"
  local total_seconds=$((end_epoch - start_epoch - paused_duration))

  # Archive session
  local archive_file
  archive_file="${HARM_WORK_DIR}/sessions_$(date '+%Y-%m').jsonl"
  jq -n \
    --arg start_time "$start_time" \
    --arg end_time "$end_time" \
    --argjson duration "$total_seconds" \
    --arg goal "$goal" \
    '{
      start_time: $start_time,
      end_time: $end_time,
      duration_seconds: $duration,
      goal: $goal
    }' >>"$archive_file"

  # Remove current state
  rm -f "$HARM_WORK_STATE_FILE"

  log_info "work" "Work session stopped" "Duration: ${total_seconds}s"

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --argjson duration "$total_seconds" \
      --arg goal "$goal" \
      '{status: "stopped", duration_seconds: $duration, goal: $goal}'
  else
    local formatted
    formatted="$(format_duration "$total_seconds")"
    success_msg "Work session stopped"
    echo "  Duration: $formatted"
    [[ -n "$goal" ]] && echo "  Goal: $goal"
  fi
}

# work_status: Show current work session status
#
# Description:
#   Displays information about the current work session including
#   elapsed time, start time, and associated goal.
#
# Arguments:
#   None
#
# Returns:
#   0 - Always succeeds (shows "inactive" if no session)
#
# Outputs:
#   stdout: Session status (text) or JSON with elapsed seconds
#
# Examples:
#   work_status
#   HARM_CLI_FORMAT=json work_status | jq '.elapsed_seconds'
#
# Notes:
#   - Shows elapsed time in human-readable format (text mode)
#   - JSON mode includes precise elapsed_seconds for scripting
#   - Elapsed time updates in real-time on each call
work_status() {
  if ! work_is_active; then
    if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
      jq -n '{status: "inactive"}'
    else
      echo "No active work session"
    fi
    return 0
  fi

  local state
  state="$(work_load_state)"
  local start_time
  start_time="$(json_get "$state" ".start_time")"
  local goal
  goal="$(json_get "$state" ".goal")"

  # Calculate elapsed time
  local start_epoch
  start_epoch="$(iso8601_to_epoch "$start_time")"
  local current_epoch
  current_epoch="$(get_utc_epoch)"
  local elapsed=$((current_epoch - start_epoch))

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --arg status "active" \
      --arg start_time "$start_time" \
      --argjson elapsed "$elapsed" \
      --arg goal "$goal" \
      '{status: $status, start_time: $start_time, elapsed_seconds: $elapsed, goal: $goal}'
  else
    local formatted
    formatted="$(format_duration "$elapsed")"
    echo "Work session: ${SUCCESS_GREEN}ACTIVE${RESET}"
    echo "  Started: $start_time"
    echo "  Elapsed: $formatted"
    [[ -n "$goal" ]] && echo "  Goal: $goal"
  fi
}

# ═══════════════════════════════════════════════════════════════
# Work Enforcement & Focus Tracking
# ═══════════════════════════════════════════════════════════════

# work_require_active: Require active work session
#
# Description:
#   Checks if a work session is active. If not, displays a reminder
#   to start a session. Useful for enforcing work tracking discipline.
#
# Arguments:
#   None
#
# Returns:
#   0 - Work session is active
#   1 - No active work session
#
# Outputs:
#   stderr: Reminder message if no session active
#
# Examples:
#   work_require_active || echo "Please start a work session"
#   work_require_active && echo "Session active, continue working"
#
# Notes:
#   - Non-blocking (doesn't prevent work, just reminds)
#   - Useful in shell hooks or aliases
#
# Performance:
#   - <10ms (file check + JSON parse)
work_require_active() {
  if work_is_active; then
    return 0
  else
    work_remind
    return 1
  fi
}

# work_remind: Remind user to start work session
#
# Description:
#   Displays friendly reminder to start a work session with example command.
#
# Arguments:
#   None
#
# Returns:
#   0 - Always succeeds
#
# Outputs:
#   stderr: Reminder message
#
# Examples:
#   work_remind
#   work_is_active || work_remind
#
# Notes:
#   - Non-blocking reminder only
#   - Suggests starting a session
work_remind() {
  echo "" >&2
  echo "💡 Tip: No active work session" >&2
  echo "   Start tracking: harm-cli work start \"task description\"" >&2
  echo "" >&2
  return 0
}

# work_focus_score: Calculate focus score for current/last session
#
# Description:
#   Calculates a focus score (0-100) based on session duration and
#   activity patterns. Longer uninterrupted sessions = higher score.
#
# Arguments:
#   None
#
# Returns:
#   0 - Score calculated
#   1 - No session data available
#
# Outputs:
#   stdout: Focus score (0-100)
#
# Examples:
#   score=$(work_focus_score)
#   work_focus_score && echo "Focus score: $score"
#
# Notes:
#   - Score based on session duration
#   - < 15 min = 0-30 (warming up)
#   - 15-60 min = 30-70 (productive)
#   - > 60 min = 70-100 (deep focus)
#   - Future: Could integrate with activity tracking
#
# Performance:
#   - <20ms (simple calculation)
work_focus_score() {
  if ! work_is_active; then
    echo "0"
    return 1
  fi

  # Get session duration
  local start_time goal paused
  start_time=$(json_get "$(work_load_state)" ".start_time")
  paused=$(json_get "$(work_load_state)" ".paused_duration" || echo "0")

  local now
  now=$(get_epoch_seconds)
  local start_epoch
  start_epoch=$(parse_iso8601_to_epoch "$start_time")
  local elapsed=$((now - start_epoch - paused))

  # Calculate score based on duration (in minutes)
  local minutes=$((elapsed / 60))

  local score
  if [[ $minutes -lt 15 ]]; then
    # Warming up: 0-30
    score=$((minutes * 2))
  elif [[ $minutes -lt 60 ]]; then
    # Productive: 30-70
    score=$((30 + (minutes - 15)))
  else
    # Deep focus: 70-100
    local bonus=$(((minutes - 60) / 6))
    score=$((70 + bonus))
    [[ $score -gt 100 ]] && score=100
  fi

  echo "$score"
  return 0
}

# ═══════════════════════════════════════════════════════════════
# Exports
# ═══════════════════════════════════════════════════════════════

export -f work_is_active work_get_state work_save_state work_load_state
export -f work_start work_stop work_status
export -f work_require_active work_remind work_focus_score
