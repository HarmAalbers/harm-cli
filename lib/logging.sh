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
: "${HARM_LOG_LEVEL:=WARN}"        # DEBUG, INFO, WARN, ERROR (default: WARN for normal usage)
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
#
# Performance optimization: Uses printf (bash built-in) instead of date subprocess
# Fallback to date for bash < 4.2 compatibility
log_timestamp() {
  # Bash 4.2+ has printf %(...)T which is 10-20x faster than spawning date
  printf '%(%Y-%m-%d %H:%M:%S)T' -1 2>/dev/null || date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "[timestamp unavailable]"
}

# log_should_write: Check if log level should be logged
# Usage: log_should_write "DEBUG" || return
log_should_write() {
  local level="${1:?log_should_write requires level}"
  local current_priority="${LOG_LEVELS[${HARM_LOG_LEVEL:-WARN}]:-1}"
  local message_priority="${LOG_LEVELS[${level}]:-0}"

  ((message_priority >= current_priority))
}

# log_sanitize: Sanitize secrets from log messages
# SECURITY FIX (HIGH-3): Prevents secret leakage in logs
# Usage: sanitized=$(log_sanitize "$message")
log_sanitize() {
  local message="${1:-}"
  # Return empty string if input is empty
  [[ -z "$message" ]] && return 0

  echo "$message" | sed -E \
    -e 's/AIza[A-Za-z0-9_-]{35}/***REDACTED_API_KEY***/g' \
    -e 's/sk-[A-Za-z0-9]{32,}/***REDACTED_SECRET_KEY***/g' \
    -e 's/ghp_[A-Za-z0-9]{36}/***REDACTED_GITHUB_TOKEN***/g' \
    -e 's/AKIA[A-Z0-9]{16}/***REDACTED_AWS_KEY***/g' \
    -e 's/Bearer [A-Za-z0-9_\.\-]+/Bearer ***REDACTED***/g' \
    -e 's/x-goog-api-key:[^[:space:]]*/x-goog-api-key:***REDACTED***/g'
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

  # Sanitize message and details to prevent secret leakage
  message=$(log_sanitize "$message")
  [[ -n "$details" ]] && details=$(log_sanitize "$details")

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
# Streaming Functions (Cross-Terminal Real-Time Log Viewing)
# ═══════════════════════════════════════════════════════════════

# _log_build_level_filter: Build grep pattern for minimum level filtering
# Usage: _log_build_level_filter "INFO"
# Returns: grep pattern that matches INFO, WARN, ERROR (but not DEBUG)
_log_build_level_filter() {
  local min_level="${1:?_log_build_level_filter requires level}"

  # Validate level
  if [[ -z "${LOG_LEVELS[$min_level]:-}" ]]; then
    echo "cat" # Invalid level, show everything
    return 1
  fi

  local min_priority="${LOG_LEVELS[$min_level]}"
  local pattern=""

  # Build pattern for all levels >= min_priority
  for lvl in DEBUG INFO WARN ERROR; do
    local lvl_priority="${LOG_LEVELS[$lvl]}"
    if ((lvl_priority >= min_priority)); then
      pattern="${pattern:+$pattern|}\\[$lvl\\]"
    fi
  done

  # Return just the pattern (not the full grep command)
  echo "($pattern)"
}

# _log_format_json_line: Convert log line to JSON format
# Usage: echo "log line" | _log_format_json_line
_log_format_json_line() {
  awk -F"[][]" '
    {
      timestamp=$2
      level=$4
      component=$6
      gsub(/^ | $/, "", timestamp)
      gsub(/^ | $/, "", level)
      gsub(/^ | $/, "", component)
      message=$0
      sub(/^[^]]*\] [^]]*\] [^]]*\] /, "", message)
      # Escape quotes in message for valid JSON
      gsub(/"/, "\\\"", message)
      printf "{\"timestamp\":\"%s\",\"level\":\"%s\",\"component\":\"%s\",\"message\":\"%s\"}\n",
        timestamp, level, component, message
    }
  '
}

# _log_format_structured_line: Add visual indicators to log lines
# Usage: echo "log line" | _log_format_structured_line
_log_format_structured_line() {
  awk '
    /\[DEBUG\]/ { print "\033[36m🔍 " $0 "\033[0m"; next }
    /\[INFO\]/  { print "\033[32m✓ " $0 "\033[0m"; next }
    /\[WARN\]/  { print "\033[33m⚠ " $0 "\033[0m"; next }
    /\[ERROR\]/ { print "\033[31m✗ " $0 "\033[0m"; next }
    { print "  " $0 }
  '
}

# _log_format_colored_line: Add color to log lines based on level
# Usage: echo "log line" | _log_format_colored_line
_log_format_colored_line() {
  awk '
    /\[DEBUG\]/ { print "\033[2m" $0 "\033[0m"; next }
    /\[INFO\]/  { print "\033[34m" $0 "\033[0m"; next }
    /\[WARN\]/  { print "\033[33m" $0 "\033[0m"; next }
    /\[ERROR\]/ { print "\033[31m" $0 "\033[0m"; next }
    { print $0 }
  '
}

# log_stream: Stream logs in real-time with cross-terminal support
# Usage: log_stream [--level=LEVEL] [--format=FORMAT] [--color=auto|always|never]
#
# Options:
#   --level=LEVEL      Filter by minimum log level (shows level and above)
#                      DEBUG shows: DEBUG, INFO, WARN, ERROR
#                      INFO shows:  INFO, WARN, ERROR
#                      WARN shows:  WARN, ERROR
#                      ERROR shows: ERROR only
#   --format=FORMAT    Output format (plain|json|structured|color)
#                      plain: Raw log lines
#                      json: JSON formatted output
#                      structured: Visual indicators (✓ ⚠ ✗ 🔍)
#                      color: Colored plain text
#   --color=WHEN       Colorize output (auto|always|never)
#                      auto: Color if terminal supports it (default)
#                      always: Always colorize
#                      never: Never colorize
#
# Examples:
#   log_stream                           # Stream all logs
#   log_stream --level=INFO              # Stream INFO, WARN, ERROR (not DEBUG)
#   log_stream --level=WARN --color=always   # Stream WARN+ERROR with colors
#   log_stream --format=json             # Stream in JSON format
#   log_stream --level=ERROR --format=structured  # Errors with visual indicators
#
# Features:
#   - Uses tail -F for rotation-aware following
#   - Cross-terminal streaming (unbuffered writes)
#   - Multiple output formats
#   - Minimum level filtering (industry standard behavior)
log_stream() {
  local level=""
  local format="plain"
  local color="auto"

  # Parse flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --level=*)
        level="${1#*=}"
        shift
        ;;
      --format=*)
        format="${1#*=}"
        shift
        ;;
      --color=*)
        color="${1#*=}"
        shift
        ;;
      --level)
        level="${2:?--level requires an argument}"
        shift 2
        ;;
      --format)
        format="${2:?--format requires an argument}"
        shift 2
        ;;
      --color)
        color="${2:?--color requires an argument}"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  # Validate log level if provided
  if [[ -n "$level" && -z "${LOG_LEVELS[$level]:-}" ]]; then
    error_msg "Invalid log level: $level (must be DEBUG, INFO, WARN, or ERROR)"
    return 1
  fi

  # Determine log file (use main log, debug logs are also in main when level >= DEBUG)
  local log_file="$HARM_LOG_FILE"

  # Verify log file exists
  if [[ ! -f "$log_file" ]]; then
    error_msg "Log file not found: $log_file"
    return 1
  fi

  # Build streaming pipeline
  # KEY: Use tail -F (capital F) for rotation-aware following
  # Resolve command paths once for reliability
  local TAIL_BIN GREP_BIN
  TAIL_BIN=$(command -v tail) || {
    error_msg "tail command not found in PATH"
    return 1
  }
  GREP_BIN=$(command -v grep) || {
    error_msg "grep command not found in PATH"
    return 1
  }

  # Add level filtering if specified (MINIMUM LEVEL - shows level and above)
  local filter_pattern=""
  if [[ -n "$level" ]]; then
    filter_pattern=$(_log_build_level_filter "$level")
  fi

  # Handle format and color interaction
  # If format=color, treat as plain+color
  if [[ "$format" == "color" ]]; then
    format="plain"
    color="always"
  fi

  # Add format conversion
  local format_cmd="cat"
  case "$format" in
    json)
      format_cmd="_log_format_json_line"
      color="never" # JSON doesn't use colors
      ;;
    structured)
      format_cmd="_log_format_structured_line"
      color="never" # Structured already has colors built-in
      ;;
    plain)
      # Check if we should colorize
      case "$color" in
        always)
          format_cmd="_log_format_colored_line"
          ;;
        auto)
          # Check if stdout is a terminal
          if [[ -t 1 ]]; then
            format_cmd="_log_format_colored_line"
          fi
          ;;
        never)
          format_cmd="cat"
          ;;
      esac
      ;;
  esac

  # Execute streaming pipeline
  # Use stdbuf if available to eliminate buffering
  if command -v stdbuf >/dev/null 2>&1; then
    # stdbuf -o0 disables output buffering
    if [[ "$format_cmd" == "_log_format_json_line" ]] \
      || [[ "$format_cmd" == "_log_format_structured_line" ]] \
      || [[ "$format_cmd" == "_log_format_colored_line" ]]; then
      # For shell functions, use while-read loop
      if [[ -n "$filter_pattern" ]]; then
        stdbuf -o0 "$TAIL_BIN" -F -n 0 "$log_file" \
          | stdbuf -o0 "$GREP_BIN" --line-buffered -E "$filter_pattern" \
          | while IFS= read -r line; do
            $format_cmd <<<"$line"
          done
      else
        stdbuf -o0 "$TAIL_BIN" -F -n 0 "$log_file" \
          | while IFS= read -r line; do
            $format_cmd <<<"$line"
          done
      fi
    else
      # For builtins/executables, pipe directly
      if [[ -n "$filter_pattern" ]]; then
        stdbuf -o0 "$TAIL_BIN" -F -n 0 "$log_file" \
          | stdbuf -o0 "$GREP_BIN" --line-buffered -E "$filter_pattern" \
          | stdbuf -o0 $format_cmd
      else
        stdbuf -o0 "$TAIL_BIN" -F -n 0 "$log_file" | stdbuf -o0 $format_cmd
      fi
    fi
  else
    # Fallback without stdbuf
    if [[ "$format_cmd" == "_log_format_json_line" ]] \
      || [[ "$format_cmd" == "_log_format_structured_line" ]] \
      || [[ "$format_cmd" == "_log_format_colored_line" ]]; then
      if [[ -n "$filter_pattern" ]]; then
        "$TAIL_BIN" -F -n 0 "$log_file" \
          | "$GREP_BIN" --line-buffered -E "$filter_pattern" \
          | while IFS= read -r line; do
            $format_cmd <<<"$line"
          done
      else
        "$TAIL_BIN" -F -n 0 "$log_file" \
          | while IFS= read -r line; do
            $format_cmd <<<"$line"
          done
      fi
    else
      if [[ -n "$filter_pattern" ]]; then
        "$TAIL_BIN" -F -n 0 "$log_file" | "$GREP_BIN" --line-buffered -E "$filter_pattern" | $format_cmd
      else
        "$TAIL_BIN" -F -n 0 "$log_file" | $format_cmd
      fi
    fi
  fi
}

# ═══════════════════════════════════════════════════════════════
# Exports
# ═══════════════════════════════════════════════════════════════

export -f log_init log_timestamp log_should_write log_write log_sanitize
export -f log_debug log_info log_warn log_error
export -f log_rotate_check log_rotate
export -f log_tail log_search log_clear log_stats
export -f log_perf_start log_perf_end
export -f log_stream _log_build_level_filter
export -f _log_format_json_line _log_format_structured_line _log_format_colored_line

# Initialize on load
log_init
