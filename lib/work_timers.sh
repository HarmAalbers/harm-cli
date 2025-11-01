#!/usr/bin/env bash
# shellcheck shell=bash
# work_timers.sh - Timer and notification management for harm-cli work sessions
#
# Part of SOLID refactoring: Single Responsibility = Timer management
#
# This module provides:
# - Desktop notifications (macOS/Linux)
# - Background timer lifecycle management
# - Pomodoro counter tracking
# - Interval reminders
#
# Dependencies:
# - lib/options.sh (for configuration)
# - lib/logging.sh (for log_info, log_debug)
#
# No dependencies on other work_* modules (lowest in dependency chain)

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_WORK_TIMERS_LOADED:-}" ]] && return 0

# Get script directory for sourcing dependencies
WORK_TIMERS_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly WORK_TIMERS_SCRIPT_DIR

# Source dependencies
# shellcheck source=lib/options.sh
source "$WORK_TIMERS_SCRIPT_DIR/options.sh"
# shellcheck source=lib/logging.sh
source "$WORK_TIMERS_SCRIPT_DIR/logging.sh"

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════

# Timer PID file (stores background timer process ID)
HARM_WORK_TIMER_PID_FILE="${HARM_WORK_TIMER_PID_FILE:-${HARM_WORK_DIR:-${HOME}/.harm-cli/work}/timer.pid}"
readonly HARM_WORK_TIMER_PID_FILE
export HARM_WORK_TIMER_PID_FILE

# Reminder PID file (stores interval reminder process ID)
HARM_WORK_REMINDER_PID_FILE="${HARM_WORK_REMINDER_PID_FILE:-${HARM_WORK_DIR:-${HOME}/.harm-cli/work}/reminder.pid}"
readonly HARM_WORK_REMINDER_PID_FILE
export HARM_WORK_REMINDER_PID_FILE

# Pomodoro count file (tracks completed pomodoros)
HARM_WORK_POMODORO_COUNT_FILE="${HARM_WORK_POMODORO_COUNT_FILE:-${HARM_WORK_DIR:-${HOME}/.harm-cli/work}/pomodoro_count}"
readonly HARM_WORK_POMODORO_COUNT_FILE
export HARM_WORK_POMODORO_COUNT_FILE

# ═══════════════════════════════════════════════════════════════
# Notification Functions
# ═══════════════════════════════════════════════════════════════

# work_send_notification: Send desktop notification
#
# Description:
#   Sends a desktop notification using platform-specific tools.
#   Supports macOS (osascript) and Linux (notify-send).
#
# Arguments:
#   $1 - title (required): Notification title
#   $2 - message (required): Notification message body
#
# Returns:
#   0 - Always succeeds (notifications are best-effort)
#
# Examples:
#   work_send_notification "Break Time" "Take a 5-minute break"
#   work_send_notification "Pomodoro Complete" "Great job!"
#
# Notes:
#   - Respects HARM_WORK_NOTIFICATIONS option (1=enabled, 0=disabled)
#   - Respects HARM_WORK_SOUND_NOTIFICATIONS option for sound
#   - Uses heredoc to prevent command injection (security fix)
#   - Logs notification details at INFO level
work_send_notification() {
  local title="${1:?work_send_notification requires title}"
  local message="${2:?work_send_notification requires message}"

  # Check if notifications are enabled
  local notifications_enabled
  notifications_enabled=$(options_get work_notifications)
  [[ "$notifications_enabled" == "1" ]] || return 0

  # Check if sound is enabled
  local sound_enabled
  sound_enabled=$(options_get work_sound_notifications)

  if [[ "$(uname)" == "Darwin" ]]; then
    # macOS - use osascript with heredoc (SECURITY FIX: MEDIUM-1)
    # Prevents command injection by avoiding shell interpretation of user input
    # Using stdin heredoc instead of -e flag eliminates quote escaping vulnerabilities
    if [[ "$sound_enabled" == "1" ]]; then
      # With sound
      osascript 2>/dev/null <<EOF || true
display notification "$message" with title "$title" sound name "Glass"
EOF
    else
      # Silent
      osascript 2>/dev/null <<EOF || true
display notification "$message" with title "$title"
EOF
    fi
  elif command -v notify-send &>/dev/null; then
    # Linux - use notify-send
    notify-send "$title" "$message" 2>/dev/null || true

    # Play sound on Linux if enabled and paplay is available
    if [[ "$sound_enabled" == "1" ]] && command -v paplay &>/dev/null; then
      paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || true
    fi
  fi

  log_info "work" "Notification sent" "Title: $title, Message: $message, Sound: $sound_enabled"
}

# ═══════════════════════════════════════════════════════════════
# Timer Management Functions
# ═══════════════════════════════════════════════════════════════

# work_stop_timer: Stop and clean up background timer and reminders
#
# Description:
#   Stops all running background timer processes (main timer and reminders).
#   Cleans up PID files after stopping processes.
#
# Arguments:
#   None
#
# Returns:
#   0 - Always succeeds (cleanup is best-effort)
#
# Examples:
#   work_stop_timer
#
# Notes:
#   - Handles missing PID files gracefully
#   - Handles stale PIDs gracefully (process already dead)
#   - Kills both timer and reminder processes
#   - Logs stopped processes at DEBUG level
work_stop_timer() {
  # Stop main timer
  if [[ -f "$HARM_WORK_TIMER_PID_FILE" ]]; then
    local timer_pid
    timer_pid=$(cat "$HARM_WORK_TIMER_PID_FILE")

    # Kill the timer process if it's still running
    if kill -0 "$timer_pid" 2>/dev/null; then
      kill "$timer_pid" 2>/dev/null || true
      log_debug "work" "Stopped timer process" "PID: $timer_pid"
    fi

    rm -f "$HARM_WORK_TIMER_PID_FILE"
  fi

  # Stop reminder process
  if [[ -f "$HARM_WORK_REMINDER_PID_FILE" ]]; then
    local reminder_pid
    reminder_pid=$(cat "$HARM_WORK_REMINDER_PID_FILE")

    if kill -0 "$reminder_pid" 2>/dev/null; then
      kill "$reminder_pid" 2>/dev/null || true
      log_debug "work" "Stopped reminder process" "PID: $reminder_pid"
    fi

    rm -f "$HARM_WORK_REMINDER_PID_FILE"
  fi

  return 0
}

# ═══════════════════════════════════════════════════════════════
# Pomodoro Counter Functions
# ═══════════════════════════════════════════════════════════════

# work_get_pomodoro_count: Get current pomodoro count
#
# Description:
#   Returns the current pomodoro count from the count file.
#   Returns 0 if the file doesn't exist.
#
# Arguments:
#   None
#
# Returns:
#   Current pomodoro count (0 if file doesn't exist)
#
# Examples:
#   count=$(work_get_pomodoro_count)
#   echo "Completed $count pomodoros"
work_get_pomodoro_count() {
  if [[ -f "$HARM_WORK_POMODORO_COUNT_FILE" ]]; then
    cat "$HARM_WORK_POMODORO_COUNT_FILE"
  else
    echo "0"
  fi
}

# work_increment_pomodoro_count: Increment pomodoro count
#
# Description:
#   Increments the pomodoro counter by 1 and returns the new count.
#   Creates the count file if it doesn't exist (starts at 0).
#
# Arguments:
#   None
#
# Returns:
#   New count after increment
#
# Examples:
#   new_count=$(work_increment_pomodoro_count)
#   echo "That's pomodoro #$new_count!"
work_increment_pomodoro_count() {
  local count
  count=$(work_get_pomodoro_count)
  count=$((count + 1))
  echo "$count" >"$HARM_WORK_POMODORO_COUNT_FILE"
  echo "$count"
}

# work_reset_pomodoro_count: Reset pomodoro count to 0
#
# Description:
#   Resets the pomodoro counter to 0.
#   Creates the count file if it doesn't exist.
#
# Arguments:
#   None
#
# Returns:
#   0 - Always succeeds
#
# Examples:
#   work_reset_pomodoro_count
work_reset_pomodoro_count() {
  echo "0" >"$HARM_WORK_POMODORO_COUNT_FILE"
}

# ═══════════════════════════════════════════════════════════════
# Module Initialization
# ═══════════════════════════════════════════════════════════════

readonly _HARM_WORK_TIMERS_LOADED=1
export _HARM_WORK_TIMERS_LOADED
