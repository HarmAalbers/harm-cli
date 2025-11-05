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
End
