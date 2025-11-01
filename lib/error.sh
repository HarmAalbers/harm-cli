# shellcheck shell=bash
# error.sh - Production-grade error handling for harm-cli
# Ported from: ~/.zsh/00_error_handling.zsh
#
# This module provides:
# - Standardized exit codes
# - Color-coded error messages
# - Stack trace support
# - JSON error output
# - Contextual help integration

set -Eeuo pipefail
IFS=$'\n\t'

# Source logging if available
if [[ -n "${HARM_LIB_DIR:-}" ]] && [[ -f "${HARM_LIB_DIR}/logging.sh" ]]; then
  # shellcheck source=lib/logging.sh
  source "${HARM_LIB_DIR}/logging.sh"
fi

# ═══════════════════════════════════════════════════════════════
# Exit Code Standards
# ═══════════════════════════════════════════════════════════════

# Prevent re-definition if already loaded
if [[ -z "${_HARM_ERROR_LOADED:-}" ]]; then
  readonly EXIT_SUCCESS=0
  readonly EXIT_ERROR=1
  readonly EXIT_INVALID_ARGS=2
  readonly EXIT_MISSING_DEPS=3
  readonly EXIT_PERMISSION=4
  readonly EXIT_NOT_FOUND=5
  readonly EXIT_INVALID_STATE=6
  readonly EXIT_TIMEOUT=124
  readonly EXIT_CANCELLED=130

  # Export for use in subshells
  export EXIT_SUCCESS EXIT_ERROR EXIT_INVALID_ARGS EXIT_MISSING_DEPS
  export EXIT_PERMISSION EXIT_NOT_FOUND EXIT_INVALID_STATE EXIT_TIMEOUT EXIT_CANCELLED

  # Color definitions
  if [[ -t 2 ]] && command -v tput >/dev/null 2>&1 && [[ -z "${NO_COLOR:-}" ]]; then
    ERROR_RED="$(tput setaf 1)"
    WARNING_YELLOW="$(tput setaf 3)"
    INFO_BLUE="$(tput setaf 4)"
    SUCCESS_GREEN="$(tput setaf 2)"
    BOLD="$(tput bold)"
    RESET="$(tput sgr0)"
    DIM="$(tput dim)"
  else
    ERROR_RED="" WARNING_YELLOW="" INFO_BLUE="" SUCCESS_GREEN=""
    BOLD="" RESET="" DIM=""
  fi

  readonly ERROR_RED WARNING_YELLOW INFO_BLUE SUCCESS_GREEN BOLD RESET DIM
  export ERROR_RED WARNING_YELLOW INFO_BLUE SUCCESS_GREEN BOLD RESET DIM

  readonly _HARM_ERROR_LOADED=1
fi

# ═══════════════════════════════════════════════════════════════
# Core Error Functions
# ═══════════════════════════════════════════════════════════════

# error_msg: Print formatted error message to stderr
# Usage: error_msg "message" [exit_code]
error_msg() {
  local msg="${1:?error_msg requires a message}"
  local code="${2:-1}"

  # Log error event
  if declare -F log_error >/dev/null 2>&1; then
    log_error "error" "Error reported: $msg" "Code: $code"
  fi

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --arg message "$msg" \
      --argjson code "$code" \
      '{error: $message, code: $code, timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))}' >&2
  else
    echo "${ERROR_RED}${BOLD}ERROR:${RESET} $msg" >&2
    if [[ -n "${DEBUG:-}" ]]; then
      echo "${DIM}Exit code: $code${RESET}" >&2
    fi
  fi
}

# warn_msg: Print formatted warning message to stderr
# Usage: warn_msg "message"
warn_msg() {
  local msg="${1:?warn_msg requires a message}"

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --arg message "$msg" \
      '{warning: $message, timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))}' >&2
  else
    echo "${WARNING_YELLOW}${BOLD}WARNING:${RESET} $msg" >&2
  fi
}

# info_msg: Print formatted info message to stderr
# Usage: info_msg "message"
info_msg() {
  local msg="${1:?info_msg requires a message}"

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --arg message "$msg" \
      '{info: $message, timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))}' >&2
  else
    echo "${INFO_BLUE}${BOLD}INFO:${RESET} $msg" >&2
  fi
}

# success_msg: Print formatted success message to stderr
# Usage: success_msg "message"
success_msg() {
  local msg="${1:?success_msg requires a message}"

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --arg message "$msg" \
      '{success: $message, timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))}' >&2
  else
    echo "${SUCCESS_GREEN}${BOLD}✓${RESET} $msg" >&2
  fi
}

# ═══════════════════════════════════════════════════════════════
# Advanced Error Handling
# ═══════════════════════════════════════════════════════════════

# error_with_code: Print error and exit with specific code
# Usage: error_with_code <code> "message"
error_with_code() {
  local code="${1:?error_with_code requires exit code}"
  shift
  local msg="$*"

  # Log fatal error
  if declare -F log_error >/dev/null 2>&1; then
    log_error "Fatal error, exiting with code $code: $msg"
  fi

  error_msg "$msg" "$code"

  # Show stack trace in debug mode
  if [[ -n "${DEBUG:-}" ]]; then
    echo "${DIM}Stack trace:${RESET}" >&2
    local i=0
    while caller $i >&2 2>/dev/null; do
      ((++i)) # Pre-increment to avoid exit code 1 with set -e when i=0
    done
  fi

  exit "$code"
}

# require_command: Check if command exists, die if not
# Usage: require_command "command" ["installation hint"]
require_command() {
  local cmd="${1:?require_command needs command name}"
  local hint="${2:-}"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    # Log missing command
    if declare -F log_error >/dev/null 2>&1; then
      log_error "Required command not found: $cmd"
    fi

    local msg="Required command not found: $cmd"
    [[ -n "$hint" ]] && msg="$msg"$'\n'"  Install: $hint"
    error_with_code "$EXIT_MISSING_DEPS" "$msg"
  fi
}

# require_file: Check if file exists, die if not
# Usage: require_file "/path/to/file" ["description"]
require_file() {
  local file="${1:?require_file needs file path}"
  local desc="${2:-file}"

  if [[ ! -f "$file" ]]; then
    # Log missing file
    if declare -F log_error >/dev/null 2>&1; then
      log_error "Required $desc not found: $file"
    fi

    error_with_code "$EXIT_NOT_FOUND" "Required $desc not found: $file"
  fi
}

# require_dir: Check if directory exists, die if not
# Usage: require_dir "/path/to/dir" ["description"]
require_dir() {
  local dir="${1:?require_dir needs directory path}"
  local desc="${2:-directory}"

  if [[ ! -d "$dir" ]]; then
    # Log missing directory
    if declare -F log_error >/dev/null 2>&1; then
      log_error "Required $desc not found: $dir"
    fi

    error_with_code "$EXIT_NOT_FOUND" "Required $desc not found: $dir"
  fi
}

# require_permission: Check if path is writable, die if not
# Usage: require_permission "/path" ["description"]
require_permission() {
  local path="${1:?require_permission needs path}"
  local desc="${2:-path}"

  if [[ ! -w "$path" ]]; then
    # Log permission error
    if declare -F log_error >/dev/null 2>&1; then
      log_error "No write permission for $desc: $path"
    fi

    error_with_code "$EXIT_PERMISSION" "No write permission for $desc: $path"
  fi
}

# ═══════════════════════════════════════════════════════════════
# Trap Handlers
# ═══════════════════════════════════════════════════════════════

# cleanup_handler: Run cleanup on exit
# Usage: trap cleanup_handler EXIT
cleanup_handler() {
  local exit_code=$?

  # Log cleanup execution
  if declare -F log_debug >/dev/null 2>&1; then
    log_debug "Running cleanup handler (exit_code=$exit_code)"
  fi

  # Call custom cleanup if defined
  if declare -F cleanup >/dev/null; then
    cleanup || true
  fi

  return "$exit_code"
}

# error_trap_handler: Handle ERR trap
# Usage: trap error_trap_handler ERR
error_trap_handler() {
  local exit_code=$?
  local line_no="${BASH_LINENO[0]}"
  local bash_source="${BASH_SOURCE[1]}"
  local func_name="${FUNCNAME[1]:-main}"

  # Log trap execution
  if declare -F log_error >/dev/null 2>&1; then
    log_error "ERR trap triggered: $bash_source:$line_no in $func_name (exit_code=$exit_code)"
  fi

  error_msg "Command failed in $bash_source:$line_no ($func_name)" "$exit_code"

  if [[ -n "${DEBUG:-}" ]]; then
    echo "${DIM}Stack trace:${RESET}" >&2
    local i=0
    while caller $i >&2 2>/dev/null; do
      ((++i)) # Pre-increment to avoid exit code 1 with set -e when i=0
    done
  fi

  return "$exit_code"
}

# ═══════════════════════════════════════════════════════════════
# Exports
# ═══════════════════════════════════════════════════════════════

export -f error_msg warn_msg info_msg success_msg
export -f error_with_code
export -f require_command require_file require_dir require_permission
export -f cleanup_handler error_trap_handler
