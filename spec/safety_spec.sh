#!/usr/bin/env bash
# ShellSpec tests for Safety module

Describe 'lib/safety.sh'
Include spec/helpers/env.sh

BeforeAll 'setup_safety_test_env'
AfterAll 'cleanup_safety_test_env'

setup_safety_test_env() {
  export HARM_CLI_HOME="$TEST_TMP"
  export HARM_CLI_LOG_LEVEL="DEBUG"

  # Create test files
  mkdir -p "$TEST_TMP/test-dir"
  echo "test" >"$TEST_TMP/test-file.txt"

  source "$ROOT/lib/safety.sh"
}

cleanup_safety_test_env() {
  rm -rf "${TEST_TMP:?}/test-dir"
  rm -f "$TEST_TMP/test-file.txt"
}

# ═══════════════════════════════════════════════════════════════
# Safety Functions Tests
# ═══════════════════════════════════════════════════════════════

Describe 'safe_rm'
It 'requires files to be specified'
When call safe_rm
The status should not equal 0
The stderr should include "No files specified"
End

It 'function exists and is exported'
When call type -t safe_rm
The output should equal "function"
End

# Note: Cannot test actual deletion without interactive confirmation
# Testing confirmation flow requires expect or similar
End

Describe 'safe_docker_prune'
It 'function exists and is exported'
When call type -t safe_docker_prune
The output should equal "function"
End

# Note: Requires Docker daemon for full testing
End

Describe 'safe_git_reset'
It 'checks if in git repository'
mkdir -p "$TEST_TMP/not-git"
cd "$TEST_TMP/not-git" || return
When call safe_git_reset
The status should not equal 0
End

It 'function exists and is exported'
When call type -t safe_git_reset
The output should equal "function"
End

# Note: Full reset testing requires git repo and confirmation
End
End
