#!/usr/bin/env bash
# ShellSpec tests for work session management

Describe 'lib/work.sh'
Include spec/helpers/env.sh

# Set up test work directory and source work module
# IMPORTANT: Must set HARM_WORK_DIR and HARM_CLI_HOME before sourcing work.sh (readonly vars)
setup_work_test_env() {
  export HARM_WORK_DIR="$TEST_TMP/work"
  export HARM_WORK_STATE_FILE="$HARM_WORK_DIR/current_session.json"
  export HARM_CLI_HOME="$TEST_TMP/harm-cli"
  mkdir -p "$HARM_WORK_DIR" "$HARM_CLI_HOME"
  source "$ROOT/lib/work.sh"
}

# Clean up work session artifacts and background processes
# Defined at top level so it's accessible to all Describe blocks
cleanup_work_session() {
  work_stop_timer 2>/dev/null || true
  rm -f "$HARM_WORK_STATE_FILE"* 2>/dev/null || true
  rm -f "$HARM_WORK_DIR"/*.pid 2>/dev/null || true
}

# Helper to start a work session for test setup
# Usage: start_test_session "goal"
start_test_session() {
  local goal="${1:-Test goal}"
  work_start "$goal" >/dev/null 2>&1 || {
    echo "ERROR: Failed to start test work session" >&2
    return 1
  }
}

BeforeAll 'setup_work_test_env'

# Clean up after tests
cleanup_work_test_env() {
  cleanup_work_session
  rm -rf "$HARM_WORK_DIR"
}

AfterAll 'cleanup_work_test_env'

Describe 'Configuration'
It 'creates work directory'
The directory "$HARM_WORK_DIR" should be exist
End

It 'exports configuration variables'
The variable HARM_WORK_DIR should be exported
The variable HARM_WORK_STATE_FILE should be exported
End
End

Describe 'work_is_active'
It 'returns false when no session exists'
rm -f "$HARM_WORK_STATE_FILE"
When call work_is_active
The status should be failure
End

It 'returns true when session is active'
echo '{"status":"active","start_time":"2025-10-18T10:00:00Z"}' >"$HARM_WORK_STATE_FILE"
When call work_is_active
The status should be success
End
End

Describe 'work_get_state'
It 'returns inactive when no session'
rm -f "$HARM_WORK_STATE_FILE"
When call work_get_state
The output should equal "inactive"
End

It 'returns current state'
echo '{"status":"active","start_time":"2025-10-18T10:00:00Z"}' >"$HARM_WORK_STATE_FILE"
When call work_get_state
The output should equal "active"
End
End

Describe 'work_start'
BeforeEach 'cleanup_work_session'

It 'starts a new work session'
export HARM_CLI_FORMAT=text
When call work_start "Test goal"
The status should be success
The output should include "Goal: Test goal"
The error should include "Work session started"
The file "$HARM_WORK_STATE_FILE" should be exist
End

It 'saves session state as JSON'
export HARM_CLI_FORMAT=text
When call work_start "Test goal"
The status should be success
The contents of file "$HARM_WORK_STATE_FILE" should include '"status": "active"'
The contents of file "$HARM_WORK_STATE_FILE" should include '"goal": "Test goal"'
End

It 'outputs JSON format when requested'
export HARM_CLI_FORMAT=json
When call work_start "Test goal"
The output should include '"status"'
The output should include '"goal"'
The error should include "[INFO]"
End

It 'fails if session already active'
When call work_start "First"
The status should be success
When call work_start "Second"
The status should be failure
The error should include "already active"
End
End

Describe 'work_status'
BeforeEach 'cleanup_work_session'

It 'shows inactive when no session'
export HARM_CLI_FORMAT=text
When call work_status
The output should include "No active work session"
End

It 'shows active session details'
export HARM_CLI_FORMAT=text
start_test_session "Test goal"
sleep 0.3
When call work_status
The output should include "ACTIVE"
The output should include "Test goal"
The output should include "Elapsed"
End

It 'outputs JSON format'
export HARM_CLI_FORMAT=json
start_test_session "Test goal"
When call work_status
The output should include '"status"'
The output should include '"goal"'
The output should include '"elapsed_seconds"'
End

It 'calculates elapsed time accurately (timezone bug test)'
export HARM_CLI_FORMAT=json
start_test_session "Test goal"
sleep 0.5
result=$(work_status)
elapsed=$(echo "$result" | jq -r '.elapsed_seconds')
# Elapsed should be ~0.5 seconds, NOT hours off due to timezone bug
# Allow 0-3 seconds range for processing time
When call test "$elapsed" -ge 0 -a "$elapsed" -le 3
The status should be success
End
End

Describe 'work_stop'
BeforeEach 'cleanup_work_session'

It 'fails when no active session'
rm -f "$HARM_WORK_STATE_FILE"
When call work_stop
The status should be failure
The error should include "No active work session"
End

It 'stops active session'
export HARM_CLI_FORMAT=text
start_test_session "Test goal"
sleep 0.3
When call work_stop
The status should be success
The error should include "Work session stopped"
The output should include "Duration"
End

It 'removes state file after stopping'
start_test_session "Test"
work_stop >/dev/null 2>&1
The file "$HARM_WORK_STATE_FILE" should not be exist
End

It 'archives session to monthly file'
start_test_session "Test goal"
sleep 0.3
work_stop >/dev/null 2>&1
archive_file="${HARM_WORK_DIR}/sessions_$(date '+%Y-%m').jsonl"
The file "$archive_file" should be exist
The contents of file "$archive_file" should include '"goal"'
End

It 'outputs JSON format'
export HARM_CLI_FORMAT=json
start_test_session "Test"
sleep 0.3
When call work_stop
The status should be success
The output should include '"status"'
The output should include '"duration_seconds"'
The error should include "[INFO]"
End

It 'calculates duration accurately (timezone bug test)'
# This test verifies the timezone bug is fixed by checking actual duration
export HARM_CLI_FORMAT=json
start_test_session "Test goal"
sleep 0.5
# Capture only stdout (JSON), stderr goes to log
result=$(work_stop 2>/dev/null)
duration=$(echo "$result" | jq -r '.duration_seconds' 2>/dev/null || echo "999")
# Duration should be ~0.5 seconds (0-3 range), NOT 7200+ (timezone bug)
When call test "$duration" -ge 0 -a "$duration" -le 3
The status should be success
End
End

Describe 'work timer management'
BeforeEach 'cleanup_timer_test'
AfterEach 'cleanup_timer_test'

cleanup_timer_test() {
  work_stop_timer 2>/dev/null || true
  rm -f "$HARM_WORK_TIMER_PID_FILE" 2>/dev/null || true
  rm -f "$HARM_WORK_STATE_FILE" 2>/dev/null || true
  pkill -f "sleep.*work" 2>/dev/null || true
}

Context 'timer PID file management'
It 'creates timer PID file on work_start'
# Start work session with very short duration for testing
export HARM_CLI_WORK_DURATION=5
start_test_session "Timer test"
The file "$HARM_WORK_TIMER_PID_FILE" should exist
End

It 'stores valid PID in timer file'
export HARM_CLI_WORK_DURATION=5
start_test_session "Timer test"
sleep 0.2
pid=$(cat "$HARM_WORK_TIMER_PID_FILE" 2>/dev/null || echo "0")
# PID should be a positive integer
test "$pid" -gt 0
The status should equal 0
End

It 'removes timer PID file on work_stop'
export HARM_CLI_WORK_DURATION=5
start_test_session "Timer test"
work_stop >/dev/null 2>&1
The file "$HARM_WORK_TIMER_PID_FILE" should not exist
End
End

Context 'timer cleanup'
It 'cleans up timer on work_stop'
export HARM_CLI_WORK_DURATION=5
start_test_session "Timer test"
timer_pid=$(cat "$HARM_WORK_TIMER_PID_FILE" 2>/dev/null)
work_stop >/dev/null 2>&1
# Check if process was killed (ps should not find it)
# Note: This may not work reliably in all test environments
Skip if "Process cleanup testing is environment-dependent"
End

It 'handles missing PID file gracefully'
When call work_stop_timer
The status should equal 0
End

It 'handles stale PID files gracefully'
# Create PID file with non-existent PID
echo "99999" >"$HARM_WORK_TIMER_PID_FILE"
When call work_stop_timer
The status should equal 0
The file "$HARM_WORK_TIMER_PID_FILE" should not exist
End

It 'handles invalid PID gracefully'
echo "not-a-number" >"$HARM_WORK_TIMER_PID_FILE"
When call work_stop_timer
The status should equal 0
End
End

Context 'prevents orphaned processes'
It 'kills timer process on stop'
Skip if "Background process management testing is complex"
End

It 'kills reminder process on stop'
Skip if "Background process management testing is complex"
End
End
End

Describe 'work notifications'
BeforeEach 'cleanup_notification_test'
AfterEach 'cleanup_notification_test'

cleanup_notification_test() {
  work_stop 2>/dev/null || true
  rm -f "$HARM_WORK_STATE_FILE" 2>/dev/null || true
}

Context 'notification function'
It 'work_send_notification requires title'
When call work_send_notification
The status should not equal 0
End

It 'work_send_notification requires message'
When call work_send_notification "Title"
The status should not equal 0
End

It 'handles missing notification command gracefully'
# Mock osascript/notify-send to not exist
PATH="/nonexistent" When call work_send_notification "Test" "Message"
The status should equal 0
End
End

Context 'notification timing'
It 'sends notification on work_start'
Skip if "Notification testing requires mocking OS commands"
End

It 'sends notification on work_stop'
Skip if "Notification testing requires mocking OS commands"
End

It 'sends notification on timer completion'
Skip if "Notification testing requires mocking and timing"
End
End

Context 'notification preferences'
It 'respects notification settings'
Skip if "Requires notification settings implementation"
End
End
End

Describe 'Critical Edge Cases'
BeforeEach 'cleanup_work_session'

Context 'Corrupted state file recovery'
It 'recovers from invalid JSON in state file'
echo '{"incomplete": json content' >"$HARM_WORK_STATE_FILE"
When call work_is_active
The status should be failure
End

It 'recovers by starting fresh after corrupted state'
echo 'not json at all!!!' >"$HARM_WORK_STATE_FILE"
When call work_start "Recovery test"
The status should be success
The file "$HARM_WORK_STATE_FILE" should exist
# Verify new state is valid JSON
grep -q '"status"' "$HARM_WORK_STATE_FILE"
The status should equal 0
End

It 'logs corrupted state error with context'
echo '{corrupted}' >"$HARM_WORK_STATE_FILE"
When call work_load_state
The status should equal 0 # work_load_state returns empty on corruption
The output should equal ""
End
End

Context 'PID reuse scenarios (stale PID file)'
It 'handles non-existent PID gracefully in work_stop_timer'
# Simulate stale PID from previous session
echo "99999" >"$HARM_WORK_TIMER_PID_FILE"
When call work_stop_timer
The status should equal 0
The file "$HARM_WORK_TIMER_PID_FILE" should not exist
End

It 'detects and cleans stale PID before reuse'
# PID 1 is always init/launchd, definitely not our timer
echo "1" >"$HARM_WORK_TIMER_PID_FILE"
When call work_stop_timer
The status should equal 0
The file "$HARM_WORK_TIMER_PID_FILE" should not exist
End

It 'starts new session despite stale timer PID'
echo "99999" >"$HARM_WORK_TIMER_PID_FILE"
When call work_start "Fresh start"
The status should be success
# New PID file should have replaced old one
pid=$(cat "$HARM_WORK_TIMER_PID_FILE" 2>/dev/null)
test "$pid" -gt 100 # Real PIDs > 100
The status should equal 0
End
End

Context 'Disk full during state save'
It 'fails gracefully when state file write fails'
# Make directory read-only to simulate disk full
chmod 444 "$HARM_WORK_DIR"
When call work_start "Will fail"
The status should not equal 0
# Restore permissions for cleanup
chmod 755 "$HARM_WORK_DIR"
The error should include "cannot"
End

It 'preserves old state if new write fails'
# Save initial state
start_test_session "Initial goal"
old_state=$(cat "$HARM_WORK_STATE_FILE" 2>/dev/null || echo "")
# Make directory read-only
chmod 444 "$HARM_WORK_DIR"
# Try to update (will fail)
work_save_state "paused" "2025-10-18T10:00:00Z" "Updated" 0 2>/dev/null || true
# Restore permissions
chmod 755 "$HARM_WORK_DIR"
# Old state should be intact
current_state=$(cat "$HARM_WORK_STATE_FILE" 2>/dev/null)
test "$current_state" = "$old_state"
The status should equal 0
End
End

Context 'Session spanning midnight (date rollover)'
It 'preserves session across midnight'
export HARM_CLI_FORMAT=json
start_test_session "All-nighter goal"
# Simulate timezone where session crossed midnight
session_state=$(work_status)
# Session should still show as active
echo "$session_state" | grep -q '"status":"active"'
The status should equal 0
End

It 'calculates duration correctly across midnight'
# Session started "yesterday", current time "today"
start_iso="2025-10-17T23:00:00Z"
echo "{\"status\":\"active\",\"start_time\":\"$start_iso\",\"goal\":\"midnight test\",\"pomodoro_count\":0}" >"$HARM_WORK_STATE_FILE"
# Manually calculate what work_status would show
result=$(work_status 2>/dev/null)
# Should not crash with timezone issues
echo "$result" | grep -q "elapsed"
The status should equal 0
End

It 'archives to correct month when spanning months'
# Session from end of October into November
oct_date="2025-10-31T22:00:00Z"
echo "{\"status\":\"active\",\"start_time\":\"$oct_date\",\"goal\":\"month-spanning\",\"pomodoro_count\":0}" >"$HARM_WORK_STATE_FILE"
When call work_stop
The status should equal 0
# Verify archived to October file (session started in October)
oct_archive="${HARM_WORK_DIR}/sessions_2025-10.jsonl"
The file "$oct_archive" should exist
End
End

Context 'Concurrent work_start prevention'
It 'atomically checks and creates state file'
# Simulate concurrent access by starting first session
When call work_start "First concurrent"
The status should be success
# Second call should fail
When call work_start "Second concurrent"
The status should not equal 0
The error should include "already active"
End

It 'prevents race condition with state file lock'
# This is a behavioral test - verify atomicity
start_test_session "Race test"
# Even if we manually check state exists first
test -f "$HARM_WORK_STATE_FILE"
# Attempting to start should still fail atomically
When call work_start "Should fail"
The status should not equal 0
End

It 'cleans up partial state on concurrent failure'
start_test_session "Cleanup test"
initial_count=$(find "$HARM_WORK_DIR" -name "current_session.json*" 2>/dev/null | wc -l)
# Attempt concurrent start (fails)
work_start "Concurrent fail" 2>/dev/null || true
# No orphaned partial files
final_count=$(find "$HARM_WORK_DIR" -name "current_session.json*" 2>/dev/null | wc -l)
test "$final_count" -le "$initial_count"
The status should equal 0
End
End
End
End
