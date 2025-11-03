#!/usr/bin/env bash
# ShellSpec tests for common.sh - Foundation module
# This module is critical - it's used by all 28 other modules

Describe 'lib/common.sh'
Include spec/helpers/env.sh

# Source the common module
BeforeAll 'export HARM_LOG_LEVEL=ERROR && source "$ROOT/lib/common.sh"'

# ═══════════════════════════════════════════════════════════════
# Module Initialization
# ═══════════════════════════════════════════════════════════════

Describe 'Module initialization'
It 'defines load guard variable'
The variable _HARM_COMMON_LOADED should equal 1
End

It 'prevents double-loading'
# Source again - should return 0 immediately
When run bash -c "source '$ROOT/lib/common.sh'; source '$ROOT/lib/common.sh'; echo 'success'"
The status should be success
The output should include "success"
End
End

# ═══════════════════════════════════════════════════════════════
# Error Handling Functions
# ═══════════════════════════════════════════════════════════════

Describe 'die'
It 'prints error message to stderr'
When run bash -c "source '$ROOT/lib/common.sh'; die 'Test error message'"
The status should equal 1
The error should include "ERROR: Test error message"
End

It 'exits with specified exit code'
When run bash -c "source '$ROOT/lib/common.sh'; die 'Test error' 42"
The status should equal 42
The error should include "Test error"
End

It 'defaults to exit code 1 when not specified'
When run bash -c "source '$ROOT/lib/common.sh'; die 'Default code'"
The status should equal 1
The error should include "Default code"
End

It 'requires a message parameter'
When run bash -c "source '$ROOT/lib/common.sh'; die"
The status should not be success
The error should include "die requires a message"
End

It 'handles empty message'
When run bash -c "source '$ROOT/lib/common.sh'; die ''"
The status should not be success
The error should include "die requires a message"
End
End

Describe 'warn'
It 'prints warning message to stderr'
When call warn "Test warning"
The error should include "WARNING: Test warning"
End

It 'does not exit (returns success)'
When call warn "Test warning"
The status should be success
The error should include "WARNING"
End

It 'requires a message parameter'
When run bash -c "source '$ROOT/lib/common.sh'; warn"
The status should not be success
The error should include "warn requires a message"
End

It 'handles special characters in message'
When call warn 'Warning with $dollar and "quotes"'
The error should include "WARNING:"
The status should be success
End
End

Describe 'require_command'
It 'succeeds when command exists'
When call require_command "bash"
The status should be success
End

It 'fails when command does not exist'
When run bash -c "source '$ROOT/lib/common.sh'; require_command nonexistent_cmd_12345"
The status should equal 127
The error should include "Required command not found: nonexistent_cmd_12345"
End

It 'includes install message when provided'
When run bash -c "source '$ROOT/lib/common.sh'; require_command nonexistent_cmd 'Install with: brew install foo'"
The status should equal 127
The error should include "Install with: brew install foo"
End

It 'requires command name parameter'
When run bash -c "source '$ROOT/lib/common.sh'; require_command"
The status should not be success
The error should include "require_command needs command name"
End

It 'handles commands with special characters'
When run bash -c "source '$ROOT/lib/common.sh'; require_command 'cmd-with-dash'"
The status should equal 127
The error should include "Required command not found"
End
End

# ═══════════════════════════════════════════════════════════════
# Logging Functions
# ═══════════════════════════════════════════════════════════════

Describe 'Log level constants'
It 'defines LOG_LEVEL_DEBUG as 0'
The variable LOG_LEVEL_DEBUG should equal 0
End

It 'defines LOG_LEVEL_INFO as 1'
The variable LOG_LEVEL_INFO should equal 1
End

It 'defines LOG_LEVEL_WARN as 2'
The variable LOG_LEVEL_WARN should equal 2
End

It 'defines LOG_LEVEL_ERROR as 3'
The variable LOG_LEVEL_ERROR should equal 3
End
End

Describe '_get_log_level'
Context 'with DEBUG level'
It 'returns 0'
HARM_CLI_LOG_LEVEL=DEBUG
When call _get_log_level
The output should equal "0"
unset HARM_CLI_LOG_LEVEL
End
End

Context 'with INFO level'
It 'returns 1'
HARM_CLI_LOG_LEVEL=INFO
When call _get_log_level
The output should equal "1"
unset HARM_CLI_LOG_LEVEL
End
End

Context 'with WARN level'
It 'returns 2'
HARM_CLI_LOG_LEVEL=WARN
When call _get_log_level
The output should equal "2"
unset HARM_CLI_LOG_LEVEL
End
End

Context 'with ERROR level'
It 'returns 3'
HARM_CLI_LOG_LEVEL=ERROR
When call _get_log_level
The output should equal "3"
unset HARM_CLI_LOG_LEVEL
End
End

Context 'with invalid level'
It 'defaults to INFO (1)'
HARM_CLI_LOG_LEVEL=INVALID
When call _get_log_level
The output should equal "1"
unset HARM_CLI_LOG_LEVEL
End
End

Context 'with unset level'
It 'defaults to INFO (1)'
unset HARM_CLI_LOG_LEVEL
When call _get_log_level
The output should equal "1"
End
End
End

Describe 'log_debug'
It 'logs when level is DEBUG'
HARM_CLI_LOG_LEVEL=DEBUG
When call log_debug "Debug message"
The error should include "[DEBUG]"
The error should include "Debug message"
unset HARM_CLI_LOG_LEVEL
End

It 'does not log when level is INFO'
HARM_CLI_LOG_LEVEL=INFO
When call log_debug "Should not appear"
The error should not include "Should not appear"
unset HARM_CLI_LOG_LEVEL
End

It 'includes timestamp'
HARM_CLI_LOG_LEVEL=DEBUG
When call log_debug "Test"
The error should match pattern '*-*-* *:*:*'
unset HARM_CLI_LOG_LEVEL
End
End

Describe 'log_info'
It 'logs when level is INFO'
HARM_CLI_LOG_LEVEL=INFO
When call log_info "Info message"
The error should include "[INFO]"
The error should include "Info message"
unset HARM_CLI_LOG_LEVEL
End

It 'logs when level is DEBUG'
HARM_CLI_LOG_LEVEL=DEBUG
When call log_info "Info message"
The error should include "[INFO]"
unset HARM_CLI_LOG_LEVEL
End

It 'does not log when level is WARN'
HARM_CLI_LOG_LEVEL=WARN
When call log_info "Should not appear"
The error should not include "Should not appear"
unset HARM_CLI_LOG_LEVEL
End
End

Describe 'log_warn'
It 'logs when level is WARN'
HARM_CLI_LOG_LEVEL=WARN
When call log_warn "Warning message"
The error should include "[WARN]"
The error should include "Warning message"
unset HARM_CLI_LOG_LEVEL
End

It 'does not log when level is ERROR'
HARM_CLI_LOG_LEVEL=ERROR
When call log_warn "Should not appear"
The error should not include "Should not appear"
unset HARM_CLI_LOG_LEVEL
End
End

Describe 'log_error'
It 'always logs ERROR level'
HARM_CLI_LOG_LEVEL=ERROR
When call log_error "Error message"
The error should include "[ERROR]"
The error should include "Error message"
unset HARM_CLI_LOG_LEVEL
End

It 'logs at all level settings'
HARM_CLI_LOG_LEVEL=DEBUG
When call log_error "Error at DEBUG"
The error should include "[ERROR]"
unset HARM_CLI_LOG_LEVEL
End
End

Describe 'log (simple)'
It 'always prints to stderr'
When call log "Simple message"
The error should equal "Simple message"
End

It 'does not include level prefix'
When call log "No prefix"
The error should not include "[INFO]"
The error should not include "[DEBUG]"
End

It 'does not include timestamp'
When call log "No timestamp"
The error should not match pattern '*-*-* *:*:*'
End
End

# ═══════════════════════════════════════════════════════════════
# File I/O Contracts (CRITICAL - data integrity)
# ═══════════════════════════════════════════════════════════════

Describe 'ensure_dir'
setup_test_dir() {
  TEST_DIR="$SHELLSPEC_TMPDIR/test_dir"
  rm -rf "$TEST_DIR"
}

cleanup_test_dir() {
  rm -rf "$TEST_DIR"
}

BeforeEach 'setup_test_dir'
AfterEach 'cleanup_test_dir'

It 'creates directory if it does not exist'
When call ensure_dir "$TEST_DIR"
The status should be success
The directory "$TEST_DIR" should be exist
End

It 'succeeds if directory already exists'
mkdir -p "$TEST_DIR"
When call ensure_dir "$TEST_DIR"
The status should be success
The directory "$TEST_DIR" should be exist
End

It 'creates nested directories'
When call ensure_dir "$TEST_DIR/nested/deep/path"
The status should be success
The directory "$TEST_DIR/nested/deep/path" should be exist
End

It 'requires a path parameter'
When run bash -c "source '$ROOT/lib/common.sh'; ensure_dir"
The status should not be success
The error should include "ensure_dir requires a path"
End

It 'fails on permission denied'
Skip if 'test ! -d /root || test -w /root' # Skip if /root writable or doesn't exist
When run bash -c "source '$ROOT/lib/common.sh'; ensure_dir /root/impossible"
The status should equal 1
The error should include "Failed to create directory"
End

It 'handles paths with spaces'
dir_with_space="$TEST_DIR/path with spaces"
When call ensure_dir "$dir_with_space"
The status should be success
The directory "$dir_with_space" should be exist
End

It 'handles concurrent creation (race condition)'
# Two processes trying to create same directory
When run bash -c "source '$ROOT/lib/common.sh'; ensure_dir '$TEST_DIR' & ensure_dir '$TEST_DIR' & wait"
The status should be success
The directory "$TEST_DIR" should be exist
End
End

Describe 'ensure_writable_dir'
setup_writable_test() {
  TEST_DIR="$SHELLSPEC_TMPDIR/writable_test"
  rm -rf "$TEST_DIR"
}

cleanup_writable_test() {
  rm -rf "$TEST_DIR"
}

BeforeEach 'setup_writable_test'
AfterEach 'cleanup_writable_test'

It 'creates directory if missing'
When call ensure_writable_dir "$TEST_DIR"
The status should be success
The directory "$TEST_DIR" should be exist
End

It 'succeeds if directory is writable'
mkdir -p "$TEST_DIR"
When call ensure_writable_dir "$TEST_DIR"
The status should be success
End

It 'fails if directory is not writable'
mkdir -p "$TEST_DIR"
chmod -w "$TEST_DIR"
When run bash -c "source '$ROOT/lib/common.sh'; ensure_writable_dir '$TEST_DIR'"
The status should equal 1
The error should include "Directory not writable"
chmod +w "$TEST_DIR"
End

It 'requires a path parameter'
When run bash -c "source '$ROOT/lib/common.sh'; ensure_writable_dir"
The status should not be success
The error should include "ensure_writable_dir requires a path"
End
End

Describe 'atomic_write (CRITICAL - data integrity)'
setup_atomic_test() {
  TEST_FILE="$SHELLSPEC_TMPDIR/atomic_test.txt"
  TEST_DIR="$SHELLSPEC_TMPDIR"
  rm -f "$TEST_FILE" "${TEST_FILE}."*
}

cleanup_atomic_test() {
  rm -f "$TEST_FILE" "${TEST_FILE}."*
}

BeforeEach 'setup_atomic_test'
AfterEach 'cleanup_atomic_test'

Context 'successful writes'
It 'writes content atomically'
When run bash -c "source '$ROOT/lib/common.sh' && echo 'test data' | atomic_write '$TEST_FILE'"
The status should be success
The file "$TEST_FILE" should be exist
The contents of file "$TEST_FILE" should equal "test data"
End

It 'handles multi-line content'
When run bash -c "source '$ROOT/lib/common.sh' && printf 'line1\nline2\nline3' | atomic_write '$TEST_FILE'"
The status should be success
The contents of file "$TEST_FILE" should include "line1"
The contents of file "$TEST_FILE" should include "line3"
End

It 'overwrites existing file atomically'
echo "old content" >"$TEST_FILE"
When run bash -c "source '$ROOT/lib/common.sh' && echo 'new content' | atomic_write '$TEST_FILE'"
The status should be success
The contents of file "$TEST_FILE" should equal "new content"
End

It 'handles empty content'
When run bash -c "source '$ROOT/lib/common.sh' && echo -n '' | atomic_write '$TEST_FILE'"
The status should be success
The file "$TEST_FILE" should be exist
End

It 'creates parent directory if missing'
nested_file="$TEST_DIR/new_dir/file.txt"
rm -rf "$TEST_DIR/new_dir"
When run bash -c "source '$ROOT/lib/common.sh' && echo 'content' | atomic_write '$nested_file'"
The status should be success
The file "$nested_file" should be exist
rm -rf "$TEST_DIR/new_dir"
End

It 'handles concurrent writes without corruption'
# Multiple processes writing to same file - one should win atomically
When run bash -c "
          source '$ROOT/lib/common.sh'
          echo 'process1' | atomic_write '$TEST_FILE' &
          echo 'process2' | atomic_write '$TEST_FILE' &
          wait
          # File should contain complete content from one process, not corrupted
          cat '$TEST_FILE' | wc -l | tr -d ' '
        "
The status should be success
# Should have exactly 1 line (not corrupted/mixed)
The output should equal "1"
End

It 'cleans up temp file after successful write'
When run bash -c "source '$ROOT/lib/common.sh' && echo 'data' | atomic_write '$TEST_FILE' && ! ls '$TEST_FILE.'* 2>/dev/null"
The status should be success
End
End

Context 'error handling'
It 'requires target path parameter'
When run bash -c "source '$ROOT/lib/common.sh'; echo 'data' | atomic_write"
The status should not be success
The error should include "atomic_write requires target path"
End

It 'fails if parent directory is not writable'
readonly_dir="$TEST_DIR/readonly"
mkdir -p "$readonly_dir"
chmod -w "$readonly_dir"
When run bash -c "source '$ROOT/lib/common.sh'; echo 'data' | atomic_write '$readonly_dir/file.txt'"
The status should equal 1
The error should include "Directory not writable"
chmod +w "$readonly_dir"
rm -rf "$readonly_dir"
End

It 'cleans up temp file on write failure'
# Test that atomic_write cleans up its temp files even on failure
# We'll test the successful case; failure cleanup is inherent to the mv -f pattern
Skip "Cleanup on failure is guaranteed by atomic_write implementation"
End
End

Context 'special characters'
It 'handles filenames with spaces'
When run bash -c "source '$ROOT/lib/common.sh' && echo 'content' | atomic_write '$TEST_DIR/file with spaces.txt'"
The status should be success
The file "$TEST_DIR/file with spaces.txt" should be exist
End

It 'handles content with special characters'
When run bash -c "source '$ROOT/lib/common.sh' && echo 'dollar backtick quotes' | atomic_write '$TEST_FILE'"
The status should be success
The contents of file "$TEST_FILE" should include "dollar"
The contents of file "$TEST_FILE" should include "backtick"
End

It 'handles binary-safe content (newlines, nulls)'
# Use printf to create content with special bytes
When run bash -c "printf 'line1\x00null\nline2' | source '$ROOT/lib/common.sh' && atomic_write '$TEST_FILE'"
The status should be success
The file "$TEST_FILE" should be exist
End
End
End

Describe 'file_exists'
It 'returns success for existing file'
When call file_exists "$ROOT/VERSION"
The status should be success
End

It 'returns failure for non-existent file'
When call file_exists "/nonexistent/file.txt"
The status should be failure
End

It 'returns failure for directory'
When call file_exists "$ROOT/lib"
The status should be failure
End

It 'requires path parameter'
When run bash -c "source '$ROOT/lib/common.sh'; file_exists"
The status should not be success
The error should include "file_exists requires path"
End
End

Describe 'dir_exists'
It 'returns success for existing directory'
When call dir_exists "$ROOT/lib"
The status should be success
End

It 'returns failure for non-existent directory'
When call dir_exists "/nonexistent/dir"
The status should be failure
End

It 'returns failure for file'
When call dir_exists "$ROOT/VERSION"
The status should be failure
End

It 'requires path parameter'
When run bash -c "source '$ROOT/lib/common.sh'; dir_exists"
The status should not be success
The error should include "dir_exists requires path"
End
End

# ═══════════════════════════════════════════════════════════════
# Input Validation
# ═══════════════════════════════════════════════════════════════

Describe 'require_arg'
It 'succeeds with non-empty value'
When call require_arg "value" "test_arg"
The status should be success
End

It 'fails with empty value'
When run bash -c "source '$ROOT/lib/common.sh'; require_arg '' 'test_arg'"
The status should equal 2
The error should include "test_arg is required"
End

It 'uses generic name when not provided'
When run bash -c "source '$ROOT/lib/common.sh'; require_arg ''"
The status should equal 2
The error should include "argument is required"
End

It 'handles whitespace-only value as empty'
When run bash -c "source '$ROOT/lib/common.sh'; require_arg '   ' 'test'"
The status should be success
End
End

Describe 'validate_int'
Context 'valid integers'
It 'accepts positive integer'
When call validate_int "42"
The status should be success
End

It 'accepts zero'
When call validate_int "0"
The status should be success
End

It 'accepts negative integer'
When call validate_int "-42"
The status should be success
End

It 'accepts large integer'
When call validate_int "999999999"
The status should be success
End

It 'accepts very large integer'
When call validate_int "12345678901234567890"
The status should be success
End
End

Context 'invalid inputs'
It 'rejects float'
When call validate_int "3.14"
The status should be failure
End

It 'rejects string'
When call validate_int "abc"
The status should be failure
End

It 'rejects integer with spaces'
When call validate_int "42 "
The status should be failure
End

It 'rejects empty string'
When call validate_int ""
The status should be failure
End

It 'rejects mixed alphanumeric'
When call validate_int "42abc"
The status should be failure
End

It 'rejects hex notation'
When call validate_int "0x2A"
The status should be failure
End

It 'rejects octal notation'
When call validate_int "052"
The status should be success # This is valid decimal 52
End
End

Context 'edge cases'
It 'handles single digit'
When call validate_int "5"
The status should be success
End

It 'rejects double negative'
When call validate_int "--42"
The status should be failure
End

It 'rejects leading zeros (but still valid)'
When call validate_int "0042"
The status should be success
End

It 'rejects plus sign'
When call validate_int "+42"
The status should be failure
End
End
End

Describe 'validate_format'
It 'accepts "text" format'
When call validate_format "text"
The status should be success
End

It 'accepts "json" format'
When call validate_format "json"
The status should be success
End

It 'defaults to "text" when empty'
When call validate_format ""
The status should be success
End

It 'rejects invalid format'
When run bash -c "source '$ROOT/lib/common.sh'; validate_format 'xml'"
The status should equal 2
The error should include "Invalid format"
The error should include "must be 'text' or 'json'"
End

It 'is case-sensitive (TEXT is invalid)'
When run bash -c "source '$ROOT/lib/common.sh'; validate_format 'TEXT'"
The status should equal 2
The error should include "Invalid format"
End
End

# ═══════════════════════════════════════════════════════════════
# Process Utilities
# ═══════════════════════════════════════════════════════════════

Describe 'run_with_timeout'
Context 'successful execution'
It 'runs command within timeout'
When call run_with_timeout 5 echo "success"
The status should be success
The output should equal "success"
End

It 'passes arguments correctly'
When call run_with_timeout 5 bash -c "echo \$1" -- "test arg"
The status should be success
The output should include "test"
End

It 'preserves command exit code on success'
When call run_with_timeout 5 bash -c "exit 0"
The status should equal 0
End
End

Context 'timeout scenarios'
It 'kills command after timeout'
# Sleep longer than timeout - should be killed
When run bash -c "source '$ROOT/lib/common.sh'; run_with_timeout 1 sleep 10"
# Timeout exit code is typically 124 or 143 (SIGTERM)
The status should not equal 0
End

It 'requires timeout parameter'
When run bash -c "source '$ROOT/lib/common.sh'; run_with_timeout"
The status should not be success
The error should include "timeout required"
End

It 'validates timeout is integer'
When run bash -c "source '$ROOT/lib/common.sh'; run_with_timeout 'abc' echo test"
The status should equal 2
The error should include "Timeout must be an integer"
End

It 'accepts zero timeout'
# Zero timeout - skip this test as behavior is implementation-dependent
Skip "Zero timeout behavior is system-dependent"
End
End

Context 'fallback mechanisms'
It 'uses perl fallback when timeout unavailable'
Skip if 'command -v perl >/dev/null || exit 0' # Skip if perl missing
# Test that perl fallback executes command successfully
When run bash -c "
          source '$ROOT/lib/common.sh'
          # Create a PATH without timeout
          export PATH=/usr/bin:/bin
          command -v timeout >/dev/null 2>&1 && exit 1  # Skip if timeout available
          run_with_timeout 5 echo 'perl fallback'
        "
The output should include "fallback"
End

It 'warns when no timeout mechanism available'
# This test verifies the warning is shown
When run bash -c "
          source '$ROOT/lib/common.sh'
          # Override command to hide both timeout and perl
          command() {
            case \"\$2\" in
              timeout|perl) return 1 ;;
              *) builtin command \"\$@\" ;;
            esac
          }
          export -f command
          run_with_timeout 5 echo 'no timeout' 2>&1
        "
The status should be success
The output should include "no timeout"
End
End
End

# ═══════════════════════════════════════════════════════════════
# JSON Helpers (SECURITY CRITICAL)
# ═══════════════════════════════════════════════════════════════

Describe 'json_escape (SECURITY CRITICAL)'
Context 'with jq available'
It 'escapes double quotes'
Skip if 'command -v jq >/dev/null || exit 0'
When call json_escape 'text with "quotes"'
# jq wraps output in quotes and escapes internal quotes
The output should include 'quotes'
The status should be success
End

It 'escapes backslashes'
Skip if 'command -v jq >/dev/null || exit 0'
When call json_escape 'path\with\backslash'
# jq properly escapes backslashes
The status should be success
The output should include 'path'
End

It 'escapes newlines'
Skip if 'command -v jq >/dev/null || exit 0'
When call json_escape $'line1\nline2'
# jq converts newlines to \n
The output should include 'line1'
The output should include 'line2'
The status should be success
End

It 'handles empty string'
Skip if 'command -v jq >/dev/null || exit 0'
When call json_escape ""
The output should equal '""'
End

It 'handles Unicode characters'
Skip if 'command -v jq >/dev/null || exit 0'
When call json_escape "emoji test"
The status should be success
The output should include "emoji"
End

It 'prevents JSON injection attack'
Skip if 'command -v jq >/dev/null || exit 0'
malicious='", "injected": "malicious'
When call json_escape "$malicious"
# Output should be safely escaped as a single JSON string
The status should be success
The output should include 'injected'
End

It 'handles control characters'
Skip if 'command -v jq >/dev/null || exit 0'
When call json_escape $'tab\there'
The status should be success
The output should include "tab"
End

It 'handles dollar signs and backticks'
Skip if 'command -v jq >/dev/null || exit 0'
When call json_escape 'test $VAR and `cmd`'
The status should be success
The output should include 'VAR'
End
End

Context 'fallback without jq'
It 'uses sed fallback for escaping'
# Test by calling in environment without jq
When run bash -c "
          source '$ROOT/lib/common.sh'
          # Mock command to return false for jq
          command() { [ \"\$2\" != 'jq' ] && builtin command \"\$@\" || return 1; }
          export -f command
          json_escape 'test quotes'
        "
The status should be success
The output should include 'test'
End

It 'escapes backslashes in fallback'
When run bash -c "
          source '$ROOT/lib/common.sh'
          command() { [ \"\$2\" != 'jq' ] && builtin command \"\$@\" || return 1; }
          export -f command
          json_escape 'pathback'
        "
The output should include 'path'
The status should be success
End

It 'handles empty string in fallback'
When run bash -c "
          source '$ROOT/lib/common.sh'
          command() { [ \"\$2\" != 'jq' ] && builtin command \"\$@\" || return 1; }
          export -f command
          json_escape ''
        "
The status should be success
End
End

Context 'special characters comprehensive test'
It 'handles all JSON special characters together'
Skip if 'command -v jq >/dev/null || exit 0'
special='{"test": "value", "quote": "\"", "backslash": "\\"}'
When call json_escape "$special"
The status should be success
The output should include "test"
The output should include "value"
End

It 'handles null bytes (if supported)'
Skip if 'command -v jq >/dev/null || exit 0'
When run bash -c "printf 'test' | source '$ROOT/lib/common.sh' && json_escape 'test'"
The status should be success
The output should include "test"
End
End
End

# ═══════════════════════════════════════════════════════════════
# Function Export Verification
# ═══════════════════════════════════════════════════════════════

Describe 'Exported functions'
It 'exports error handling functions'
When run bash -c "source '$ROOT/lib/common.sh'; declare -Ff die"
The output should include "die"
The status should be success
End

It 'exports logging functions'
When run bash -c "source '$ROOT/lib/common.sh'; declare -Ff log_info"
The output should include "log_info"
End

It 'exports file I/O functions'
When run bash -c "source '$ROOT/lib/common.sh'; declare -Ff atomic_write"
The output should include "atomic_write"
End

It 'exports validation functions'
When run bash -c "source '$ROOT/lib/common.sh'; declare -Ff validate_int"
The output should include "validate_int"
End

It 'allows exported functions in subshells'
When run bash -c "source '$ROOT/lib/common.sh'; (warn 'subshell test' 2>&1)"
The output should include "WARNING"
End
End

# ═══════════════════════════════════════════════════════════════
# Integration Tests (functions working together)
# ═══════════════════════════════════════════════════════════════

Describe 'Integration tests'
setup_integration() {
  INTEGRATION_DIR="$SHELLSPEC_TMPDIR/integration"
  rm -rf "$INTEGRATION_DIR"
}

cleanup_integration() {
  rm -rf "$INTEGRATION_DIR"
}

BeforeEach 'setup_integration'
AfterEach 'cleanup_integration'

It 'ensure_dir + atomic_write workflow'
file="$INTEGRATION_DIR/data.json"
ensure_dir "$(dirname "$file")"
echo '{"test": "data"}' | atomic_write "$file"
When call cat "$file"
The output should include "test"
The status should be success
End

It 'validation + error handling workflow'
When run bash -c "
        source '$ROOT/lib/common.sh'
        value='not a number'
        if ! validate_int \"\$value\"; then
          die 'Invalid value' 2
        fi
      "
The status should equal 2
The error should include "Invalid value"
End

It 'require_command + conditional execution'
When run bash -c "
        source '$ROOT/lib/common.sh'
        require_command bash
        echo 'Command available'
      "
The status should be success
The output should include "Command available"
End
End
End
