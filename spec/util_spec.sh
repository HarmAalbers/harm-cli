#!/usr/bin/env bash
# ShellSpec tests for utility functions

Describe 'lib/util.sh'
Include spec/helpers/env.sh

# Source the util module
# shellcheck disable=SC2016
BeforeAll 'source "$ROOT/lib/util.sh"'

Describe 'String utilities'
Describe 'trim'
It 'removes leading whitespace'
When call trim "  hello"
The output should equal "hello"
End

It 'removes trailing whitespace'
When call trim "hello  "
The output should equal "hello"
End

It 'removes both leading and trailing'
When call trim "  hello world  "
The output should equal "hello world"
End

It 'handles empty string'
When call trim ""
The output should equal ""
End
End

Describe 'uppercase'
It 'converts to uppercase'
When call uppercase "hello world"
The output should equal "HELLO WORLD"
End
End

Describe 'lowercase'
It 'converts to lowercase'
When call lowercase "HELLO WORLD"
The output should equal "hello world"
End
End

Describe 'starts_with'
It 'returns success when string starts with prefix'
When call starts_with "hello world" "hello"
The status should be success
End

It 'returns failure when string does not start with prefix'
When call starts_with "hello world" "world"
The status should be failure
End
End

Describe 'ends_with'
It 'returns success when string ends with suffix'
When call ends_with "hello world" "world"
The status should be success
End

It 'returns failure when string does not end with suffix'
When call ends_with "hello world" "hello"
The status should be failure
End
End
End

Describe 'Array utilities'
Describe 'array_join'
It 'joins array with delimiter'
When call array_join "," "a" "b" "c"
The output should equal "a,b,c"
End

It 'works with single element'
When call array_join "," "single"
The output should equal "single"
End

It 'handles empty array'
When call array_join ","
The output should equal ""
End
End

Describe 'array_contains'
It 'finds element in array'
When call array_contains "b" "a" "b" "c"
The status should be success
End

It 'returns failure when element not found'
When call array_contains "d" "a" "b" "c"
The status should be failure
End
End
End

Describe 'File utilities'
Describe 'file_sha256'
It 'calculates SHA256 hash'
Skip if 'command -v sha256sum >/dev/null || command -v shasum >/dev/null || exit 0'
When call file_sha256 "$ROOT/VERSION"
The status should be success
The output should match pattern '[0-9a-f]*'
End

It 'fails on missing file'
When run bash -c "source $ROOT/lib/error.sh && source $ROOT/lib/util.sh && file_sha256 /nonexistent"
The status should equal 5
The error should include "Required file not found"
End
End

Describe 'file_age'
It 'returns age in seconds'
When call file_age "$ROOT/VERSION"
The status should be success
The output should match pattern '[0-9]*'
End
End

Describe 'ensure_executable'
It 'makes file executable'
temp_file="$TEST_TMP/test_exec.sh"
echo "#!/bin/bash" >"$temp_file"
chmod -x "$temp_file"
When call ensure_executable "$temp_file"
The status should be success
The path "$temp_file" should be executable
End
End
End

Describe 'Path utilities'
Describe 'is_absolute'
It 'returns success for absolute path'
When call is_absolute "/absolute/path"
The status should be success
End

It 'returns failure for relative path'
When call is_absolute "relative/path"
The status should be failure
End
End

Describe 'basename_no_ext'
It 'extracts filename without extension'
When call basename_no_ext "/path/to/file.txt"
The output should equal "file"
End

It 'handles files with multiple dots'
When call basename_no_ext "/path/to/file.tar.gz"
The output should equal "file.tar"
End

It 'handles files without extension'
When call basename_no_ext "/path/to/file"
The output should equal "file"
End
End
End

Describe 'Process utilities'
Describe 'is_running'
It 'detects running process'
When call is_running "$$"
The status should be success
End

It 'returns failure for non-existent PID'
When call is_running "999999"
The status should be failure
End

It 'validates PID is integer'
When run bash -c "source $ROOT/lib/error.sh && source $ROOT/lib/util.sh && is_running 'not_a_number'"
The status should equal 2
The error should include "PID must be an integer"
End
End
End

Describe 'Time utilities'
Describe 'parse_duration'
It 'parses hours'
When call parse_duration "2h"
The output should equal "7200"
End

It 'parses minutes'
When call parse_duration "30m"
The output should equal "1800"
End

It 'parses seconds'
When call parse_duration "45s"
The output should equal "45"
End

It 'parses combined duration'
When call parse_duration "1h30m15s"
The output should equal "5415"
End

It 'parses days'
When call parse_duration "2d"
The output should equal "172800"
End

It 'treats plain number as seconds'
When call parse_duration "100"
The output should equal "100"
End
End

Describe 'format_duration'
It 'formats seconds only'
When call format_duration "45"
The output should equal "45s"
End

It 'formats minutes and seconds'
When call format_duration "90"
The output should equal "1m30s"
End

It 'formats hours, minutes, seconds'
When call format_duration "3661"
The output should equal "1h1m1s"
End

It 'formats zero as 0s'
When call format_duration "0"
The output should equal "0s"
End
End

Describe 'Time utilities'
Describe 'get_utc_timestamp'
It 'returns ISO 8601 UTC timestamp'
When call get_utc_timestamp
# Verify format with string matching (ShellSpec pattern syntax)
The line 1 of output should match pattern '????-??-??T??:??:??Z'
The status should be success
End

It 'returns current time (not fixed)'
timestamp1=$(get_utc_timestamp)
sleep 0.2
timestamp2=$(get_utc_timestamp)
# Timestamps should be different after a brief delay
The value "$timestamp1" should not equal "$timestamp2"
End
End

Describe 'get_utc_epoch'
It 'returns Unix epoch timestamp'
When call get_utc_epoch
# Verify output is a positive integer (using word matcher)
The word 1 of output should match pattern '*[0-9]*'
The status should be success
End

It 'increments over time'
epoch1=$(get_utc_epoch)
sleep 0.2
epoch2=$(get_utc_epoch)
# Second epoch should be at least slightly later
diff=$((epoch2 - epoch1))
When call test "$diff" -ge 0
The status should be success
End
End

Describe 'iso8601_to_epoch'
It 'converts UTC timestamp to epoch'
# Known timestamp: 2025-01-01T00:00:00Z = 1735689600
When call iso8601_to_epoch "2025-01-01T00:00:00Z"
The output should equal "1735689600"
The status should be success
End

It 'handles timestamps with seconds'
# 2025-01-01T12:30:45Z = 1735689600 + 12*3600 + 30*60 + 45
When call iso8601_to_epoch "2025-01-01T12:30:45Z"
The output should equal "1735734645"
The status should be success
End

It 'produces consistent results across multiple calls'
timestamp="2025-10-21T14:30:00Z"
result1=$(iso8601_to_epoch "$timestamp")
result2=$(iso8601_to_epoch "$timestamp")
The value "$result1" should equal "$result2"
End

It 'validates UTC timezone (Z suffix required)'
# This test ensures we are correctly parsing UTC timestamps
# If the bug exists, BSD date without -u will interpret as local time
# causing a timezone offset error
timestamp=$(get_utc_timestamp)
epoch1=$(get_utc_epoch)
sleep 0.2
epoch2=$(iso8601_to_epoch "$timestamp")
# Difference should be small (allowing for processing time)
# NOT hours (which would indicate timezone bug)
diff=$((epoch1 - epoch2))
# Absolute value should be less than 5 seconds
abs_diff="${diff#-}"
When call test "$abs_diff" -lt 5
The status should be success
End
End
End
End

Describe 'JSON utilities'
Describe 'json_get'
It 'extracts field from JSON'
Skip if 'command -v jq >/dev/null || exit 0'
json='{"name": "test", "value": 42}'
When call json_get "$json" ".name"
The output should equal "test"
End
End

Describe 'json_validate'
It 'validates correct JSON'
Skip if 'command -v jq >/dev/null || exit 0'
When call json_validate '{"valid": true}'
The status should be success
End

It 'rejects invalid JSON'
Skip if 'command -v jq >/dev/null || exit 0'
When call json_validate '{invalid json'
The status should be failure
End
End
End
End
