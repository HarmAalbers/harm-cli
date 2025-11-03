#!/usr/bin/env bash
# spec/helpers/time_mocks.sh - Time and sleep mocking for deterministic tests
#
# Provides:
# - Mock date command (controllable timestamps)
# - Mock sleep command (instant time advancement)
# - Time travel functions
#
# Usage:
#   source spec/helpers/time_mocks.sh
#   mock_time_set 1234567890
#   mock_sleep 300        # Advances time by 300s instantly
#   mock_time_advance 60  # Jump forward 60 seconds

# Prevent multiple loading
[[ -n "${_TIME_MOCKS_LOADED:-}" ]] && return 0

# Ensure core mocks are loaded
if [[ -z "${_MOCKS_LOADED:-}" ]]; then
  HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=spec/helpers/mocks.sh
  source "${HELPER_DIR}/mocks.sh"
fi

# Mock time state file
MOCK_TIME_FILE="${MOCK_STATE_DIR}/mock_time.state"

# Initialize with current time if not already set
if [[ ! -f "$MOCK_TIME_FILE" ]]; then
  command date +%s > "$MOCK_TIME_FILE"
fi

# Global mock time variable (for quick access)
MOCK_CURRENT_TIME=$(cat "$MOCK_TIME_FILE" 2>/dev/null || command date +%s)
export MOCK_CURRENT_TIME

# _update_mock_time: Internal helper to update time state
_update_mock_time() {
  local new_time="$1"
  echo "$new_time" > "$MOCK_TIME_FILE"
  MOCK_CURRENT_TIME=$new_time
}

# mock_date: Mock version of date command
#
# Description:
#   Replaces the system date command with a controllable version.
#   Supports +%s format (unix timestamp), other formats fall back to real date.
#
# Arguments:
#   Same as date command
#
# Examples:
#   mock_date +%s           # Returns mock timestamp
#   mock_date +"%Y-%m-%d"   # Falls back to real date
mock_date() {
  mock_record_call "date" "$@"

  # Handle different date formats
  case "$*" in
    "+%s")
      # Return mock timestamp
      cat "$MOCK_TIME_FILE"
      ;;
    *)
      # For non-timestamp formats, use real date
      # (Tests generally only care about timestamps)
      command date "$@"
      ;;
  esac
}

# mock_sleep: Mock version of sleep command
#
# Description:
#   Instead of actually sleeping, advances mock time instantly.
#   Makes time-based tests run instantly.
#
# Arguments:
#   $1 - duration: Number of seconds to "sleep"
#
# Examples:
#   mock_sleep 300    # Advances time by 300s (instant)
#   mock_sleep 0.5    # Advances time by 0.5s (instant)
mock_sleep() {
  local duration="${1:-0}"
  mock_record_call "sleep" "$duration"

  # Convert to integer (bash arithmetic only handles integers)
  local duration_int
  duration_int=$(echo "$duration" | awk '{print int($1+0.5)}')

  # Advance mock time
  local current_time
  current_time=$(cat "$MOCK_TIME_FILE")
  local new_time=$((current_time + duration_int))
  _update_mock_time "$new_time"

  # Return immediately (no actual sleep!)
  return 0
}

# mock_time_advance: Advance mock time by N seconds
#
# Description:
#   Time travel function - jumps mock time forward.
#   Useful for testing time-dependent behavior.
#
# Arguments:
#   $1 - seconds: Number of seconds to advance
#
# Examples:
#   mock_time_advance 300     # Jump forward 5 minutes
#   mock_time_advance 900     # Jump forward 15 minutes
#   mock_time_advance $((25 * 60))  # Jump forward 25 minutes
mock_time_advance() {
  local seconds="${1:?mock_time_advance requires seconds}"
  mock_record_call "mock_time_advance" "$seconds"

  local current_time
  current_time=$(cat "$MOCK_TIME_FILE")
  local new_time=$((current_time + seconds))
  _update_mock_time "$new_time"
}

# mock_time_set: Set mock time to specific timestamp
#
# Description:
#   Set mock time to an exact timestamp.
#   Useful for reproducible tests.
#
# Arguments:
#   $1 - timestamp: Unix timestamp to set
#
# Examples:
#   mock_time_set 1234567890
#   mock_time_set $(date +%s)
mock_time_set() {
  local timestamp="${1:?mock_time_set requires timestamp}"
  mock_record_call "mock_time_set" "$timestamp"
  _update_mock_time "$timestamp"
}

# mock_time_reset: Reset mock time to current real time
#
# Description:
#   Resets mock time to match system time.
#   Call in BeforeEach for fresh time state.
#
# Examples:
#   mock_time_reset
mock_time_reset() {
  mock_record_call "mock_time_reset"
  local real_time
  real_time=$(command date +%s)
  _update_mock_time "$real_time"
}

# mock_time_get: Get current mock time
#
# Outputs:
#   Current mock timestamp
#
# Examples:
#   current=$(mock_time_get)
#   echo "Mock time is $current"
mock_time_get() {
  cat "$MOCK_TIME_FILE"
}

# Export mock functions
export -f mock_date
export -f mock_sleep
export -f mock_time_advance
export -f mock_time_set
export -f mock_time_reset
export -f mock_time_get
export -f _update_mock_time

# Export state file
export MOCK_TIME_FILE

# Mark as loaded
readonly _TIME_MOCKS_LOADED=1
export _TIME_MOCKS_LOADED

# Note: Actual aliasing of date/sleep happens in test setup
# to avoid breaking the test framework itself
