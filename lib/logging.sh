#!/usr/bin/env bash
# shellcheck shell=bash
# logging.sh - Production-grade logging system for harm-cli
# Ported from: ~/.zsh/05_logging.zsh
#
# This module provides:
# - Multi-level logging (DEBUG, INFO, WARN, ERROR)
# - File-based logging with rotation
# - JSON and text output formats
# - Performance timers for profiling
# - Atomic writes with unbuffered I/O
# - Cross-shell compatibility (bash-portable)

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
if [[ -n "${_HARM_LOGGING_LOADED:-}" ]]; then
  return 0
fi

# Source error handling (only once)
if [[ -z "${LOG_SCRIPT_DIR:-}" ]]; then
  LOG_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
  readonly LOG_SCRIPT_DIR
  # shellcheck source=lib/error.sh
  source "$LOG_SCRIPT_DIR/error.sh"
fi

# Mark as loaded
readonly _HARM_LOGGING_LOADED=1

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════

# Log directory and files
HARM_LOG_DIR="${HARM_LOG_DIR:-${HOME}/.harm-cli/logs}"
readonly HARM_LOG_DIR
export HARM_LOG_DIR

HARM_LOG_FILE="${HARM_LOG_FILE:-${HARM_LOG_DIR}/harm-cli.log}"
readonly HARM_LOG_FILE
export HARM_LOG_FILE

HARM_DEBUG_LOG_FILE="${HARM_DEBUG_LOG_FILE:-${HARM_LOG_DIR}/debug.log}"
readonly HARM_DEBUG_LOG_FILE
export HARM_DEBUG_LOG_FILE

# Log configuration
: "${HARM_LOG_LEVEL:=INFO}"        # DEBUG, INFO, WARN, ERROR
: "${HARM_LOG_TO_FILE:=1}"         # 1=enabled, 0=disabled
: "${HARM_LOG_TO_CONSOLE:=1}"      # 1=enabled, 0=disabled
: "${HARM_LOG_MAX_SIZE:=10485760}" # 10MB default
: "${HARM_LOG_MAX_FILES:=5}"       # Keep last 5 rotated logs
: "${HARM_LOG_UNBUFFERED:=1}"      # Force immediate flush

export HARM_LOG_LEVEL HARM_LOG_TO_FILE HARM_LOG_TO_CONSOLE
export HARM_LOG_MAX_SIZE HARM_LOG_MAX_FILES HARM_LOG_UNBUFFERED

# Log level priorities (bash 4+ associative array)
declare -gA LOG_LEVELS=(
  [DEBUG]=0
  [INFO]=1
  [WARN]=2
  [ERROR]=3
)

# ═══════════════════════════════════════════════════════════════
# Core Logging Functions
# ═══════════════════════════════════════════════════════════════

# log_init: Initialize logging system
# Usage: log_init
log_init() {
  # Create log directory if needed
  if [[ ! -d "$HARM_LOG_DIR" ]]; then
    mkdir -p "$HARM_LOG_DIR" 2>/dev/null || {
      warn_msg "Could not create log directory: $HARM_LOG_DIR"
      export HARM_LOG_TO_FILE=0
      return 1
    }
  fi

  # Create log files if they don't exist
  touch "$HARM_LOG_FILE" 2>/dev/null || true
  touch "$HARM_DEBUG_LOG_FILE" 2>/dev/null || true

  return 0
}

# log_timestamp: Get current timestamp
# Usage: timestamp=$(log_timestamp)
log_timestamp() {
  date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "[timestamp unavailable]"
}

# log_should_write: Check if log level should be logged
# Usage: log_should_write "DEBUG" || return
log_should_write() {
  local level="${1:?log_should_write requires level}"
  local current_priority="${LOG_LEVELS[${HARM_LOG_LEVEL}]:-1}"
  local message_priority="${LOG_LEVELS[${level}]:-0}"

  ((message_priority >= current_priority))
}

# log_write: Core logging function (all others call this)
# Usage: log_write "LEVEL" "component" "message" ["details"]
log_write() {
  local level="${1:?log_write requires level}"
  local component="${2:?log_write requires component}"
  local message="${3:?log_write requires message}"
  local details="${4:-}"

  # Check if we should log this level
  log_should_write "$level" || return 0

  local timestamp
  timestamp="$(log_timestamp)"

  # Format message
  local log_message="[$timestamp] [$level] [$component] $message"
  [[ -n "$details" ]] && log_message="$log_message | Details: $details"

  # Log to console if enabled
  if ((HARM_LOG_TO_CONSOLE)); then
    local color=""
    case "$level" in
      DEBUG) color="$DIM" ;;
      INFO) color="$INFO_BLUE" ;;
      WARN) color="$WARNING_YELLOW" ;;
      ERROR) color="$ERROR_RED" ;;
    esac
    echo "${color}${log_message}${RESET}" >&2
  fi

  # Log to file if enabled
  if ((HARM_LOG_TO_FILE)); then
    # Initialize if needed
    [[ ! -f "$HARM_LOG_FILE" ]] && log_init

    if [[ -w "$HARM_LOG_FILE" ]]; then
      # Unbuffered write (immediate flush for cross-terminal streaming)
      if ((HARM_LOG_UNBUFFERED)); then
        {
          exec 3>>"$HARM_LOG_FILE"
          echo "$log_message" >&3
          exec 3>&-
        }
      else
        echo "$log_message" >>"$HARM_LOG_FILE"
      fi

      # Debug logs go to separate file
      if [[ "$level" == "DEBUG" && -w "$HARM_DEBUG_LOG_FILE" ]]; then
        echo "$log_message" >>"$HARM_DEBUG_LOG_FILE"
      fi

      # Check rotation after writing
      log_rotate_check
    fi
  fi
}

# Convenience logging functions
# Usage: log_debug "component" "message" ["details"]

log_debug() {
  log_write "DEBUG" "${1:?component required}" "${2:?message required}" "${3:-}"
}

log_info() {
  log_write "INFO" "${1:?component required}" "${2:?message required}" "${3:-}"
}

log_warn() {
  log_write "WARN" "${1:?component required}" "${2:?message required}" "${3:-}"
}

log_error() {
  log_write "ERROR" "${1:?component required}" "${2:?message required}" "${3:-}"
}

# ═══════════════════════════════════════════════════════════════
# Log Rotation
# ═══════════════════════════════════════════════════════════════

# log_rotate_check: Check if rotation is needed (called after each write)
# Usage: log_rotate_check
log_rotate_check() {
  local last_check_file="$HARM_LOG_DIR/.last_rotation_check"
  local current_time
  current_time="$(date +%s 2>/dev/null || echo 0)"

  # Only check once per hour to avoid performance impact
  if [[ -f "$last_check_file" ]]; then
    local last_check
    last_check="$(cat "$last_check_file" 2>/dev/null || echo 0)"
    local time_diff=$((current_time - last_check))

    # 3600 seconds = 1 hour
    ((time_diff < 3600)) && return 0
  fi

  # Update check timestamp
  echo "$current_time" >"$last_check_file"

  # Check file size
  if [[ -f "$HARM_LOG_FILE" ]]; then
    local file_size
    file_size="$(stat -f%z "$HARM_LOG_FILE" 2>/dev/null || stat -c%s "$HARM_LOG_FILE" 2>/dev/null || echo 0)"

    if ((file_size > HARM_LOG_MAX_SIZE)); then
      log_rotate
    fi
  fi
}

# log_rotate: Rotate log files
# Usage: log_rotate
log_rotate() {
  [[ ! -f "$HARM_LOG_FILE" ]] && return 0

  local timestamp
  timestamp="$(date '+%Y%m%d_%H%M%S')"
  local rotated_file="${HARM_LOG_FILE}.${timestamp}"

  # Move current log to rotated file
  mv "$HARM_LOG_FILE" "$rotated_file" 2>/dev/null || return 1

  # Create new empty log
  touch "$HARM_LOG_FILE"

  # Clean old rotated files (keep only MAX_FILES)
  local rotated_count
  rotated_count="$(find "$HARM_LOG_DIR" -name "$(basename "$HARM_LOG_FILE").*" -type f | wc -l)"

  if ((rotated_count > HARM_LOG_MAX_FILES)); then
    # Delete oldest files
    find "$HARM_LOG_DIR" -name "$(basename "$HARM_LOG_FILE").*" -type f \
      -print0 | xargs -0 ls -t | tail -n +$((HARM_LOG_MAX_FILES + 1)) | xargs -I {} rm -f {}
  fi
}

# ═══════════════════════════════════════════════════════════════
# Log Viewing & Analysis
# ═══════════════════════════════════════════════════════════════

# log_tail: Tail the log file
# Usage: log_tail [lines]
log_tail() {
  local lines="${1:-50}"

  require_file "$HARM_LOG_FILE" "log file"

  tail -n "$lines" "$HARM_LOG_FILE"
}

# log_search: Search logs for pattern
# Usage: log_search "pattern" [level]
log_search() {
  local pattern="${1:?log_search requires pattern}"
  local level="${2:-}"

  require_file "$HARM_LOG_FILE" "log file"

  if [[ -n "$level" ]]; then
    grep "\[$level\]" "$HARM_LOG_FILE" | grep -i "$pattern"
  else
    grep -i "$pattern" "$HARM_LOG_FILE"
  fi
}

# log_clear: Clear log files
# Usage: log_clear [--force]
log_clear() {
  if [[ "${1:-}" != "--force" ]]; then
    warn_msg "This will delete all logs. Use --force to confirm."
    return 1
  fi

  rm -f "$HARM_LOG_FILE" "$HARM_DEBUG_LOG_FILE"
  find "$HARM_LOG_DIR" -name "$(basename "$HARM_LOG_FILE").*" -type f -delete 2>/dev/null || true

  log_init
  success_msg "Logs cleared"
}

# log_stats: Show log statistics
# Usage: log_stats
log_stats() {
  require_file "$HARM_LOG_FILE" "log file"

  local total
  total="$(wc -l <"$HARM_LOG_FILE" | tr -d ' ')"
  local errors
  errors="$(grep -c '\[ERROR\]' "$HARM_LOG_FILE" || echo 0)"
  local warnings
  warnings="$(grep -c '\[WARN\]' "$HARM_LOG_FILE" || echo 0)"
  local infos
  infos="$(grep -c '\[INFO\]' "$HARM_LOG_FILE" || echo 0)"

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --argjson total "$total" \
      --argjson errors "$errors" \
      --argjson warnings "$warnings" \
      --argjson infos "$infos" \
      '{total: $total, errors: $errors, warnings: $warnings, infos: $infos}'
  else
    echo "Log Statistics:"
    echo "  Total lines: $total"
    echo "  Errors:      $errors"
    echo "  Warnings:    $warnings"
    echo "  Info:        $infos"
  fi
}

# ═══════════════════════════════════════════════════════════════
# Performance Timers (bash 4+ using associative array)
# ═══════════════════════════════════════════════════════════════

# Associative array for timers
declare -gA HARM_PERF_TIMERS

# log_perf_start: Start performance timer
# Usage: log_perf_start "timer_name"
log_perf_start() {
  local name="${1:?log_perf_start requires timer name}"
  HARM_PERF_TIMERS[$name]="$(date +%s%N 2>/dev/null || date +%s)"
}

# log_perf_end: End performance timer and log duration
# Usage: log_perf_end "timer_name" "component"
log_perf_end() {
  local name="${1:?log_perf_end requires timer name}"
  local component="${2:?log_perf_end requires component}"

  if [[ -z "${HARM_PERF_TIMERS[$name]:-}" ]]; then
    log_warn "$component" "Timer not started: $name"
    return 1
  fi

  local start_time="${HARM_PERF_TIMERS[$name]}"
  local end_time
  end_time="$(date +%s%N 2>/dev/null || date +%s)"
  local duration=$((end_time - start_time))

  # Convert nanoseconds to milliseconds
  if [[ "$end_time" =~ [0-9]{10,} ]]; then
    duration=$((duration / 1000000)) # ns to ms
    log_debug "$component" "Timer: $name completed in ${duration}ms"
  else
    log_debug "$component" "Timer: $name completed in ${duration}s"
  fi

  # Clean up timer
  unset "HARM_PERF_TIMERS[$name]"
}

# ═══════════════════════════════════════════════════════════════
# Exports
# ═══════════════════════════════════════════════════════════════

export -f log_init log_timestamp log_should_write log_write
export -f log_debug log_info log_warn log_error
export -f log_rotate_check log_rotate
export -f log_tail log_search log_clear log_stats
export -f log_perf_start log_perf_end

# Initialize on load
log_init
