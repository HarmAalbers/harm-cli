#!/usr/bin/env bash
# ShellSpec tests for work_session.sh module

export HARM_LOG_LEVEL=ERROR

Describe 'lib/work_session.sh'
Include spec/helpers/env.sh

BeforeAll 'setup_session_test_env'
AfterAll 'cleanup_session_test_env'

# Set up test environment
setup_session_test_env() {
  export HARM_CLI_HOME="$TEST_TMP/harm-cli"
  export HARM_LOG_LEVEL=ERROR
  export HARM_TEST_MODE=1 # Prevents background processes
  export HARM_WORK_DIR="$TEST_TMP/work"
  export HARM_WORK_STATE_FILE="$HARM_WORK_DIR/current_session.json"
  export HARM_WORK_ENFORCEMENT=off

  mkdir -p "$HARM_CLI_HOME" "$HARM_WORK_DIR"

  # Disable Homebrew command not found handler
  unset -f homebrew_command_not_found_handle 2>/dev/null || true
  export HOMEBREW_COMMAND_NOT_FOUND_CI=1

  # Inline mocks (do NOT use Include spec/helpers/mocks.sh - causes hangs)
  MOCK_TIME=$(command date +%s)

  date() {
    if [[ "$1" == "+%s" ]]; then
      echo "$MOCK_TIME"
    else
      command date "$@"
    fi
  }

  sleep() { :; }
  activity_query() { return 0; }
  pkill() { :; }
  kill() { :; }
  ps() { echo "bash"; }
  osascript() { :; }
  notify-send() { :; }
  paplay() { :; }

  options_get() {
    case "$1" in
      work_duration) echo "1500" ;;
      work_reminder_interval) echo "0" ;;
      break_short) echo "300" ;;
      break_long) echo "900" ;;
      pomodoros_until_long) echo "4" ;;
      strict_block_project_switch) echo "0" ;;
      strict_require_break) echo "0" ;;
      work_notifications) echo "0" ;;
      work_sound_notifications) echo "0" ;;
      *) echo "0" ;;
    esac
  }

  # Mock helper functions
  break_start() { return 0; }
  get_epoch_seconds() { echo "$MOCK_TIME"; }
  parse_iso8601_to_epoch() { echo "$MOCK_TIME"; }

  export -f date sleep activity_query pkill kill ps osascript notify-send paplay options_get
  export -f break_start get_epoch_seconds parse_iso8601_to_epoch

  # CRITICAL: Add </dev/null stdin redirection to prevent hangs
  source "$ROOT/lib/work_session.sh" 2>/dev/null </dev/null
}

# Clean up after tests
cleanup_session_test_env() {
  # Kill any background jobs
  jobs -p | xargs -r kill 2>/dev/null || true
  wait 2>/dev/null || true

  # Clean up directories
  rm -rf "$HARM_CLI_HOME" "$HARM_WORK_DIR"

  # Kill any lingering sleep processes
  pkill -f "sleep.*" 2>/dev/null || true
}

Describe 'Module Loading'
It 'sources work_session.sh without errors'
The variable _HARM_WORK_SESSION_LOADED should be defined
End

It 'exports work_is_active function'
When call type work_is_active
The status should be success
The output should include "work_is_active"
End

It 'exports work_start function'
When call type work_start
The status should be success
The output should include "work_start"
End

It 'exports work_stop function'
When call type work_stop
The status should be success
The output should include "work_stop"
End

It 'exports work_status function'
When call type work_status
The status should be success
The output should include "work_status"
End
End

Describe 'work_is_active'
It 'returns false when no state file exists'
rm -f "$HARM_WORK_STATE_FILE"
When call work_is_active
The status should be failure
End

It 'returns false when session is inactive'
echo '{"status":"inactive"}' >"$HARM_WORK_STATE_FILE"
When call work_is_active
The status should be failure
End

It 'returns true when session is active'
echo '{"status":"active"}' >"$HARM_WORK_STATE_FILE"
When call work_is_active
The status should be success
End

It 'returns false when session is paused'
echo '{"status":"paused"}' >"$HARM_WORK_STATE_FILE"
When call work_is_active
The status should be failure
End
End

Describe 'work_get_state'
It 'returns "inactive" when no session exists'
rm -f "$HARM_WORK_STATE_FILE"
When call work_get_state
The output should equal "inactive"
The status should be success
End

It 'returns current state from file'
echo '{"status":"active"}' >"$HARM_WORK_STATE_FILE"
When call work_get_state
The output should equal "active"
End

It 'returns paused state'
echo '{"status":"paused"}' >"$HARM_WORK_STATE_FILE"
When call work_get_state
The output should equal "paused"
End
End

Describe 'work_save_state'
It 'requires status parameter'
When run work_save_state
The status should be failure
The stderr should include "requires status"
End

It 'requires start_time parameter'
When run work_save_state "active"
The status should be failure
The stderr should include "requires start_time"
End

It 'creates state file with required fields'
When call work_save_state "active" "2025-01-01T12:00:00Z" "test goal"
The status should be success
The path "$HARM_WORK_STATE_FILE" should be exist
End

It 'saves status field correctly'
work_save_state "active" "2025-01-01T12:00:00Z" "test" 0
When call jq -r '.status' "$HARM_WORK_STATE_FILE"
The output should equal "active"
End

It 'saves start_time field correctly'
work_save_state "active" "2025-01-01T10:30:00Z" "" 0
When call jq -r '.start_time' "$HARM_WORK_STATE_FILE"
The output should equal "2025-01-01T10:30:00Z"
End

It 'saves goal field correctly'
work_save_state "active" "2025-01-01T12:00:00Z" "Complete refactoring" 0
When call jq -r '.goal' "$HARM_WORK_STATE_FILE"
The output should equal "Complete refactoring"
End

It 'includes last_updated timestamp'
work_save_state "active" "2025-01-01T12:00:00Z" "" 0
When call jq -r '.last_updated' "$HARM_WORK_STATE_FILE"
The output should not equal "null"
End
End

Describe 'work_load_state'
It 'returns success with no output when no state file exists'
rm -f "$HARM_WORK_STATE_FILE"
When run work_load_state
The status should be success
The output should be blank
End

It 'returns JSON state from file'
echo '{"status":"active","start_time":"2025-01-01T12:00:00Z"}' >"$HARM_WORK_STATE_FILE"
When call work_load_state
The output should include '"status":"active"'
The status should be success
End
End

Describe 'work_start'
It 'starts new work session with goal'
rm -f "$HARM_WORK_STATE_FILE"
When call work_start "Test goal"
The status should be success
The output should include "Test goal"
The stderr should include "started"
The path "$HARM_WORK_STATE_FILE" should be exist
End

It 'fails when session already active'
echo '{"status":"active","start_time":"2025-01-01T12:00:00Z"}' >"$HARM_WORK_STATE_FILE"
When run work_start "Another goal"
The status should be failure
The stderr should include "already active"
End
End

Describe 'work_stop'
It 'fails when no active session'
rm -f "$HARM_WORK_STATE_FILE"
When run work_stop
The status should be failure
The stderr should include "No active"
End

It 'stops active session'
echo '{"status":"active","start_time":"2025-01-01T12:00:00Z"}' >"$HARM_WORK_STATE_FILE"
When call work_stop
The status should be success
The output should include "Pomodoro"
The stderr should include "stopped"
End
End

Describe 'work_status'
It 'shows inactive when no session'
rm -f "$HARM_WORK_STATE_FILE"
When call work_status
The output should include "No active"
The status should be success
End

It 'shows active session details'
echo '{"status":"active","start_time":"2025-01-01T12:00:00Z","goal":"Test goal"}' >"$HARM_WORK_STATE_FILE"
When call work_status
The output should include "ACTIVE"
The output should include "Test goal"
The status should be success
End
End

Describe 'work_require_active'
It 'returns success when session is active'
echo '{"status":"active"}' >"$HARM_WORK_STATE_FILE"
When call work_require_active
The status should be success
End

It 'returns failure and shows reminder when inactive'
rm -f "$HARM_WORK_STATE_FILE"
When call work_require_active
The status should be failure
The stderr should include "Tip"
End
End

Describe 'work_remind'
It 'displays tip message'
When call work_remind
The stderr should include "Tip"
The stderr should include "work start"
The status should be success
End
End

Describe 'work_focus_score'
It 'returns 0 when no active session'
rm -f "$HARM_WORK_STATE_FILE"
When call work_focus_score
The output should equal "0"
The status should be failure
End

It 'calculates score based on elapsed time'
# Create active session - score depends on elapsed time
# With MOCK_TIME and parse_iso8601_to_epoch both returning same value, elapsed=0, score=0
echo '{"status":"active","start_time":"2025-01-01T12:00:00Z"}' >"$HARM_WORK_STATE_FILE"
When call work_focus_score
The status should be success
# Score will be 0 with elapsed=0, which is correct behavior
The output should equal "0"
End
End

Describe 'Integration - State lifecycle'
It 'starts a session and state becomes active'
rm -f "$HARM_WORK_STATE_FILE"
work_start "Integration test goal" 2>/dev/null
When call work_get_state
The output should equal "active"
End

It 'shows active session in status'
echo '{"status":"active","start_time":"2025-01-01T12:00:00Z","goal":"Integration test"}' >"$HARM_WORK_STATE_FILE"
When call work_status
The output should include "ACTIVE"
The output should include "Integration test"
End

It 'stops session and state becomes inactive'
echo '{"status":"active","start_time":"2025-01-01T12:00:00Z"}' >"$HARM_WORK_STATE_FILE"
work_stop 2>/dev/null
When call work_get_state
The output should equal "inactive"
End
End
End
