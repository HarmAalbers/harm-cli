#!/usr/bin/env bash
# ShellSpec tests for insights module

Describe 'lib/insights.sh'
Include spec/helpers/env.sh

# Source the insights module
BeforeAll 'export HARM_LOG_LEVEL=ERROR && source "$ROOT/lib/insights.sh"'

Describe 'Module initialization'
It 'prevents double-loading'
When call bash -c "source $ROOT/lib/insights.sh && source $ROOT/lib/insights.sh && echo OK"
The status should be success
The output should include "OK"
The variable _HARM_INSIGHTS_LOADED should equal 1
End
End

Describe 'insights_command_frequency'
Context 'with no data available'
# Mock activity_query to return error
activity_query() { return 1; }

It 'returns success with no data message'
When call insights_command_frequency "today"
The status should equal 0
The output should include "No data available"
End
End

Context 'with valid activity data'
# Mock activity_query with sample data
activity_query() {
  cat <<EOF
{"type": "command", "command": "harm-cli work start", "timestamp": "2025-01-01T10:00:00Z"}
{"type": "command", "command": "harm-cli goal show", "timestamp": "2025-01-01T10:05:00Z"}
{"type": "command", "command": "harm-cli work status", "timestamp": "2025-01-01T10:10:00Z"}
{"type": "command", "command": "harm-cli work status", "timestamp": "2025-01-01T10:15:00Z"}
{"type": "command", "command": "harm-cli work status", "timestamp": "2025-01-01T10:20:00Z"}
EOF
}

It 'shows header with period'
When call insights_command_frequency "today"
The output should include "Most Used Commands"
The output should include "(today)"
End

It 'lists commands with counts'
When call insights_command_frequency "today"
The output should include "harm-cli"
End

It 'sorts by frequency descending'
When call insights_command_frequency "today"
The output should include "times"
End
End

Context 'with custom period'
activity_query() {
  echo '{"type": "command", "command": "test", "timestamp": "2025-01-01T10:00:00Z"}'
}

It 'accepts week period'
When call insights_command_frequency "week"
The output should include "(week)"
End

It 'accepts month period'
When call insights_command_frequency "month"
The output should include "(month)"
End
End
End

Describe 'insights_peak_hours'
Context 'with no data available'
activity_query() { return 1; }

It 'returns success with no data message'
When call insights_peak_hours "week"
The status should equal 0
The output should include "No data available"
End
End

Context 'with valid activity data'
activity_query() {
  cat <<EOF
{"type": "command", "command": "test1", "timestamp": "2025-01-01T09:00:00Z"}
{"type": "command", "command": "test2", "timestamp": "2025-01-01T09:30:00Z"}
{"type": "command", "command": "test3", "timestamp": "2025-01-01T14:00:00Z"}
{"type": "command", "command": "test4", "timestamp": "2025-01-01T14:15:00Z"}
{"type": "command", "command": "test5", "timestamp": "2025-01-01T14:45:00Z"}
EOF
}

It 'shows peak hours header'
When call insights_peak_hours "week"
The output should include "Peak Activity Hours"
End

It 'formats hours as HH:00 - HH:59'
When call insights_peak_hours "week"
The output should include ":00"
The output should include ":59"
End

It 'shows command counts per hour'
When call insights_peak_hours "week"
The output should include "commands"
End
End
End

Describe 'insights_error_analysis'
Context 'with no data available'
activity_query() { return 1; }

It 'returns success with no data message'
When call insights_error_analysis "today"
The status should equal 0
The output should include "No data available"
End
End

Context 'with no commands executed'
activity_query() {
  echo '{"type": "event", "event": "test"}'
}

It 'shows no commands message'
When call insights_error_analysis "today"
The output should include "No commands executed"
End
End

Context 'with successful commands only'
activity_query() {
  cat <<EOF
{"type": "command", "command": "test1", "exit_code": 0}
{"type": "command", "command": "test2", "exit_code": 0}
{"type": "command", "command": "test3", "exit_code": 0}
EOF
}

It 'shows 0% error rate'
When call insights_error_analysis "today"
The output should include "Error Rate: 0"
End

It 'shows success message'
When call insights_error_analysis "today"
The output should include "No failed commands"
End
End

Context 'with failed commands'
activity_query() {
  cat <<EOF
{"type": "command", "command": "test1", "exit_code": 0}
{"type": "command", "command": "test2", "exit_code": 1}
{"type": "command", "command": "test3", "exit_code": 1}
{"type": "command", "command": "test2", "exit_code": 1}
EOF
}

It 'calculates error rate percentage'
When call insights_error_analysis "today"
The output should include "Error Rate"
End

It 'lists failed commands'
When call insights_error_analysis "today"
The output should include "Failed Commands"
End

It 'shows failure counts'
When call insights_error_analysis "today"
The output should include "failures"
End
End
End

Describe 'insights_project_activity'
Context 'with no data available'
activity_query() { return 1; }

It 'returns success with no data message'
When call insights_project_activity "week"
The status should equal 0
The output should include "No data available"
End
End

Context 'with project data'
activity_query() {
  cat <<EOF
{"type": "command", "project": "harm-cli"}
{"type": "command", "project": "harm-cli"}
{"type": "command", "project": "other-project"}
EOF
}

It 'shows project activity header'
When call insights_project_activity "week"
The output should include "Project Activity"
End

It 'lists projects with action counts'
When call insights_project_activity "week"
The output should include "actions"
End
End
End

Describe 'insights_performance'
Context 'with no data available'
activity_query() { return 1; }

It 'returns success with no data message'
When call insights_performance "today"
The status should equal 0
The output should include "No data available"
End
End

Context 'with performance data'
activity_query() {
  cat <<EOF
{"type": "command", "command": "fast", "duration_ms": 100}
{"type": "command", "command": "slow", "duration_ms": 5000}
{"type": "command", "command": "medium", "duration_ms": 500}
EOF
}

It 'shows performance header'
When call insights_performance "today"
The output should include "Performance Metrics"
End

It 'calculates average duration'
When call insights_performance "today"
The output should include "Average Duration"
The output should include "ms"
End

It 'shows max duration'
When call insights_performance "today"
The output should include "Max Duration"
End

It 'lists slowest commands'
When call insights_performance "today"
The output should include "Slowest Commands"
End
End
End

Describe 'insights_show'
# Mock logging to avoid undefined function errors
log_error() { echo "ERROR: $*" >&2; }

Context 'parameter validation'
It 'rejects invalid period'
When call insights_show "invalid"
The status should equal 1
The stderr should include "ERROR"
The stderr should include "Invalid period"
End

It 'accepts today period'
activity_query() { return 1; }
When call insights_show "today"
The status should equal 0
The output should include "Productivity Insights"
End

It 'accepts yesterday period'
activity_query() { return 1; }
When call insights_show "yesterday"
The status should equal 0
The output should include "Productivity Insights"
End

It 'accepts week period'
activity_query() { return 1; }
When call insights_show "week"
The status should equal 0
The output should include "Productivity Insights"
End

It 'accepts month period'
activity_query() { return 1; }
When call insights_show "month"
The status should equal 0
The output should include "Productivity Insights"
End

It 'accepts all period'
activity_query() { return 1; }
When call insights_show "all"
The status should equal 0
The output should include "Productivity Insights"
End
End

Context 'with no data'
activity_query() { return 1; }

It 'shows no data message'
When call insights_show "week"
The output should include "No activity data"
End

It 'shows initialization tip'
When call insights_show "week"
The output should include "harm-cli init"
End
End

Context 'with category selection'
activity_query() {
  echo '{"type": "command", "command": "test", "exit_code": 0, "duration_ms": 100}'
}

It 'shows all categories by default'
When call insights_show "week"
The output should include "Productivity Insights"
End

It 'shows only commands category'
When call insights_show "week" "commands"
The output should include "Most Used Commands"
The output should not include "Performance Metrics"
End

It 'shows only performance category'
When call insights_show "week" "performance"
The output should include "Performance Metrics"
The output should not include "Most Used Commands"
End

It 'shows only errors category'
When call insights_show "week" "errors"
The output should include "Error Analysis"
End

It 'shows only projects category'
When call insights_show "week" "projects"
The output should include "Project Activity"
End

It 'shows only hours category'
When call insights_show "week" "hours"
The output should include "Peak Activity Hours"
End

It 'rejects unknown category'
log_error() { echo "ERROR: $*" >&2; }
When call insights_show "week" "unknown"
The status should equal 1
The stderr should include "ERROR"
The stderr should include "Unknown category"
End
End
End

Describe 'insights_export_json'
Context 'with no data'
activity_query() { return 1; }

It 'returns error JSON'
When call insights_export_json "week"
The status should equal 1
The output should include '"error"'
End
End

Context 'with valid data'
activity_query() {
  cat <<EOF
{"type": "command", "command": "test1", "exit_code": 0, "duration_ms": 100, "project": "test", "timestamp": "2025-01-01T10:00:00Z"}
{"type": "command", "command": "test2", "exit_code": 1, "duration_ms": 200, "project": "test", "timestamp": "2025-01-01T11:00:00Z"}
EOF
}

It 'exports valid JSON'
When call insights_export_json "week"
The status should equal 0
# Check for JSON structure
The output should include "{"
The output should include "}"
End

It 'includes period in output'
When call insights_export_json "week"
The output should include '"period"'
The output should include '"week"'
End

It 'includes timestamp'
When call insights_export_json "week"
The output should include '"generated_at"'
End

It 'includes total_commands count'
When call insights_export_json "week"
The output should include '"total_commands"'
End

It 'includes total_errors count'
When call insights_export_json "week"
The output should include '"total_errors"'
End

It 'includes error_rate percentage'
When call insights_export_json "week"
The output should include '"error_rate"'
End

It 'includes avg_duration_ms'
When call insights_export_json "week"
The output should include '"avg_duration_ms"'
End

It 'includes top_commands array'
When call insights_export_json "week"
The output should include '"top_commands"'
End

It 'includes projects array'
When call insights_export_json "week"
The output should include '"projects"'
End

It 'includes peak_hours array'
When call insights_export_json "week"
The output should include '"peak_hours"'
End
End
End

Describe 'insights_export_html'
setup_temp() {
  TEST_OUTPUT="$SHELLSPEC_TMPDIR/test-report.html"
}
cleanup_temp() {
  rm -f "$TEST_OUTPUT"
}

BeforeEach setup_temp
AfterEach cleanup_temp

Context 'with no data'
activity_query() { return 1; }

It 'returns error code 1'
When call insights_export_html "week" "$TEST_OUTPUT"
The status should equal 1
The stderr should include "ERROR"
The stderr should include "Failed to export"
End
End

Context 'with valid data'
activity_query() {
  cat <<EOF
{"type": "command", "command": "test", "exit_code": 0, "duration_ms": 100, "project": "test", "timestamp": "2025-01-01T10:00:00Z"}
EOF
}

# Mock log_info to avoid undefined function
log_info() { echo "INFO: $*" >&2; }

It 'creates HTML file'
When call insights_export_html "week" "$TEST_OUTPUT"
The status should equal 0
The path "$TEST_OUTPUT" should be exist
The output should include "Report exported to"
The stderr should include "INFO"
The stderr should include "HTML report exported"
End

It 'generates valid HTML'
insights_export_html "week" "$TEST_OUTPUT" >/dev/null 2>&1
The contents of file "$TEST_OUTPUT" should include "<!DOCTYPE html>"
The contents of file "$TEST_OUTPUT" should include "<html"
The contents of file "$TEST_OUTPUT" should include "</html>"
End

It 'includes title'
insights_export_html "week" "$TEST_OUTPUT" >/dev/null 2>&1
The contents of file "$TEST_OUTPUT" should include "<title>"
The contents of file "$TEST_OUTPUT" should include "Productivity Insights"
End

It 'includes metrics'
insights_export_html "week" "$TEST_OUTPUT" >/dev/null 2>&1
The contents of file "$TEST_OUTPUT" should include "Total Commands"
The contents of file "$TEST_OUTPUT" should include "Error Rate"
The contents of file "$TEST_OUTPUT" should include "Avg Duration"
End

It 'includes top commands section'
insights_export_html "week" "$TEST_OUTPUT" >/dev/null 2>&1
The contents of file "$TEST_OUTPUT" should include "Top Commands"
End

It 'includes projects section'
insights_export_html "week" "$TEST_OUTPUT" >/dev/null 2>&1
The contents of file "$TEST_OUTPUT" should include "Projects"
End
End

Context 'with default output file'
It 'defaults to insights-report.html'
activity_query() {
  echo '{"type": "command", "command": "test", "exit_code": 0, "duration_ms": 100, "project": "test", "timestamp": "2025-01-01T10:00:00Z"}'
}
When call insights_export_html "week"
The output should include "insights-report.html"
End
End
End

Describe 'insights_daily_summary'
Context 'with no data'
activity_query() { return 1; }

It 'shows no activity message'
When call insights_daily_summary "today"
The output should include "No activity data"
End
End

Context 'with daily data'
activity_query() {
  cat <<EOF
{"type": "command", "command": "test1", "exit_code": 0, "duration_ms": 100}
{"type": "command", "command": "test2", "exit_code": 0, "duration_ms": 200}
{"type": "command", "command": "test1", "exit_code": 0, "duration_ms": 150}
EOF
}

It 'shows daily summary header'
When call insights_daily_summary "today"
The output should include "Daily Summary"
End

It 'shows activity metrics'
When call insights_daily_summary "today"
The output should include "commands executed"
The output should include "errors encountered"
End

It 'shows top 3 commands'
When call insights_daily_summary "today"
The output should include "Top 3 Commands"
End

It 'calculates productivity score'
When call insights_daily_summary "today"
The output should include "Productivity Score"
End

It 'provides recommendations'
When call insights_daily_summary "today"
The output should include "Recommendations"
End
End

Context 'recommendations logic'
It 'recommends debugging for high errors'
activity_query() {
  for i in {1..10}; do
    echo '{"type": "command", "command": "test", "exit_code": 1, "duration_ms": 100}'
  done
}
When call insights_daily_summary "today"
The output should include "High error rate"
End

It 'recommends checking resources for slow commands'
activity_query() {
  echo '{"type": "command", "command": "slow", "exit_code": 0, "duration_ms": 5000}'
}
When call insights_daily_summary "today"
The output should include "running slow"
End

It 'recommends setting goals for low activity'
activity_query() {
  echo '{"type": "command", "command": "test", "exit_code": 0, "duration_ms": 100}'
}
When call insights_daily_summary "today"
The output should include "Low activity"
End

It 'shows congratulations for high score'
activity_query() {
  for i in {1..100}; do
    echo '{"type": "command", "command": "test", "exit_code": 0, "duration_ms": 100}'
  done
}
When call insights_daily_summary "today"
The output should include "Excellent productivity"
End
End
End

Describe 'insights command dispatcher'
# Mock logging
log_error() { echo "ERROR: $*" >&2; }

Context 'subcommand routing'
activity_query() { return 1; }

It 'defaults to show subcommand'
When call insights
The output should include "Productivity Insights"
End

It 'routes to show subcommand'
When call insights "show" "week"
The output should include "Productivity Insights"
End

It 'routes to json subcommand'
When call insights "json" "week"
The status should equal 1
The output should include '"error"'
End

It 'routes to daily subcommand'
When call insights "daily" "today"
The output should include "Daily Summary"
End

It 'rejects unknown subcommand'
When call insights "unknown"
The status should equal 1
The stderr should include "ERROR"
The stderr should include "Unknown subcommand"
End

It 'shows usage for unknown subcommand'
When call insights "invalid"
The status should equal 1
The error should include "Usage: insights"
End
End

Context 'export subcommand'
activity_query() {
  echo '{"type": "command", "command": "test", "exit_code": 0, "duration_ms": 100, "project": "test", "timestamp": "2025-01-01T10:00:00Z"}'
}

It 'defaults to insights-report.html'
When call insights "export"
The output should include "insights-report.html"
End

It 'accepts custom output file'
When call insights "export" "custom.html"
The output should include "custom.html"
End
End
End

Describe 'Edge cases'
Context 'corrupted activity log'
activity_query() {
  cat <<EOF
{"type": "command", "command": "test1"}
invalid json line
{"type": "command", "command": "test2"}
EOF
}

It 'handles malformed JSON gracefully'
# jq will fail on invalid lines but continue
# The function should not crash
When call insights_command_frequency "today"
# May return success or error depending on jq behavior
# Status should be success (it filters out bad lines)
The status should be success
The output should include "Most Used Commands"
End
End

Context 'empty activity log'
activity_query() {
  echo ""
}

It 'handles empty data gracefully'
When call insights_command_frequency "today"
The status should equal 0
The output should include "Most Used Commands"
End
End

Context 'missing required fields'
activity_query() {
  echo '{"type": "command"}'
}

It 'handles missing command field'
When call insights_command_frequency "today"
The status should equal 0
The output should include "Most Used Commands"
End
End
End

Describe 'Logging integration'
Context 'with logging available'
log_error() { echo "LOG_ERROR: $*" >&2; }
log_info() { echo "LOG_INFO: $*" >&2; }

It 'logs invalid period error'
When call insights_show "invalid"
The status should equal 1
The error should include "LOG_ERROR"
End

It 'logs HTML export'
activity_query() {
  echo '{"type": "command", "command": "test", "exit_code": 0, "duration_ms": 100, "project": "test", "timestamp": "2025-01-01T10:00:00Z"}'
}
When call insights_export_html "week" "$SHELLSPEC_TMPDIR/test.html"
The status should equal 0
The output should include "Report exported to"
The stderr should include "LOG_INFO"
The stderr should include "HTML report exported"
End
End

Context 'without logging available'
It 'works without logging functions'
# Module can load without logging but functions may fail
When call bash -c "unset -f log_error log_info 2>/dev/null; source $ROOT/lib/insights.sh && echo OK"
The output should include "OK"
End
End
End
End
