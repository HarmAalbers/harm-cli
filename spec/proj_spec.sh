#!/usr/bin/env bash
# ShellSpec tests for Project module

Describe 'lib/proj.sh'
Include spec/helpers/env.sh

BeforeAll 'setup_proj_test_env'
AfterAll 'cleanup_proj_test_env'

setup_proj_test_env() {
  # Set test configuration
  export HARM_CLI_HOME="$TEST_TMP"
  export HARM_LOG_LEVEL=ERROR # Suppress DEBUG/INFO logs during tests

  # Create test project directories
  mkdir -p "$TEST_TMP/test-project-1"
  mkdir -p "$TEST_TMP/test-project-2"
  echo '{}' >"$TEST_TMP/test-project-1/package.json"          # nodejs type
  echo '[project]' >"$TEST_TMP/test-project-2/pyproject.toml" # python type

  # Source the module
  source "$ROOT/lib/proj.sh"
}

cleanup_proj_test_env() {
  rm -rf "${TEST_TMP:?}/test-project-1"
  rm -rf "${TEST_TMP:?}/test-project-2"
  rm -rf "${TEST_TMP:?}/projects"
}

# ═══════════════════════════════════════════════════════════════
# Project List Tests
# ═══════════════════════════════════════════════════════════════

Describe 'proj_list'
It 'handles empty registry gracefully'
When call proj_list
The status should equal 0
The output should include "No projects registered"
End

It 'provides helpful message when empty'
When call proj_list
The output should include "harm-cli proj add"
End

It 'supports JSON output'
export HARM_CLI_FORMAT="json"
When call proj_list
The output should equal "[]"
End

It 'function exists and is exported'
When call type -t proj_list
The output should equal "function"
End
End

# ═══════════════════════════════════════════════════════════════
# Project Add Tests
# ═══════════════════════════════════════════════════════════════

Describe 'proj_add'
It 'adds project with auto-detected name'
When call proj_add "$TEST_TMP/test-project-1"
The status should equal 0
The output should include "added"
The output should include "test-project-1"
End

It 'adds project with custom name'
When call proj_add "$TEST_TMP/test-project-2" "myproject"
The status should equal 0
The output should include "myproject"
End

It 'detects nodejs project type'
When call proj_add "$TEST_TMP/test-project-1" "nodejs-test"
The status should equal 0
The output should include "nodejs"
End

It 'detects python project type'
When call proj_add "$TEST_TMP/test-project-2" "python-test"
The status should equal 0
The output should include "python"
End

It 'rejects invalid path'
When call proj_add "/nonexistent/path"
The status should not equal 0
The stderr should include "Invalid project path"
End

It 'prevents duplicate names'
# Add first project
proj_add "$TEST_TMP/test-project-1" "duplicate" >/dev/null 2>&1
# Try to add again with same name
When call proj_add "$TEST_TMP/test-project-2" "duplicate"
The status should not equal 0
The stderr should include "already exists"
End

It 'function exists and is exported'
When call type -t proj_add
The output should equal "function"
End
End

# ═══════════════════════════════════════════════════════════════
# Project Remove Tests
# ═══════════════════════════════════════════════════════════════

Describe 'proj_remove'
It 'removes existing project'
# Add project first
proj_add "$TEST_TMP/test-project-1" "to-remove" >/dev/null 2>&1
# Then remove it
When call proj_remove "to-remove"
The status should equal 0
The output should include "removed"
End

It 'handles non-existent project'
When call proj_remove "nonexistent"
The status should not equal 0
The stderr should include "not found"
End

It 'function exists and is exported'
When call type -t proj_remove
The output should equal "function"
End
End

# ═══════════════════════════════════════════════════════════════
# Project Switch Tests
# ═══════════════════════════════════════════════════════════════

Describe 'proj_switch'
It 'outputs cd command for existing project'
# Add project first
proj_add "$TEST_TMP/test-project-1" "switch-test" >/dev/null 2>&1
# Then switch to it
When call proj_switch "switch-test"
The status should equal 0
The output should include "cd"
The output should include "test-project-1"
End

It 'handles non-existent project'
When call proj_switch "nonexistent"
The status should not equal 0
The stderr should include "not found"
The output should include "Available projects"
End

It 'shows available projects when not found'
When call proj_switch "missing"
The status should not equal 0
The stderr should include "not found"
The output should include "Available projects"
End

It 'function exists and is exported'
When call type -t proj_switch
The output should equal "function"
End
End

# ═══════════════════════════════════════════════════════════════
# Stdout Filtering Tests (for the shell function improvement)
# ═══════════════════════════════════════════════════════════════

Describe 'proj shell function stdout filtering'
It 'filters cd command from output with pollution'
# Test the grep filtering logic that extracts only the cd command
# when stdout is polluted with hashes/debug output
When call bash -c 'output="cd \"/test\"
a359b87062e3dc19deed9a20e11402d6c52e322cbb02df493222f384950bb735"
switch_cmd="$(echo "$output" | grep -m1 "^cd ")"
grep_exit=$?
# grep should succeed (exit 0) and find the cd command
[ $grep_exit -eq 0 ] && [[ "$switch_cmd" =~ ^cd\  ]]'
The status should equal 0
End

It 'handles output without cd command gracefully'
# Test that grep correctly signals "no match" (exit 1) when no cd command exists
When call bash -c 'output="Some error message"
switch_cmd="$(echo "$output" | grep -m1 "^cd ")"
grep_exit=$?
# grep should fail with exit 1 (no match), and switch_cmd should be empty
[ $grep_exit -eq 1 ] && [ -z "$switch_cmd" ]'
The status should equal 0
End

It 'grep returns first cd line only when multiple exist'
# Test that grep with -m1 only extracts the first cd line, not subsequent ones
When call bash -c 'output="cd \"/first\"
cd \"/second\""
switch_cmd="$(echo "$output" | grep -m1 "^cd ")"
# Should extract only the first cd line
[[ "$switch_cmd" == "cd \"/first\"" ]]'
The status should equal 0
End

It 'validates cd command format before execution'
# Test that the function recognizes valid vs invalid cd command formats
When call bash -c 'valid_cmd="cd \"/valid/path\""
invalid_cmd="echo \"/path\""
# Valid: starts with "cd " followed by path
[[ "$valid_cmd" =~ ^cd\  ]] && \
# Invalid: does not start with "cd "
! [[ "$invalid_cmd" =~ ^cd\  ]]'
The status should equal 0
End

It 'handles paths with spaces correctly'
# Test that cd commands with spaces in paths are preserved correctly
When call bash -c 'output="cd \"/path with spaces/test\""
switch_cmd="$(echo "$output" | grep -m1 "^cd ")"
# grep should preserve spaces in the path
[[ "$switch_cmd" == "cd \"/path with spaces/test\"" ]]'
The status should equal 0
End
End
