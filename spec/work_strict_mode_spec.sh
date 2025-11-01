#!/usr/bin/env bash
# ShellSpec tests for work strict mode features

Describe 'lib/work.sh - Strict Mode'
Include spec/helpers/env.sh

# Set up test work directory and source work module
setup_strict_mode_test_env() {
  export HARM_WORK_DIR="$TEST_TMP/work"
  export HARM_WORK_STATE_FILE="$HARM_WORK_DIR/current_session.json"
  export HARM_WORK_ENFORCEMENT_FILE="$HARM_WORK_DIR/enforcement.json"
  export HARM_BREAK_STATE_FILE="$HARM_WORK_DIR/current_break.json"
  export HARM_CLI_HOME="$TEST_TMP/harm-cli"
  export HARM_WORK_ENFORCEMENT="strict"
  mkdir -p "$HARM_WORK_DIR" "$HARM_CLI_HOME"
  source "$ROOT/lib/work.sh"
}

# Clean up work session artifacts
cleanup_strict_mode_session() {
  work_stop_timer 2>/dev/null || true
  rm -f "$HARM_WORK_STATE_FILE"* 2>/dev/null || true
  rm -f "$HARM_WORK_ENFORCEMENT_FILE"* 2>/dev/null || true
  rm -f "$HARM_BREAK_STATE_FILE"* 2>/dev/null || true
  rm -f "$HARM_WORK_DIR"/*.pid 2>/dev/null || true
  rm -f "$HARM_WORK_DIR"/*.jsonl 2>/dev/null || true
}

BeforeAll 'setup_strict_mode_test_env'

cleanup_strict_mode_test_env() {
  cleanup_strict_mode_session
  rm -rf "$HARM_WORK_DIR"
}

AfterAll 'cleanup_strict_mode_test_env'

Describe 'Strict Mode Options'
It 'has strict_block_project_switch option'
When call options_get strict_block_project_switch
The status should be success
The output should equal "0"
End

It 'has strict_require_break option'
When call options_get strict_require_break
The status should be success
The output should equal "0"
End

It 'has strict_confirm_early_stop option'
When call options_get strict_confirm_early_stop
The status should be success
The output should equal "0"
End

It 'has strict_track_breaks option'
When call options_get strict_track_breaks
The status should be success
The output should equal "0"
End
End

Describe 'Project Switch Blocking'
BeforeEach 'cleanup_strict_mode_session'

Context 'when strict_block_project_switch is disabled'
It 'allows project switches with warning'
export HARM_STRICT_BLOCK_PROJECT_SWITCH=0

# Start session and set active project
work_start "Test goal" >/dev/null 2>&1
export _WORK_ACTIVE_PROJECT="test-project"
work_enforcement_save_state

# Simulate project switch (should warn but not block)
When call work_check_project_switch "/home/user/test-project" "/home/user/other-project"
The status should be success
The error should include "CONTEXT SWITCH DETECTED"
End
End

Context 'when strict_block_project_switch is enabled'
It 'blocks project switches'
export HARM_STRICT_BLOCK_PROJECT_SWITCH=1

# Start session and set active project
work_start "Test goal" >/dev/null 2>&1
export _WORK_ACTIVE_PROJECT="test-project"
work_enforcement_save_state

# Simulate project switch (should block)
When call work_check_project_switch "/home/user/test-project" "/home/user/other-project"
The status should be failure
The error should include "PROJECT SWITCH BLOCKED"
End

It 'blocks work_start in different project'
export HARM_STRICT_BLOCK_PROJECT_SWITCH=1

# Set active project from previous session
export _WORK_ACTIVE_PROJECT="other-project"
work_enforcement_save_state

# Try to start session in current directory (different project)
When call work_start "New task"
The status should be failure
The error should include "Project switch blocked"
End
End
End

Describe 'Break Requirement Enforcement'
BeforeEach 'cleanup_strict_mode_session'

Context 'when strict_require_break is disabled'
It 'allows starting session without break'
export HARM_STRICT_REQUIRE_BREAK=0

# Stop a session (sets break_required flag)
work_start "Test goal" >/dev/null 2>&1
work_stop >/dev/null 2>&1

# Should allow starting new session immediately
When call work_start "New session"
The status should be success
End
End

Context 'when strict_require_break is enabled'
It 'blocks new session when break required'
export HARM_STRICT_REQUIRE_BREAK=1

# Create enforcement state with break_required flag
echo '{"break_required": true, "break_type_required": "short"}' >"$HARM_WORK_ENFORCEMENT_FILE"

When call work_start "New task"
The status should be failure
The error should include "Break required"
End

It 'sets break_required flag after work_stop'
export HARM_STRICT_REQUIRE_BREAK=1

work_start "Test goal" >/dev/null 2>&1
When call work_stop
The status should be success
The file "$HARM_WORK_ENFORCEMENT_FILE" should be exist
The contents of file "$HARM_WORK_ENFORCEMENT_FILE" should include '"break_required": true'
End

It 'clears break_required after completing break'
export HARM_STRICT_REQUIRE_BREAK=1
export HARM_STRICT_TRACK_BREAKS=1

# Set break_required flag
echo '{"break_required": true, "break_type_required": "short"}' >"$HARM_WORK_ENFORCEMENT_FILE"

# Start and complete a break (simulate full duration)
export HARM_BREAK_SHORT=1 # 1 second for testing
break_start 1 "short" >/dev/null 2>&1
sleep 2 # Ensure >= 80% of duration
When call break_stop
The status should be success
The contents of file "$HARM_WORK_ENFORCEMENT_FILE" should include '"break_required": false'
End
End
End

Describe 'Early Termination Detection'
BeforeEach 'cleanup_strict_mode_session'

It 'detects early session termination'
export HARM_WORK_DURATION=100 # 100 seconds expected

# Start session
work_start "Test goal" >/dev/null 2>&1

# Immediately stop (way less than 80% of 100s)
# Note: In non-interactive mode, no confirmation prompt
export HARM_STRICT_CONFIRM_EARLY_STOP=0
When call work_stop
The status should be success

# Check archived session has early_stop flag
archive_file="${HARM_WORK_DIR}/sessions_$(date '+%Y-%m').jsonl"
The file "$archive_file" should be exist
The contents of file "$archive_file" should include '"early_stop": true'
End

It 'archives termination reason when provided'
Skip "Requires interactive input simulation - manual test only"
End
End

Describe 'Break Archiving'
BeforeEach 'cleanup_strict_mode_session'

Context 'when strict_track_breaks is disabled'
It 'does not archive breaks'
export HARM_STRICT_TRACK_BREAKS=0
export HARM_BREAK_SHORT=1

break_start 1 "short" >/dev/null 2>&1
sleep 2
When call break_stop
The status should be success

breaks_file="${HARM_WORK_DIR}/breaks_$(date '+%Y-%m').jsonl"
The file "$breaks_file" should not be exist
End
End

Context 'when strict_track_breaks is enabled'
It 'archives break sessions'
export HARM_STRICT_TRACK_BREAKS=1
export HARM_BREAK_SHORT=10

break_start 10 "short" >/dev/null 2>&1
sleep 2 # Short break, not fully completed
When call break_stop
The status should be success

breaks_file="${HARM_WORK_DIR}/breaks_$(date '+%Y-%m').jsonl"
The file "$breaks_file" should be exist
The contents of file "$breaks_file" should include '"type": "short"'
The contents of file "$breaks_file" should include '"completed_fully"'
End

It 'marks break as completed when >= 80% duration'
export HARM_STRICT_TRACK_BREAKS=1
export HARM_BREAK_SHORT=1

break_start 1 "short" >/dev/null 2>&1
sleep 2 # >= 80% of 1 second
When call break_stop
The status should be success

breaks_file="${HARM_WORK_DIR}/breaks_$(date '+%Y-%m').jsonl"
The contents of file "$breaks_file" should include '"completed_fully": true'
End

It 'marks break as incomplete when < 80% duration'
export HARM_STRICT_TRACK_BREAKS=1
export HARM_BREAK_SHORT=10

break_start 10 "short" >/dev/null 2>&1
sleep 1 # < 80% of 10 seconds
When call break_stop
The status should be success

breaks_file="${HARM_WORK_DIR}/breaks_$(date '+%Y-%m').jsonl"
The contents of file "$breaks_file" should include '"completed_fully": false'
End
End
End

Describe 'Break Compliance Reporting'
BeforeEach 'cleanup_strict_mode_session'

It 'shows message when no break data'
When call work_break_compliance
The status should be success
The output should include "No break data available"
End

It 'calculates compliance metrics'
export HARM_STRICT_TRACK_BREAKS=1

# Create sample break history
breaks_file="${HARM_WORK_DIR}/breaks_$(date '+%Y-%m').jsonl"
echo '{"start_time":"2025-10-31T10:00:00Z","end_time":"2025-10-31T10:05:00Z","duration_seconds":300,"planned_duration_seconds":300,"type":"short","completed_fully":true}' >"$breaks_file"
echo '{"start_time":"2025-10-31T11:00:00Z","end_time":"2025-10-31T11:03:00Z","duration_seconds":180,"planned_duration_seconds":300,"type":"short","completed_fully":false}' >>"$breaks_file"

# Create sample work sessions
sessions_file="${HARM_WORK_DIR}/sessions_$(date '+%Y-%m').jsonl"
echo '{"start_time":"2025-10-31T09:30:00Z","end_time":"2025-10-31T10:00:00Z","duration_seconds":1800,"goal":"Task 1","pomodoro_count":1}' >"$sessions_file"
echo '{"start_time":"2025-10-31T10:30:00Z","end_time":"2025-10-31T11:00:00Z","duration_seconds":1800,"goal":"Task 2","pomodoro_count":2}' >>"$sessions_file"

When call work_break_compliance
The status should be success
The output should include "Work sessions: 2"
The output should include "Breaks taken: 2"
The output should include "Breaks completed fully: 1"
The output should include "Compliance rate: 100%"
The output should include "Completion rate: 50%"
End

It 'provides feedback based on compliance'
export HARM_STRICT_TRACK_BREAKS=1

# Create sample with low compliance
breaks_file="${HARM_WORK_DIR}/breaks_$(date '+%Y-%m').jsonl"
echo '{"start_time":"2025-10-31T10:00:00Z","end_time":"2025-10-31T10:05:00Z","duration_seconds":300,"planned_duration_seconds":300,"type":"short","completed_fully":true}' >"$breaks_file"

sessions_file="${HARM_WORK_DIR}/sessions_$(date '+%Y-%m').jsonl"
echo '{"start_time":"2025-10-31T09:30:00Z","end_time":"2025-10-31T10:00:00Z","duration_seconds":1800,"goal":"Task 1","pomodoro_count":1}' >"$sessions_file"
echo '{"start_time":"2025-10-31T10:30:00Z","end_time":"2025-10-31T11:00:00Z","duration_seconds":1800,"goal":"Task 2","pomodoro_count":2}' >>"$sessions_file"
echo '{"start_time":"2025-10-31T11:30:00Z","end_time":"2025-10-31T12:00:00Z","duration_seconds":1800,"goal":"Task 3","pomodoro_count":3}' >>"$sessions_file"

When call work_break_compliance
The status should be success
The output should include "Warning: Less than half of work sessions followed by breaks"
End
End

Describe 'Integration - Full Strict Workflow'
BeforeEach 'cleanup_strict_mode_session'

It 'enforces complete strict workflow'
export HARM_STRICT_BLOCK_PROJECT_SWITCH=1
export HARM_STRICT_REQUIRE_BREAK=1
export HARM_STRICT_TRACK_BREAKS=1
export HARM_WORK_DURATION=5
export HARM_BREAK_SHORT=2

# 1. Start work session
work_start "Task 1" >/dev/null 2>&1
The file "$HARM_WORK_STATE_FILE" should be exist

# 2. Stop work session (sets break_required)
work_stop >/dev/null 2>&1
The file "$HARM_WORK_ENFORCEMENT_FILE" should be exist
The contents of file "$HARM_WORK_ENFORCEMENT_FILE" should include '"break_required": true'

# 3. Try to start new session without break (should fail)
When call work_start "Task 2"
The status should be failure
The error should include "Break required"

# 4. Take break
break_start 2 "short" >/dev/null 2>&1
sleep 3 # Complete break
break_stop >/dev/null 2>&1

# 5. Now should be able to start new session
When call work_start "Task 2"
The status should be success
End
End

# Close the top-level Describe block from line 4
End
