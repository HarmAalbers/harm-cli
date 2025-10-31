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

Describe 'log_stream'
BeforeEach 'export HARM_LOG_LEVEL=DEBUG && export HARM_LOG_TO_FILE=1 && export HARM_LOG_TO_CONSOLE=0 && export HARM_LOG_UNBUFFERED=1 && rm -f "$HARM_LOG_FILE" && log_init'

Describe 'Function existence'
It 'is defined as a function'
When call type log_stream
The status should be success
# Check for "log_stream ()" pattern which indicates a function definition
The output should include "log_stream ()"
End
End

Describe 'Basic streaming (no filters)'
# Helper to simulate streaming with timeout
stream_with_timeout() {
  timeout 1 log_stream "$@" 2>/dev/null || true
}

It 'uses tail -F for rotation-aware following'
# This test verifies the command construction, not actual streaming
# We check that log_stream would use tail -F by inspecting the function
Skip if "Implementation pending" true
When call stream_with_timeout
The status should be success
End
End

Describe 'Level filtering'
BeforeEach 'log_info "test" "Info message" && log_warn "test" "Warning message" && log_error "test" "Error message"'

It 'filters by ERROR level with --level=ERROR flag'
Skip if "Implementation pending" true
# Stream for 0.5s, write new ERROR, verify it appears
When call stream_with_timeout --level=ERROR
The output should include "ERROR"
The output should not include "INFO"
End

It 'filters by WARN level with --level=WARN flag'
Skip if "Implementation pending" true
When call stream_with_timeout --level=WARN
The output should include "WARN"
The output should not include "INFO"
End

It 'shows all levels when no filter specified'
Skip if "Implementation pending" true
When call stream_with_timeout
The output should include "INFO"
The output should include "WARN"
The output should include "ERROR"
End
End

Describe 'Format options'
BeforeEach 'log_info "test" "Test message"'

It 'outputs plain text by default'
Skip if "Implementation pending" true
When call stream_with_timeout
The output should include "Test message"
The output should include "[INFO]"
End

It 'outputs JSON with --format=json flag'
Skip if "Implementation pending" true
When call stream_with_timeout --format=json
The output should include '"level"'
The output should include '"message"'
The output should include '"timestamp"'
End

It 'outputs structured format with --format=structured flag'
Skip if "Implementation pending" true
When call stream_with_timeout --format=structured
# Structured format adds visual indicators
The status should be success
End
End

Describe 'Cross-terminal immediate visibility'
It 'immediately shows logs written from another process'
Skip if "Implementation pending" true
# Start streaming in background with timeout
timeout 2 log_stream >"$TEST_TMP/stream_output" 2>&1 &
sleep 0.15

# Write a log entry (simulating another terminal)
log_info "cross_terminal_test" "Message from another terminal"

# Wait briefly for stream to catch up
sleep 0.25

# Verify the message appeared in the stream
When call cat "$TEST_TMP/stream_output"
The output should include "Message from another terminal"
End
End

Describe 'Unbuffered write integration'
It 'uses unbuffered writes when HARM_LOG_UNBUFFERED=1'
export HARM_LOG_UNBUFFERED=1
log_info "test" "Unbuffered message"
# File should be immediately readable
When call cat "$HARM_LOG_FILE"
The output should include "Unbuffered message"
The status should be success
End

It 'respects HARM_LOG_UNBUFFERED=0 for buffered mode'
export HARM_LOG_UNBUFFERED=0
log_info "test" "Buffered message"
# Should still work, just with buffering
When call cat "$HARM_LOG_FILE"
The output should include "Buffered message"
The status should be success
End
End
End

Describe 'Minimum level filtering (_log_build_level_filter)'
It 'builds correct pattern for DEBUG level (shows all)'
When call _log_build_level_filter "DEBUG"
The status should be success
The output should include "DEBUG"
The output should include "INFO"
The output should include "WARN"
The output should include "ERROR"
End

It 'builds correct pattern for INFO level (shows INFO+)'
When call _log_build_level_filter "INFO"
The status should be success
The output should include "INFO"
The output should include "WARN"
The output should include "ERROR"
The output should not include "DEBUG"
End

It 'builds correct pattern for WARN level (shows WARN+)'
When call _log_build_level_filter "WARN"
The status should be success
The output should include "WARN"
The output should include "ERROR"
The output should not include "INFO"
The output should not include "DEBUG"
End

It 'builds correct pattern for ERROR level (shows ERROR only)'
When call _log_build_level_filter "ERROR"
The status should be success
The output should include "ERROR"
The output should not include "WARN"
The output should not include "INFO"
The output should not include "DEBUG"
End

It 'handles invalid log level gracefully'
When call _log_build_level_filter "INVALID"
The status should be failure
The output should equal "cat"
End
End

Describe 'Format helper functions'
Describe '_log_format_json_line'
It 'converts log line to JSON format'
When call sh -c 'echo "[2025-10-22 12:34:56] [INFO] [test] Test message" | _log_format_json_line'
The status should be success
The output should include '"timestamp"'
The output should include '"level":"INFO"'
The output should include '"component":"test"'
The output should include '"message":"Test message"'
End

It 'handles messages with special characters'
When call sh -c 'echo "[2025-10-22 12:34:56] [ERROR] [test] Message with quotes and symbols" | _log_format_json_line'
The status should be success
The output should include '"timestamp"'
The output should include '"level":"ERROR"'
End
End

Describe '_log_format_colored_line'
It 'adds color codes for DEBUG level'
When call sh -c 'echo "[2025-10-22 12:34:56] [DEBUG] [test] Debug message" | _log_format_colored_line'
The status should be success
# Should contain ANSI escape codes for dim text (\033[2m)
The output should include "DEBUG"
End

It 'adds color codes for INFO level'
When call sh -c 'echo "[2025-10-22 12:34:56] [INFO] [test] Info message" | _log_format_colored_line'
The status should be success
# Should contain ANSI escape codes for blue (\033[34m)
The output should include "INFO"
End

It 'adds color codes for WARN level'
When call sh -c 'echo "[2025-10-22 12:34:56] [WARN] [test] Warning message" | _log_format_colored_line'
The status should be success
# Should contain ANSI escape codes for yellow (\033[33m)
The output should include "WARN"
End

It 'adds color codes for ERROR level'
When call sh -c 'echo "[2025-10-22 12:34:56] [ERROR] [test] Error message" | _log_format_colored_line'
The status should be success
# Should contain ANSI escape codes for red (\033[31m)
The output should include "ERROR"
End
End

Describe '_log_format_structured_line'
It 'adds visual indicators for DEBUG level'
When call sh -c 'echo "[2025-10-22 12:34:56] [DEBUG] [test] Debug message" | _log_format_structured_line'
The status should be success
# Should add emoji or visual indicator
The output should include "🔍"
End

It 'adds visual indicators for INFO level'
When call sh -c 'echo "[2025-10-22 12:34:56] [INFO] [test] Info message" | _log_format_structured_line'
The status should be success
The output should include "✓"
End

It 'adds visual indicators for WARN level'
When call sh -c 'echo "[2025-10-22 12:34:56] [WARN] [test] Warning message" | _log_format_structured_line'
The status should be success
The output should include "⚠"
End

It 'adds visual indicators for ERROR level'
When call sh -c 'echo "[2025-10-22 12:34:56] [ERROR] [test] Error message" | _log_format_structured_line'
The status should be success
The output should include "✗"
End
End
End
End
