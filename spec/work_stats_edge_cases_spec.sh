#!/usr/bin/env bash
# ShellSpec tests for work_stats.sh edge cases
# Tests critical failure paths and edge cases

Describe 'lib/work_stats.sh edge cases'
Include spec/helpers/env.sh
Include spec/helpers/matchers.sh

# Set up test environment before sourcing work_stats.sh
setup_work_stats_test_env() {
  export HARM_LOG_LEVEL=ERROR # Suppress DEBUG/INFO logs during tests
  export HARM_WORK_DIR="$TEST_TMP/work"
  export HARM_CLI_HOME="$TEST_TMP/harm-cli"
  mkdir -p "$HARM_WORK_DIR" "$HARM_CLI_HOME"

  # Source dependencies in correct order
  source "$ROOT/lib/work_stats.sh"
}

# Clean up test artifacts
cleanup_work_stats_test_env() {
  rm -rf "$HARM_WORK_DIR"
  unset HARM_CLI_FORMAT
}

BeforeAll 'setup_work_stats_test_env'
AfterAll 'cleanup_work_stats_test_env'

# Helper to create archive file with test data
create_archive_file() {
  local month="${1:-$(date '+%Y-%m')}"
  local archive_file="${HARM_WORK_DIR}/sessions_${month}.jsonl"
  shift
  # Remaining args are JSON lines to write
  for line in "$@"; do
    echo "$line" >>"$archive_file"
  done
}

Describe 'work_stats_today edge cases'
BeforeEach 'cleanup_work_stats_test_env && mkdir -p "$HARM_WORK_DIR"'

Context 'missing archive file'
It 'handles missing archive file gracefully (text format)'
export HARM_CLI_FORMAT=text
When call work_stats_today
The status should equal 0
The output should include "No sessions recorded for today"
End

It 'handles missing archive file gracefully (JSON format)'
export HARM_CLI_FORMAT=json
When call work_stats_today
The status should equal 0
The output should start with "{"
The output should include '"sessions": 0'
The output should include '"total_duration_seconds": 0'
The output should include '"pomodoros": 0'
End
End

Context 'empty archive file'
It 'handles empty archive file without crashing'
export HARM_CLI_FORMAT=text
# Create empty archive
touch "${HARM_WORK_DIR}/sessions_$(date '+%Y-%m').jsonl"
When call work_stats_today
The status should equal 0
The output should include "Total work time"
The output should include "0s"
# Should not crash with format_duration error
The stderr should not include "format_duration"
The stderr should not include "must be an integer"
End

It 'outputs zero stats for empty archive (JSON)'
export HARM_CLI_FORMAT=json
touch "${HARM_WORK_DIR}/sessions_$(date '+%Y-%m').jsonl"
When call work_stats_today
The status should equal 0
The output should start with "{"
The output should include '"sessions": 0'
The output should include '"total_duration_seconds": 0'
End
End

Context 'no matching dates in archive'
It 'handles no sessions for today'
export HARM_CLI_FORMAT=text
local today
today=$(date '+%Y-%m-%d')
# Create archive with sessions from different days
create_archive_file "$(date '+%Y-%m')" \
  '{"start_time":"2025-01-01T10:00:00Z","duration_seconds":300,"pomodoro_count":1}' \
  '{"start_time":"2025-01-02T10:00:00Z","duration_seconds":600,"pomodoro_count":2}'

When call work_stats_today
The status should equal 0
# Should show 0 stats, not crash
The output should include "Pomodoros completed: 0"
The output should include "Total sessions: 0"
The output should include "Total work time: 0s"
End

It 'returns zero values when no matching dates (JSON)'
export HARM_CLI_FORMAT=json
create_archive_file "$(date '+%Y-%m')" \
  '{"start_time":"2025-01-01T10:00:00Z","duration_seconds":300,"pomodoro_count":1}'

When call work_stats_today
The status should equal 0
The output should start with "{"
The output should include '"sessions": 0'
The output should include '"total_duration_seconds": 0'
The output should include '"pomodoros": 0'
End
End

Context 'malformed data in archive'
It 'handles missing duration_seconds field'
export HARM_CLI_FORMAT=text
local today
today=$(date '+%Y-%m-%d')
# Session without duration_seconds
create_archive_file "$(date '+%Y-%m')" \
  "{\"start_time\":\"${today}T10:00:00Z\",\"pomodoro_count\":1}"

When call work_stats_today
The status should equal 0
# jq's "// 0" should provide default
The output should include "Total work time: 0s"
End

It 'handles null duration_seconds'
export HARM_CLI_FORMAT=text
local today
today=$(date '+%Y-%m-%d')
create_archive_file "$(date '+%Y-%m')" \
  "{\"start_time\":\"${today}T10:00:00Z\",\"duration_seconds\":null,\"pomodoro_count\":1}"

When call work_stats_today
The status should equal 0
The output should include "Total work time: 0s"
End

It 'handles negative duration_seconds'
export HARM_CLI_FORMAT=text
local today
today=$(date '+%Y-%m-%d')
create_archive_file "$(date '+%Y-%m')" \
  "{\"start_time\":\"${today}T10:00:00Z\",\"duration_seconds\":-100,\"pomodoro_count\":1}"

When call work_stats_today
The status should equal 0
The output should include "Total work time"
# Negative values should sum correctly (jq doesn't validate)
# format_duration will fail if receives negative, so this tests the path
End

It 'handles non-numeric duration_seconds'
export HARM_CLI_FORMAT=json
local today
today=$(date '+%Y-%m-%d')
# Invalid JSON will cause jq to fail gracefully
create_archive_file "$(date '+%Y-%m')" \
  "{\"start_time\":\"${today}T10:00:00Z\",\"duration_seconds\":\"invalid\",\"pomodoro_count\":1}"

# Should handle gracefully, may return 0 or error
When call work_stats_today
The status should equal 0
The output should start with "{"
End

It 'handles missing pomodoro_count field'
export HARM_CLI_FORMAT=text
local today
today=$(date '+%Y-%m-%d')
create_archive_file "$(date '+%Y-%m')" \
  "{\"start_time\":\"${today}T10:00:00Z\",\"duration_seconds\":300}"

When call work_stats_today
The status should equal 0
The output should include "Pomodoros completed: 0"
End
End
End

Describe 'work_stats_week edge cases'
BeforeEach 'cleanup_work_stats_test_env && mkdir -p "$HARM_WORK_DIR"'

Context 'missing archive file'
It 'handles missing archive gracefully (text)'
export HARM_CLI_FORMAT=text
When call work_stats_week
The status should equal 0
The output should include "No sessions recorded for this week"
End

It 'handles missing archive gracefully (JSON)'
export HARM_CLI_FORMAT=json
When call work_stats_week
The status should equal 0
The output should start with "{"
The output should include '"sessions": 0'
The output should include '"total_duration_seconds": 0'
End
End

Context 'empty archive file'
It 'handles empty archive without format_duration error'
export HARM_CLI_FORMAT=text
touch "${HARM_WORK_DIR}/sessions_$(date '+%Y-%m').jsonl"
When call work_stats_week
The status should equal 0
The output should include "Total work time: 0s"
The stderr should not include "must be an integer"
End

It 'returns valid JSON for empty archive'
export HARM_CLI_FORMAT=json
touch "${HARM_WORK_DIR}/sessions_$(date '+%Y-%m').jsonl"
When call work_stats_week
The status should equal 0
The output should start with "{"
The output should include '"sessions": 0'
The output should include '"total_duration_seconds": 0'
End
End
End

Describe 'work_stats_month edge cases'
BeforeEach 'cleanup_work_stats_test_env && mkdir -p "$HARM_WORK_DIR"'

Context 'missing archive file'
It 'handles missing archive gracefully (text)'
export HARM_CLI_FORMAT=text
When call work_stats_month
The status should equal 0
local current_month
current_month=$(date '+%Y-%m')
The output should include "No sessions recorded for $current_month"
End

It 'handles missing archive gracefully (JSON)'
export HARM_CLI_FORMAT=json
When call work_stats_month
The status should equal 0
The output should start with "{"
The output should include '"sessions": 0'
The output should include '"total_duration_seconds": 0'
End
End

Context 'empty archive file'
It 'handles empty archive without division by zero'
export HARM_CLI_FORMAT=text
touch "${HARM_WORK_DIR}/sessions_$(date '+%Y-%m').jsonl"
When call work_stats_month
The status should equal 0
# Should handle 0 sessions without crash
The output should include "Total sessions: 0"
The output should include "Total work time: 0s"
The output should include "Average per day: 0s"
End

It 'handles empty archive in JSON format'
export HARM_CLI_FORMAT=json
touch "${HARM_WORK_DIR}/sessions_$(date '+%Y-%m').jsonl"
When call work_stats_month
The status should equal 0
The output should start with "{"
The output should include '"sessions": 0'
The output should include '"total_duration_seconds": 0'
End
End
End

Describe 'work_break_compliance edge cases'
BeforeEach 'cleanup_work_stats_test_env && mkdir -p "$HARM_WORK_DIR"'

Context 'missing files'
It 'handles missing breaks file gracefully (text)'
export HARM_CLI_FORMAT=text
When call work_break_compliance
The status should equal 0
The output should include "No break data available"
End

It 'handles missing breaks file gracefully (JSON)'
export HARM_CLI_FORMAT=json
When call work_break_compliance
The status should equal 0
The output should start with "{"
The output should include '"breaks_taken": 0'
The output should include '"breaks_expected": 0'
End
End

Context 'empty breaks file'
It 'handles empty breaks file without division by zero'
export HARM_CLI_FORMAT=text
local current_month
current_month=$(date '+%Y-%m')
touch "${HARM_WORK_DIR}/breaks_${current_month}.jsonl"

When call work_break_compliance
The status should equal 0
The output should include "Breaks taken: 0"
The output should include "Compliance rate: 0%"
The output should include "Completion rate: 0%"
End
End
End
End
