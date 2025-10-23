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

Describe "Function parameter consistency (updated for new architecture)"
It "add_to_shell_rc defined without parameters"
# New architecture: add_to_shell_rc doesn't take parameters
When run grep "^add_to_shell_rc()" install.sh
The status should be success
The output should equal "add_to_shell_rc() {"
End

It "install_completions function removed (handled in harm-cli.sh)"
# Check that install_completions no longer exists as a function
When run grep "^install_completions()" install.sh
The status should be failure
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

It "defines add_to_shell_rc function"
When run grep -q "^add_to_shell_rc()" install.sh
The status should be success
End
End

Describe "Architectural consistency (new architecture)"
It "generate_aliases writes directly to ~/.harm-cli/aliases.sh"
When run grep -A10 "^generate_aliases()" install.sh
The output should include 'HARM_CLI_HOME/aliases.sh'
End

It "generate_aliases no longer returns file path"
# New architecture: generate_aliases doesn't echo file path
When run grep -A50 "^generate_aliases()" install.sh
The output should not include 'echo "$aliases_file"'
End

It "main flow calls generate_aliases without capturing output"
When run grep -A5 "generate_aliases" install.sh
The output should include 'generate_aliases'
The output should not include 'aliases_file=$(generate_aliases)'
End

It "main flow calls add_to_shell_rc without parameters"
When run grep "add_to_shell_rc" install.sh
The output should include 'add_to_shell_rc'
The output should not include 'add_to_shell_rc "$'
End
End

Describe "Output management (new architecture)"
It "generate_aliases uses print_step for user feedback"
When run grep -A5 "^generate_aliases()" install.sh
The output should include 'print_step'
End

It "generate_aliases uses print_success to confirm creation"
When run grep -A50 "^generate_aliases()" install.sh
The output should include 'print_success'
End
End

# ═══════════════════════════════════════════════════════════════
# New Architecture Tests (Industry Standard: Single-Line Sourcing)
# ═══════════════════════════════════════════════════════════════

Describe "New file structure (separated config files)"
Describe "Function existence"
It "defines generate_shell_integration function"
When run grep -q "^generate_shell_integration()" install.sh
The status should be success
End
End

Describe "generate_shell_integration behavior"
It "harm-cli.sh sources config.sh"
# Verify the function generates code that sources config.sh
When run grep -A100 "^generate_shell_integration()" install.sh
The output should include 'source "$HARM_CLI_HOME/config.sh"'
End

It "harm-cli.sh sources aliases.sh"
# Verify the function generates code that sources aliases.sh
When run grep -A100 "^generate_shell_integration()" install.sh
The output should include 'source "$HARM_CLI_HOME/aliases.sh"'
End

It "harm-cli.sh adds to PATH"
# Verify the function generates code that adds to PATH
When run grep -A100 "^generate_shell_integration()" install.sh
The output should include 'export PATH='
End

It "harm-cli.sh loads completions based on shell type"
# Verify the function generates code that detects shell and loads completions
When run grep -A100 "^generate_shell_integration()" install.sh
The output should include 'ZSH_VERSION'
The output should include 'BASH_VERSION'
End

It "harm-cli.sh has proper header comments"
# Verify generated file has documentation
When run grep -A100 "^generate_shell_integration()" install.sh
The output should include 'Shell Integration Loader'
The output should include 'To customize:'
End
End

Describe "generate_aliases behavior (updated)"
It "writes directly to ~/.harm-cli/aliases.sh"
# Verify function creates file in correct location
When run grep -A10 "^generate_aliases()" install.sh
The output should include 'HARM_CLI_HOME/aliases.sh'
End

It "generates aliases based on SHORTCUT_STYLE patterns"
# Verify function has case statement for different styles
When run grep -A80 "^generate_aliases()" install.sh
The output should include 'case "$SHORTCUT_STYLE"'
The output should include "alias h='harm-cli'"
The output should include "alias work='harm-cli work'"
End

It "includes harm-cli comment identifier in aliases"
# Verify aliases use "# harm-cli:" prefix
When run grep -A80 "^generate_aliases()" install.sh
The output should include '# harm-cli:'
End

It "has proper header with usage instructions"
# Verify generated file has helpful header
When run grep -A80 "^generate_aliases()" install.sh
The output should include 'harm-cli Shell Aliases'
The output should include 'You can customize these aliases'
End
End

Describe "add_to_shell_rc behavior (simplified)"
It "adds single source line for harm-cli.sh"
# Verify function adds the correct source line
When run grep -A20 "^add_to_shell_rc()" install.sh
The output should include 'source ~/.harm-cli/harm-cli.sh'
End

It "includes harm-cli identifier comment"
# Verify the line added to .zshrc has identifying comment
When run grep -A20 "^add_to_shell_rc()" install.sh
The output should include '# harm-cli'
End

It "checks if already installed before adding"
# Verify function is idempotent
When run grep -A20 "^add_to_shell_rc()" install.sh
The output should include 'grep -q "harm-cli.sh"'
End
End
End

Describe "Comment identifier standards"
It "harm-cli.sh uses harm-cli identifier in comments"
# Verify generated harm-cli.sh has proper identification
When run grep -A100 "^generate_shell_integration()" install.sh
The output should include '# harm-cli'
End

It "aliases.sh uses harm-cli identifier in comments"
# Verify generated aliases.sh has proper identification
When run grep -A80 "^generate_aliases()" install.sh
The output should include '# harm-cli'
End

It "config.sh uses harm-cli identifier in comments"
# Verify generated config.sh has proper identification
When run grep -A200 "^generate_config_file()" install.sh
The output should include '# harm-cli'
End
End
End
