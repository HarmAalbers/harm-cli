#!/usr/bin/env bash
# shellcheck shell=bash
# work_breaks.sh - Break session management for harm-cli
#
# Part of SOLID refactoring: Single Responsibility = Break sessions
#
# This module provides:
# - Break session lifecycle (start/stop/status)
# - Interactive countdown UI
# - Popup window support
# - Scheduled break daemon
#
# Dependencies:
# - lib/work_timers.sh (for notifications, work_get_pomodoro_count)
# - lib/work_session.sh (for work_is_active)
# - lib/work_enforcement.sh (for enforcement state)
# - lib/options.sh, lib/logging.sh, lib/util.sh, lib/common.sh, lib/error.sh

set -Eeuo pipefail
IFS=$'\n\t'

[[ -n "${_HARM_WORK_BREAKS_LOADED:-}" ]] && return 0

# Performance optimization: Reuse already-computed directory from parent module
if [[ -n "${WORK_SCRIPT_DIR:-}" ]]; then
  WORK_BREAKS_SCRIPT_DIR="$WORK_SCRIPT_DIR"
else
  WORK_BREAKS_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
fi
readonly WORK_BREAKS_SCRIPT_DIR

# shellcheck source=lib/common.sh
source "$WORK_BREAKS_SCRIPT_DIR/common.sh"
# shellcheck source=lib/error.sh
source "$WORK_BREAKS_SCRIPT_DIR/error.sh"
# shellcheck source=lib/logging.sh
source "$WORK_BREAKS_SCRIPT_DIR/logging.sh"
# shellcheck source=lib/util.sh
source "$WORK_BREAKS_SCRIPT_DIR/util.sh"
# shellcheck source=lib/options.sh
source "$WORK_BREAKS_SCRIPT_DIR/options.sh"
# shellcheck source=lib/work_timers.sh
source "$WORK_BREAKS_SCRIPT_DIR/work_timers.sh"
# shellcheck source=lib/work_session.sh
source "$WORK_BREAKS_SCRIPT_DIR/work_session.sh"
# shellcheck source=lib/work_enforcement.sh
source "$WORK_BREAKS_SCRIPT_DIR/work_enforcement.sh"

HARM_BREAK_STATE_FILE="${HARM_BREAK_STATE_FILE:-${HARM_WORK_DIR:-${HOME}/.harm-cli/work}/current_break.json}"
readonly HARM_BREAK_STATE_FILE
export HARM_BREAK_STATE_FILE

HARM_BREAK_TIMER_PID_FILE="${HARM_BREAK_TIMER_PID_FILE:-${HARM_WORK_DIR:-${HOME}/.harm-cli/work}/break_timer.pid}"
readonly HARM_BREAK_TIMER_PID_FILE
export HARM_BREAK_TIMER_PID_FILE

HARM_SCHEDULED_BREAK_PID_FILE="${HARM_SCHEDULED_BREAK_PID_FILE:-${HARM_WORK_DIR:-${HOME}/.harm-cli/work}/scheduled_break.pid}"
readonly HARM_SCHEDULED_BREAK_PID_FILE
export HARM_SCHEDULED_BREAK_PID_FILE

break_countdown_interactive() {
  local duration="${1:?break_countdown_interactive requires duration}"
  local break_type="${2:-break}"
  local start_time end_time elapsed remaining

  start_time=$(date +%s)
  end_time=$((start_time + duration))

  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║                    ☕ BREAK TIME ☕                         ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  echo "  Type: ${break_type^} break"
  echo "  Duration: $(format_duration "$duration")"
  echo ""
  echo "  💡 Tip: Step away from the screen, stretch, hydrate!"
  echo ""
  echo "─────────────────────────────────────────────────────────────"
  echo ""

  local bar_width=50
  local progress_full="████████████████████████████████████████████████████"
  local progress_empty="░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"

  SECONDS=0
  while true; do
    elapsed=$SECONDS
    remaining=$((duration - elapsed))

    if [[ $remaining -le 0 ]]; then
      remaining=0
      break
    fi

    local percent=$((elapsed * 100 / duration))
    local filled=$((percent * bar_width / 100))
    local empty=$((bar_width - filled))

    local bar="[${progress_full:0:filled}${progress_empty:0:empty}]"

    local min=$((remaining / 60))
    local sec=$((remaining % 60))
    local time_str
    time_str=$(printf "%02d:%02d" "$min" "$sec")

    printf "\033[4A\033[J  %s %d%%\n  Time remaining: ${SUCCESS_GREEN}%s${RESET}\n\n  Press Ctrl+C to stop break early\n" \
      "$bar" "$percent" "$time_str"

    sleep 1
  done

  printf "\033[4A\033[J  [%s] 100%%\n  Time remaining: ${SUCCESS_GREEN}00:00${RESET}\n\n\n" "$progress_full"
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║              ✅ BREAK COMPLETE! ✅                         ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  echo "  ${SUCCESS_GREEN}Great job!${RESET} You've recharged. Ready to work!"
  echo ""

  sleep 2

  return 0
}

break_is_active() {
  [[ -f "$HARM_BREAK_STATE_FILE" ]] \
    && json_get "$(cat "$HARM_BREAK_STATE_FILE")" ".status" | grep -q "active"
}

break_start() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || "${1:-}" == "help" ]]; then
    cat <<'EOF'
Start a break session

Usage:
  break_start [OPTIONS] [duration] [type]

Options:
  --blocking       Interactive countdown with live progress (default)
  --background     Background timer with notifications only
  -h, --help       Show this help

Arguments:
  duration         Break duration in seconds (default: auto-detect based on pomodoros)
  type             Break type: "short", "long", or "custom" (default: auto-detect)

Examples:
  break_start                      # Auto-detect break type, interactive countdown
  break_start --background         # Auto-detect, background mode
  break_start 300 short            # 5-minute short break, interactive
  break_start --background 900     # 15-minute break, background mode

Notes:
  - Interactive mode (--blocking) blocks the terminal and shows live countdown
  - Background mode runs timer in background with notifications
  - Default is --blocking when running in a terminal (TTY)
  - Auto-falls back to --background when no TTY available (e.g., scripts, CI)
EOF
    return 0
  fi

  local duration="" break_type="" blocking_mode="true"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --blocking)
        blocking_mode="true"
        shift
        ;;
      --background)
        blocking_mode="false"
        shift
        ;;
      *)
        if [[ -z "$duration" ]]; then
          duration="$1"
        elif [[ -z "$break_type" ]]; then
          break_type="$1"
        fi
        shift
        ;;
    esac
  done

  if break_is_active; then
    error_msg "Break session already active" "$EXIT_ERROR"
    return "$EXIT_ERROR"
  fi

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

  [[ -z "$break_type" ]] && break_type="custom"

  local start_time
  start_time="$(get_utc_timestamp)"

  jq -n \
    --arg status "active" \
    --arg start_time "$start_time" \
    --argjson duration "$duration" \
    --arg type "$break_type" \
    --arg mode "$blocking_mode" \
    '{
      status: $status,
      start_time: $start_time,
      duration_seconds: $duration,
      type: $type,
      blocking_mode: ($mode == "true")
    }' | atomic_write "$HARM_BREAK_STATE_FILE"

  log_info "break" "Break session started" "Type: $break_type, Duration: ${duration}s, Blocking: $blocking_mode"

  if [[ "$blocking_mode" == "true" ]] && [[ -t 0 ]] && [[ -t 1 ]] && [[ "${HARM_CLI_FORMAT:-text}" == "text" ]]; then
    local popup_mode
    popup_mode=$(options_get break_popup_mode)

    work_send_notification "☕ Break Started" "${break_type^} break - $((duration / 60)) minutes to recharge"

    if [[ "$popup_mode" == "1" ]]; then
      local skip_mode
      skip_mode=$(options_get break_skip_mode)

      log_info "break" "Launching break timer in popup window" "skip_mode=$skip_mode"

      if terminal_launch_script "$ROOT_DIR/libexec/break-timer-ui.sh" \
        --duration "$duration" \
        --type "$break_type" \
        --skip-mode "$skip_mode"; then

        if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
          jq -n \
            --arg start_time "$start_time" \
            --argjson duration "$duration" \
            --arg type "$break_type" \
            '{status: "started", start_time: $start_time, duration_seconds: $duration, type: $type, mode: "popup"}'
        else
          success_msg "Break timer opened in new window"
          echo "  Type: ${break_type^} break"
          echo "  Duration: $((duration / 60)) minutes"
          echo "  Skip mode: $skip_mode"
          echo ""
          echo "  💡 The break timer is running in a separate window"
          echo "  💡 Note: Break will auto-complete, but you need to manually run 'harm-cli break stop' after"
        fi

        return 0
      else
        warn_msg "Failed to open popup window, falling back to inline mode"
        log_warn "break" "Popup launch failed, using inline countdown"

        break_countdown_interactive "$duration" "$break_type"

        break_stop
        return $?
      fi
    else
      break_countdown_interactive "$duration" "$break_type"

      break_stop
      return $?
    fi
  fi

  (
    sleep "$duration"

    if [[ -f "$HARM_BREAK_STATE_FILE" ]]; then
      # Send completion notification
      if declare -F work_send_notification >/dev/null 2>&1; then
        work_send_notification "⏰ Break Complete!" "Time to get back to work!"
      fi

      # Log the expiry (lightweight - just logging, no complex operations)
      if declare -F log_info >/dev/null 2>&1; then
        log_info "break" "Break timer expired" "Duration: ${duration}s"
      fi

      # Mark the break as auto-completed by updating the state
      # This allows break_stop or the next command to detect it expired naturally
      if [[ -f "$HARM_BREAK_STATE_FILE" ]] && command -v jq >/dev/null 2>&1; then
        local temp_state
        temp_state=$(mktemp)
        jq '.auto_completed = true' "$HARM_BREAK_STATE_FILE" >"$temp_state" 2>/dev/null \
          && mv "$temp_state" "$HARM_BREAK_STATE_FILE" || rm -f "$temp_state"
      fi
    fi
  ) &

  echo $! >"$HARM_BREAK_TIMER_PID_FILE"

  local duration_min=$((duration / 60))
  work_send_notification "☕ Break Started" "${break_type^} break - ${duration_min} minutes to recharge"

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --arg start_time "$start_time" \
      --argjson duration "$duration" \
      --arg type "$break_type" \
      '{status: "started", start_time: $start_time, duration_seconds: $duration, type: $type, mode: "background"}'
  else
    success_msg "Break session started (background mode)"
    echo "  Type: ${break_type^} break"
    echo "  Duration: ${duration_min} minutes"
    echo "  Timer running in background (non-blocking)"
    echo ""
    echo "  💡 Tip: Use 'harm-cli break start' without --background for interactive mode"
  fi
}

break_stop() {
  if ! break_is_active; then
    error_msg "No active break session" "$EXIT_ERROR"
    return "$EXIT_ERROR"
  fi

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
  local start_time break_type duration_planned
  read -r start_time break_type duration_planned < <(
    jq -r '[.start_time, .type, .duration_seconds] | @tsv' "$HARM_BREAK_STATE_FILE"
  )

  local end_time
  end_time="$(get_utc_timestamp)"

  local start_epoch end_epoch
  start_epoch="$(iso8601_to_epoch "$start_time")"
  end_epoch="$(get_utc_epoch)"
  local total_seconds=$((end_epoch - start_epoch))

  local completed_fully="false"
  if ((total_seconds * 100 >= duration_planned * 80)); then
    completed_fully="true"
  fi

  local track_breaks
  track_breaks=$(options_get strict_track_breaks 2>/dev/null || echo "0")

  if [[ "$track_breaks" == "1" ]]; then
    local archive_file
    archive_file="${HARM_WORK_DIR}/breaks_$(date '+%Y-%m').jsonl"
    jq -n \
      --arg start_time "$start_time" \
      --arg end_time "$end_time" \
      --argjson duration "$total_seconds" \
      --argjson planned_duration "$duration_planned" \
      --arg type "$break_type" \
      --argjson completed_fully "$completed_fully" \
      '{
        start_time: $start_time,
        end_time: $end_time,
        duration_seconds: $duration,
        planned_duration_seconds: $planned_duration,
        type: $type,
        completed_fully: $completed_fully
      }' >>"$archive_file"

    log_debug "break" "Break archived" "Duration: ${total_seconds}s, Completed: $completed_fully"
  fi

  if [[ "$HARM_WORK_ENFORCEMENT" == "strict" ]] && [[ "$completed_fully" == "true" ]]; then
    local require_break
    require_break=$(options_get strict_require_break 2>/dev/null || echo "0")

    if [[ "$require_break" == "1" ]] && [[ -f "$HARM_WORK_ENFORCEMENT_FILE" ]]; then
      local current_state
      current_state=$(cat "$HARM_WORK_ENFORCEMENT_FILE" 2>/dev/null || echo '{}')
      echo "$current_state" | jq '.break_required = false | .break_type_required = null | .last_break_end = $time' \
        --arg time "$end_time" | atomic_write "$HARM_WORK_ENFORCEMENT_FILE"

      log_info "break" "Break requirement cleared" "Type: $break_type"
    fi
  fi

  rm -f "$HARM_BREAK_STATE_FILE"

  if [[ "$HARM_WORK_ENFORCEMENT" == "strict" ]] && [[ -f "$HARM_WORK_ENFORCEMENT_FILE" ]]; then
    local current_state
    current_state=$(cat "$HARM_WORK_ENFORCEMENT_FILE" 2>/dev/null || echo '{}')

    echo "$current_state" | jq '.break_required = false' | atomic_write "$HARM_WORK_ENFORCEMENT_FILE"

    log_info "break" "Break requirement cleared"
  fi

  log_info "break" "Break session stopped" "Duration: ${total_seconds}s, Type: $break_type, Completed: $completed_fully"

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

scheduled_break_start_daemon() {
  local enabled
  enabled=$(options_get break_scheduled_enabled)

  if [[ "$enabled" != "1" ]]; then
    log_debug "scheduled_break" "Scheduled breaks are disabled"
    return 1
  fi

  if [[ -f "$HARM_SCHEDULED_BREAK_PID_FILE" ]]; then
    local pid
    pid=$(cat "$HARM_SCHEDULED_BREAK_PID_FILE")

    if kill -0 "$pid" 2>/dev/null; then
      log_debug "scheduled_break" "Daemon already running" "PID=$pid"
      return 1
    else
      rm -f "$HARM_SCHEDULED_BREAK_PID_FILE"
    fi
  fi

  local interval_min
  interval_min=$(options_get break_scheduled_interval)
  local interval_sec=$((interval_min * 60))

  log_info "scheduled_break" "Starting scheduled break daemon" "interval=${interval_min}m"

  (
    while true; do
      sleep "$interval_sec"

      [[ ! -f "$HARM_SCHEDULED_BREAK_PID_FILE" ]] && break

      if ! work_is_active && ! break_is_active; then
        log_info "scheduled_break" "Triggering scheduled break"

        local break_type="short"
        local duration
        duration=$(options_get break_short)

        work_send_notification "⏰ Scheduled Break Time!" "It's been ${interval_min} minutes. Time for a break!"

        break_start --background "$duration" "$break_type" 2>/dev/null || true
      else
        log_debug "scheduled_break" "Skipping scheduled break (work/break active)"
      fi
    done
  ) &

  echo $! >"$HARM_SCHEDULED_BREAK_PID_FILE"

  log_info "scheduled_break" "Daemon started" "PID=$!, interval=${interval_min}m"
  return 0
}

scheduled_break_stop_daemon() {
  if [[ ! -f "$HARM_SCHEDULED_BREAK_PID_FILE" ]]; then
    log_debug "scheduled_break" "Daemon not running"
    return 1
  fi

  local pid
  pid=$(cat "$HARM_SCHEDULED_BREAK_PID_FILE")

  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    log_info "scheduled_break" "Daemon stopped" "PID=$pid"
  else
    log_debug "scheduled_break" "Daemon already stopped (stale PID)"
  fi

  rm -f "$HARM_SCHEDULED_BREAK_PID_FILE"
  return 0
}

scheduled_break_status() {
  local enabled
  enabled=$(options_get break_scheduled_enabled)

  if [[ "$enabled" != "1" ]]; then
    if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
      jq -n '{status: "disabled"}'
    else
      echo "Scheduled breaks: ${WARN_YELLOW}DISABLED${RESET}"
      echo "  Enable: harm-cli options set break_scheduled_enabled 1"
    fi
    return 0
  fi

  local running="false"
  local pid=""

  if [[ -f "$HARM_SCHEDULED_BREAK_PID_FILE" ]]; then
    pid=$(cat "$HARM_SCHEDULED_BREAK_PID_FILE")

    if kill -0 "$pid" 2>/dev/null; then
      running="true"
    fi
  fi

  local interval_min
  interval_min=$(options_get break_scheduled_interval)

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --arg status "$running" \
      --arg pid "$pid" \
      --argjson interval "$interval_min" \
      '{status: ($status == "true" | if . then "running" else "stopped" end), pid: $pid, interval_minutes: $interval}'
  else
    if [[ "$running" == "true" ]]; then
      echo "Scheduled breaks: ${SUCCESS_GREEN}RUNNING${RESET}"
      echo "  PID: $pid"
      echo "  Interval: ${interval_min} minutes"
    else
      echo "Scheduled breaks: ${ERROR_RED}STOPPED${RESET}"
      echo "  Interval: ${interval_min} minutes (when running)"
      echo "  Start: harm-cli work init (or restart shell)"
    fi
  fi
}

readonly _HARM_WORK_BREAKS_LOADED=1
export _HARM_WORK_BREAKS_LOADED
