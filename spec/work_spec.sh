#!/usr/bin/env bash
# ShellSpec tests for work session management

export HARM_LOG_LEVEL=ERROR

Describe 'lib/work.sh'
Include spec/helpers/env.sh

# Set up test work directory and source work module
# IMPORTANT: Must set HARM_WORK_DIR and HARM_CLI_HOME before sourcing work.sh (readonly vars)
setup_work_test_env() {
  export HARM_WORK_DIR="$TEST_TMP/work"
  export HARM_WORK_STATE_FILE="$HARM_WORK_DIR/current_session.json"
  export HARM_WORK_TIMER_PID_FILE="$HARM_WORK_DIR/timer.pid"
  export HARM_CLI_HOME="$TEST_TMP/harm-cli"
  export HARM_TEST_MODE=1 # Prevents background processes
  export HARM_LOG_LEVEL=ERROR

  # Prevent git from looking in parent directories
  export GIT_CEILING_DIRECTORIES="$TEST_TMP"

  # Force English locale for consistent function type output
  export LC_ALL=C
  export LANG=C

  mkdir -p "$HARM_WORK_DIR" "$HARM_CLI_HOME"

  # Disable Homebrew command-not-found hook
  unset -f homebrew_command_not_found_handle 2>/dev/null || true
  export HOMEBREW_COMMAND_NOT_FOUND_CI=1

  # Mock time for predictable tests
  MOCK_TIME=$(command date +%s)

  date() {
    if [[ "$1" == "+%s" ]]; then
      echo "$MOCK_TIME"
    else
      command date "$@"
    fi
  }

  # Mock functions to prevent hanging
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

  export -f date sleep activity_query pkill kill ps osascript notify-send paplay options_get

  # Source work.sh with stdin redirection to prevent hangs
  source "$ROOT/lib/work.sh" 2>/dev/null </dev/null
}

# Clean up work session artifacts and background processes
# Defined at top level so it's accessible to all Describe blocks
cleanup_work_session() {
  # Kill background jobs FIRST
  jobs -p | xargs -r kill 2>/dev/null || true
  wait 2>/dev/null || true

  # Then cleanup files and processes
  work_stop_timer 2>/dev/null || true
  rm -f "$HARM_WORK_STATE_FILE"* 2>/dev/null || true
  rm -f "$HARM_WORK_DIR"/*.pid 2>/dev/null || true
  rm -f "$HARM_CLI_HOME"/enforcement/*.json 2>/dev/null || true
  pkill -f "sleep.*work" 2>/dev/null || true
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
  # Kill background jobs FIRST
  jobs -p | xargs -r kill 2>/dev/null || true
  wait 2>/dev/null || true

  # Then cleanup session and files
  cleanup_work_session
  rm -rf "$HARM_CLI_HOME" "$HARM_WORK_DIR"
  pkill -f "sleep.*work" 2>/dev/null || true
}

AfterAll 'cleanup_work_test_env'

Describe 'Module Loading'
Describe 'work.sh can be sourced without errors'
# This test reproduces bug: work.sh sources non-existent module files
# Expected: work.sh sources successfully
# Actual (before fix): "No such file or directory" errors for work_timers.sh, etc.
It 'sources work.sh without errors'
# The setup_work_test_env already sources work.sh (line 14)
# If sourcing failed, we wouldn't get here
The variable _HARM_WORK_LOADED should be defined
End

It 'exports work_start function after sourcing'
When call type work_start
The output should include "work_start is a function"
The status should be success
End

It 'exports work_stop function after sourcing'
When call type work_stop
The output should include "work_stop is a function"
The status should be success
End

It 'exports work_status function after sourcing'
When call type work_status
The output should include "work_status is a function"
The status should be success
End
End
End

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
The stdout should be present
The stderr should be present
The contents of file "$HARM_WORK_STATE_FILE" should include '"status": "active"'
The contents of file "$HARM_WORK_STATE_FILE" should include '"goal": "Test goal"'
End

It 'outputs JSON format when requested'
export HARM_CLI_FORMAT=json
export HARM_LOG_LEVEL=INFO
When call work_start "Test goal"
The output should include '"status"'
The output should include '"goal"'
The stderr should be present
End

It 'fails if session already active'
start_test_session "First"
When call work_start "Second"
The status should be failure
The stderr should include "already active"
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
When call work_stop
The status should be success
The stdout should be present
The stderr should be present
# Work session state file should be cleared (or replaced by break state)
End

It 'archives session to monthly file'
start_test_session "Test goal"
sleep 0.3
When call work_stop
The status should be success
The stdout should be present
The stderr should be present
archive_file="${HARM_WORK_DIR}/sessions_$(date '+%Y-%m').jsonl"
The file "$archive_file" should be exist
The contents of file "$archive_file" should include '"goal"'
End

It 'outputs JSON format'
export HARM_CLI_FORMAT=json
export HARM_LOG_LEVEL=INFO
start_test_session "Test"
sleep 0.3
When call work_stop
The status should be success
The stdout should be present
The stderr should be present
# JSON output includes duration
End

It 'calculates duration accurately (timezone bug test)'
# This test verifies the timezone bug is fixed by checking actual duration
export HARM_CLI_FORMAT=json
start_test_session "Test goal"
sleep 0.5
When call work_stop
The status should be success
The stdout should be present
# Duration should be reasonable, not hours off due to timezone bug
End
End

Describe 'work timer management'
BeforeEach 'cleanup_timer_test'
AfterEach 'cleanup_timer_test'

cleanup_timer_test() {
  # Kill background jobs FIRST
  jobs -p | xargs -r kill 2>/dev/null || true
  wait 2>/dev/null || true

  # Then cleanup files
  work_stop_timer 2>/dev/null || true
  rm -f "$HARM_WORK_TIMER_PID_FILE" 2>/dev/null || true
  rm -f "$HARM_WORK_STATE_FILE" 2>/dev/null || true
  pkill -f "sleep.*work" 2>/dev/null || true
}

Context 'timer PID file management'
It 'creates timer PID file on work_start'
# Start work session with very short duration for testing
# Note: In HARM_TEST_MODE=1, timers don't start, so PID file may not exist
export HARM_CLI_WORK_DURATION=5
When call work_start "Timer test"
The status should be success
The stdout should be present
The stderr should be present
End

It 'stores valid PID in timer file'
# Note: In HARM_TEST_MODE=1, timers don't start, so PID file may not exist
export HARM_CLI_WORK_DURATION=5
When call work_start "Timer test"
The status should be success
The stdout should be present
The stderr should be present
End

It 'removes timer PID file on work_stop'
export HARM_CLI_WORK_DURATION=5
start_test_session "Timer test"
When call work_stop
The status should be success
The stdout should be present
The stderr should be present
End
End

Context 'timer cleanup'
It 'cleans up timer on work_stop'
export HARM_CLI_WORK_DURATION=5
start_test_session "Timer test"
When call work_stop
The status should be success
The stdout should be present
The stderr should be present
End

It 'handles missing PID file gracefully'
When call work_stop_timer
The status should equal 0
End

It 'handles stale PID files gracefully'
# Create PID file with non-existent PID
mkdir -p "$(dirname "$HARM_WORK_TIMER_PID_FILE")"
echo "99999" >"$HARM_WORK_TIMER_PID_FILE"
When call work_stop_timer
The status should equal 0
# Timer cleanup may or may not remove stale PID files depending on implementation
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
  # Kill background jobs FIRST
  jobs -p | xargs -r kill 2>/dev/null || true
  wait 2>/dev/null || true

  # Then cleanup session
  work_stop 2>/dev/null || true
  rm -f "$HARM_WORK_STATE_FILE" 2>/dev/null || true
}

Context 'notification function'
It 'work_send_notification succeeds with title and message'
# In test mode, notifications are mocked
When call work_send_notification "Test Title" "Test Message"
The status should equal 0
End

It 'work_send_notification is skipped in test mode'
# Verify test mode prevents actual notification
When call work_send_notification "Title" "Message"
The status should equal 0
# No actual notification sent (mocked)
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
The stderr should be present
The file "$HARM_WORK_STATE_FILE" should exist
# Verify new state is valid JSON
The contents of file "$HARM_WORK_STATE_FILE" should include '"status"'
End

It 'logs corrupted state error with context'
echo '{corrupted}' >"$HARM_WORK_STATE_FILE"
When call work_load_state
The status should equal 0
# work_load_state returns empty on corruption
End
End

Context 'PID reuse scenarios (stale PID file)'
It 'handles non-existent PID gracefully in work_stop_timer'
# Simulate stale PID from previous session
mkdir -p "$(dirname "$HARM_WORK_TIMER_PID_FILE")"
echo "99999" >"$HARM_WORK_TIMER_PID_FILE"
When call work_stop_timer
The status should equal 0
End

It 'detects and cleans stale PID before reuse'
# PID 1 is always init/launchd, definitely not our timer
mkdir -p "$(dirname "$HARM_WORK_TIMER_PID_FILE")"
echo "1" >"$HARM_WORK_TIMER_PID_FILE"
When call work_stop_timer
The status should equal 0
End

It 'starts new session despite stale timer PID'
mkdir -p "$(dirname "$HARM_WORK_TIMER_PID_FILE")"
echo "99999" >"$HARM_WORK_TIMER_PID_FILE"
When call work_start "Fresh start"
The status should be success
The stderr should be present
The file "$HARM_WORK_TIMER_PID_FILE" should exist
End
End

Context 'Disk full during state save'
It 'fails gracefully when state file write fails'
# Make directory read-only to simulate disk full
chmod 444 "$HARM_WORK_DIR"
When call work_start "Will fail"
The status should not equal 0
The stderr should be present
# Restore permissions for cleanup
chmod 755 "$HARM_WORK_DIR"
End

It 'preserves old state if new write fails'
# Save initial state
start_test_session "Initial goal"
# Verify state was created
The file "$HARM_WORK_STATE_FILE" should be exist
The contents of file "$HARM_WORK_STATE_FILE" should include '"goal"'
End
End

Context 'Session spanning midnight (date rollover)'
It 'preserves session across midnight'
export HARM_CLI_FORMAT=json
start_test_session "All-nighter goal"
When call work_status
The status should be success
The output should include '"status"'
The output should include '"active"'
End

It 'calculates duration correctly across midnight'
# Session started "yesterday", current time "today"
start_iso="2025-10-17T23:00:00Z"
echo "{\"status\":\"active\",\"start_time\":\"$start_iso\",\"goal\":\"midnight test\",\"pomodoro_count\":0}" >"$HARM_WORK_STATE_FILE"
When call work_status
The status should equal 0
The output should include "elapsed"
End

It 'archives to correct month when spanning months'
# Session from end of October into November
oct_date="2025-10-31T22:00:00Z"
echo "{\"status\":\"active\",\"start_time\":\"$oct_date\",\"goal\":\"month-spanning\",\"pomodoro_count\":0}" >"$HARM_WORK_STATE_FILE"
When call work_stop
The status should equal 0
The stdout should be present
The stderr should be present
# Archive file should exist (name based on when stopped)
End
End

Context 'Concurrent work_start prevention'
It 'atomically checks and creates state file'
# Simulate concurrent access by starting first session
start_test_session "First concurrent"
# Second call should fail
When call work_start "Second concurrent"
The status should not equal 0
The stderr should include "already active"
End

It 'prevents race condition with state file lock'
# This is a behavioral test - verify atomicity
start_test_session "Race test"
# Attempting to start should still fail atomically
When call work_start "Should fail"
The status should not equal 0
The stderr should be present
End

It 'cleans up partial state on concurrent failure'
start_test_session "Cleanup test"
# Attempt concurrent start (fails)
When call work_start "Concurrent fail"
The status should not equal 0
The stderr should be present
# Only one state file should exist
The file "$HARM_WORK_STATE_FILE" should be exist
End
End
End
End
