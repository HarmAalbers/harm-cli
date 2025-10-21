#!/usr/bin/env bash
# ShellSpec tests for Python module

Describe 'lib/python.sh'
Include spec/helpers/env.sh

BeforeAll 'setup_python_test_env'
AfterAll 'cleanup_python_test_env'

setup_python_test_env() {
  # Set test configuration
  export HARM_CLI_HOME="$TEST_TMP"
  export HARM_CLI_LOG_LEVEL="DEBUG"

  # Create test Python project
  cat >"$TEST_TMP/pyproject.toml" <<'EOF'
[tool.poetry]
name = "test-project"
version = "0.1.0"
EOF

  # Source the module
  source "$ROOT/lib/python.sh"
}

cleanup_python_test_env() {
  rm -f "$TEST_TMP/pyproject.toml"
}

# ═══════════════════════════════════════════════════════════════
# Python Utilities Tests
# ═══════════════════════════════════════════════════════════════

Describe 'python_is_poetry'
It 'detects Poetry project'
cd "$TEST_TMP" || return
When call python_is_poetry
The status should equal 0
End

It 'detects non-Poetry project'
cd "$ROOT" || return
When call python_is_poetry
The status should equal 1
End

It 'function exists and is exported'
When call type -t python_is_poetry
The output should equal "function"
End
End

Describe 'python_is_venv_active'
It 'detects when venv not active'
unset VIRTUAL_ENV
When call python_is_venv_active
The status should equal 1
End

It 'detects when venv active'
export VIRTUAL_ENV="/path/to/venv"
When call python_is_venv_active
The status should equal 0
End

It 'function exists and is exported'
When call type -t python_is_venv_active
The output should equal "function"
End
End

# ═══════════════════════════════════════════════════════════════
# Python Operations Tests
# ═══════════════════════════════════════════════════════════════

Describe 'python_status'
It 'shows Python environment status'
When call python_status
The status should equal 0
The output should include "Python Environment Status"
End

It 'shows Python version'
When call python_status
The output should include "Python:"
End

It 'shows virtual environment status'
When call python_status
The output should include "Virtual Environment:"
End

It 'function exists and is exported'
When call type -t python_status
The output should equal "function"
End
End

Describe 'python_test'
It 'function exists and is exported'
When call type -t python_test
The output should equal "function"
End

# Note: Actual test execution requires pytest/unittest
# Just verify function structure
End

Describe 'python_lint'
It 'function exists and is exported'
When call type -t python_lint
The output should equal "function"
End
End

Describe 'python_format'
It 'function exists and is exported'
When call type -t python_format
The output should equal "function"
End
End
End
