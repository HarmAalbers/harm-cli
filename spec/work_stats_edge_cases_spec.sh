#!/usr/bin/env bash
# ShellSpec tests for work_stats.sh edge cases
# Tests critical failure paths that cause format_duration errors

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
The output should be valid_json
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
# Should not crash with format_duration error
The stderr should not include "format_duration"
The stderr should not include "must be an integer"
End

It 'outputs zero stats for empty archive (JSON)'
export HARM_CLI_FORMAT=json
touch "${HARM_WORK_DIR}/sessions_$(date '+%Y-%m').jsonl"
When call work_stats_today
The status should equal 0
The output should be valid_json
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
The output should be valid_json
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

Context 'valid data scenarios'
It 'formats valid duration correctly'
export HARM_CLI_FORMAT=text
local today
today=$(date '+%Y-%m-%d')
create_archive_file "$(date '+%Y-%m')" \
  "{\"start_time\":\"${today}T10:00:00Z\",\"duration_seconds\":3665,\"pomodoro_count\":2}"

When call work_stats_today
The status should equal 0
# 3665 seconds = 1h1m5s
The output should include "1h1m5s"
The output should include "Pomodoros completed: 2"
The output should include "Total sessions: 1"
End

It 'aggregates multiple sessions correctly'
export HARM_CLI_FORMAT=json
local today
today=$(date '+%Y-%m-%d')
create_archive_file "$(date '+%Y-%m')" \
  "{\"start_time\":\"${today}T10:00:00Z\",\"duration_seconds\":1500,\"pomodoro_count\":1}" \
  "{\"start_time\":\"${today}T14:00:00Z\",\"duration_seconds\":1800,\"pomodoro_count\":2}"

When call work_stats_today
The status should equal 0
The output should be valid_json
The output should include '"sessions": 2'
The output should include '"total_duration_seconds": 3300'
The output should include '"pomodoros": 2'
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
The output should be valid_json
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
The output should be valid_json
The output should include '"sessions": 0'
The output should include '"total_duration_seconds": 0'
End
End

Context 'no matching sessions in date range'
It 'handles no sessions this week'
export HARM_CLI_FORMAT=text
# Add old sessions (before this week)
create_archive_file "$(date '+%Y-%m')" \
  '{"start_time":"2025-01-01T10:00:00Z","duration_seconds":300,"pomodoro_count":1}'

When call work_stats_week
The status should equal 0
The output should include "Pomodoros completed: 0"
The output should include "Total sessions: 0"
The output should include "Total work time: 0s"
End
End

Context 'malformed data handling'
It 'handles sessions with missing duration_seconds'
export HARM_CLI_FORMAT=text
local week_start
week_start=$(date -v-mon '+%Y-%m-%d' 2>/dev/null || date -d 'last monday' '+%Y-%m-%d' 2>/dev/null)
create_archive_file "$(date '+%Y-%m')" \
  "{\"start_time\":\"${week_start}T10:00:00Z\",\"pomodoro_count\":1}"

When call work_stats_week
The status should equal 0
# awk '{sum+=$1} END {print sum+0}' should handle empty input
The output should include "Total work time: 0s"
End

It 'handles null values from jq queries'
export HARM_CLI_FORMAT=text
local week_start
week_start=$(date -v-mon '+%Y-%m-%d' 2>/dev/null || date -d 'last monday' '+%Y-%m-%d' 2>/dev/null)
create_archive_file "$(date '+%Y-%m')" \
  "{\"start_time\":\"${week_start}T10:00:00Z\",\"duration_seconds\":null,\"pomodoro_count\":null}"

When call work_stats_week
The status should equal 0
The output should include "Pomodoros completed: 0"
The output should include "Total work time: 0s"
End

It 'handles empty pomodoro count (tail on empty input)'
export HARM_CLI_FORMAT=text
touch "${HARM_WORK_DIR}/sessions_$(date '+%Y-%m').jsonl"
When call work_stats_week
The status should equal 0
# ${pomodoros:-0} should provide default
The output should include "Pomodoros completed: 0"
End
End

Context 'valid data'
It 'calculates weekly stats correctly'
export HARM_CLI_FORMAT=json
local week_start
week_start=$(date -v-mon '+%Y-%m-%d' 2>/dev/null || date -d 'last monday' '+%Y-%m-%d' 2>/dev/null)
create_archive_file "$(date '+%Y-%m')" \
  "{\"start_time\":\"${week_start}T10:00:00Z\",\"duration_seconds\":1500,\"pomodoro_count\":1}" \
  "{\"start_time\":\"${week_start}T14:00:00Z\",\"duration_seconds\":1800,\"pomodoro_count\":2}"

When call work_stats_week
The status should equal 0
The output should be valid_json
The output should include '"sessions": 2'
The output should include '"total_duration_seconds": 3300'
The output should include '"pomodoros": 2'
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
The output should be valid_json
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
The output should be valid_json
The output should include '"sessions": 0'
The output should include '"total_duration_seconds": 0'
End
End

Context 'malformed data handling'
It 'handles sessions with missing duration_seconds'
export HARM_CLI_FORMAT=text
create_archive_file "$(date '+%Y-%m')" \
  '{"start_time":"2025-01-15T10:00:00Z","pomodoro_count":1}'

When call work_stats_month
The status should equal 0
The output should include "Total work time: 0s"
The output should include "Average per day: 0s"
End

It 'handles null duration_seconds in monthly stats'
export HARM_CLI_FORMAT=text
create_archive_file "$(date '+%Y-%m')" \
  '{"start_time":"2025-01-15T10:00:00Z","duration_seconds":null,"pomodoro_count":1}'

When call work_stats_month
The status should equal 0
# awk '{sum+=$1} END {print sum+0}' handles null/empty
The output should include "Total work time: 0s"
End

It 'handles missing pomodoro_count gracefully'
export HARM_CLI_FORMAT=text
create_archive_file "$(date '+%Y-%m')" \
  '{"start_time":"2025-01-15T10:00:00Z","duration_seconds":300}'

When call work_stats_month
The status should equal 0
# ${pomodoros:-0} provides default
The output should include "Pomodoros completed: 0"
End

It 'handles empty pomodoro list (tail on empty)'
export HARM_CLI_FORMAT=text
create_archive_file "$(date '+%Y-%m')" \
  '{"start_time":"2025-01-15T10:00:00Z","duration_seconds":300}'

When call work_stats_month
The status should equal 0
The output should include "Pomodoros completed: 0"
End
End

Context 'division by zero prevention'
It 'handles average calculation when total_duration is 0'
export HARM_CLI_FORMAT=text
create_archive_file "$(date '+%Y-%m')" \
  '{"start_time":"2025-01-15T10:00:00Z","duration_seconds":0,"pomodoro_count":0}'

When call work_stats_month
The status should equal 0
# avg_per_day = 0 / date_number should be 0
The output should include "Average per day: 0s"
The stderr should not include "division by zero"
End
End

Context 'valid data'
It 'calculates monthly stats correctly'
export HARM_CLI_FORMAT=json
create_archive_file "$(date '+%Y-%m')" \
  '{"start_time":"2025-01-15T10:00:00Z","duration_seconds":1500,"pomodoro_count":1}' \
  '{"start_time":"2025-01-16T10:00:00Z","duration_seconds":1800,"pomodoro_count":2}'

When call work_stats_month
The status should equal 0
The output should be valid_json
The output should include '"sessions": 2'
The output should include '"total_duration_seconds": 3300'
The output should include '"pomodoros": 2'
End

It 'formats monthly duration correctly (text)'
export HARM_CLI_FORMAT=text
create_archive_file "$(date '+%Y-%m')" \
  '{"start_time":"2025-01-15T10:00:00Z","duration_seconds":7200,"pomodoro_count":3}'

When call work_stats_month
The status should equal 0
# 7200 seconds = 2h
The output should include "Total work time: 2h"
The output should include "Total sessions: 1"
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
The output should be valid_json
The output should include '"breaks_taken": 0'
The output should include '"breaks_expected": 0'
End

It 'handles missing sessions file but existing breaks file'
export HARM_CLI_FORMAT=text
local current_month
current_month=$(date '+%Y-%m')
local breaks_file="${HARM_WORK_DIR}/breaks_${current_month}.jsonl"
echo '{"duration_seconds":300,"planned_duration_seconds":300,"completed_fully":true}' >"$breaks_file"

When call work_break_compliance
The status should equal 0
The output should include "Work sessions: 0"
The output should include "Breaks taken: 1"
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

Context 'division by zero prevention'
It 'handles zero breaks_taken for completion_rate'
export HARM_CLI_FORMAT=json
local current_month
current_month=$(date '+%Y-%m')
touch "${HARM_WORK_DIR}/breaks_${current_month}.jsonl"

When call work_break_compliance
The status should equal 0
The output should be valid_json
The output should include '"completion_rate_percent": 0'
End

It 'handles zero work_sessions for compliance_rate'
export HARM_CLI_FORMAT=json
local current_month
current_month=$(date '+%Y-%m')
local breaks_file="${HARM_WORK_DIR}/breaks_${current_month}.jsonl"
echo '{"duration_seconds":300,"planned_duration_seconds":300,"completed_fully":true}' >"$breaks_file"

When call work_break_compliance
The status should equal 0
The output should be valid_json
The output should include '"compliance_rate_percent": 0'
End
End

Context 'malformed break data'
It 'handles missing duration_seconds in breaks'
export HARM_CLI_FORMAT=text
local current_month
current_month=$(date '+%Y-%m')
local breaks_file="${HARM_WORK_DIR}/breaks_${current_month}.jsonl"
echo '{"planned_duration_seconds":300,"completed_fully":true}' >"$breaks_file"

When call work_break_compliance
The status should equal 0
# awk should handle missing values
The output should include "Breaks taken: 1"
End

It 'handles null values in break records'
export HARM_CLI_FORMAT=text
local current_month
current_month=$(date '+%Y-%m')
local breaks_file="${HARM_WORK_DIR}/breaks_${current_month}.jsonl"
echo '{"duration_seconds":null,"planned_duration_seconds":null,"completed_fully":false}' >"$breaks_file"

When call work_break_compliance
The status should equal 0
The output should include "Breaks taken: 1"
The output should include "Breaks completed fully: 0"
End
End
End

Describe 'format_duration input validation'
Context 'receives valid numeric input from stats functions'
It 'work_stats_today passes valid number to format_duration'
export HARM_CLI_FORMAT=text
local today
today=$(date '+%Y-%m-%d')
create_archive_file "$(date '+%Y-%m')" \
  "{\"start_time\":\"${today}T10:00:00Z\",\"duration_seconds\":100,\"pomodoro_count\":1}"

When call work_stats_today
The status should equal 0
The stderr should not include "must be an integer"
The output should include "1m40s"
End

It 'work_stats_week passes valid number to format_duration'
export HARM_CLI_FORMAT=text
local week_start
week_start=$(date -v-mon '+%Y-%m-%d' 2>/dev/null || date -d 'last monday' '+%Y-%m-%d' 2>/dev/null)
create_archive_file "$(date '+%Y-%m')" \
  "{\"start_time\":\"${week_start}T10:00:00Z\",\"duration_seconds\":200,\"pomodoro_count\":1}"

When call work_stats_week
The status should equal 0
The stderr should not include "must be an integer"
The output should include "3m20s"
End

It 'work_stats_month passes valid number to format_duration'
export HARM_CLI_FORMAT=text
create_archive_file "$(date '+%Y-%m')" \
  '{"start_time":"2025-01-15T10:00:00Z","duration_seconds":300,"pomodoro_count":1}'

When call work_stats_month
The status should equal 0
The stderr should not include "must be an integer"
The output should include "5m"
End
End

Context 'handles edge case inputs that become 0'
It 'empty archive results in 0 passed to format_duration'
export HARM_CLI_FORMAT=text
touch "${HARM_WORK_DIR}/sessions_$(date '+%Y-%m').jsonl"

When call work_stats_today
The status should equal 0
The output should include "0s"
The stderr should not include "must be an integer"
End

It 'no matching dates results in 0 passed to format_duration'
export HARM_CLI_FORMAT=text
create_archive_file "$(date '+%Y-%m')" \
  '{"start_time":"2020-01-01T10:00:00Z","duration_seconds":100,"pomodoro_count":1}'

When call work_stats_today
The status should equal 0
The output should include "0s"
End
End
End
End
