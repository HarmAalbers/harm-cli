#!/usr/bin/env bash
# shellcheck shell=bash
# work_session.sh - Work session lifecycle management for harm-cli
#
# Part of SOLID refactoring: Single Responsibility = Session lifecycle
#
# This module provides:
# - Work session state management (save/load/check)
# - Session start/stop operations
# - Session status reporting
# - Focus score calculation
# - Session reminders
#
# Dependencies:
# - lib/work_timers.sh (for notifications, timers, pomodoro counter)
# - lib/work_enforcement.sh (for strict mode enforcement)
# - lib/options.sh, lib/logging.sh, lib/util.sh, lib/common.sh, lib/error.sh

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_WORK_SESSION_LOADED:-}" ]] && return 0

# Get script directory for sourcing dependencies
# Performance optimization: Reuse already-computed directory from parent module
if [[ -n "${WORK_SCRIPT_DIR:-}" ]]; then
  WORK_SESSION_SCRIPT_DIR="$WORK_SCRIPT_DIR"
else
  WORK_SESSION_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
fi
readonly WORK_SESSION_SCRIPT_DIR

# Source dependencies
# shellcheck source=lib/common.sh
source "$WORK_SESSION_SCRIPT_DIR/common.sh"
# shellcheck source=lib/error.sh
source "$WORK_SESSION_SCRIPT_DIR/error.sh"
# shellcheck source=lib/logging.sh
source "$WORK_SESSION_SCRIPT_DIR/logging.sh"
# shellcheck source=lib/util.sh
source "$WORK_SESSION_SCRIPT_DIR/util.sh"
# shellcheck source=lib/options.sh
source "$WORK_SESSION_SCRIPT_DIR/options.sh"
# shellcheck source=lib/work_timers.sh
source "$WORK_SESSION_SCRIPT_DIR/work_timers.sh"
# shellcheck source=lib/work_enforcement.sh
source "$WORK_SESSION_SCRIPT_DIR/work_enforcement.sh"

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════

HARM_WORK_DIR="${HARM_WORK_DIR:-${HOME}/.harm-cli/work}"
readonly HARM_WORK_DIR
export HARM_WORK_DIR

HARM_WORK_STATE_FILE="${HARM_WORK_STATE_FILE:-${HARM_WORK_DIR}/current_session.json}"
readonly HARM_WORK_STATE_FILE
export HARM_WORK_STATE_FILE

# ═══════════════════════════════════════════════════════════════
# Work Session State Management
# ═══════════════════════════════════════════════════════════════

work_is_active() {
  [[ -f "$HARM_WORK_STATE_FILE" ]] \
    && json_get "$(cat "$HARM_WORK_STATE_FILE")" ".status" | grep -q "^active$"
}

work_get_state() {
  if [[ ! -f "$HARM_WORK_STATE_FILE" ]]; then
    echo "inactive"
    return 0
  fi

  json_get "$(cat "$HARM_WORK_STATE_FILE")" ".status"
}

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

work_load_state() {
  if [[ ! -f "$HARM_WORK_STATE_FILE" ]]; then
    return 0
  fi

  # Validate JSON before returning
  if ! jq empty "$HARM_WORK_STATE_FILE" 2>/dev/null; then
    log_error "work" "Corrupted work session state file" "File: $HARM_WORK_STATE_FILE"
    return 0
  fi

  cat "$HARM_WORK_STATE_FILE"
}

# ═══════════════════════════════════════════════════════════════
# Work Session Commands
# ═══════════════════════════════════════════════════════════════

work_start() {
  local goal="${1:-}"

  if ! work_strict_enforce_break; then
    return "$EXIT_ERROR"
  fi

  if [[ -z "$goal" ]] && [[ -t 0 ]] && [[ -t 1 ]] && [[ "${HARM_CLI_FORMAT:-text}" == "text" ]]; then
    if [[ -f "$WORK_SESSION_SCRIPT_DIR/interactive.sh" ]]; then
      source "$WORK_SESSION_SCRIPT_DIR/interactive.sh"
    fi

    if declare -F interactive_choose >/dev/null 2>&1; then
      log_debug "work" "Starting interactive work session wizard"

      echo "🍅 Start Pomodoro Session"
      echo ""

      local -a goal_options=()

      if [[ -f "$WORK_SESSION_SCRIPT_DIR/goals.sh" ]]; then
        source "$WORK_SESSION_SCRIPT_DIR/goals.sh" 2>/dev/null || true
      fi

      if declare -F goal_exists_today >/dev/null 2>&1 && goal_exists_today 2>/dev/null; then
        local goal_file
        goal_file=$(goal_file_for_today 2>/dev/null)

        if [[ -f "$goal_file" ]]; then
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

      goal_options+=("Custom goal...")

      if goal=$(interactive_choose "What are you working on?" "${goal_options[@]}" 2>/dev/null); then
        if [[ "$goal" == "Custom goal..." ]]; then
          if ! goal=$(interactive_input "Enter goal description" 2>/dev/null); then
            error_msg "Goal input cancelled"
            return "$EXIT_ERROR"
          fi

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

  # Check if session is active, but clean up corrupted state first
  if [[ -f "$HARM_WORK_STATE_FILE" ]]; then
    if ! jq empty "$HARM_WORK_STATE_FILE" 2>/dev/null; then
      log_warn "work" "Removing corrupted work session state file" "File: $HARM_WORK_STATE_FILE"
      rm -f "$HARM_WORK_STATE_FILE"
    fi
  fi

  if work_is_active; then
    error_msg "Work session already active" "$EXIT_ERROR"
    return "$EXIT_ERROR"
  fi

  if [[ "$HARM_WORK_ENFORCEMENT" == "strict" ]]; then
    local block_switch
    block_switch=$(options_get strict_block_project_switch 2>/dev/null || echo "0")

    if [[ "$block_switch" == "1" ]] && [[ -n "${_WORK_ACTIVE_PROJECT:-}" ]]; then
      local current_project
      current_project=$(basename "$PWD")

      if [[ "$current_project" != "$_WORK_ACTIVE_PROJECT" ]]; then
        error_msg "Cannot start work session in different project" "$EXIT_ERROR"
        echo "" >&2
        echo "🚫 Project switch blocked by strict mode!" >&2
        echo "   Active project: $_WORK_ACTIVE_PROJECT" >&2
        echo "   Current location: $current_project" >&2
        echo "" >&2
        echo "   Options:" >&2
        echo "   1. Navigate to active project first" >&2
        echo "   2. Stop current session: harm-cli work stop" >&2
        echo "" >&2
        return "$EXIT_ERROR"
      fi
    fi

    local require_break
    require_break=$(options_get strict_require_break 2>/dev/null || echo "0")

    if [[ "$require_break" == "1" ]]; then
      work_enforcement_load_state 2>/dev/null || true

      if [[ -f "$HARM_WORK_ENFORCEMENT_FILE" ]]; then
        local break_required
        break_required=$(jq -r '.break_required // false' "$HARM_WORK_ENFORCEMENT_FILE" 2>/dev/null)

        if [[ "$break_required" == "true" ]]; then
          local required_break_type
          required_break_type=$(jq -r '.break_type_required // "short"' "$HARM_WORK_ENFORCEMENT_FILE" 2>/dev/null)

          error_msg "Break required before starting new work session" "$EXIT_ERROR"
          echo "" >&2
          echo "☕ Break required by strict mode!" >&2
          echo "   You must complete a ${required_break_type} break before starting a new session." >&2
          echo "" >&2
          echo "   Start break: harm-cli break start" >&2
          echo "" >&2
          return "$EXIT_ERROR"
        fi
      fi
    fi
  fi

  local start_time
  start_time="$(get_utc_timestamp)"

  local work_duration
  work_duration=$(options_get work_duration)

  work_save_state "active" "$start_time" "$goal" 0

  log_info "work" "Work session started" "Goal: ${goal:-none}, Duration: ${work_duration}s"

  # Skip background processes in test mode
  if [[ "${HARM_TEST_MODE:-0}" != "1" ]]; then
    (
      sleep "$work_duration"

      if [[ -f "$HARM_WORK_STATE_FILE" ]]; then
        work_send_notification "🍅 Work Session Complete" "Time for a break! You've completed a pomodoro."
        log_info "work" "Work timer expired" "Duration: ${work_duration}s"
      fi
    ) &

    echo $! >"$HARM_WORK_TIMER_PID_FILE"

    local reminder_interval
    reminder_interval=$(options_get work_reminder_interval)

    if ((reminder_interval > 0)); then
      local reminder_seconds=$((reminder_interval * 60))

      (
        while [[ -f "$HARM_WORK_STATE_FILE" ]]; do
          sleep "$reminder_seconds"

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

      echo $! >"$HARM_WORK_REMINDER_PID_FILE"
      log_debug "work" "Started reminder process" "Interval: ${reminder_interval}m"
    fi
  fi

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

work_stop() {
  if ! work_is_active; then
    error_msg "No active work session" "$EXIT_ERROR"
    return "$EXIT_ERROR"
  fi

  work_stop_timer

  local start_time goal paused_duration
  read -r start_time goal paused_duration < <(
    jq -r '[.start_time, .goal, (.paused_duration // 0)] | @tsv' "$HARM_WORK_STATE_FILE"
  )

  local end_time
  end_time="$(get_utc_timestamp)"

  local start_epoch end_epoch
  start_epoch="$(iso8601_to_epoch "$start_time")"
  end_epoch="$(get_utc_epoch)"
  local total_seconds=$((end_epoch - start_epoch - paused_duration))

  local work_duration termination_reason=""
  work_duration=$(options_get work_duration)
  local early_stop="false"

  if ((total_seconds * 100 < work_duration * 80)); then
    early_stop="true"

    local confirm_early
    confirm_early=$(options_get strict_confirm_early_stop 2>/dev/null || echo "0")

    if [[ "$confirm_early" == "1" ]] && [[ -t 0 ]] && [[ -t 1 ]]; then
      if [[ -f "$WORK_SESSION_SCRIPT_DIR/interactive.sh" ]]; then
        source "$WORK_SESSION_SCRIPT_DIR/interactive.sh" 2>/dev/null || true
      fi

      if declare -F interactive_confirm >/dev/null 2>&1; then
        local minutes_worked=$((total_seconds / 60))
        local minutes_expected=$((work_duration / 60))

        echo "" >&2
        echo "⚠️  Early termination detected!" >&2
        echo "   Expected: ${minutes_expected} minutes" >&2
        echo "   Actual: ${minutes_worked} minutes" >&2
        echo "" >&2

        if ! interactive_confirm "Do you want to stop this session early?" "no"; then
          echo "Session stop cancelled." >&2
          return 0
        fi

        if declare -F interactive_input >/dev/null 2>&1; then
          if termination_reason=$(interactive_input "Reason for early stop (optional)" 2>/dev/null); then
            log_info "work" "Early stop reason" "Reason: ${termination_reason:-none}"
          fi
        fi
      fi
    fi
  fi

  local pomodoro_count
  pomodoro_count=$(work_increment_pomodoro_count)

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

  local archive_file
  archive_file="${HARM_WORK_DIR}/sessions_$(date '+%Y-%m').jsonl"
  jq -n \
    --arg start_time "$start_time" \
    --arg end_time "$end_time" \
    --argjson duration "$total_seconds" \
    --arg goal "$goal" \
    --argjson pomodoro_count "$pomodoro_count" \
    --argjson early_stop "$early_stop" \
    --arg termination_reason "$termination_reason" \
    '{
      start_time: $start_time,
      end_time: $end_time,
      duration_seconds: $duration,
      goal: $goal,
      pomodoro_count: $pomodoro_count,
      early_stop: ($early_stop == "true"),
      termination_reason: (if $termination_reason != "" then $termination_reason else null end)
    }' >>"$archive_file"

  rm -f "$HARM_WORK_STATE_FILE"

  if [[ "$HARM_WORK_ENFORCEMENT" == "strict" ]]; then
    local require_break
    require_break=$(options_get strict_require_break 2>/dev/null || echo "0")

    if [[ "$require_break" == "1" ]]; then
      jq -n \
        --argjson violations "${_WORK_VIOLATIONS:-0}" \
        --arg project "${_WORK_ACTIVE_PROJECT:-}" \
        --arg goal "" \
        --arg updated "$end_time" \
        --arg last_session_end "$end_time" \
        --argjson break_required true \
        --arg break_type_required "$break_type" \
        '{
          violations: $violations,
          project: $project,
          goal: $goal,
          updated: $updated,
          last_session_end: $last_session_end,
          break_required: $break_required,
          break_type_required: $break_type_required
        }' | atomic_write "$HARM_WORK_ENFORCEMENT_FILE"

      log_info "work" "Break requirement set" "Type: $break_type"
    else
      work_enforcement_clear 2>/dev/null || true
    fi
  else
    work_enforcement_clear 2>/dev/null || true
  fi

  log_info "work" "Work session stopped" "Duration: ${total_seconds}s, Pomodoro: #${pomodoro_count}, Early: $early_stop"

  work_send_notification "✅ Work Complete!" "Pomodoro #${pomodoro_count} done. Take a ${break_min}-minute ${break_type} break!"

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
      break_start --background "$break_duration" "$break_type"
    else
      echo "  💡 Suggested: Take a ${break_min}-minute ${break_type} break!"
      echo "  Run: harm-cli break start (interactive blocking mode)"
    fi
  fi
}

work_status() {
  if ! work_is_active; then
    if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
      jq -n '{status: "inactive"}'
    else
      echo "No active work session"
    fi
    return 0
  fi

  local start_time goal
  read -r start_time goal < <(
    jq -r '[.start_time, .goal] | @tsv' "$HARM_WORK_STATE_FILE"
  )

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

work_require_active() {
  if work_is_active; then
    return 0
  else
    work_remind
    return 1
  fi
}

work_remind() {
  echo "" >&2
  echo "💡 Tip: No active work session" >&2
  echo "   Start tracking: harm-cli work start \"task description\"" >&2
  echo "" >&2
  return 0
}

work_focus_score() {
  if ! work_is_active; then
    echo "0"
    return 1
  fi

  local start_time paused
  read -r start_time paused < <(
    jq -r '[.start_time, (.paused_duration // 0)] | @tsv' "$HARM_WORK_STATE_FILE"
  )

  local now
  now=$(get_epoch_seconds)
  local start_epoch
  start_epoch=$(parse_iso8601_to_epoch "$start_time")
  local elapsed=$((now - start_epoch - paused))

  local minutes=$((elapsed / 60))

  local score
  if [[ $minutes -lt 15 ]]; then
    score=$((minutes * 2))
  elif [[ $minutes -lt 60 ]]; then
    score=$((30 + (minutes - 15)))
  else
    local bonus=$(((minutes - 60) / 6))
    score=$((70 + bonus))
    [[ $score -gt 100 ]] && score=100
  fi

  echo "$score"
  return 0
}

# ═══════════════════════════════════════════════════════════════
# Module Initialization
# ═══════════════════════════════════════════════════════════════

readonly _HARM_WORK_SESSION_LOADED=1
export _HARM_WORK_SESSION_LOADED
