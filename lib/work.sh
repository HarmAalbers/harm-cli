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
# shellcheck source=lib/options.sh
source "$WORK_SCRIPT_DIR/options.sh"

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════

HARM_WORK_DIR="${HARM_WORK_DIR:-${HOME}/.harm-cli/work}"
readonly HARM_WORK_DIR
export HARM_WORK_DIR

HARM_WORK_STATE_FILE="${HARM_WORK_STATE_FILE:-${HARM_WORK_DIR}/current_session.json}"
readonly HARM_WORK_STATE_FILE
export HARM_WORK_STATE_FILE

HARM_WORK_TIMER_PID_FILE="${HARM_WORK_TIMER_PID_FILE:-${HARM_WORK_DIR}/timer.pid}"
readonly HARM_WORK_TIMER_PID_FILE
export HARM_WORK_TIMER_PID_FILE

HARM_WORK_REMINDER_PID_FILE="${HARM_WORK_REMINDER_PID_FILE:-${HARM_WORK_DIR}/reminder.pid}"
readonly HARM_WORK_REMINDER_PID_FILE
export HARM_WORK_REMINDER_PID_FILE

HARM_WORK_POMODORO_COUNT_FILE="${HARM_WORK_POMODORO_COUNT_FILE:-${HARM_WORK_DIR}/pomodoro_count}"
readonly HARM_WORK_POMODORO_COUNT_FILE
export HARM_WORK_POMODORO_COUNT_FILE

HARM_BREAK_STATE_FILE="${HARM_BREAK_STATE_FILE:-${HARM_WORK_DIR}/current_break.json}"
readonly HARM_BREAK_STATE_FILE
export HARM_BREAK_STATE_FILE

HARM_BREAK_TIMER_PID_FILE="${HARM_BREAK_TIMER_PID_FILE:-${HARM_WORK_DIR}/break_timer.pid}"
readonly HARM_BREAK_TIMER_PID_FILE
export HARM_BREAK_TIMER_PID_FILE

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

# work_send_notification: Send desktop notification with optional sound
#
# Arguments:
#   $1 - Title
#   $2 - Message
#
# Notes:
#   - Uses osascript on macOS, notify-send on Linux
#   - Only sends if work_notifications option is enabled
#   - Plays sound if work_sound_notifications option is enabled
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

# work_stop_timer: Stop and clean up background timer and reminders
#
# Returns:
#   0 on success
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

# work_get_pomodoro_count: Get current pomodoro count
#
# Returns:
#   Current pomodoro count (0 if file doesn't exist)
work_get_pomodoro_count() {
  if [[ -f "$HARM_WORK_POMODORO_COUNT_FILE" ]]; then
    cat "$HARM_WORK_POMODORO_COUNT_FILE"
  else
    echo "0"
  fi
}

# work_increment_pomodoro_count: Increment pomodoro count
#
# Returns:
#   New count
work_increment_pomodoro_count() {
  local count
  count=$(work_get_pomodoro_count)
  count=$((count + 1))
  echo "$count" >"$HARM_WORK_POMODORO_COUNT_FILE"
  echo "$count"
}

# work_reset_pomodoro_count: Reset pomodoro count to 0
work_reset_pomodoro_count() {
  echo "0" >"$HARM_WORK_POMODORO_COUNT_FILE"
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

  # Interactive mode if no goal provided and TTY available
  if [[ -z "$goal" ]] && [[ -t 0 ]] && [[ -t 1 ]] && [[ "${HARM_CLI_FORMAT:-text}" == "text" ]]; then
    # Source interactive module if available
    if [[ -f "$WORK_SCRIPT_DIR/interactive.sh" ]]; then
      # shellcheck source=lib/interactive.sh
      source "$WORK_SCRIPT_DIR/interactive.sh"
    fi

    # Check if interactive functions available
    if type interactive_choose >/dev/null 2>&1; then
      log_debug "work" "Starting interactive work session wizard"

      echo "🍅 Start Pomodoro Session"
      echo ""

      # Build goal options
      local -a goal_options=()

      # Load goals module if available
      if [[ -f "$WORK_SCRIPT_DIR/goals.sh" ]]; then
        # shellcheck source=lib/goals.sh
        source "$WORK_SCRIPT_DIR/goals.sh" 2>/dev/null || true
      fi

      # Add existing incomplete goals
      if type goal_exists_today >/dev/null 2>&1 && goal_exists_today 2>/dev/null; then
        local goal_file
        goal_file=$(goal_file_for_today 2>/dev/null)

        if [[ -f "$goal_file" ]]; then
          # Read incomplete goals
          while IFS= read -r line; do
            local completed
            completed=$(echo "$line" | jq -r '.completed' 2>/dev/null || echo "true")

            if [[ "$completed" == "false" ]]; then
              local goal_text
              goal_text=$(echo "$line" | jq -r '.goal' 2>/dev/null)
              [[ -n "$goal_text" ]] && goal_options+=("$goal_text")
            fi
          done <"$goal_file"
        fi
      fi

      # Always add "Custom goal..." option
      goal_options+=("Custom goal...")

      # Interactive selection
      if goal=$(interactive_choose "What are you working on?" "${goal_options[@]}" 2>/dev/null); then
        # If custom goal selected, prompt for input
        if [[ "$goal" == "Custom goal..." ]]; then
          if ! goal=$(interactive_input "Enter goal description" 2>/dev/null); then
            error_msg "Goal input cancelled"
            return "$EXIT_ERROR"
          fi

          # Empty input check
          if [[ -z "$goal" ]]; then
            error_msg "Goal cannot be empty"
            return "$EXIT_ERROR"
          fi
        fi

        log_info "work" "Interactive wizard completed" "Goal: $goal"
      else
        error_msg "Work session cancelled"
        return "$EXIT_ERROR"
      fi
    fi
  fi

  # Check if already active
  if work_is_active; then
    error_msg "Work session already active" "$EXIT_ERROR"
    return "$EXIT_ERROR"
  fi

  local start_time
  start_time="$(get_utc_timestamp)"

  # Get work duration from options (in seconds)
  local work_duration
  work_duration=$(options_get work_duration)

  # Save session state
  work_save_state "active" "$start_time" "$goal" 0

  log_info "work" "Work session started" "Goal: ${goal:-none}, Duration: ${work_duration}s"

  # Start background timer (non-blocking)
  # The timer will notify when the work session should end
  (
    sleep "$work_duration"

    # Notify work session complete
    if [[ -f "$HARM_WORK_STATE_FILE" ]]; then
      work_send_notification "🍅 Work Session Complete" "Time for a break! You've completed a pomodoro."

      # Suggest stopping the session
      log_info "work" "Work timer expired" "Duration: ${work_duration}s"
    fi
  ) &

  # Save timer PID
  echo $! >"$HARM_WORK_TIMER_PID_FILE"

  # Start interval reminder process if enabled
  local reminder_interval
  reminder_interval=$(options_get work_reminder_interval)

  if ((reminder_interval > 0)); then
    # Convert minutes to seconds
    local reminder_seconds=$((reminder_interval * 60))

    (
      # Loop until work session ends
      while [[ -f "$HARM_WORK_STATE_FILE" ]]; do
        sleep "$reminder_seconds"

        # Check if session is still active before sending reminder
        if [[ -f "$HARM_WORK_STATE_FILE" ]]; then
          local state elapsed_min session_start_time start_epoch now_epoch
          state=$(cat "$HARM_WORK_STATE_FILE")
          session_start_time=$(json_get "$state" ".start_time")
          start_epoch=$(iso8601_to_epoch "$session_start_time")
          now_epoch=$(get_utc_epoch)
          elapsed_min=$(((now_epoch - start_epoch) / 60))

          work_send_notification "⏰ Focus Reminder" "You've been working for ${elapsed_min} minutes. Keep going!"
          log_info "work" "Interval reminder sent" "Elapsed: ${elapsed_min}m"
        fi
      done
    ) &

    # Save reminder PID
    echo $! >"$HARM_WORK_REMINDER_PID_FILE"
    log_debug "work" "Started reminder process" "Interval: ${reminder_interval}m"
  fi

  # Send start notification
  local duration_min=$((work_duration / 60))
  work_send_notification "🍅 Work Session Started" "${goal:-Focus time} - ${duration_min} minutes"

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --arg start_time "$start_time" \
      --arg goal "$goal" \
      --argjson duration "$work_duration" \
      '{status: "started", start_time: $start_time, goal: $goal, duration_seconds: $duration}'
  else
    success_msg "Work session started"
    [[ -n "$goal" ]] && echo "  Goal: $goal"
    echo "  Duration: ${duration_min} minutes"
    echo "  Timer running in background (non-blocking)"
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

  # Stop the background timer
  work_stop_timer

  # PERFORMANCE OPTIMIZATION (PERF-2):
  # Instead of 3 separate json_get calls (3 jq processes),
  # use single jq with TSV output (1 process = 66% faster)
  local start_time goal paused_duration
  read -r start_time goal paused_duration < <(
    jq -r '[.start_time, .goal, (.paused_duration // 0)] | @tsv' "$HARM_WORK_STATE_FILE"
  )

  local end_time
  end_time="$(get_utc_timestamp)"

  # Calculate duration
  local start_epoch end_epoch
  start_epoch="$(iso8601_to_epoch "$start_time")"
  end_epoch="$(get_utc_epoch)"
  local total_seconds=$((end_epoch - start_epoch - paused_duration))

  # Increment pomodoro count
  local pomodoro_count
  pomodoro_count=$(work_increment_pomodoro_count)

  # Determine break type
  local pomodoros_until_long
  pomodoros_until_long=$(options_get pomodoros_until_long)
  local break_duration break_type

  if ((pomodoro_count % pomodoros_until_long == 0)); then
    break_duration=$(options_get break_long)
    break_type="long"
  else
    break_duration=$(options_get break_short)
    break_type="short"
  fi

  local break_min=$((break_duration / 60))

  # Archive session
  local archive_file
  archive_file="${HARM_WORK_DIR}/sessions_$(date '+%Y-%m').jsonl"
  jq -n \
    --arg start_time "$start_time" \
    --arg end_time "$end_time" \
    --argjson duration "$total_seconds" \
    --arg goal "$goal" \
    --argjson pomodoro_count "$pomodoro_count" \
    '{
      start_time: $start_time,
      end_time: $end_time,
      duration_seconds: $duration,
      goal: $goal,
      pomodoro_count: $pomodoro_count
    }' >>"$archive_file"

  # Remove current state
  rm -f "$HARM_WORK_STATE_FILE"

  # Clear enforcement state
  work_enforcement_clear 2>/dev/null || true

  log_info "work" "Work session stopped" "Duration: ${total_seconds}s, Pomodoro: #${pomodoro_count}"

  # Send notification suggesting break
  work_send_notification "✅ Work Complete!" "Pomodoro #${pomodoro_count} done. Take a ${break_min}-minute ${break_type} break!"

  # Check if auto-start break is enabled
  local auto_start_break
  auto_start_break=$(options_get work_auto_start_break)

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --argjson duration "$total_seconds" \
      --arg goal "$goal" \
      --argjson pomodoro_count "$pomodoro_count" \
      --arg break_type "$break_type" \
      --argjson break_duration "$break_duration" \
      --argjson auto_start "$auto_start_break" \
      '{status: "stopped", duration_seconds: $duration, goal: $goal, pomodoro_count: $pomodoro_count, suggested_break: {type: $break_type, duration_seconds: $break_duration}, auto_start_break: ($auto_start == 1)}'
  else
    local formatted
    formatted="$(format_duration "$total_seconds")"
    success_msg "Work session stopped"
    echo "  Duration: $formatted"
    [[ -n "$goal" ]] && echo "  Goal: $goal"
    echo "  Pomodoro: #${pomodoro_count}"
    echo ""

    if [[ "$auto_start_break" == "1" ]]; then
      echo "  🔄 Auto-starting ${break_type} break (${break_min} minutes)..."
      echo ""
      # Auto-start the break
      break_start "$break_duration" "$break_type"
    else
      echo "  💡 Suggested: Take a ${break_min}-minute ${break_type} break!"
    fi
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

  # PERFORMANCE OPTIMIZATION (PERF-2):
  # Single jq call instead of multiple json_get invocations
  local start_time goal
  read -r start_time goal < <(
    jq -r '[.start_time, .goal] | @tsv' "$HARM_WORK_STATE_FILE"
  )

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
  # PERFORMANCE OPTIMIZATION (PERF-2):
  # Single jq call with TSV output instead of multiple calls
  local start_time paused
  read -r start_time paused < <(
    jq -r '[.start_time, (.paused_duration // 0)] | @tsv' "$HARM_WORK_STATE_FILE"
  )

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
# Break Session Commands
# ═══════════════════════════════════════════════════════════════

# break_is_active: Check if break session is currently active
break_is_active() {
  [[ -f "$HARM_BREAK_STATE_FILE" ]] \
    && json_get "$(cat "$HARM_BREAK_STATE_FILE")" ".status" | grep -q "active"
}

# break_start: Start a break session
#
# Arguments:
#   $1 - duration (optional): Break duration in seconds (defaults to break_short or break_long)
#   $2 - type (optional): "short" or "long" (auto-detected if not specified)
#
# Returns:
#   0 - Break started successfully
#   1 - Break already active
break_start() {
  local duration="${1:-}"
  local break_type="${2:-}"

  # Check if already active
  if break_is_active; then
    error_msg "Break session already active" "$EXIT_ERROR"
    return "$EXIT_ERROR"
  fi

  # Auto-detect break type if not specified
  if [[ -z "$duration" ]]; then
    local pomodoro_count
    pomodoro_count=$(work_get_pomodoro_count)
    local pomodoros_until_long
    pomodoros_until_long=$(options_get pomodoros_until_long)

    if ((pomodoro_count % pomodoros_until_long == 0)) && ((pomodoro_count > 0)); then
      duration=$(options_get break_long)
      break_type="long"
    else
      duration=$(options_get break_short)
      break_type="short"
    fi
  fi

  # Default type if still not set
  [[ -z "$break_type" ]] && break_type="custom"

  local start_time
  start_time="$(get_utc_timestamp)"

  # Save break state
  jq -n \
    --arg status "active" \
    --arg start_time "$start_time" \
    --argjson duration "$duration" \
    --arg type "$break_type" \
    '{
      status: $status,
      start_time: $start_time,
      duration_seconds: $duration,
      type: $type
    }' | atomic_write "$HARM_BREAK_STATE_FILE"

  log_info "break" "Break session started" "Type: $break_type, Duration: ${duration}s"

  # Start background timer (non-blocking)
  (
    sleep "$duration"

    # Notify break complete
    if [[ -f "$HARM_BREAK_STATE_FILE" ]]; then
      work_send_notification "⏰ Break Complete!" "Time to get back to work!"
      log_info "break" "Break timer expired" "Duration: ${duration}s"
    fi
  ) &

  # Save timer PID
  echo $! >"$HARM_BREAK_TIMER_PID_FILE"

  # Send start notification
  local duration_min=$((duration / 60))
  work_send_notification "☕ Break Started" "${break_type^} break - ${duration_min} minutes to recharge"

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --arg start_time "$start_time" \
      --argjson duration "$duration" \
      --arg type "$break_type" \
      '{status: "started", start_time: $start_time, duration_seconds: $duration, type: $type}'
  else
    success_msg "Break session started"
    echo "  Type: ${break_type^} break"
    echo "  Duration: ${duration_min} minutes"
    echo "  Timer running in background (non-blocking)"
  fi
}

# break_stop: Stop current break session
#
# Returns:
#   0 - Break stopped successfully
#   1 - No active break
break_stop() {
  if ! break_is_active; then
    error_msg "No active break session" "$EXIT_ERROR"
    return "$EXIT_ERROR"
  fi

  # Stop the background timer
  if [[ -f "$HARM_BREAK_TIMER_PID_FILE" ]]; then
    local timer_pid
    timer_pid=$(cat "$HARM_BREAK_TIMER_PID_FILE")

    if kill -0 "$timer_pid" 2>/dev/null; then
      kill "$timer_pid" 2>/dev/null || true
    fi

    rm -f "$HARM_BREAK_TIMER_PID_FILE"
  fi

  local state
  state=$(cat "$HARM_BREAK_STATE_FILE")
  local start_time break_type
  start_time=$(json_get "$state" ".start_time")
  break_type=$(json_get "$state" ".type")

  local end_time
  end_time="$(get_utc_timestamp)"

  # Calculate duration
  local start_epoch end_epoch
  start_epoch="$(iso8601_to_epoch "$start_time")"
  end_epoch="$(get_utc_epoch)"
  local total_seconds=$((end_epoch - start_epoch))

  # Remove break state
  rm -f "$HARM_BREAK_STATE_FILE"

  log_info "break" "Break session stopped" "Duration: ${total_seconds}s, Type: $break_type"

  # Send notification
  work_send_notification "💪 Break Complete!" "Let's get back to work!"

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --argjson duration "$total_seconds" \
      --arg type "$break_type" \
      '{status: "stopped", duration_seconds: $duration, type: $type}'
  else
    local formatted
    formatted="$(format_duration "$total_seconds")"
    success_msg "Break session stopped"
    echo "  Duration: $formatted"
    echo "  Type: ${break_type^} break"
  fi
}

# break_status: Show current break session status
#
# Returns:
#   0 - Always succeeds
break_status() {
  if ! break_is_active; then
    if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
      jq -n '{status: "inactive"}'
    else
      echo "No active break session"
    fi
    return 0
  fi

  local state
  state=$(cat "$HARM_BREAK_STATE_FILE")
  local start_time break_type duration_planned
  start_time=$(json_get "$state" ".start_time")
  break_type=$(json_get "$state" ".type")
  duration_planned=$(json_get "$state" ".duration_seconds")

  # Calculate elapsed and remaining time
  local start_epoch current_epoch
  start_epoch="$(iso8601_to_epoch "$start_time")"
  current_epoch="$(get_utc_epoch)"
  local elapsed=$((current_epoch - start_epoch))
  local remaining=$((duration_planned - elapsed))

  [[ $remaining -lt 0 ]] && remaining=0

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --arg status "active" \
      --arg start_time "$start_time" \
      --argjson elapsed "$elapsed" \
      --argjson remaining "$remaining" \
      --arg type "$break_type" \
      '{status: $status, start_time: $start_time, elapsed_seconds: $elapsed, remaining_seconds: $remaining, type: $type}'
  else
    local elapsed_formatted remaining_formatted
    elapsed_formatted="$(format_duration "$elapsed")"
    remaining_formatted="$(format_duration "$remaining")"

    echo "Break session: ${SUCCESS_GREEN}ACTIVE${RESET}"
    echo "  Type: ${break_type^} break"
    echo "  Started: $start_time"
    echo "  Elapsed: $elapsed_formatted"
    echo "  Remaining: $remaining_formatted"
  fi
}

# ═══════════════════════════════════════════════════════════════
# Statistics & Reporting
# ═══════════════════════════════════════════════════════════════

# work_stats_today: Show today's work statistics
#
# Returns:
#   0 on success
work_stats_today() {
  local today
  today=$(date '+%Y-%m-%d')
  local current_month
  current_month=$(date '+%Y-%m')
  local archive_file="${HARM_WORK_DIR}/sessions_${current_month}.jsonl"

  if [[ ! -f "$archive_file" ]]; then
    if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
      jq -n --arg date "$today" '{date: $date, sessions: 0, total_duration_seconds: 0, pomodoros: 0}'
    else
      echo "No sessions recorded for today ($today)"
    fi
    return 0
  fi

  # Filter sessions for today and calculate stats
  local sessions total_duration pomodoros
  sessions=$(jq -s --arg date "$today" '[.[] | select(.start_time | startswith($date))] | length' "$archive_file")
  total_duration=$(jq -s --arg date "$today" '[.[] | select(.start_time | startswith($date)) | .duration_seconds // 0] | add // 0' "$archive_file")
  pomodoros=$(jq -s --arg date "$today" '[.[] | select(.start_time | startswith($date)) | .pomodoro_count // 0] | max // 0' "$archive_file")
  pomodoros=${pomodoros:-0}

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --arg date "$today" \
      --argjson sessions "$sessions" \
      --argjson duration "$total_duration" \
      --argjson pomodoros "$pomodoros" \
      '{date: $date, sessions: $sessions, total_duration_seconds: $duration, pomodoros: $pomodoros}'
  else
    local formatted
    formatted="$(format_duration "$total_duration")"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Today's Work Statistics ($today)"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  🍅 Pomodoros completed: $pomodoros"
    echo "  📊 Total sessions: $sessions"
    echo "  ⏱  Total work time: $formatted"
    echo ""
  fi
}

# work_stats_week: Show this week's work statistics
#
# Returns:
#   0 on success
work_stats_week() {
  local week_start
  week_start=$(date -v-mon '+%Y-%m-%d' 2>/dev/null || date -d 'last monday' '+%Y-%m-%d' 2>/dev/null)
  local current_month
  current_month=$(date '+%Y-%m')
  local archive_file="${HARM_WORK_DIR}/sessions_${current_month}.jsonl"

  if [[ ! -f "$archive_file" ]]; then
    if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
      jq -n --arg week_start "$week_start" '{week_start: $week_start, sessions: 0, total_duration_seconds: 0, pomodoros: 0}'
    else
      echo "No sessions recorded for this week"
    fi
    return 0
  fi

  # Calculate stats for the week
  local sessions total_duration pomodoros
  sessions=$(jq -s --arg start "$week_start" '[.[] | select(.start_time >= $start)] | length' "$archive_file")
  total_duration=$(jq -s --arg start "$week_start" '[.[] | select(.start_time >= $start) | .duration_seconds // 0] | add // 0' "$archive_file")
  pomodoros=$(jq -s --arg start "$week_start" '[.[] | select(.start_time >= $start) | .pomodoro_count // 0] | max // 0' "$archive_file")
  pomodoros=${pomodoros:-0}

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --arg week_start "$week_start" \
      --argjson sessions "$sessions" \
      --argjson duration "$total_duration" \
      --argjson pomodoros "$pomodoros" \
      '{week_start: $week_start, sessions: $sessions, total_duration_seconds: $duration, pomodoros: $pomodoros}'
  else
    local formatted
    formatted="$(format_duration "$total_duration")"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  This Week's Work Statistics (since $week_start)"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  🍅 Pomodoros completed: $pomodoros"
    echo "  📊 Total sessions: $sessions"
    echo "  ⏱  Total work time: $formatted"
    echo ""
  fi
}

# work_stats_month: Show this month's work statistics
#
# Returns:
#   0 on success
work_stats_month() {
  local current_month
  current_month=$(date '+%Y-%m')
  local archive_file="${HARM_WORK_DIR}/sessions_${current_month}.jsonl"

  if [[ ! -f "$archive_file" ]]; then
    if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
      jq -n --arg month "$current_month" '{month: $month, sessions: 0, total_duration_seconds: 0, pomodoros: 0}'
    else
      echo "No sessions recorded for $current_month"
    fi
    return 0
  fi

  # Calculate monthly stats
  local sessions total_duration pomodoros
  sessions=$(jq -s 'length' "$archive_file")
  total_duration=$(jq -s '[.[] | .duration_seconds // 0] | add // 0' "$archive_file")
  pomodoros=$(jq -s '[.[] | .pomodoro_count // 0] | max // 0' "$archive_file")
  pomodoros=${pomodoros:-0}

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --arg month "$current_month" \
      --argjson sessions "$sessions" \
      --argjson duration "$total_duration" \
      --argjson pomodoros "$pomodoros" \
      '{month: $month, sessions: $sessions, total_duration_seconds: $duration, pomodoros: $pomodoros}'
  else
    local formatted
    formatted="$(format_duration "$total_duration")"
    local avg_per_day=$((total_duration / $(date '+%d')))
    local avg_formatted
    avg_formatted="$(format_duration "$avg_per_day")"

    echo "═══════════════════════════════════════════════════════════════"
    echo "  Monthly Work Statistics ($current_month)"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  🍅 Pomodoros completed: $pomodoros"
    echo "  📊 Total sessions: $sessions"
    echo "  ⏱  Total work time: $formatted"
    echo "  📈 Average per day: $avg_formatted"
    echo ""
  fi
}

# work_stats: Show comprehensive work statistics (all periods)
#
# Returns:
#   0 on success
work_stats() {
  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    # JSON: Combine all stats
    local today week month
    today=$(work_stats_today)
    week=$(work_stats_week)
    month=$(work_stats_month)

    jq -n \
      --argjson today "$today" \
      --argjson week "$week" \
      --argjson month "$month" \
      '{today: $today, week: $week, month: $month}'
  else
    # Text: Show all periods
    work_stats_today
    work_stats_week
    work_stats_month

    # Show current pomodoro count
    local current_count
    current_count=$(work_get_pomodoro_count)
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Current Session"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  🎯 Current pomodoro count: $current_count"
    echo ""

    if work_is_active; then
      echo "  ✅ Work session is ACTIVE"
      work_status
    else
      echo "  ⏸  No active work session"
    fi

    echo ""
  fi
}

# ═══════════════════════════════════════════════════════════════
# Work Enforcement System
# ═══════════════════════════════════════════════════════════════

# Enforcement state file
HARM_WORK_ENFORCEMENT_FILE="${HARM_WORK_ENFORCEMENT_FILE:-${HARM_WORK_DIR}/enforcement.json}"
readonly HARM_WORK_ENFORCEMENT_FILE

# Enforcement mode: strict, moderate, coaching, off
HARM_WORK_ENFORCEMENT="${HARM_WORK_ENFORCEMENT:-moderate}"
readonly HARM_WORK_ENFORCEMENT

# Distraction threshold (warnings before forcing goal review)
HARM_WORK_DISTRACTION_THRESHOLD="${HARM_WORK_DISTRACTION_THRESHOLD:-3}"
readonly HARM_WORK_DISTRACTION_THRESHOLD

# Enforcement state variables
declare -gi _WORK_VIOLATIONS=0
declare -g _WORK_ACTIVE_PROJECT=""
declare -g _WORK_ACTIVE_GOAL=""

# work_enforcement_load_state: Load enforcement state from disk
#
# Description:
#   Loads violation count and active project/goal from state file.
#
# Returns:
#   0 - State loaded
#   1 - No state file
work_enforcement_load_state() {
  [[ -f "$HARM_WORK_ENFORCEMENT_FILE" ]] || return 1

  local state
  state=$(cat "$HARM_WORK_ENFORCEMENT_FILE")

  _WORK_VIOLATIONS=$(echo "$state" | jq -r '.violations // 0')
  _WORK_ACTIVE_PROJECT=$(echo "$state" | jq -r '.project // ""')
  _WORK_ACTIVE_GOAL=$(echo "$state" | jq -r '.goal // ""')

  return 0
}

# work_enforcement_save_state: Save enforcement state to disk
#
# Description:
#   Persists violation count and active project/goal.
#
# Returns:
#   0 - State saved
work_enforcement_save_state() {
  jq -n \
    --argjson violations "$_WORK_VIOLATIONS" \
    --arg project "$_WORK_ACTIVE_PROJECT" \
    --arg goal "$_WORK_ACTIVE_GOAL" \
    --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      violations: $violations,
      project: $project,
      goal: $goal,
      updated: $updated
    }' | atomic_write "$HARM_WORK_ENFORCEMENT_FILE"
}

# work_enforcement_clear: Clear enforcement state
#
# Description:
#   Resets violations and clears active project/goal.
#
# Returns:
#   0 - Always succeeds
work_enforcement_clear() {
  _WORK_VIOLATIONS=0
  _WORK_ACTIVE_PROJECT=""
  _WORK_ACTIVE_GOAL=""
  rm -f "$HARM_WORK_ENFORCEMENT_FILE" 2>/dev/null || true
}

# work_check_project_switch: Hook for detecting project switches
#
# Description:
#   Chpwd hook that detects when user switches projects during
#   a work session in strict mode. Increments violation counter
#   and warns user.
#
# Arguments:
#   $1 - old_pwd (string): Previous directory
#   $2 - new_pwd (string): New directory
#
# Returns:
#   0 - Always succeeds
work_check_project_switch() {
  # Only enforce in strict mode
  [[ "$HARM_WORK_ENFORCEMENT" == "strict" ]] || return 0

  # Only enforce during active work session
  work_is_active || return 0

  local old_pwd="$1"
  local new_pwd="$2"

  # Get project names
  local old_project new_project
  old_project=$(basename "$old_pwd")
  new_project=$(basename "$new_pwd")

  # Skip if same project
  [[ "$old_project" == "$new_project" ]] && return 0

  # First time setting active project
  if [[ -z "$_WORK_ACTIVE_PROJECT" ]]; then
    _WORK_ACTIVE_PROJECT="$new_project"
    work_enforcement_save_state
    log_info "work" "Active project set" "project=$new_project"
    return 0
  fi

  # Project switch detected!
  if [[ "$new_project" != "$_WORK_ACTIVE_PROJECT" ]]; then
    _WORK_VIOLATIONS=$((_WORK_VIOLATIONS + 1))
    work_enforcement_save_state

    echo "" >&2
    echo "⚠️  CONTEXT SWITCH DETECTED!" >&2
    echo "   Active project: $_WORK_ACTIVE_PROJECT" >&2
    echo "   Switched to: $new_project" >&2
    echo "   Violations: $_WORK_VIOLATIONS" >&2

    # Warning threshold
    if [[ $_WORK_VIOLATIONS -ge $HARM_WORK_DISTRACTION_THRESHOLD ]]; then
      echo "" >&2
      echo "❌ TOO MANY DISTRACTIONS!" >&2
      echo "   Consider:" >&2
      echo "   1. Stop work: harm-cli work stop" >&2
      echo "   2. Review goal: harm-cli goal show" >&2
      echo "   3. Refocus on: $_WORK_ACTIVE_PROJECT" >&2
    fi
    echo "" >&2

    log_warn "work" "Project switch violation" "from=$_WORK_ACTIVE_PROJECT to=$new_project violations=$_WORK_VIOLATIONS"
  fi

  return 0
}

# work_get_violations: Get current violation count
#
# Description:
#   Returns the number of context switches/violations.
#
# Returns:
#   0 - Always succeeds
#
# Outputs:
#   stdout: Violation count (integer)
work_get_violations() {
  # Try to load from file if not in memory
  if [[ $_WORK_VIOLATIONS -eq 0 ]] && [[ -f "$HARM_WORK_ENFORCEMENT_FILE" ]]; then
    work_enforcement_load_state 2>/dev/null || true
  fi

  echo "$_WORK_VIOLATIONS"
}

# work_reset_violations: Reset violation counter
#
# Description:
#   Clears violation count (useful after refocusing).
#
# Returns:
#   0 - Always succeeds
work_reset_violations() {
  _WORK_VIOLATIONS=0
  work_enforcement_save_state
  log_info "work" "Violations reset"
  echo "✓ Violation counter reset"
}

# work_set_enforcement: Change enforcement mode
#
# Description:
#   Changes work enforcement level.
#
# Arguments:
#   $1 - mode (string): strict|moderate|coaching|off
#
# Returns:
#   0 - Mode set successfully
#   1 - Invalid mode
work_set_enforcement() {
  local mode="${1:?Enforcement mode required}"

  case "$mode" in
    strict | moderate | coaching | off)
      echo "HARM_WORK_ENFORCEMENT=$mode" >>"${HOME}/.harm-cli/config"
      log_info "work" "Enforcement mode changed" "mode=$mode"
      echo "✓ Enforcement mode set to: $mode"
      echo "  Restart shell for changes to take effect"
      ;;
    *)
      log_error "work" "Invalid enforcement mode: $mode"
      echo "Error: Invalid mode. Options: strict, moderate, coaching, off" >&2
      return 1
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════════
# Hook Registration
# ═══════════════════════════════════════════════════════════════

# Register enforcement hooks if in strict mode
if [[ "$HARM_WORK_ENFORCEMENT" == "strict" ]] && type harm_add_hook >/dev/null 2>&1; then
  # Load existing state
  work_enforcement_load_state 2>/dev/null || true

  # Register project switch detection
  harm_add_hook chpwd work_check_project_switch 2>/dev/null || true

  log_debug "work" "Work enforcement enabled" "mode=$HARM_WORK_ENFORCEMENT"
fi

# ═══════════════════════════════════════════════════════════════
# Exports
# ═══════════════════════════════════════════════════════════════

export -f work_is_active work_get_state work_save_state work_load_state
export -f work_start work_stop work_status
export -f work_require_active work_remind work_focus_score
export -f work_send_notification work_stop_timer
export -f work_get_pomodoro_count work_increment_pomodoro_count work_reset_pomodoro_count
export -f break_is_active break_start break_stop break_status
export -f work_stats work_stats_today work_stats_week work_stats_month
export -f work_enforcement_load_state work_enforcement_save_state work_enforcement_clear
export -f work_check_project_switch work_get_violations work_reset_violations work_set_enforcement
