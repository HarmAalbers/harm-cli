#!/usr/bin/env bash
# ShellSpec tests for harm-cli core functionality

Describe 'harm-cli core'
Include spec/helpers/env.sh

Describe 'version command'
It 'shows version in text format'
When run "$CLI" version
The status should be success
The output should include "harm-cli version"
The output should include "0.1.0-alpha"
End

It 'shows version in JSON format'
When run "$CLI" version json
The status should be success
The output should include '"version"'
The output should include "0.1.0-alpha"
End

It 'shows version with --version flag'
When run "$CLI" --version
The status should be success
The output should include "0.1.0-alpha"
End
End

Describe 'help command'
It 'shows help message'
When run "$CLI" help
The status should be success
The output should include "Usage:"
The output should include "Commands:"
End

It 'shows help with --help flag'
When run "$CLI" --help
The status should be success
The output should include "Usage:"
End
End

Describe 'doctor command'
It 'checks system dependencies'
When run "$CLI" doctor
The status should be success
The error should include "Checking system health"
The output should include "Bash version"
End
End

Describe 'error handling'
It 'fails on unknown command'
When run "$CLI" nonexistent-command
The status should be failure
The error should include "Unknown command"
End

It 'fails on unknown option'
When run "$CLI" --nonexistent-option
The status should be failure
The error should include "Unknown option"
End
End
End
