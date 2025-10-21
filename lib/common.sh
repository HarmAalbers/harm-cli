#!/usr/bin/env bash
# shellcheck shell=bash
# common.sh - Common utilities and helpers for harm-cli
#
# This module provides fundamental utilities used across all harm-cli modules:
#   - Error handling (die, warn)
#   - Logging (log_*, with levels)
#   - File I/O contracts (atomic_write, ensure_dir)
#   - Input validation
#   - Process utilities

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_COMMON_LOADED:-}" ]] && return 0
readonly _HARM_COMMON_LOADED=1

# ═══════════════════════════════════════════════════════════════
# Error Handling
# ═══════════════════════════════════════════════════════════════

# die: Print error message to stderr and exit with given code
# Usage: die "message" [exit_code]
die() {
  local msg="${1:?die requires a message}"
  local code="${2:-1}"
  echo "ERROR: $msg" >&2
  exit "$code"
}

# warn: Print warning message to stderr
# Usage: warn "message"
warn() {
  local msg="${1:?warn requires a message}"
  echo "WARNING: $msg" >&2
}

# require_command: Check if command exists, die if not
# Usage: require_command "jq" "Install with: brew install jq"
require_command() {
  local cmd="${1:?require_command needs command name}"
  local install_msg="${2:-}"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    local msg="Required command not found: $cmd"
    [[ -n "$install_msg" ]] && msg="$msg\n$install_msg"
    die "$msg" 127
  fi
}

# ═══════════════════════════════════════════════════════════════
# Logging
# ═══════════════════════════════════════════════════════════════

# Log levels: DEBUG=0, INFO=1, WARN=2, ERROR=3
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3

# Get current log level from environment
_get_log_level() {
  local level="${HARM_CLI_LOG_LEVEL:-INFO}"
  case "$level" in
    DEBUG) echo "$LOG_LEVEL_DEBUG" ;;
    INFO) echo "$LOG_LEVEL_INFO" ;;
    WARN) echo "$LOG_LEVEL_WARN" ;;
    ERROR) echo "$LOG_LEVEL_ERROR" ;;
    *) echo "$LOG_LEVEL_INFO" ;;
  esac
}

# Internal: log with level
_log() {
  local level_num="$1"
  local level_name="$2"
  shift 2
  local msg="$*"

  local current_level
  current_level="$(_get_log_level)"

  if ((level_num >= current_level)); then
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] [$level_name] $msg" >&2
  fi
}

# Public logging functions
log_debug() { _log "$LOG_LEVEL_DEBUG" "DEBUG" "$@"; }
log_info() { _log "$LOG_LEVEL_INFO" "INFO" "$@"; }
log_warn() { _log "$LOG_LEVEL_WARN" "WARN" "$@"; }
log_error() { _log "$LOG_LEVEL_ERROR" "ERROR" "$@"; }

# Simple log (always prints, for user-visible output)
log() { echo "$@" >&2; }

# ═══════════════════════════════════════════════════════════════
# File I/O Contracts
# ═══════════════════════════════════════════════════════════════

# ensure_dir: Create directory if it doesn't exist
# Usage: ensure_dir "/path/to/dir"
ensure_dir() {
  local dir="${1:?ensure_dir requires a path}"
  [[ -d "$dir" ]] || mkdir -p "$dir" || die "Failed to create directory: $dir" 1
}

# ensure_writable_dir: Ensure directory exists and is writable
# Usage: ensure_writable_dir "/path/to/dir"
ensure_writable_dir() {
  local dir="${1:?ensure_writable_dir requires a path}"
  ensure_dir "$dir"
  [[ -w "$dir" ]] || die "Directory not writable: $dir" 1
}

# atomic_write: Write content to file atomically (via temp file + mv)
# Usage: atomic_write "/path/to/file" < content
#    or: echo "content" | atomic_write "/path/to/file"
atomic_write() {
  local target="${1:?atomic_write requires target path}"
  local dir
  dir="$(dirname -- "$target")"

  ensure_writable_dir "$dir"

  local temp
  temp="$(mktemp "$target.XXXXXX")" || die "Failed to create temp file" 1

  # Write stdin to temp file
  cat >"$temp" || {
    rm -f "$temp"
    die "Failed to write temp file: $temp" 1
  }

  # Atomic move
  mv -f "$temp" "$target" || {
    rm -f "$temp"
    die "Failed to move temp file to target: $target" 1
  }
}

# file_exists: Check if file exists (helper)
# Usage: file_exists "/path/to/file" || die "File not found"
file_exists() {
  [[ -f "${1:?file_exists requires path}" ]]
}

# dir_exists: Check if directory exists (helper)
# Usage: dir_exists "/path/to/dir" || die "Dir not found"
dir_exists() {
  [[ -d "${1:?dir_exists requires path}" ]]
}

# ═══════════════════════════════════════════════════════════════
# Input Validation
# ═══════════════════════════════════════════════════════════════

# require_arg: Ensure argument is non-empty
# Usage: require_arg "$arg" "Argument name"
require_arg() {
  local value="$1"
  local name="${2:-argument}"

  [[ -n "$value" ]] || die "$name is required" 2
}

# validate_int: Check if value is a valid integer
# Usage: validate_int "$value" || die "Not an integer"
validate_int() {
  [[ "${1:-}" =~ ^-?[0-9]+$ ]]
}

# validate_format: Check if format is valid (text or json)
# Usage: validate_format "$format"
validate_format() {
  local format="${1:-text}"
  case "$format" in
    text | json) return 0 ;;
    *) die "Invalid format: $format (must be 'text' or 'json')" 2 ;;
  esac
}

# ═══════════════════════════════════════════════════════════════
# Process Utilities
# ═══════════════════════════════════════════════════════════════

# run_with_timeout: Run command with timeout
# Usage: run_with_timeout 10 command args...
run_with_timeout() {
  local timeout="${1:?timeout required}"
  shift

  validate_int "$timeout" || die "Timeout must be an integer" 2

  # Use timeout command if available, otherwise use perl fallback
  if command -v timeout >/dev/null 2>&1; then
    timeout "$timeout" "$@"
  elif command -v perl >/dev/null 2>&1; then
    perl -e "alarm $timeout; exec @ARGV" -- "$@"
  else
    warn "No timeout mechanism available, running without timeout"
    "$@"
  fi
}

# ═══════════════════════════════════════════════════════════════
# JSON Helpers
# ═══════════════════════════════════════════════════════════════

# json_escape: Escape string for JSON
# Usage: json_escape "$string"
json_escape() {
  local str="${1:-}"
  # Use jq if available for proper escaping
  if command -v jq >/dev/null 2>&1; then
    jq -R -n --arg str "$str" '$str'
  else
    # Fallback: basic escaping
    printf '%s' "$str" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g'
  fi
}

# ═══════════════════════════════════════════════════════════════
# Exports (mark functions for use in subshells/scripts)
# ═══════════════════════════════════════════════════════════════

export -f die warn require_command
export -f log_debug log_info log_warn log_error log
export -f ensure_dir ensure_writable_dir atomic_write file_exists dir_exists
export -f require_arg validate_int validate_format
export -f run_with_timeout json_escape
