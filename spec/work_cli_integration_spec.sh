#!/usr/bin/env bash
# ShellSpec tests for work CLI command integration
#
# Tests the actual CLI command routing through bin/harm-cli dispatcher
# to catch integration failures that unit tests miss.
#
# Coverage:
# - work violations command (QA Issue #1)
# - work reset-violations command (QA Issue #2)
# - work set-mode command (QA Issue #3)
# - work stats with JSON format (QA Issue #4)
# - Command routing and help text accuracy

Describe 'Work CLI Integration Tests'
Include spec/helpers/env.sh

BeforeAll 'export HARM_LOG_LEVEL=ERROR'

# Setup test environment before all tests
setup_cli_test_env() {
  export HARM_WORK_DIR="$TEST_TMP/work"
  export HARM_WORK_STATE_FILE="$HARM_WORK_DIR/current_session.json"
  export HARM_WORK_ENFORCEMENT_FILE="$HARM_WORK_DIR/enforcement.json"
  export HARM_CLI_HOME="$TEST_TMP/harm-cli"
  export HARM_CLI_LOG_LEVEL="ERROR" # Quiet during tests

  mkdir -p "$HARM_WORK_DIR" "$HARM_CLI_HOME"
}

# Clean up after all tests
cleanup_cli_test_env() {
  rm -rf "$HARM_WORK_DIR" "$HARM_CLI_HOME"
}

BeforeAll 'setup_cli_test_env'
AfterAll 'cleanup_cli_test_env'

# Clean up between tests
cleanup_between_tests() {
  rm -f "$HARM_WORK_STATE_FILE"* 2>/dev/null || true
  rm -f "$HARM_WORK_ENFORCEMENT_FILE"* 2>/dev/null || true
  rm -f "$HARM_WORK_DIR"/*.pid 2>/dev/null || true
}

BeforeEach 'cleanup_between_tests'

# ═══════════════════════════════════════════════════════════════
# QA Issue #1: work violations command missing
# ═══════════════════════════════════════════════════════════════

Describe 'harm-cli work violations'
Context 'when no active session'
It 'returns violation count (defaults to 0)'
When run "$CLI" work violations
The status should be success
The output should include "0"
End
End

Context 'when violations exist'
# Setup: Create enforcement file with violations
setup_violations() {
  echo '{"mode":"moderate","violations":3,"active_project":"test-project"}' >"$HARM_WORK_ENFORCEMENT_FILE"
}

BeforeEach 'setup_violations'

It 'returns current violation count'
When run "$CLI" work violations
The status should be success
The output should include "3"
End
End

Context 'JSON output format'
setup_violations() {
  echo '{"mode":"moderate","violations":5,"active_project":"test"}' >"$HARM_WORK_ENFORCEMENT_FILE"
}

BeforeEach 'setup_violations'

It 'supports JSON format via HARM_CLI_FORMAT'
export HARM_CLI_FORMAT=json
When run "$CLI" work violations
The status should be success
The output should include "5"
unset HARM_CLI_FORMAT
End

It 'supports --format json flag'
When run "$CLI" --format json work violations
The status should be success
The output should include "5"
End
End
End

# ═══════════════════════════════════════════════════════════════
# QA Issue #2: work reset-violations command missing
# ═══════════════════════════════════════════════════════════════

Describe 'harm-cli work reset-violations'
Context 'resetting violation counter'
setup_violations() {
  echo '{"mode":"moderate","violations":10,"active_project":"test"}' >"$HARM_WORK_ENFORCEMENT_FILE"
}

BeforeEach 'setup_violations'

It 'resets violation count to 0'
When run "$CLI" work reset-violations
The status should be success
The output should include "reset"
End

It 'persists reset to enforcement file'
"$CLI" work reset-violations >/dev/null 2>&1
violations=$("$CLI" work violations)
The value "$violations" should equal "0"
End

It 'logs the reset operation'
When run "$CLI" work reset-violations
The output should include "✓"
The output should include "Violation counter reset"
End
End

Context 'when no violations exist'
It 'succeeds even when counter already at 0'
When run "$CLI" work reset-violations
The status should be success
The output should include "reset"
End
End
End

# ═══════════════════════════════════════════════════════════════
# QA Issue #3: work set-mode command missing
# ═══════════════════════════════════════════════════════════════

Describe 'harm-cli work set-mode'
Context 'setting enforcement mode'
# Valid modes to test
Parameters
strict "strict"
moderate "moderate"
coaching "coaching"
off "off"
End

It "accepts valid mode: $1"
When run "$CLI" work set-mode "$2"
The status should be success
The output should include "set to"
The output should include "$2"
End
End

Context 'invalid mode'
It 'rejects invalid mode'
When run "$CLI" work set-mode invalid-mode
The status should be failure
The error should include "Invalid mode"
End

It 'rejects empty mode'
When run "$CLI" work set-mode
The status should be failure
The error should include "required"
End
End

Context 'output format'
It 'provides clear success message'
When run "$CLI" work set-mode moderate
The status should be success
The output should include "✓"
The output should include "Enforcement mode set to: moderate"
End

It 'warns about shell restart requirement'
When run "$CLI" work set-mode strict
The status should be success
The output should include "Restart shell"
End
End
End

# ═══════════════════════════════════════════════════════════════
# QA Issue #4: work stats JSON format compliance
# ═══════════════════════════════════════════════════════════════

Describe 'harm-cli work stats'
Context 'JSON format output'
# Create sample session data
setup_session_data() {
  local current_month
  current_month=$(date '+%Y-%m')
  local archive_file="$HARM_WORK_DIR/sessions_${current_month}.jsonl"

  # Add test sessions
  local today
  today=$(date '+%Y-%m-%d')
  echo "{\"status\":\"completed\",\"start_time\":\"${today}T10:00:00Z\",\"end_time\":\"${today}T10:25:00Z\",\"duration_seconds\":1500,\"goal\":\"Test task 1\",\"pomodoro_count\":1}" >>"$archive_file"
  echo "{\"status\":\"completed\",\"start_time\":\"${today}T11:00:00Z\",\"end_time\":\"${today}T11:25:00Z\",\"duration_seconds\":1500,\"goal\":\"Test task 2\",\"pomodoro_count\":2}" >>"$archive_file"
}

BeforeEach 'setup_session_data'

It 'outputs valid JSON for stats today'
export HARM_CLI_FORMAT=json
When run "$CLI" work stats today
The status should be success
# Should be valid JSON - check if jq can parse it
The output should start with "{"
The output should include '"date"'
unset HARM_CLI_FORMAT
End

It 'includes required fields in JSON output'
export HARM_CLI_FORMAT=json
When run "$CLI" work stats today
The status should be success
The output should include '"date"'
The output should include '"sessions"'
The output should include '"total_duration_seconds"'
unset HARM_CLI_FORMAT
End

It 'outputs valid JSON for stats week'
export HARM_CLI_FORMAT=json
When run "$CLI" work stats week
The status should be success
The output should start with "{"
unset HARM_CLI_FORMAT
End

It 'outputs valid JSON for stats month'
export HARM_CLI_FORMAT=json
When run "$CLI" work stats month
The status should be success
The output should start with "{"
unset HARM_CLI_FORMAT
End
End

Context 'text format output'
setup_session_data() {
  local current_month
  current_month=$(date '+%Y-%m')
  local archive_file="$HARM_WORK_DIR/sessions_${current_month}.jsonl"

  local today
  today=$(date '+%Y-%m-%d')
  echo "{\"status\":\"completed\",\"start_time\":\"${today}T10:00:00Z\",\"end_time\":\"${today}T10:25:00Z\",\"duration_seconds\":1500,\"goal\":\"Test\",\"pomodoro_count\":1}" >>"$archive_file"
}

BeforeEach 'setup_session_data'

It 'outputs human-readable text by default'
unset HARM_CLI_FORMAT
When run "$CLI" work stats today
The status should be success
The output should not include '{"'
The output should include "Work Statistics"
End

It 'shows session count in text format'
When run "$CLI" work stats today
The status should be success
The output should include "Total sessions:"
End
End

Context 'empty data'
# Clean environment - remove all session files
setup_empty_env() {
  rm -f "$HARM_WORK_DIR"/*.jsonl 2>/dev/null || true
}

BeforeEach 'setup_empty_env'

It 'handles no sessions gracefully in JSON format'
export HARM_CLI_FORMAT=json
When run "$CLI" work stats today
The status should be success
The output should start with "{"
The output should include '"sessions": 0'
unset HARM_CLI_FORMAT
End

It 'handles no sessions gracefully in text format'
When run "$CLI" work stats today
The status should be success
The output should include "No sessions"
End
End
End

# ═══════════════════════════════════════════════════════════════
# Command Routing Tests
# ═══════════════════════════════════════════════════════════════

Describe 'Work command routing'
Context 'dispatcher integration'

check_status_output() {
  echo "$1" | grep -qE "(ACTIVE|No active work session)"
}

It 'routes work start through CLI dispatcher'
When run "$CLI" work start "Test goal"
The status should be success
The stderr should include "Work session started"
The output should include "Goal: Test goal"
The output should include "Duration: 25 minutes"
End

It 'routes work stop through CLI dispatcher'
# Clean up and start a session first
"$CLI" break stop >/dev/null 2>&1 || true
"$CLI" work reset >/dev/null 2>&1 || true
"$CLI" work start "Test" >/dev/null 2>&1
When run "$CLI" work stop
The status should be success
The stderr should include "stopped"
The output should include "Goal: Test"
The output should include "Auto-starting short break"
End

It 'routes work status through CLI dispatcher'
When run "$CLI" work status
The status should be success
# Either shows active session or no session message - both are valid
# Just verify it ran successfully and produced some output
The output should not equal ""
End

It 'routes work reset through CLI dispatcher'
When run "$CLI" work reset
The status should be success
The output should include "reset"
End
End

Context 'error handling'
It 'shows error for unknown work subcommand'
When run "$CLI" work invalid-subcommand
The status should be failure
The error should include "Unknown work command"
End

It 'provides helpful error message'
When run "$CLI" work invalid-subcommand
The status should be failure
The error should include "Try:"
End
End
End

# ═══════════════════════════════════════════════════════════════
# Help Text Accuracy Tests
# ═══════════════════════════════════════════════════════════════

Describe 'Work help text accuracy'
Context 'documented commands exist'
# These commands are documented in --help but may not be implemented

It 'documents violations command'
When run "$CLI" work --help
The output should include "violations"
End

It 'documents reset-violations command'
When run "$CLI" work --help
The output should include "reset-violations"
End

It 'documents set-mode command'
When run "$CLI" work --help
The output should include "set-mode"
End

It 'documents stats command'
When run "$CLI" work --help
The output should include "stats"
End

It 'documents enforcement modes'
When run "$CLI" work --help
The output should include "strict"
The output should include "moderate"
The output should include "coaching"
End
End

Context 'help command works'
It 'shows help with --help flag'
When run "$CLI" work --help
The status should be success
The output should include "Work Commands"
End

It 'shows help with -h flag'
When run "$CLI" work -h
The status should be success
The output should include "Work Commands"
End
End
End

# ═══════════════════════════════════════════════════════════════
# Break Command Integration (from bin/harm-cli lines 469-476)
# ═══════════════════════════════════════════════════════════════

Describe 'Break command routing edge case'
Context 'violations/reset-violations/set-mode under break command'
# In bin/harm-cli lines 469-476, these commands are routed under 'break'
# This is likely a bug, but we test current behavior

It 'routes violations through break dispatcher (current behavior)'
setup_violations() {
  echo '{"mode":"moderate","violations":7,"active_project":"test"}' >"$HARM_WORK_ENFORCEMENT_FILE"
}
setup_violations
When run "$CLI" break violations
The status should be success
The output should include "7"
End

It 'routes reset-violations through break dispatcher (current behavior)'
setup_violations() {
  echo '{"mode":"moderate","violations":8,"active_project":"test"}' >"$HARM_WORK_ENFORCEMENT_FILE"
}
setup_violations
When run "$CLI" break reset-violations
The status should be success
The output should include "reset"
End

It 'routes set-mode through break dispatcher (current behavior)'
When run "$CLI" break set-mode moderate
The status should be success
The output should include "set to"
End
End
End

# ═══════════════════════════════════════════════════════════════
# End-to-End Integration Tests
# ═══════════════════════════════════════════════════════════════

Describe 'End-to-end work session flow'
Context 'complete workflow'
It 'starts a work session'
When run "$CLI" work start "Integration test task"
The status should be success
The stderr should include "Work session started"
The output should include "Goal: Integration test task"
The output should include "Duration: 25 minutes"
End

It 'shows status for active session'
"$CLI" work start "Test" >/dev/null 2>&1
When run "$CLI" work status
The status should be success
The output should include "ACTIVE"
End

It 'stops a work session and archives it'
# Clean up any existing sessions
"$CLI" break stop >/dev/null 2>&1 || true
"$CLI" work reset >/dev/null 2>&1 || true
# Start fresh session
"$CLI" work start "Test" >/dev/null 2>&1
When run "$CLI" work stop
The status should be success
The stderr should include "Work session stopped"
The output should include "Goal: Test"
The output should include "Auto-starting short break"
# Verify session archived
The path "$HARM_WORK_DIR/sessions_$(date '+%Y-%m').jsonl" should be exist
End
End

Context 'enforcement workflow'
It 'sets enforcement mode'
When run "$CLI" work set-mode moderate
The status should be success
The output should include "Enforcement mode set to: moderate"
End

It 'tracks violations'
echo '{"mode":"moderate","violations":5,"active_project":"test"}' >"$HARM_WORK_ENFORCEMENT_FILE"
When run "$CLI" work violations
The status should be success
The output should equal "5"
End

It 'resets violations'
echo '{"mode":"moderate","violations":5,"active_project":"test"}' >"$HARM_WORK_ENFORCEMENT_FILE"
"$CLI" work reset-violations >/dev/null 2>&1
When run "$CLI" work violations
The status should be success
The output should equal "0"
End
End

Context 'stats workflow'
setup_stats_data() {
  current_month=$(date '+%Y-%m')
  archive_file="$HARM_WORK_DIR/sessions_${current_month}.jsonl"
  today=$(date '+%Y-%m-%d')
  echo "{\"status\":\"completed\",\"start_time\":\"${today}T10:00:00Z\",\"end_time\":\"${today}T10:25:00Z\",\"duration_seconds\":1500,\"goal\":\"Stats test\",\"pomodoro_count\":1}" >>"$archive_file"
}

It 'queries stats for today'
setup_stats_data
When run "$CLI" work stats today
The status should be success
The output should include "Work Statistics"
End

It 'queries stats for week'
setup_stats_data
When run "$CLI" work stats week
The status should be success
The output should include "Work Statistics"
End

It 'queries stats for month'
setup_stats_data
When run "$CLI" work stats month
The status should be success
The output should include "Work Statistics"
End
End
End

# ═══════════════════════════════════════════════════════════════
# Format Flag Consistency Tests
# ═══════════════════════════════════════════════════════════════

Describe 'Output format consistency'
Context 'global --format flag'
It 'respects global --format json flag for stats'
setup_session_data() {
  local current_month
  current_month=$(date '+%Y-%m')
  local archive_file="$HARM_WORK_DIR/sessions_${current_month}.jsonl"
  local today
  today=$(date '+%Y-%m-%d')
  echo "{\"status\":\"completed\",\"start_time\":\"${today}T10:00:00Z\",\"duration_seconds\":1500,\"goal\":\"Test\",\"pomodoro_count\":1}" >>"$archive_file"
}
setup_session_data

When run "$CLI" --format json work stats today
The status should be success
The output should start with "{"
End

It 'respects global -F json flag for stats'
setup_session_data() {
  local current_month
  current_month=$(date '+%Y-%m')
  local archive_file="$HARM_WORK_DIR/sessions_${current_month}.jsonl"
  local today
  today=$(date '+%Y-%m-%d')
  echo "{\"status\":\"completed\",\"start_time\":\"${today}T10:00:00Z\",\"duration_seconds\":1500,\"goal\":\"Test\",\"pomodoro_count\":1}" >>"$archive_file"
}
setup_session_data

When run "$CLI" -F json work stats today
The status should be success
The output should start with "{"
End
End

Context 'HARM_CLI_FORMAT environment variable'
It 'respects HARM_CLI_FORMAT=json'
setup_session_data() {
  local current_month
  current_month=$(date '+%Y-%m')
  local archive_file="$HARM_WORK_DIR/sessions_${current_month}.jsonl"
  local today
  today=$(date '+%Y-%m-%d')
  echo "{\"status\":\"completed\",\"start_time\":\"${today}T10:00:00Z\",\"duration_seconds\":1500,\"goal\":\"Test\",\"pomodoro_count\":1}" >>"$archive_file"
}
setup_session_data

export HARM_CLI_FORMAT=json
When run "$CLI" work stats today
The status should be success
The output should start with "{"
unset HARM_CLI_FORMAT
End
End
End

End
