#!/usr/bin/env bash
# shellcheck shell=bash
# ShellSpec test for install.sh
# Integration tests that verify installer behavior

Describe "install.sh"
Describe "Script structure validation"
It "has valid bash syntax"
When run bash -n install.sh
The status should be success
End

It "uses set -u to catch unset variables"
When run grep -q "set -Eeuo pipefail" install.sh
The status should be success
End
End

Describe "Function parameter consistency"
It "install_completions accepts aliases_file parameter"
# Extract the function definition
When run grep -A3 "^install_completions()" install.sh
The output should include 'local aliases_file="$1"'
End

It "add_to_shell_rc accepts aliases_file parameter"
When run grep -A3 "^add_to_shell_rc()" install.sh
The output should include 'local aliases_file="$1"'
End

It "both functions have consistent parameter patterns"
# Both should accept the file as first parameter
install_params=$(grep -A3 "^install_completions()" install.sh | grep "local aliases_file")
add_params=$(grep -A3 "^add_to_shell_rc()" install.sh | grep "local aliases_file")

# Both should have the same parameter pattern
The value "$install_params" should not be blank
The value "$add_params" should not be blank
End

It "install_completions is called with parameter"
# Check that the call site passes the parameter
When run grep "install_completions" install.sh
The output should include 'install_completions "$aliases_file"'
End
End

Describe "ShellCheck compliance"
It "passes ShellCheck with project rules (if shellcheck available)"
# This would have caught the bug if install.sh was linted
# Skip if shellcheck is not installed
Skip if "shellcheck is not installed" ! command -v shellcheck >/dev/null 2>&1
When run shellcheck install.sh --exclude=2016,2034,2094,2148,2155
The status should be success
End
End

Describe "Function existence"
It "defines generate_aliases function"
When run grep -q "^generate_aliases()" install.sh
The status should be success
End

It "defines install_completions function"
When run grep -q "^install_completions()" install.sh
The status should be success
End

It "defines add_to_shell_rc function"
When run grep -q "^add_to_shell_rc()" install.sh
The status should be success
End
End

Describe "Architectural consistency"
It "generate_aliases returns temp file path via echo"
When run grep -A50 "^generate_aliases()" install.sh
The output should include 'echo "$aliases_file"'
End

It "main flow captures generate_aliases output"
When run grep 'aliases_file=' install.sh
The output should include 'aliases_file=$(generate_aliases)'
End

It "main flow passes aliases_file to both functions"
calls=$(grep -E "(install_completions|add_to_shell_rc)" install.sh | grep '\$aliases_file')
# Should have at least 2 calls with $aliases_file parameter
count=$(echo "$calls" | wc -l | tr -d ' ')
The value "$count" should not be blank
The value "$count" should equal 2
End
End
End
