#!/usr/bin/env bash
# shellcheck shell=bash
# activity.sh - Activity tracking and command logging for harm-cli
# Tracks commands, performance metrics, and project switches
#
# This module provides:
# - Command execution logging (JSONL format)
# - Performance tracking (duration, exit codes)
# - Project switch detection
# - Activity querying and filtering
# - Automatic cleanup of old logs

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_ACTIVITY_LOADED:-}" ]] && return 0

# Source dependencies
ACTIVITY_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly ACTIVITY_SCRIPT_DIR

# shellcheck source=lib/common.sh
source "$ACTIVITY_SCRIPT_DIR/common.sh"
# shellcheck source=lib/logging.sh
source "$ACTIVITY_SCRIPT_DIR/logging.sh"
# shellcheck source=lib/util.sh
source "$ACTIVITY_SCRIPT_DIR/util.sh"
# shellcheck source=lib/hooks.sh
source "$ACTIVITY_SCRIPT_DIR/hooks.sh"

# Mark as loaded
readonly _HARM_ACTIVITY_LOADED=1

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════

# Activity storage directory
HARM_ACTIVITY_DIR="${HARM_ACTIVITY_DIR:-${HOME}/.harm-cli/activity}"
readonly HARM_ACTIVITY_DIR
export HARM_ACTIVITY_DIR

# Activity log file (JSONL format)
HARM_ACTIVITY_LOG="${HARM_ACTIVITY_LOG:-${HARM_ACTIVITY_DIR}/activity.jsonl}"
readonly HARM_ACTIVITY_LOG
export HARM_ACTIVITY_LOG

# Minimum command duration to log (milliseconds)
# Commands faster than this are filtered out to reduce noise
HARM_ACTIVITY_MIN_DURATION_MS="${HARM_ACTIVITY_MIN_DURATION_MS:-100}"
readonly HARM_ACTIVITY_MIN_DURATION_MS

# Commands to exclude from logging (space-separated)
HARM_ACTIVITY_EXCLUDE="${HARM_ACTIVITY_EXCLUDE:-ls cd pwd clear exit history}"
readonly HARM_ACTIVITY_EXCLUDE

# Log retention period (days)
HARM_ACTIVITY_RETENTION_DAYS="${HARM_ACTIVITY_RETENTION_DAYS:-90}"
readonly HARM_ACTIVITY_RETENTION_DAYS

# Enable/disable activity tracking
HARM_ACTIVITY_ENABLED="${HARM_ACTIVITY_ENABLED:-1}"
readonly HARM_ACTIVITY_ENABLED

# Initialize directories
ensure_dir "$HARM_ACTIVITY_DIR"

# ═══════════════════════════════════════════════════════════════
# State Management
# ═══════════════════════════════════════════════════════════════

# Track command start time (milliseconds since epoch)
declare -g _ACTIVITY_CMD_START=0

# Track last command for logging
declare -g _ACTIVITY_LAST_CMD=""

# ═══════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════

# _activity_is_enabled: Check if activity tracking is enabled
#
# Returns:
#   0 - Activity tracking enabled
#   1 - Activity tracking disabled
_activity_is_enabled() {
  [[ $HARM_ACTIVITY_ENABLED -eq 1 ]]
}

# _activity_should_log: Check if command should be logged
#
# Description:
#   Determines if a command should be logged based on:
#   - Exclude list
#   - Command duration threshold
#   - Command validity
#
# Arguments:
#   $1 - cmd (string): Command to check
#   $2 - duration_ms (integer): Command duration in milliseconds
#
# Returns:
#   0 - Command should be logged
#   1 - Command should not be logged
_activity_should_log() {
  local cmd="${1:?Command required}"
  local duration_ms="${2:?Duration required}"

  # Skip if below duration threshold
  [[ $duration_ms -lt $HARM_ACTIVITY_MIN_DURATION_MS ]] && return 1

  # Get first word of command
  local first_word="${cmd%% *}"

  # Check exclude list (temporarily use default IFS to split on spaces)
  local excluded
  local old_ifs="$IFS"
  IFS=' '
  for excluded in $HARM_ACTIVITY_EXCLUDE; do
    [[ "$first_word" == "$excluded" ]] && IFS="$old_ifs" && return 1
  done
  IFS="$old_ifs"

  # Skip internal harm-cli commands
  [[ "$cmd" == harm-cli* ]] || [[ "$cmd" == _harm* ]] && return 1

  return 0
}

# _activity_get_project: Get current project name
#
# Description:
#   Attempts to determine project name from:
#   1. Git repository name
#   2. Current directory name
#
# Returns:
#   0 - Always succeeds
#
# Outputs:
#   stdout: Project name (or "unknown")
_activity_get_project() {
  local project="unknown"

  # Try to get git repo name
  if git rev-parse --git-dir >/dev/null 2>&1; then
    project="$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")"
  else
    # Fall back to directory name
    project="$(basename "$PWD")"
  fi

  echo "$project"
}

# ═══════════════════════════════════════════════════════════════
# Logging Functions
# ═══════════════════════════════════════════════════════════════

# _activity_log_command: Log command execution to JSONL
#
# Description:
#   Logs command details in JSON Lines format:
#   - timestamp (ISO 8601)
#   - type ("command")
#   - command (string)
#   - exit_code (integer)
#   - duration_ms (integer)
#   - pwd (string)
#   - project (string)
#
# Arguments:
#   $1 - cmd (string): Command that was executed
#   $2 - exit_code (integer): Command exit code
#   $3 - duration_ms (integer): Command duration in milliseconds
#
# Returns:
#   0 - Logged successfully
#   1 - Logging failed
#
# Side Effects:
#   - Appends JSON line to $HARM_ACTIVITY_LOG
_activity_log_command() {
  local cmd="${1:?Command required}"
  local exit_code="${2:?Exit code required}"
  local duration_ms="${3:?Duration required}"

  local timestamp project
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  project="$(_activity_get_project)"

  # Build JSON entry using jq for safety
  local json_entry
  json_entry=$(jq -n \
    --arg timestamp "$timestamp" \
    --arg type "command" \
    --arg cmd "$cmd" \
    --argjson exit_code "$exit_code" \
    --argjson duration_ms "$duration_ms" \
    --arg pwd "$PWD" \
    --arg project "$project" \
    '{
      timestamp: $timestamp,
      type: $type,
      command: $cmd,
      exit_code: $exit_code,
      duration_ms: $duration_ms,
      pwd: $pwd,
      project: $project
    }')

  # Append to log file atomically
  echo "$json_entry" >>"$HARM_ACTIVITY_LOG" || {
    log_error "activity" "Failed to write to activity log"
    return 1
  }

  log_debug "activity" "Logged command" "duration=${duration_ms}ms exit=$exit_code"
  return 0
}

# _activity_log_project_switch: Log project/directory change
#
# Description:
#   Logs directory changes in JSON Lines format.
#
# Arguments:
#   $1 - old_pwd (string): Previous directory
#   $2 - new_pwd (string): New directory
#
# Returns:
#   0 - Logged successfully
#   1 - Logging failed
_activity_log_project_switch() {
  local old_pwd="${1:?Old PWD required}"
  local new_pwd="${2:?New PWD required}"

  local timestamp project
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  project="$(_activity_get_project)"

  local json_entry
  json_entry=$(jq -n \
    --arg timestamp "$timestamp" \
    --arg type "project_switch" \
    --arg old_pwd "$old_pwd" \
    --arg new_pwd "$new_pwd" \
    --arg project "$project" \
    '{
      timestamp: $timestamp,
      type: $type,
      old_pwd: $old_pwd,
      new_pwd: $new_pwd,
      project: $project
    }')

  echo "$json_entry" >>"$HARM_ACTIVITY_LOG" || {
    log_error "activity" "Failed to write project switch to activity log"
    return 1
  }

  log_debug "activity" "Logged project switch" "project=$project"
  return 0
}

# ═══════════════════════════════════════════════════════════════
# Hook Handlers
# ═══════════════════════════════════════════════════════════════

# _activity_get_timestamp_ms: Get current timestamp in milliseconds
#
# Description:
#   Safely gets current time in milliseconds, with fallback for systems
#   that don't support %N format in date command (BSD/macOS).
#
# Returns:
#   0 - Timestamp in milliseconds (stdout)
_activity_get_timestamp_ms() {
  local timestamp
  timestamp=$(date +%s%3N 2>/dev/null)

  # Strip any non-numeric characters (handles literal "N" on BSD systems)
  timestamp="${timestamp//[^0-9]/}"

  # If we got a valid number, return it
  if [[ -n "$timestamp" && "$timestamp" -gt 0 ]] 2>/dev/null; then
    echo "$timestamp"
  else
    # Fallback: use seconds and convert to milliseconds
    echo "$(($(date +%s) * 1000))"
  fi
}

# _activity_preexec_hook: Capture command start time
#
# Description:
#   Called before command execution via preexec hook.
#   Records start time for duration calculation.
#
# Arguments:
#   $1 - cmd (string): Command about to execute
#
# Returns:
#   0 - Always succeeds
_activity_preexec_hook() {
  _activity_is_enabled || return 0

  local cmd="$1"
  _ACTIVITY_LAST_CMD="$cmd"
  _ACTIVITY_CMD_START=$(_activity_get_timestamp_ms)

  log_debug "activity" "Command starting" "cmd=$cmd"
}

# _activity_precmd_hook: Log completed command
#
# Description:
#   Called before prompt display via precmd hook.
#   Calculates duration and logs command if it meets criteria.
#
# Arguments:
#   $1 - exit_code (integer): Last command exit code
#   $2 - last_cmd (string): Last command executed
#
# Returns:
#   0 - Always succeeds
_activity_precmd_hook() {
  _activity_is_enabled || return 0

  local exit_code="${1:-0}"
  local last_cmd="${2:-$_ACTIVITY_LAST_CMD}"

  # Skip if no command start time recorded
  [[ $_ACTIVITY_CMD_START -eq 0 ]] && return 0

  # Calculate duration
  local end_time duration_ms
  end_time=$(_activity_get_timestamp_ms)
  duration_ms=$((end_time - _ACTIVITY_CMD_START))

  # Reset start time
  _ACTIVITY_CMD_START=0

  # Skip if no command recorded
  [[ -z "$last_cmd" ]] && return 0

  # Check if command should be logged
  if _activity_should_log "$last_cmd" "$duration_ms"; then
    _activity_log_command "$last_cmd" "$exit_code" "$duration_ms"
  fi

  return 0
}

# _activity_chpwd_hook: Log directory changes
#
# Description:
#   Called on directory change via chpwd hook.
#   Logs project switches.
#
# Arguments:
#   $1 - old_pwd (string): Previous directory
#   $2 - new_pwd (string): New directory
#
# Returns:
#   0 - Always succeeds
_activity_chpwd_hook() {
  _activity_is_enabled || return 0

  local old_pwd="$1"
  local new_pwd="$2"

  # Only log if directories are different
  [[ "$old_pwd" != "$new_pwd" ]] || return 0

  _activity_log_project_switch "$old_pwd" "$new_pwd"
}

# ═══════════════════════════════════════════════════════════════
# Query Functions
# ═══════════════════════════════════════════════════════════════

# activity_query: Query activity log
#
# Description:
#   Retrieves activity data for a specified time period.
#   Returns JSONL format (one JSON object per line).
#
# Arguments:
#   $1 - period (string, optional): Time period to query
#        Options: today, yesterday, week, month, all
#        Default: today
#
# Returns:
#   0 - Query successful
#   1 - Log file not found
#
# Outputs:
#   stdout: JSONL data for specified period
#
# Examples:
#   activity_query today
#   activity_query week | jq -r '.command'
#   activity_query month | jq 'select(.exit_code != 0)'
activity_query() {
  local period="${1:-today}"

  # Check if log file exists
  [[ -f "$HARM_ACTIVITY_LOG" ]] || {
    log_warn "activity" "No activity log found"
    return 1
  }

  local start_date
  case "$period" in
    today)
      start_date=$(date -u +%Y-%m-%d)
      jq -c "select(.timestamp | startswith(\"$start_date\"))" "$HARM_ACTIVITY_LOG"
      ;;
    yesterday)
      start_date=$(date -u -d '1 day ago' +%Y-%m-%d 2>/dev/null || date -u -v-1d +%Y-%m-%d)
      jq -c "select(.timestamp | startswith(\"$start_date\"))" "$HARM_ACTIVITY_LOG"
      ;;
    week)
      start_date=$(date -u -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -u -v-7d +%Y-%m-%d)
      jq -c "select(.timestamp >= \"$start_date\")" "$HARM_ACTIVITY_LOG"
      ;;
    month)
      start_date=$(date -u -d '30 days ago' +%Y-%m-%d 2>/dev/null || date -u -v-30d +%Y-%m-%d)
      jq -c "select(.timestamp >= \"$start_date\")" "$HARM_ACTIVITY_LOG"
      ;;
    all)
      cat "$HARM_ACTIVITY_LOG"
      ;;
    *)
      log_error "activity" "Invalid period: $period"
      return 1
      ;;
  esac
}

# activity_stats: Get activity statistics
#
# Description:
#   Generates statistics for a time period:
#   - Total commands
#   - Error rate
#   - Average duration
#   - Most used commands
#   - Projects worked on
#
# Arguments:
#   $1 - period (string, optional): Time period (default: today)
#
# Returns:
#   0 - Always succeeds
#
# Outputs:
#   stdout: Human-readable statistics
#
# Examples:
#   activity_stats today
#   activity_stats week
activity_stats() {
  local period="${1:-today}"

  echo "Activity Statistics - $period"
  echo "═══════════════════════════════════════"

  local data
  data=$(activity_query "$period" 2>/dev/null)

  if [[ -z "$data" ]]; then
    echo "No activity data for $period"
    return 0
  fi

  # Total commands
  local total_commands
  total_commands=$(echo "$data" | jq -s 'map(select(.type == "command")) | length')
  echo "📊 Total Commands: $total_commands"

  # Error rate
  local errors
  errors=$(echo "$data" | jq -s 'map(select(.type == "command" and .exit_code != 0)) | length')
  local error_rate
  if [[ $total_commands -gt 0 ]]; then
    error_rate=$(echo "scale=1; $errors * 100 / $total_commands" | bc 2>/dev/null || echo "0")
  else
    error_rate="0"
  fi
  echo "❌ Error Rate: ${error_rate}% ($errors errors)"

  # Average duration
  local avg_duration
  avg_duration=$(echo "$data" | jq -s 'map(select(.type == "command") | .duration_ms) | add / length | floor' 2>/dev/null || echo "0")
  echo "⏱️  Average Duration: ${avg_duration}ms"

  # Most used commands
  echo ""
  echo "🔥 Top Commands:"
  echo "$data" | jq -r 'select(.type == "command") | .command' \
    | awk '{print $1}' \
    | sort | uniq -c | sort -rn | head -5 \
    | awk '{printf "   %2d. %-20s (%d times)\n", NR, $2, $1}'

  # Projects
  echo ""
  echo "📁 Projects:"
  echo "$data" | jq -r '.project' \
    | sort | uniq -c | sort -rn | head -5 \
    | awk '{printf "   • %-20s (%d actions)\n", $2, $1}'
}

# activity_clear: Clear activity log
#
# Description:
#   Removes all activity data. Use with caution!
#
# Arguments:
#   None
#
# Returns:
#   0 - Cleared successfully
#   1 - Clear failed
activity_clear() {
  if [[ -f "$HARM_ACTIVITY_LOG" ]]; then
    rm -f "$HARM_ACTIVITY_LOG" || {
      log_error "activity" "Failed to clear activity log"
      return 1
    }
    log_info "activity" "Activity log cleared"
  else
    log_info "activity" "No activity log to clear"
  fi
  return 0
}

# activity_cleanup: Remove old activity data
#
# Description:
#   Removes activity entries older than retention period.
#   Keeps log file size manageable.
#
# Arguments:
#   None
#
# Returns:
#   0 - Cleanup successful
#   1 - Cleanup failed
activity_cleanup() {
  [[ -f "$HARM_ACTIVITY_LOG" ]] || return 0

  local cutoff_date
  cutoff_date=$(date -u -d "$HARM_ACTIVITY_RETENTION_DAYS days ago" +%Y-%m-%d 2>/dev/null \
    || date -u -v-"${HARM_ACTIVITY_RETENTION_DAYS}"d +%Y-%m-%d)

  log_info "activity" "Cleaning up entries older than $cutoff_date"

  # Create temp file with recent entries
  local temp_file
  temp_file=$(mktemp)

  jq -c "select(.timestamp >= \"$cutoff_date\")" "$HARM_ACTIVITY_LOG" >"$temp_file" || {
    log_error "activity" "Cleanup failed"
    rm -f "$temp_file"
    return 1
  }

  # Replace log file
  mv "$temp_file" "$HARM_ACTIVITY_LOG" || {
    log_error "activity" "Failed to update activity log"
    rm -f "$temp_file"
    return 1
  }

  log_info "activity" "Cleanup complete"
  return 0
}

# ═══════════════════════════════════════════════════════════════
# Initialization
# ═══════════════════════════════════════════════════════════════

# Register hooks if activity tracking is enabled
if _activity_is_enabled; then
  log_debug "activity" "Registering activity tracking hooks"

  # Register hooks
  harm_add_hook preexec _activity_preexec_hook 2>/dev/null || true
  harm_add_hook precmd _activity_precmd_hook 2>/dev/null || true
  harm_add_hook chpwd _activity_chpwd_hook 2>/dev/null || true

  log_info "activity" "Activity tracking enabled"
fi
