#!/usr/bin/env bash
# spec/helpers/mocks.sh - Core mocking infrastructure for harm-cli tests
#
# Provides:
# - Mock call recording and verification
# - Mock state management
# - Mock reset functionality
#
# Usage:
#   source spec/helpers/mocks.sh
#   mock_record_call "function_name" "arg1" "arg2"
#   mock_was_called "function_name"
#   mock_call_count "function_name"
#   mock_reset_all

# Prevent multiple loading
[[ -n "${_MOCKS_LOADED:-}" ]] && return 0

# Mock state directory (uses TEST_TMP if available, otherwise /tmp)
MOCK_STATE_DIR="${TEST_TMP:-/tmp}/harm-cli-mocks"
mkdir -p "$MOCK_STATE_DIR"

# Mock call tracking log
MOCK_CALLS_LOG="${MOCK_STATE_DIR}/calls.log"
: > "$MOCK_CALLS_LOG"

# mock_record_call: Record a mock function call
#
# Arguments:
#   $1 - func_name: Function name being mocked
#   $@ - args: Arguments passed to the function
#
# Examples:
#   mock_record_call "sleep" "300"
#   mock_record_call "osascript" "-e" "display notification"
mock_record_call() {
  local func_name="$1"
  shift
  local timestamp
  timestamp=$(date +%s 2>/dev/null || echo "0")
  echo "${timestamp}|${func_name}|$*" >> "$MOCK_CALLS_LOG"
}

# mock_was_called: Check if a mock function was called
#
# Arguments:
#   $1 - func_name: Function name to check
#
# Returns:
#   0 - Function was called
#   1 - Function was not called
#
# Examples:
#   mock_was_called "sleep"
#   if mock_was_called "osascript"; then echo "Called"; fi
mock_was_called() {
  local func_name="${1:?mock_was_called requires function name}"
  grep -q "|${func_name}|" "$MOCK_CALLS_LOG" 2>/dev/null
}

# mock_call_count: Get number of times a function was called
#
# Arguments:
#   $1 - func_name: Function name to count
#
# Outputs:
#   Number of calls (0 if never called)
#
# Examples:
#   count=$(mock_call_count "sleep")
#   echo "sleep was called $count times"
mock_call_count() {
  local func_name="${1:?mock_call_count requires function name}"
  grep -c "|${func_name}|" "$MOCK_CALLS_LOG" 2>/dev/null || echo "0"
}

# mock_get_call_args: Get arguments from a specific call
#
# Arguments:
#   $1 - func_name: Function name
#   $2 - call_index: Which call (1-based, defaults to last)
#
# Outputs:
#   Arguments from that call
#
# Examples:
#   args=$(mock_get_call_args "sleep" 1)  # First call
#   args=$(mock_get_call_args "sleep")    # Last call
mock_get_call_args() {
  local func_name="${1:?mock_get_call_args requires function name}"
  local call_index="${2:-}"

  if [[ -z "$call_index" ]]; then
    # Get last call
    grep "|${func_name}|" "$MOCK_CALLS_LOG" 2>/dev/null | tail -1 | cut -d'|' -f3-
  else
    # Get specific call (1-based index)
    grep "|${func_name}|" "$MOCK_CALLS_LOG" 2>/dev/null | sed -n "${call_index}p" | cut -d'|' -f3-
  fi
}

# mock_reset_all: Reset all mock state
#
# Description:
#   Clears all mock call logs and state files.
#   Call this in BeforeEach to ensure clean test state.
#
# Examples:
#   mock_reset_all
mock_reset_all() {
  : > "$MOCK_CALLS_LOG"
  rm -f "${MOCK_STATE_DIR}"/*.state 2>/dev/null || true
  rm -f "${MOCK_STATE_DIR}"/*.log 2>/dev/null || true
}

# mock_dump_calls: Dump all recorded calls (for debugging)
#
# Outputs:
#   All recorded mock calls with timestamps
#
# Examples:
#   mock_dump_calls
mock_dump_calls() {
  if [[ -f "$MOCK_CALLS_LOG" ]]; then
    cat "$MOCK_CALLS_LOG"
  else
    echo "No mock calls recorded"
  fi
}

# Export functions for use in tests
export -f mock_record_call
export -f mock_was_called
export -f mock_call_count
export -f mock_get_call_args
export -f mock_reset_all
export -f mock_dump_calls

# Mark as loaded
readonly _MOCKS_LOADED=1
export _MOCKS_LOADED
export MOCK_STATE_DIR
export MOCK_CALLS_LOG
