#!/usr/bin/env bash
# ShellSpec tests for logging module

Describe 'lib/logging.sh'
Include spec/helpers/env.sh

# Set up test log directory
BeforeAll 'export HARM_LOG_DIR="$TEST_TMP/logs" && export HARM_LOG_FILE="$HARM_LOG_DIR/test.log" && export HARM_DEBUG_LOG_FILE="$HARM_LOG_DIR/debug.log" && mkdir -p "$HARM_LOG_DIR"'

# Clean up after tests
AfterAll 'rm -rf "$HARM_LOG_DIR"'

# Source the logging module
BeforeAll 'source "$ROOT/lib/logging.sh"'

Describe 'Initialization'
It 'creates log directory'
The directory "$HARM_LOG_DIR" should be exist
End

It 'creates log files'
The file "$HARM_LOG_FILE" should be exist
End

It 'exports configuration variables'
The variable HARM_LOG_DIR should be exported
The variable HARM_LOG_FILE should be exported
The variable HARM_LOG_LEVEL should be exported
End
End

Describe 'log_timestamp'
It 'returns formatted timestamp'
When call log_timestamp
The status should be success
The output should match pattern '*-*-* *:*:*'
End
End

Describe 'log_should_write'
Context 'when level is INFO'
BeforeEach 'export HARM_LOG_LEVEL=INFO'

It 'allows INFO level'
When call log_should_write "INFO"
The status should be success
End

It 'allows WARN level'
When call log_should_write "WARN"
The status should be success
End

It 'allows ERROR level'
When call log_should_write "ERROR"
The status should be success
End

It 'blocks DEBUG level'
When call log_should_write "DEBUG"
The status should be failure
End
End

Context 'when level is ERROR'
BeforeEach 'export HARM_LOG_LEVEL=ERROR'

It 'allows ERROR level'
When call log_should_write "ERROR"
The status should be success
End

It 'blocks WARN level'
When call log_should_write "WARN"
The status should be failure
End

It 'blocks INFO level'
When call log_should_write "INFO"
The status should be failure
End
End
End

Describe 'log_write'
BeforeEach 'export HARM_LOG_LEVEL=DEBUG && export HARM_LOG_TO_FILE=1 && export HARM_LOG_TO_CONSOLE=0 && rm -f "$HARM_LOG_FILE" && log_init'

It 'writes log message to file'
When call log_write "INFO" "test" "Test message"
The file "$HARM_LOG_FILE" should be exist
The contents of file "$HARM_LOG_FILE" should include "Test message"
The contents of file "$HARM_LOG_FILE" should include "[INFO]"
The contents of file "$HARM_LOG_FILE" should include "[test]"
End

It 'includes details when provided'
When call log_write "INFO" "test" "Message" "Extra details"
The contents of file "$HARM_LOG_FILE" should include "Details: Extra details"
End

It 'writes DEBUG to separate file'
When call log_write "DEBUG" "test" "Debug message"
The contents of file "$HARM_DEBUG_LOG_FILE" should include "Debug message"
The contents of file "$HARM_DEBUG_LOG_FILE" should include "[DEBUG]"
End

It 'respects log level filtering'
export HARM_LOG_LEVEL=ERROR
When call log_write "INFO" "test" "Should not appear"
The contents of file "$HARM_LOG_FILE" should not include "Should not appear"
End
End

Describe 'Convenience functions'
BeforeEach 'export HARM_LOG_LEVEL=DEBUG && export HARM_LOG_TO_FILE=1 && export HARM_LOG_TO_CONSOLE=0 && rm -f "$HARM_LOG_FILE" && log_init'

It 'log_debug writes DEBUG level'
When call log_debug "test" "Debug message"
The contents of file "$HARM_LOG_FILE" should include "[DEBUG]"
The contents of file "$HARM_LOG_FILE" should include "Debug message"
End

It 'log_info writes INFO level'
When call log_info "test" "Info message"
The contents of file "$HARM_LOG_FILE" should include "[INFO]"
The contents of file "$HARM_LOG_FILE" should include "Info message"
End

It 'log_warn writes WARN level'
When call log_warn "test" "Warning message"
The contents of file "$HARM_LOG_FILE" should include "[WARN]"
The contents of file "$HARM_LOG_FILE" should include "Warning message"
End

It 'log_error writes ERROR level'
When call log_error "test" "Error message"
The contents of file "$HARM_LOG_FILE" should include "[ERROR]"
The contents of file "$HARM_LOG_FILE" should include "Error message"
End
End

Describe 'log_rotate'
BeforeEach 'export HARM_LOG_TO_FILE=1 && rm -f "$HARM_LOG_FILE"* && log_init && echo "Test log line" >> "$HARM_LOG_FILE"'

rotated_count() { find "$HARM_LOG_DIR" -name "test.log.*" | wc -l | tr -d " "; }

It 'rotates log file'
When call log_rotate
The status should be success
# Check that a rotated file was created
The result of function rotated_count should equal 1
End

It 'creates new empty log after rotation'
When call log_rotate
The file "$HARM_LOG_FILE" should be exist
The contents of file "$HARM_LOG_FILE" should equal ""
End
End

Describe 'log_tail'
BeforeEach 'rm -f "$HARM_LOG_FILE" && log_init && for i in {1..100}; do echo "Line $i" >> "$HARM_LOG_FILE"; done'

It 'shows last 50 lines by default'
When call log_tail
The status should be success
The line 1 of output should equal "Line 51"
The line 50 of output should equal "Line 100"
End

It 'respects custom line count'
When call log_tail 10
The status should be success
The line 1 of output should equal "Line 91"
End
End

Describe 'log_search'
BeforeEach 'rm -f "$HARM_LOG_FILE" && log_init && echo "[2025-10-18 10:00:00] [INFO] [test] Found something" >> "$HARM_LOG_FILE" && echo "[2025-10-18 10:01:00] [ERROR] [test] Error occurred" >> "$HARM_LOG_FILE" && echo "[2025-10-18 10:02:00] [WARN] [test] Warning here" >> "$HARM_LOG_FILE"'

It 'searches for pattern'
When call log_search "something"
The status should be success
The output should include "Found something"
End

It 'filters by log level'
When call log_search "test" "ERROR"
The status should be success
The output should include "Error occurred"
The output should not include "Found something"
End
End

Describe 'log_stats'
BeforeEach 'export HARM_LOG_TO_CONSOLE=0 && rm -f "$HARM_LOG_FILE" && log_init && log_info "test" "Info message" && log_warn "test" "Warning message" && log_error "test" "Error message" && log_error "test" "Another error"'

It 'shows statistics in text format'
HARM_CLI_FORMAT=text
When call log_stats
The status should be success
The output should include "Total lines"
The output should include "Errors"
End

It 'shows statistics in JSON format'
HARM_CLI_FORMAT=json
When call log_stats
The status should be success
The output should include "total"
The output should include "errors"
End
End

Describe 'Performance timers'
It 'starts and ends timer'
When call log_perf_start "test_timer"
The status should be success
End

It 'logs timer duration'
export HARM_LOG_LEVEL=DEBUG
export HARM_LOG_TO_CONSOLE=0
rm -f "$HARM_LOG_FILE"
log_init
log_perf_start "test_timer"
sleep 0.1
When call log_perf_end "test_timer" "test"
The status should be success
The contents of file "$HARM_LOG_FILE" should include "Timer: test_timer completed"
End

It 'warns if timer not started'
export HARM_LOG_TO_CONSOLE=0
When call log_perf_end "nonexistent_timer" "test"
The status should be failure
End
End

Describe 'log_clear'
BeforeEach 'rm -f "$HARM_LOG_FILE" && log_init && echo "Test data" >> "$HARM_LOG_FILE"'

It 'requires --force flag'
When call log_clear
The status should be failure
The error should include "--force"
End

It 'clears logs with --force'
When call log_clear --force
The status should be success
The error should include "Logs cleared"
The contents of file "$HARM_LOG_FILE" should equal ""
End
End
End
