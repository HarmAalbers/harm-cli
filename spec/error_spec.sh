#!/usr/bin/env bash
# ShellSpec tests for error handling module

Describe 'lib/error.sh'
Include spec/helpers/env.sh

# Source the error module
BeforeAll 'source "$ROOT/lib/error.sh"'

Describe 'Exit codes'
It 'defines standard exit codes'
The variable EXIT_SUCCESS should equal 0
The variable EXIT_ERROR should equal 1
The variable EXIT_INVALID_ARGS should equal 2
The variable EXIT_MISSING_DEPS should equal 3
The variable EXIT_PERMISSION should equal 4
The variable EXIT_NOT_FOUND should equal 5
The variable EXIT_TIMEOUT should equal 124
The variable EXIT_CANCELLED should equal 130
End
End

Describe 'Color definitions'
Context 'when colors are available'
It 'defines color variables'
The variable ERROR_RED should be defined
The variable WARNING_YELLOW should be defined
The variable INFO_BLUE should be defined
The variable SUCCESS_GREEN should be defined
The variable BOLD should be defined
The variable RESET should be defined
The variable DIM should be defined
End
End
End

Describe 'error_msg'
It 'prints error message to stderr'
When call error_msg "Test error"
The error should include "ERROR: Test error"
End

It 'supports JSON output format'
export HARM_CLI_FORMAT="json"
When call error_msg "JSON error" 42
The error should include '"error"'
The error should include '"code"'
The error should include "JSON error"
unset HARM_CLI_FORMAT
End
End

Describe 'warn_msg'
It 'prints warning message to stderr'
When call warn_msg "Test warning"
The error should include "WARNING: Test warning"
End

It 'supports JSON output format'
export HARM_CLI_FORMAT="json"
When call warn_msg "JSON warning"
The error should include '"warning"'
The error should include "JSON warning"
unset HARM_CLI_FORMAT
End
End

Describe 'info_msg'
It 'prints info message to stderr'
When call info_msg "Test info"
The error should include "INFO: Test info"
End

It 'supports JSON output format'
export HARM_CLI_FORMAT="json"
When call info_msg "JSON info"
The error should include '"info"'
The error should include "JSON info"
unset HARM_CLI_FORMAT
End
End

Describe 'success_msg'
It 'prints success message to stderr'
When call success_msg "Test success"
The error should include "Test success"
End

It 'supports JSON output format'
export HARM_CLI_FORMAT="json"
When call success_msg "JSON success"
The error should include '"success"'
The error should include "JSON success"
unset HARM_CLI_FORMAT
End
End

Describe 'error_with_code'
It 'exits with specified code'
When run bash -c "source $ROOT/lib/error.sh; error_with_code 42 'Test error'"
The status should equal 42
The error should include "Test error"
End
End

Describe 'require_command'
It 'succeeds when command exists'
When call require_command "bash"
The status should be success
End

It 'fails when command does not exist'
When run bash -c "source $ROOT/lib/error.sh; require_command nonexistent_command_12345"
The status should equal "$EXIT_MISSING_DEPS"
The error should include "Required command not found"
The error should include "nonexistent_command_12345"
End

It 'includes installation hint when provided'
When run bash -c "source $ROOT/lib/error.sh; require_command nonexistent_cmd 'brew install nonexistent'"
The status should equal "$EXIT_MISSING_DEPS"
The error should include "Install: brew install nonexistent"
End
End

Describe 'require_file'
It 'succeeds when file exists'
When call require_file "$ROOT/VERSION"
The status should be success
End

It 'fails when file does not exist'
When run bash -c "source $ROOT/lib/error.sh; require_file /nonexistent/file.txt"
The status should equal "$EXIT_NOT_FOUND"
The error should include "Required file not found"
End

It 'includes description when provided'
When run bash -c "source $ROOT/lib/error.sh; require_file /nonexistent/file.txt 'config file'"
The status should equal "$EXIT_NOT_FOUND"
The error should include "Required config file not found"
End
End

Describe 'require_dir'
It 'succeeds when directory exists'
When call require_dir "$ROOT/lib"
The status should be success
End

It 'fails when directory does not exist'
When run bash -c "source $ROOT/lib/error.sh; require_dir /nonexistent/directory"
The status should equal "$EXIT_NOT_FOUND"
The error should include "Required directory not found"
End
End

Describe 'require_permission'
It 'succeeds when path is writable'
Skip if 'test ! -w /tmp' # Skip if /tmp is not writable
When call require_permission "/tmp"
The status should be success
End

It 'fails when path is not writable'
Skip if 'test -w /etc/hosts' # Skip if somehow writable
When run bash -c "source $ROOT/lib/error.sh; require_permission /etc/hosts"
The status should equal "$EXIT_PERMISSION"
The error should include "No write permission"
End
End
End
