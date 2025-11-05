#!/usr/bin/env bash
# spec/helpers/timer_mocks.sh - Background timer mocking
#
# Provides:
# - Mock background timer creation (no actual sleep)
# - Timer completion triggering (for testing)
# - Timer state inspection
#
# Usage:
#   source spec/helpers/timer_mocks.sh
#   pid=$(mock_pomodoro_timer 25)
#   mock_trigger_timer "$pid"
#   mock_timer_is_active "$pid"

# Prevent multiple loading
[[ -n "${_TIMER_MOCKS_LOADED:-}" ]] && return 0

# Ensure dependencies are loaded
if [[ -z "${_MOCKS_LOADED:-}" ]]; then
  HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=spec/helpers/mocks.sh
  source "${HELPER_DIR}/mocks.sh"
fi

if [[ -z "${_TIME_MOCKS_LOADED:-}" ]]; then
  HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=spec/helpers/time_mocks.sh
  source "${HELPER_DIR}/time_mocks.sh"
fi

# Timer state directory
MOCK_TIMERS_DIR="${MOCK_STATE_DIR}/timers"
mkdir -p "$MOCK_TIMERS_DIR"

# Timer operations log
MOCK_TIMERS_LOG="${MOCK_STATE_DIR}/timers.log"
: >"$MOCK_TIMERS_LOG"

# mock_pomodoro_timer: Create mock pomodoro background timer
#
# Description:
#   Simulates the background timer process without actually sleeping.
#   Records timer metadata for later triggering/inspection.
#
# Arguments:
#   $1 - duration_minutes (optional): Duration in minutes (default: 25)
#
# Outputs:
#   Mock PID for the timer process
#
# Examples:
#   pid=$(mock_pomodoro_timer 25)
#   pid=$(mock_pomodoro_timer)  # Default 25 minutes
mock_pomodoro_timer() {
  local duration_minutes="${1:-25}"
  local duration_seconds=$((duration_minutes * 60))

  # Generate mock PID
  local mock_pid=$((10000 + RANDOM % 10000))

  # Get current mock time
  local start_time
  start_time=$(mock_time_get)
  local end_time=$((start_time + duration_seconds))

  # Create timer state file with jq if available, otherwise plain text
  local timer_file="${MOCK_TIMERS_DIR}/${mock_pid}.timer"
  if command -v jq >/dev/null 2>&1; then
    cat >"$timer_file" <<EOF
{
  "pid": $mock_pid,
  "duration_minutes": $duration_minutes,
  "duration_seconds": $duration_seconds,
  "start_time": $start_time,
  "end_time": $end_time,
  "type": "pomodoro"
}
EOF
  else
    # Fallback: plain key=value format
    cat >"$timer_file" <<EOF
pid=$mock_pid
duration_minutes=$duration_minutes
duration_seconds=$duration_seconds
start_time=$start_time
end_time=$end_time
type=pomodoro
EOF
  fi

  mock_record_call "mock_pomodoro_timer" "$duration_minutes"
  echo "$(command date +%s)|timer_start|pomodoro|${duration_seconds}|${mock_pid}" >>"$MOCK_TIMERS_LOG"

  echo "$mock_pid"
}

# mock_trigger_timer: Trigger timer completion
#
# Description:
#   Manually triggers timer completion (for testing).
#   Advances time to end_time and executes completion actions.
#
# Arguments:
#   $1 - mock_pid: PID of the timer to trigger
#
# Returns:
#   0 - Timer triggered successfully
#   1 - Timer not found
#
# Examples:
#   mock_trigger_timer "$pid"
mock_trigger_timer() {
  local mock_pid="${1:?mock_trigger_timer requires PID}"
  local timer_file="${MOCK_TIMERS_DIR}/${mock_pid}.timer"

  if [[ ! -f "$timer_file" ]]; then
    echo "ERROR: Timer $mock_pid not found" >&2
    return 1
  fi

  mock_record_call "mock_trigger_timer" "$mock_pid"

  # Read timer details
  local end_time
  if command -v jq >/dev/null 2>&1; then
    end_time=$(jq -r '.end_time' "$timer_file")
  else
    end_time=$(grep "^end_time=" "$timer_file" | cut -d'=' -f2)
  fi

  # Advance mock time to end
  mock_time_set "$end_time"

  # Log completion
  echo "$(command date +%s)|timer_complete|${mock_pid}" >>"$MOCK_TIMERS_LOG"

  # Clean up timer file (timer is done)
  rm -f "$timer_file"

  return 0
}

# mock_timer_is_active: Check if timer is active
#
# Arguments:
#   $1 - mock_pid: PID of the timer to check
#
# Returns:
#   0 - Timer is active
#   1 - Timer is not active
#
# Examples:
#   if mock_timer_is_active "$pid"; then
#     echo "Timer still running"
#   fi
mock_timer_is_active() {
  local mock_pid="${1:?mock_timer_is_active requires PID}"
  [[ -f "${MOCK_TIMERS_DIR}/${mock_pid}.timer" ]]
}

# mock_timer_get_remaining: Get remaining time for timer
#
# Arguments:
#   $1 - mock_pid: PID of the timer
#
# Outputs:
#   Remaining seconds (or 0 if timer not found)
#
# Examples:
#   remaining=$(mock_timer_get_remaining "$pid")
#   echo "$remaining seconds left"
mock_timer_get_remaining() {
  local mock_pid="${1:?mock_timer_get_remaining requires PID}"
  local timer_file="${MOCK_TIMERS_DIR}/${mock_pid}.timer"

  if [[ ! -f "$timer_file" ]]; then
    echo "0"
    return 0
  fi

  # Read end time
  local end_time
  if command -v jq >/dev/null 2>&1; then
    end_time=$(jq -r '.end_time' "$timer_file")
  else
    end_time=$(grep "^end_time=" "$timer_file" | cut -d'=' -f2)
  fi

  # Calculate remaining
  local current_time
  current_time=$(mock_time_get)
  local remaining=$((end_time - current_time))

  # Clamp to 0 if negative
  if [[ $remaining -lt 0 ]]; then
    remaining=0
  fi

  echo "$remaining"
}

# mock_timer_stop: Stop a timer
#
# Description:
#   Stops a timer before completion.
#
# Arguments:
#   $1 - mock_pid: PID of the timer to stop
#
# Returns:
#   0 - Timer stopped
#   1 - Timer not found
#
# Examples:
#   mock_timer_stop "$pid"
mock_timer_stop() {
  local mock_pid="${1:?mock_timer_stop requires PID}"
  local timer_file="${MOCK_TIMERS_DIR}/${mock_pid}.timer"

  if [[ ! -f "$timer_file" ]]; then
    return 1
  fi

  mock_record_call "mock_timer_stop" "$mock_pid"
  echo "$(command date +%s)|timer_stop|${mock_pid}" >>"$MOCK_TIMERS_LOG"

  rm -f "$timer_file"
  return 0
}

# mock_timer_stop_all: Stop all active timers
#
# Description:
#   Cleanup function to stop all timers.
#
# Examples:
#   mock_timer_stop_all
mock_timer_stop_all() {
  rm -f "${MOCK_TIMERS_DIR}"/*.timer 2>/dev/null || true
  echo "$(command date +%s)|timer_stop_all|all" >>"$MOCK_TIMERS_LOG"
}

# mock_timer_count: Count active timers
#
# Outputs:
#   Number of active timers
#
# Examples:
#   count=$(mock_timer_count)
#   echo "$count timers active"
mock_timer_count() {
  # shellcheck disable=SC2012
  ls -1 "${MOCK_TIMERS_DIR}"/*.timer 2>/dev/null | wc -l | tr -d ' '
}

# mock_timer_get_all_pids: Get all active timer PIDs
#
# Outputs:
#   List of active timer PIDs (one per line)
#
# Examples:
#   pids=$(mock_timer_get_all_pids)
#   for pid in $pids; do
#     echo "Timer $pid is active"
#   done
mock_timer_get_all_pids() {
  for timer_file in "${MOCK_TIMERS_DIR}"/*.timer; do
    if [[ -f "$timer_file" ]]; then
      local basename
      basename=$(basename "$timer_file")
      echo "${basename%.timer}"
    fi
  done
}

# mock_timer_dump: Dump timer log (for debugging)
#
# Outputs:
#   All timer operations
mock_timer_dump() {
  if [[ -f "$MOCK_TIMERS_LOG" ]]; then
    cat "$MOCK_TIMERS_LOG"
  else
    echo "No timer operations recorded"
  fi
}

# Export mock functions
export -f mock_pomodoro_timer
export -f mock_trigger_timer
export -f mock_timer_is_active
export -f mock_timer_get_remaining
export -f mock_timer_stop
export -f mock_timer_stop_all
export -f mock_timer_count
export -f mock_timer_get_all_pids
export -f mock_timer_dump

# Export state
export MOCK_TIMERS_DIR
export MOCK_TIMERS_LOG

# Mark as loaded
readonly _TIMER_MOCKS_LOADED=1
export _TIMER_MOCKS_LOADED
