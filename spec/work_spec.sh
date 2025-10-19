#!/usr/bin/env bash
# ShellSpec tests for work session management

Describe 'lib/work.sh'
Include spec/helpers/env.sh

# Set up test work directory
BeforeAll 'export HARM_WORK_DIR="$TEST_TMP/work" && export HARM_WORK_STATE_FILE="$HARM_WORK_DIR/current_session.json" && mkdir -p "$HARM_WORK_DIR"'

# Clean up after tests
AfterAll 'rm -rf "$HARM_WORK_DIR"'

# Source the work module
BeforeAll 'source "$ROOT/lib/work.sh"'

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
BeforeEach 'rm -f "$HARM_WORK_STATE_FILE"*'

It 'starts a new work session'
export HARM_CLI_FORMAT=text
When call work_start "Test goal"
The status should be success
The error should include "Work session started"
The file "$HARM_WORK_STATE_FILE" should be exist
End

It 'saves session state as JSON'
export HARM_CLI_FORMAT=text
work_start "Test goal" >/dev/null 2>&1
The contents of file "$HARM_WORK_STATE_FILE" should include '"status": "active"'
The contents of file "$HARM_WORK_STATE_FILE" should include '"goal": "Test goal"'
End

It 'outputs JSON format when requested'
export HARM_CLI_FORMAT=json
When call work_start "Test goal"
The output should include '"status"'
The output should include '"goal"'
End

It 'fails if session already active'
work_start "First" >/dev/null 2>&1
When call work_start "Second"
The status should be failure
The error should include "already active"
End
End

Describe 'work_status'
BeforeEach 'rm -f "$HARM_WORK_STATE_FILE"*'

It 'shows inactive when no session'
export HARM_CLI_FORMAT=text
When call work_status
The output should include "No active work session"
End

It 'shows active session details'
export HARM_CLI_FORMAT=text
work_start "Test goal" >/dev/null 2>&1
sleep 1
When call work_status
The output should include "ACTIVE"
The output should include "Test goal"
The output should include "Elapsed"
End

It 'outputs JSON format'
export HARM_CLI_FORMAT=json
work_start "Test goal" >/dev/null 2>&1
When call work_status
The output should include '"goal"'
The output should include '"status"'
The output should include '"elapsed_seconds"'
End

It 'calculates elapsed time accurately (timezone bug test)'
export HARM_CLI_FORMAT=json
work_start "Test goal" >/dev/null 2>&1
sleep 2
result=$(work_status)
elapsed=$(echo "$result" | jq -r '.elapsed_seconds')
# Elapsed should be ~2 seconds, NOT hours off due to timezone bug
# Allow 1-5 seconds range for processing time
When call test "$elapsed" -ge 1 -a "$elapsed" -le 5
The status should be success
End
End

Describe 'work_stop'
It 'fails when no active session'
rm -f "$HARM_WORK_STATE_FILE"
When call work_stop
The status should be failure
The error should include "No active work session"
End

It 'stops active session'
export HARM_CLI_FORMAT=text
work_start "Test goal" >/dev/null 2>&1
sleep 1
When call work_stop
The status should be success
The error should include "Work session stopped"
The output should include "Duration"
End

It 'removes state file after stopping'
work_start "Test" >/dev/null 2>&1
work_stop >/dev/null 2>&1
The file "$HARM_WORK_STATE_FILE" should not be exist
End

It 'archives session to monthly file'
work_start "Test goal" >/dev/null 2>&1
sleep 1
work_stop >/dev/null 2>&1
archive_file="${HARM_WORK_DIR}/sessions_$(date '+%Y-%m').jsonl"
The file "$archive_file" should be exist
The contents of file "$archive_file" should include '"goal"'
End

It 'outputs JSON format'
export HARM_CLI_FORMAT=json
work_start "Test" >/dev/null 2>&1
sleep 1
When call work_stop
The status should be success
The output should include '"status"'
The output should include '"duration_seconds"'
The error should include "[INFO]"
End
It 'calculates duration accurately (timezone bug test)'
# This test verifies the timezone bug is fixed by checking actual duration
export HARM_CLI_FORMAT=json
work_start "Test goal" >/dev/null 2>&1
sleep 2
# Capture only stdout (JSON), stderr goes to log
result=$(work_stop 2>/dev/null)
duration=$(echo "$result" | jq -r '.duration_seconds' 2>/dev/null || echo "999")
# Duration should be ~2 seconds (1-5 range), NOT 7200+ (timezone bug)
When call test "$duration" -ge 1 -a "$duration" -le 5
The status should be success
End
End
End
