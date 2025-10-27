#!/usr/bin/env bash
# shellcheck shell=bash
# python.sh - Python development environment management
# Ported from: ~/.zsh/80_python_development.zsh
#
# Features:
# - Python environment detection (Poetry, venv, requirements.txt)
# - Project status and health checks
# - Testing integration (pytest, unittest)
# - Linting and formatting (ruff, black, mypy)
# - Django project support
#
# Public API:
#   python_status              - Show Python environment status
#   python_test                - Run test suite
#   python_lint                - Run linters
#   python_format              - Format code
#   python_is_poetry           - Check if Poetry project
#   python_is_venv_active      - Check if venv active
#
# Dependencies: python3, optional: poetry, pytest, ruff

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_PYTHON_LOADED:-}" ]] && return 0

# Source dependencies
PYTHON_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly PYTHON_SCRIPT_DIR

# shellcheck source=lib/common.sh
source "$PYTHON_SCRIPT_DIR/common.sh"
# shellcheck source=lib/error.sh
source "$PYTHON_SCRIPT_DIR/error.sh"
# shellcheck source=lib/logging.sh
source "$PYTHON_SCRIPT_DIR/logging.sh"
# shellcheck source=lib/util.sh
source "$PYTHON_SCRIPT_DIR/util.sh"

# ═══════════════════════════════════════════════════════════════════
# Python Utilities
# ═══════════════════════════════════════════════════════════════════

# python_is_poetry: Check if current directory is a Poetry project
#
# Description:
#   Determines if current directory contains a Poetry project by
#   checking for pyproject.toml file.
#
# Arguments:
#   None
#
# Returns:
#   0 - Poetry project detected
#   1 - Not a Poetry project
#
# Outputs:
#   stderr: Log messages via log_debug
#
# Examples:
#   python_is_poetry && echo "Poetry project"
#   if python_is_poetry; then
#     poetry install
#   fi
#
# Notes:
#   - Checks for pyproject.toml file existence
#   - Doesn't validate file contents
#   - Fast check (<5ms)
#
# Performance:
#   - Typical: <5ms (file system check)
python_is_poetry() {
  log_debug "python" "Checking if Poetry project"

  if [[ -f "pyproject.toml" ]]; then
    log_debug "python" "Poetry project detected"
    return 0
  else
    log_debug "python" "Not a Poetry project"
    return 1
  fi
}

# python_is_venv_active: Check if virtual environment is active
#
# Description:
#   Checks if a Python virtual environment is currently activated
#   by examining the VIRTUAL_ENV environment variable.
#
# Arguments:
#   None
#
# Returns:
#   0 - Virtual environment active
#   1 - No virtual environment active
#
# Outputs:
#   stderr: Log messages via log_debug
#
# Examples:
#   python_is_venv_active || echo "Activate venv first"
#   if python_is_venv_active; then
#     echo "Using venv: $VIRTUAL_ENV"
#   fi
#
# Notes:
#   - Checks VIRTUAL_ENV environment variable
#   - Set by source .venv/bin/activate
#   - Instant check
#
# Performance:
#   - <1ms (environment variable check)
python_is_venv_active() {
  log_debug "python" "Checking if venv active"

  if [[ -n "${VIRTUAL_ENV:-}" ]]; then
    log_debug "python" "Virtual environment active" "$VIRTUAL_ENV"
    return 0
  else
    log_debug "python" "No virtual environment active"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════════
# Python Operations
# ═══════════════════════════════════════════════════════════════════

# python_status: Display Python environment status
#
# Description:
#   Shows comprehensive status of Python environment including version,
#   virtual environment, project type (Poetry/requirements.txt), Django
#   detection, and dependency information.
#
# Arguments:
#   None
#
# Returns:
#   0 - Status displayed successfully
#
# Outputs:
#   stdout: Python environment status report
#   stderr: Log messages via log_info/log_debug
#
# Examples:
#   python_status
#   harm-cli python status
#
# Notes:
#   - Detects Poetry projects (pyproject.toml)
#   - Detects requirements.txt projects
#   - Detects Django projects (manage.py)
#   - Shows venv status (active, available, none)
#   - Provides activation suggestions when needed
#
# Performance:
#   - Typical: 50-200ms (depends on Poetry/Django checks)
#   - Fast path (no Poetry): <50ms
python_status() {
  log_info "python" "Showing Python environment status"

  echo "Python Environment Status"
  echo "══════════════════════════════════════════"
  echo ""

  # Python version
  echo "Python:"
  if command -v python3 >/dev/null 2>&1; then
    local version
    version=$(python3 --version 2>&1 | cut -d' ' -f2)
    echo "  Version: $version"
    echo "  Path: $(command -v python3)"
  elif command -v python >/dev/null 2>&1; then
    local version
    version=$(python --version 2>&1 | cut -d' ' -f2)
    echo "  Version: $version"
    echo "  Path: $(command -v python)"
  else
    echo "  ✗ Python not found"
    echo "  → Install: brew install python3 (macOS)"
    return 1
  fi

  echo ""

  # Virtual environment
  echo "Virtual Environment:"
  if python_is_venv_active; then
    echo "  ✓ Active"
    echo "  Path: $VIRTUAL_ENV"
  elif [[ -d ".venv" ]]; then
    echo "  ⚠  Available but not active"
    echo "  → Activate: source .venv/bin/activate"
  elif [[ -d "venv" ]]; then
    echo "  ⚠  Available but not active"
    echo "  → Activate: source venv/bin/activate"
  else
    echo "  None"
  fi

  echo ""

  # Project type
  echo "Project Type:"
  if python_is_poetry; then
    echo "  ✓ Poetry project (pyproject.toml)"

    if command -v poetry >/dev/null 2>&1; then
      local deps
      deps=$(poetry show 2>/dev/null | wc -l | tr -d ' ')
      echo "  Dependencies: $deps"
    else
      echo "  ⚠  Poetry not installed"
      echo "  → Install: curl -sSL https://install.python-poetry.org | python3 -"
    fi
  elif [[ -f "requirements.txt" ]]; then
    echo "  Requirements.txt project"
    local count
    count=$(grep -v '^#' requirements.txt 2>/dev/null | grep -c -v '^$' || echo "0")
    echo "  Dependencies: $count"
  elif [[ -f "setup.py" ]]; then
    echo "  Setup.py project"
  else
    echo "  No project configuration"
  fi

  # Django detection
  if [[ -f "manage.py" ]]; then
    echo ""
    echo "Django Project:"
    echo "  ✓ Django detected (manage.py)"

    if python_is_venv_active && command -v python >/dev/null 2>&1; then
      # Try to get Django version
      local django_ver
      django_ver=$(python -c "import django; print(django.get_version())" 2>/dev/null || echo "unknown")
      [[ "$django_ver" != "unknown" ]] && echo "  Version: $django_ver"
    fi
  fi

  log_debug "python" "Status displayed"
  return 0
}

# python_test: Run Python test suite
#
# Description:
#   Runs Python tests using pytest (preferred) or unittest.
#   Auto-detects test framework and executes appropriately.
#
# Arguments:
#   $@ - Additional arguments passed to test command
#
# Returns:
#   0 - Tests passed
#   EXIT_COMMAND_FAILED - Tests failed
#   EXIT_DEPENDENCY_MISSING - No test framework found
#
# Outputs:
#   stdout: Test output
#   stderr: Log messages
#
# Examples:
#   python_test
#   python_test -v
#   python_test tests/test_ai.py
#   harm-cli python test
#
# Notes:
#   - Prefers pytest if available
#   - Falls back to unittest discover
#   - Passes all arguments to test command
#   - Django: Uses manage.py test
#
# Performance:
#   - Depends on test suite size
#   - Framework startup: ~100-500ms

# _python_find_and_activate_venv: Find and activate virtual environment
#
# Description:
#   Internal helper that finds and activates venv if available but not active.
#   Modifies current shell environment to activate venv.
#
# Returns:
#   0 - Venv activated or already active
#   1 - No venv found
_python_find_and_activate_venv() {
  # Already active
  if python_is_venv_active; then
    log_debug "python" "Virtual environment already active" "$VIRTUAL_ENV"
    return 0
  fi

  # Find venv directory
  local venv_dir=""
  if [[ -d ".venv" ]]; then
    venv_dir=".venv"
  elif [[ -d "venv" ]]; then
    venv_dir="venv"
  else
    log_debug "python" "No virtual environment found"
    return 1
  fi

  # Activate venv
  local activate_script="$venv_dir/bin/activate"
  if [[ -f "$activate_script" ]]; then
    log_info "python" "Activating virtual environment" "$venv_dir"
    # Source activate script (modifies environment)
    # shellcheck disable=SC1090
    source "$activate_script"
    return 0
  else
    log_warn "python" "Virtual environment directory exists but activate script not found" "$venv_dir"
    return 1
  fi
}

python_test() {
  log_info "python" "Running Python tests"

  # Auto-activate venv if available (non-fatal if not found)
  if ! python_is_venv_active; then
    if _python_find_and_activate_venv; then
      echo "✓ Activated virtual environment"
    else
      echo "⚠  No virtual environment found (continuing anyway)"
    fi
  fi

  # Django project
  if [[ -f "manage.py" ]]; then
    if python_is_venv_active; then
      echo "🧪 Running Django tests..."
      python manage.py test "$@"
      return $?
    else
      warn_msg "Django project detected but no venv active"
      echo "Consider running: source .venv/bin/activate"
    fi
  fi

  # pytest (preferred)
  if command -v pytest >/dev/null 2>&1; then
    echo "🧪 Running tests with pytest..."
    pytest "$@"
    return $?
  fi

  # unittest (fallback)
  if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
    echo "🧪 Running tests with unittest..."
    python -m unittest discover "$@"
    return $?
  fi

  error_msg "No test framework found"
  log_error "python" "No test framework available"
  echo "Install: pip install pytest"
  return "$EXIT_DEPENDENCY_MISSING"
}

# python_lint: Run Python linters
#
# Description:
#   Runs Python code linters. Prefers ruff (fast), falls back to flake8.
#   Checks code quality, style issues, and potential bugs.
#
# Arguments:
#   $@ - Additional arguments passed to linter
#
# Returns:
#   0 - No issues found
#   EXIT_COMMAND_FAILED - Linting issues found
#   EXIT_DEPENDENCY_MISSING - No linter available
#
# Outputs:
#   stdout: Linter output
#   stderr: Log messages
#
# Examples:
#   python_lint
#   python_lint --fix
#   python_lint src/
#   harm-cli python lint
#
# Notes:
#   - Prefers ruff (fast, modern)
#   - Falls back to flake8
#   - ruff can auto-fix with --fix flag
#
# Performance:
#   - ruff: Very fast (~100-500ms for medium projects)
#   - flake8: Slower (~500ms-2s)
python_lint() {
  log_info "python" "Running Python linter"

  # ruff (preferred - fast and modern)
  if command -v ruff >/dev/null 2>&1; then
    echo "🔍 Running ruff..."
    ruff check "$@" .
    return $?
  fi

  # flake8 (fallback)
  if command -v flake8 >/dev/null 2>&1; then
    echo "🔍 Running flake8..."
    flake8 "$@" .
    return $?
  fi

  error_msg "No linter found"
  log_error "python" "No linter available"
  echo "Install: pip install ruff (recommended) or pip install flake8"
  return "$EXIT_DEPENDENCY_MISSING"
}

# python_format: Format Python code
#
# Description:
#   Formats Python code using ruff (preferred) or black.
#   Auto-formats all Python files in current directory.
#
# Arguments:
#   $@ - Additional arguments or specific files
#
# Returns:
#   0 - Formatting successful
#   EXIT_DEPENDENCY_MISSING - No formatter available
#
# Outputs:
#   stdout: Formatter output
#   stderr: Log messages
#
# Examples:
#   python_format
#   python_format src/
#   python_format --check  # Check only, don't modify
#   harm-cli python format
#
# Notes:
#   - ruff format is very fast
#   - black is also excellent
#   - Both modify files in place
#   - Use --check to verify without modifying
#
# Performance:
#   - ruff: Very fast (~100-500ms)
#   - black: Fast (~500ms-2s)
python_format() {
  log_info "python" "Formatting Python code"

  # ruff (preferred - very fast)
  if command -v ruff >/dev/null 2>&1; then
    echo "✨ Formatting with ruff..."
    ruff format "$@" .
    return $?
  fi

  # black (fallback - also excellent)
  if command -v black >/dev/null 2>&1; then
    echo "✨ Formatting with black..."
    black "$@" .
    return $?
  fi

  error_msg "No formatter found"
  log_error "python" "No formatter available"
  echo "Install: pip install ruff (recommended) or pip install black"
  return "$EXIT_DEPENDENCY_MISSING"
}

# Export public functions
export -f python_is_poetry
export -f python_is_venv_active
export -f python_status
export -f python_test
export -f python_lint
export -f python_format

# Mark module as loaded
readonly _HARM_PYTHON_LOADED=1
