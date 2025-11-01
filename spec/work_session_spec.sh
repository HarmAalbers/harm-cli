#!/usr/bin/env bash
# ShellSpec tests for work_session.sh module

Describe 'lib/work_session.sh'
Include spec/helpers/env.sh

# Set up test environment
setup_session_test_env() {
  export HARM_WORK_DIR="$TEST_TMP/work"
  export HARM_WORK_STATE_FILE="$HARM_WORK_DIR/current_session.json"
  export HARM_CLI_HOME="$TEST_TMP/harm-cli"
  mkdir -p "$HARM_WORK_DIR" "$HARM_CLI_HOME"

  # Source the module (will fail until created)
  source "$ROOT/lib/work_session.sh"
}

BeforeAll 'setup_session_test_env'

# Clean up after tests
cleanup_session_test_env() {
  rm -rf "$HARM_WORK_DIR"
}

AfterAll 'cleanup_session_test_env'

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
End

It 'exports work_stop function'
When call type work_stop
The status should be success
End

It 'exports work_status function'
When call type work_status
The status should be success
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
It 'fails when no state file exists'
rm -f "$HARM_WORK_STATE_FILE"
When run work_load_state
The status should be failure
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
Skip "Complex test - needs mock for timers and enforcement"
rm -f "$HARM_WORK_STATE_FILE"
When call work_start "Test goal"
The status should be success
The path "$HARM_WORK_STATE_FILE" should be exist
End

It 'fails when session already active'
Skip "Needs mock for work_is_active check"
echo '{"status":"active"}' >"$HARM_WORK_STATE_FILE"
When run work_start "Another goal"
The status should be failure
End
End

Describe 'work_stop'
It 'fails when no active session'
Skip "Needs mock for work_is_active check"
rm -f "$HARM_WORK_STATE_FILE"
When run work_stop
The status should be failure
End

It 'stops active session'
Skip "Complex test - needs timer mocks"
# Would need to mock work_is_active, work_stop_timer, etc.
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
Skip "Needs time calculation mocks"
# Would need to mock timestamps for consistent output
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
Skip "Complex test - needs time mocking"
# Would need to mock timestamps and calculate expected score
End
End

Describe 'Integration - State lifecycle'
It 'complete session lifecycle works'
Skip "Full integration test - complex setup"
# This would test: start -> status -> stop -> verify cleanup
End
End
End
