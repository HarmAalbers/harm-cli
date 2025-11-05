#!/usr/bin/env bash
# spec/helpers/process_mocks.sh - Process management mocking
#
# Provides:
# - Mock kill command (safe process termination)
# - Mock pkill command (pattern-based kill)
# - Mock ps command (process inspection)
# - Mock background process creation
#
# Usage:
#   source spec/helpers/process_mocks.sh
#   mock_kill -0 1234      # Check if PID exists
#   mock_kill 1234         # Kill mock process
#   mock_pkill -f pattern  # Pattern-based kill

# Prevent multiple loading
[[ -n "${_PROCESS_MOCKS_LOADED:-}" ]] && return 0

# Ensure core mocks are loaded
if [[ -z "${_MOCKS_LOADED:-}" ]]; then
  HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=spec/helpers/mocks.sh
  source "${HELPER_DIR}/mocks.sh"
fi

# Process state directory
MOCK_PIDS_DIR="${MOCK_STATE_DIR}/pids"
mkdir -p "$MOCK_PIDS_DIR"

# Process operations log
MOCK_PROCESS_LOG="${MOCK_STATE_DIR}/processes.log"
: >"$MOCK_PROCESS_LOG"

# mock_kill: Mock version of kill command
#
# Description:
#   Safely kills mock processes without touching real processes.
#   Supports -0 flag for checking if process exists.
#
# Arguments:
#   -0 pid - Check if process exists (always returns 0 for mock PIDs)
#   pid    - Kill the mock process
#
# Returns:
#   0 - Success (process exists/killed)
#   1 - Failure (process doesn't exist)
#
# Examples:
#   mock_kill -0 1234    # Check if exists
#   mock_kill 1234       # Kill process
mock_kill() {
  mock_record_call "kill" "$@"

  local signal=""
  local pid=""

  # Parse arguments
  if [[ "${1:-}" == "-0" ]]; then
    signal="-0"
    pid="${2:-}"
  elif [[ "${1:-}" == "-"* ]]; then
    signal="$1"
    pid="${2:-}"
  else
    pid="${1:-}"
  fi

  # Validate PID
  if [[ -z "$pid" ]]; then
    echo "mock_kill: missing PID" >&2
    return 1
  fi

  # Check if mock PID exists
  local pid_file="${MOCK_PIDS_DIR}/${pid}.pid"

  if [[ -f "$pid_file" ]]; then
    if [[ "$signal" == "-0" ]]; then
      # Check if alive (always true for mock PIDs)
      return 0
    else
      # Kill the mock process
      rm -f "$pid_file"
      echo "$(command date +%s)|kill|${signal}|${pid}" >>"$MOCK_PROCESS_LOG"
      return 0
    fi
  else
    # PID doesn't exist
    return 1
  fi
}

# mock_pkill: Mock version of pkill command
#
# Description:
#   Pattern-based process killing (logged but doesn't actually kill).
#   Always succeeds to prevent test failures.
#
# Arguments:
#   Same as pkill command
#
# Examples:
#   mock_pkill -f "sleep.*pomodoro"
mock_pkill() {
  mock_record_call "pkill" "$@"

  # Log the pkill operation
  echo "$(command date +%s)|pkill|$*" >>"$MOCK_PROCESS_LOG"

  # Find and kill all matching mock processes
  local pattern="${*: -1}" # Last argument is typically the pattern
  for pid_file in "$MOCK_PIDS_DIR"/*.pid; do
    if [[ -f "$pid_file" ]]; then
      local pid_name
      pid_name=$(cat "$pid_file" 2>/dev/null || echo "")
      # Simple pattern match (not a perfect pkill replica, but good enough)
      if [[ "$pid_name" == *"$pattern"* ]] || [[ "$pattern" == *"$pid_name"* ]]; then
        rm -f "$pid_file"
        echo "$(command date +%s)|pkill|killed|$pid_name" >>"$MOCK_PROCESS_LOG"
      fi
    fi
  done

  # Always succeed
  return 0
}

# mock_ps: Mock version of ps command
#
# Description:
#   Mocks process inspection.
#   Handles specific patterns used in harm-cli.
#
# Arguments:
#   Same as ps command
#
# Examples:
#   mock_ps -o comm= -p $PPID
mock_ps() {
  mock_record_call "ps" "$@"

  # Handle specific ps patterns
  if [[ "$*" == *"-o comm="* ]]; then
    # For terminal_is_remote check: ps -o comm= -p $PPID
    # Return "bash" to indicate not remote (not "sshd")
    echo "bash"
    return 0
  fi

  # Default: return empty (no processes)
  return 0
}

# mock_background_process: Create a mock background process
#
# Description:
#   Simulates a background process by creating a PID file.
#   Returns a mock PID for testing.
#
# Arguments:
#   $1 - name: Process name/description
#   $2 - pid (optional): Specific PID to use (defaults to random)
#
# Outputs:
#   The mock PID
#
# Examples:
#   pid=$(mock_background_process "pomodoro_timer")
#   echo "Started process $pid"
mock_background_process() {
  local name="${1:?mock_background_process requires name}"
  local pid="${2:-$((10000 + RANDOM % 10000))}"

  local pid_file="${MOCK_PIDS_DIR}/${pid}.pid"
  echo "$name" >"$pid_file"

  echo "$(command date +%s)|spawn|$name|$pid" >>"$MOCK_PROCESS_LOG"
  echo "$pid"
}

# mock_process_exists: Check if a mock process exists
#
# Arguments:
#   $1 - pid: Process ID to check
#
# Returns:
#   0 - Process exists
#   1 - Process doesn't exist
#
# Examples:
#   if mock_process_exists 1234; then
#     echo "Process alive"
#   fi
mock_process_exists() {
  local pid="${1:?mock_process_exists requires pid}"
  [[ -f "${MOCK_PIDS_DIR}/${pid}.pid" ]]
}

# mock_process_kill_all: Kill all mock processes
#
# Description:
#   Cleanup function to kill all mock processes.
#   Useful in AfterEach cleanup.
#
# Examples:
#   mock_process_kill_all
mock_process_kill_all() {
  rm -f "${MOCK_PIDS_DIR}"/*.pid 2>/dev/null || true
  echo "$(command date +%s)|kill_all|all_processes" >>"$MOCK_PROCESS_LOG"
}

# mock_process_count: Get number of active mock processes
#
# Outputs:
#   Number of active mock processes
#
# Examples:
#   count=$(mock_process_count)
#   echo "$count processes running"
mock_process_count() {
  # shellcheck disable=SC2012
  ls -1 "${MOCK_PIDS_DIR}"/*.pid 2>/dev/null | wc -l | tr -d ' '
}

# Export mock functions
export -f mock_kill
export -f mock_pkill
export -f mock_ps
export -f mock_background_process
export -f mock_process_exists
export -f mock_process_kill_all
export -f mock_process_count

# Export state
export MOCK_PIDS_DIR
export MOCK_PROCESS_LOG

# Mark as loaded
readonly _PROCESS_MOCKS_LOADED=1
export _PROCESS_MOCKS_LOADED
