#!/usr/bin/env bash
# shellcheck shell=bash
# focus.sh - Focus monitoring and periodic productivity checks
# Provides pomodoro timers, break reminders, and AI-powered focus scoring
#
# This module provides:
# - Periodic focus checks (every N minutes)
# - Focus scoring based on activity patterns
# - Break reminders
# - Pomodoro timer integration
# - AI-powered focus assessments

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_FOCUS_LOADED:-}" ]] && return 0

# Source dependencies
FOCUS_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly FOCUS_SCRIPT_DIR

# shellcheck source=lib/common.sh
source "$FOCUS_SCRIPT_DIR/common.sh"
# shellcheck source=lib/logging.sh
source "$FOCUS_SCRIPT_DIR/logging.sh"
# shellcheck source=lib/work.sh
source "$FOCUS_SCRIPT_DIR/work.sh"
# shellcheck source=lib/activity.sh
source "$FOCUS_SCRIPT_DIR/activity.sh"
# shellcheck source=lib/ai.sh
source "$FOCUS_SCRIPT_DIR/ai.sh" 2>/dev/null || true

# Mark as loaded
readonly _HARM_FOCUS_LOADED=1

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════

# Focus check interval (seconds)
HARM_FOCUS_CHECK_INTERVAL="${HARM_FOCUS_CHECK_INTERVAL:-900}" # 15 minutes
readonly HARM_FOCUS_CHECK_INTERVAL

# Pomodoro duration (minutes)
HARM_POMODORO_DURATION="${HARM_POMODORO_DURATION:-25}"
readonly HARM_POMODORO_DURATION

# Break duration (minutes)
HARM_BREAK_DURATION="${HARM_BREAK_DURATION:-5}"
readonly HARM_BREAK_DURATION

# Enable/disable focus monitoring
HARM_FOCUS_ENABLED="${HARM_FOCUS_ENABLED:-1}"
readonly HARM_FOCUS_ENABLED

# ═══════════════════════════════════════════════════════════════
# State Management
# ═══════════════════════════════════════════════════════════════

# Track last focus check time
declare -g _FOCUS_LAST_CHECK=0

# Track context switches
declare -g _FOCUS_LAST_PWD="$PWD"
declare -gi _FOCUS_CONTEXT_SWITCHES=0

# Pomodoro state file
HARM_POMODORO_STATE="${HARM_CLI_HOME:-$HOME/.harm-cli}/pomodoro.state"
readonly HARM_POMODORO_STATE

# ═══════════════════════════════════════════════════════════════
# Focus Scoring
# ═══════════════════════════════════════════════════════════════

# focus_calculate_score: Calculate focus score (1-10)
#
# Description:
#   Calculates focus score based on:
#   - Work session duration
#   - Violation count
#   - Command patterns
#   - Error rate
#
# Returns:
#   0 - Always succeeds
#
# Outputs:
#   stdout: Focus score (1-10)
focus_calculate_score() {
  log_debug "focus" "Calculating focus score"

  local score=5 # Start neutral

  # Check if work session active
  if work_is_active; then
    score=$((score + 2)) # Active session = +2
  else
    log_debug "focus" "No active work session, returning neutral score" "Score: $score"
    echo "$score"
    return 0
  fi

  # Get violations
  local violations
  violations=$(work_get_violations 2>/dev/null || echo "0")

  # Penalty for violations
  if [[ $violations -eq 0 ]]; then
    score=$((score + 2)) # No violations = +2
  elif [[ $violations -lt 3 ]]; then
    score=$((score - 1)) # Few violations = -1
  else
    score=$((score - 3)) # Many violations = -3
  fi

  # Check recent activity (last 15 minutes)
  local recent_commands
  recent_commands=$(activity_query today 2>/dev/null | tail -20 | wc -l | tr -d ' ')

  if [[ $recent_commands -gt 10 ]]; then
    score=$((score + 1)) # Active = +1
  fi

  # Bounds check
  [[ $score -lt 1 ]] && score=1
  [[ $score -gt 10 ]] && score=10

  log_debug "focus" "Focus score calculated" "Score: $score, Violations: $violations"
  echo "$score"
}

# ═══════════════════════════════════════════════════════════════
# Focus Checks
# ═══════════════════════════════════════════════════════════════

# focus_check: Perform focus check and show summary
#
# Description:
#   Shows focus summary with:
#   - Current goal
#   - Recent activity
#   - Focus score
#   - Violations
#   - Recommendations
#
# Returns:
#   0 - Always succeeds
focus_check() {
  log_info "focus" "Running focus check"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🎯 Focus Check"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Check if work session active
  if ! work_is_active; then
    log_warn "focus" "Focus check requested but no active work session"
    echo "⚠️  No active work session"
    echo "   Start one with: harm-cli work start"
    echo ""
    return 0
  fi

  # Get current goal
  local state
  state=$(work_load_state 2>/dev/null) || state="{}"
  local goal
  goal=$(echo "$state" | jq -r '.goal // "No goal set"')

  echo "🎯 Current Goal:"
  echo "   $goal"
  echo ""

  # Get recent activity
  local recent_commands
  recent_commands=$(activity_query today 2>/dev/null | tail -10 | jq -r '.command' 2>/dev/null || echo "")

  if [[ -n "$recent_commands" ]]; then
    echo "📋 Recent Activity (last 10 commands):"
    # shellcheck disable=SC2001
    echo "$recent_commands" | sed 's/^/   • /'
    echo ""
  fi

  # Calculate focus score
  local score
  score=$(focus_calculate_score)

  echo "⭐ Focus Score: $score/10"

  # Show violations if any
  local violations
  violations=$(work_get_violations 2>/dev/null || echo "0")

  if [[ $violations -gt 0 ]]; then
    echo "⚠️  Violations: $violations context switches"
  else
    echo "✅ No distractions detected"
  fi

  echo ""

  # Recommendations
  echo "💡 Recommendations:"
  if [[ $score -ge 8 ]]; then
    echo "   ✅ Excellent focus - keep going!"
  elif [[ $score -ge 6 ]]; then
    echo "   👍 Good focus - stay on track"
  elif [[ $score -ge 4 ]]; then
    echo "   ⚠️  Some distractions - refocus on your goal"
  else
    echo "   ❌ Low focus - consider:"
    echo "      1. Review your goal: harm-cli goal show"
    echo "      2. Take a break: 5 minutes"
    echo "      3. Restart: harm-cli work stop && harm-cli work start"
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

# focus_periodic_check: Hook for periodic focus checks
#
# Description:
#   Precmd hook that triggers focus check every N minutes.
#   Only runs during active work sessions.
#
# Arguments:
#   $1 - exit_code (integer): Last command exit code
#   $2 - last_cmd (string): Last command executed
#
# Returns:
#   0 - Always succeeds
focus_periodic_check() {
  # Skip if focus monitoring disabled
  [[ $HARM_FOCUS_ENABLED -eq 1 ]] || return 0

  # Skip if no work session
  work_is_active || return 0

  local now
  now=$(date +%s)
  local elapsed=$((now - _FOCUS_LAST_CHECK))

  # Check if it's time for a focus check
  if [[ $elapsed -ge $HARM_FOCUS_CHECK_INTERVAL ]]; then
    _FOCUS_LAST_CHECK=$now

    log_info "focus" "Periodic focus check triggered" "Elapsed: ${elapsed}s"
    # Show focus check (async to avoid blocking prompt)
    (focus_check &)
  fi

  return 0
}

# ═══════════════════════════════════════════════════════════════
# Pomodoro Timer
# ═══════════════════════════════════════════════════════════════

# pomodoro_start: Start a pomodoro session
#
# Description:
#   Starts a pomodoro timer for focused work.
#
# Arguments:
#   $1 - duration (integer, optional): Duration in minutes (default: 25)
#
# Returns:
#   0 - Timer started
#   1 - Already running
pomodoro_start() {
  local duration="${1:-$HARM_POMODORO_DURATION}"
  log_info "focus" "Pomodoro start requested" "Duration: ${duration}m"

  if [[ -f "$HARM_POMODORO_STATE" ]]; then
    log_warn "focus" "Pomodoro already running, cannot start new session"
    echo "⏱️  Pomodoro already running"
    echo "   Stop with: harm-cli focus pomodoro-stop"
    return 1
  fi

  local start_time
  start_time=$(date +%s)

  # Save state to file
  echo "$start_time" >"$HARM_POMODORO_STATE"

  log_info "focus" "Pomodoro session started" "Duration: ${duration}m, Start: $start_time"
  echo "🍅 Pomodoro started: ${duration} minutes"
  echo "   Focus time! Will alert you when done."
  echo ""

  # Schedule notification (background)
  (
    sleep $((duration * 60))
    if [[ -f "$HARM_POMODORO_STATE" ]]; then
      log_info "focus" "Pomodoro completed" "Duration: ${duration}m"
      echo "" >&2
      echo "🔔 Pomodoro Complete!" >&2
      echo "   Time for a ${HARM_BREAK_DURATION}-minute break" >&2
      echo "" >&2
      rm -f "$HARM_POMODORO_STATE"
    fi
  ) &

  return 0
}

# pomodoro_stop: Stop pomodoro timer
#
# Description:
#   Stops the current pomodoro session.
#
# Returns:
#   0 - Timer stopped
pomodoro_stop() {
  log_debug "focus" "Pomodoro stop requested"

  if [[ ! -f "$HARM_POMODORO_STATE" ]]; then
    log_debug "focus" "No active pomodoro to stop"
    echo "No active pomodoro"
    return 0
  fi

  local start_time elapsed
  start_time=$(cat "$HARM_POMODORO_STATE")
  elapsed=$((($(date +%s) - start_time) / 60))

  rm -f "$HARM_POMODORO_STATE"

  log_info "focus" "Pomodoro stopped" "Elapsed: ${elapsed}m"
  echo "🍅 Pomodoro stopped after ${elapsed} minutes"
  return 0
}

# pomodoro_status: Show pomodoro status
#
# Description:
#   Shows current pomodoro timer status.
#
# Returns:
#   0 - Always succeeds
pomodoro_status() {
  if [[ ! -f "$HARM_POMODORO_STATE" ]]; then
    echo "⏱️  No active pomodoro"
    echo "   Start one with: harm-cli focus pomodoro ${HARM_POMODORO_DURATION}"
    return 0
  fi

  local start_time elapsed remaining
  start_time=$(cat "$HARM_POMODORO_STATE")
  elapsed=$((($(date +%s) - start_time) / 60))
  remaining=$((HARM_POMODORO_DURATION - elapsed))

  echo "🍅 Pomodoro Active"
  echo "   Started: $elapsed minutes ago"
  echo "   Remaining: ~${remaining} minutes"
}

# ═══════════════════════════════════════════════════════════════
# Context Switch Tracking
# ═══════════════════════════════════════════════════════════════

# focus_track_context_switch: Track directory changes
#
# Description:
#   Chpwd hook that counts context switches for focus scoring.
#
# Arguments:
#   $1 - old_pwd (string): Previous directory
#   $2 - new_pwd (string): New directory
#
# Returns:
#   0 - Always succeeds
focus_track_context_switch() {
  # Only track during work sessions
  work_is_active || return 0

  local old_pwd="$1"
  local new_pwd="$2"

  # Skip if same directory
  [[ "$old_pwd" == "$new_pwd" ]] && return 0

  _FOCUS_CONTEXT_SWITCHES=$((_FOCUS_CONTEXT_SWITCHES + 1))
  log_debug "focus" "Context switch detected" "count=$_FOCUS_CONTEXT_SWITCHES"

  return 0
}

# ═══════════════════════════════════════════════════════════════
# Hook Registration
# ═══════════════════════════════════════════════════════════════

# Register focus monitoring hooks if enabled
if [[ $HARM_FOCUS_ENABLED -eq 1 ]] && type harm_add_hook >/dev/null 2>&1; then
  # Register periodic check
  harm_add_hook precmd focus_periodic_check 2>/dev/null || true

  # Register context switch tracking
  harm_add_hook chpwd focus_track_context_switch 2>/dev/null || true

  log_debug "focus" "Focus monitoring enabled" "interval=${HARM_FOCUS_CHECK_INTERVAL}s"
fi

# ═══════════════════════════════════════════════════════════════
# Exports
# ═══════════════════════════════════════════════════════════════

export -f focus_calculate_score focus_check focus_periodic_check
export -f pomodoro_start pomodoro_stop pomodoro_status
export -f focus_track_context_switch
