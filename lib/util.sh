#!/usr/bin/env bash
# shellcheck shell=bash
# util.sh - Core utility functions for harm-cli
#
# This module provides essential helper functions:
# - String manipulation (trim, uppercase, lowercase)
# - Array helpers (join, contains)
# - File utilities (sha256, file_age, ensure_executable)
# - Path utilities (resolve_path, is_absolute)
# - Process utilities (is_running, kill_tree)
# - Time utilities (parse_duration, format_duration)

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_UTIL_LOADED:-}" ]] && return 0

# Source dependencies
UTIL_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly UTIL_SCRIPT_DIR

# shellcheck source=lib/common.sh
source "$UTIL_SCRIPT_DIR/common.sh"
# shellcheck source=lib/error.sh
source "$UTIL_SCRIPT_DIR/error.sh"

# Mark as loaded
readonly _HARM_UTIL_LOADED=1

# ═══════════════════════════════════════════════════════════════
# String Utilities
# ═══════════════════════════════════════════════════════════════

# trim: Remove leading/trailing whitespace
# Usage: trimmed=$(trim "  hello  ")
trim() {
  local str="$*"
  # Remove leading whitespace
  str="${str#"${str%%[![:space:]]*}"}"
  # Remove trailing whitespace
  str="${str%"${str##*[![:space:]]}"}"
  printf '%s\n' "$str"
}

# uppercase: Convert string to uppercase (bash 4+)
# Usage: upper=$(uppercase "hello")
uppercase() {
  printf '%s\n' "${*^^}"
}

# lowercase: Convert string to lowercase (bash 4+)
# Usage: lower=$(lowercase "HELLO")
lowercase() {
  printf '%s\n' "${*,,}"
}

# starts_with: Check if string starts with prefix
# Usage: starts_with "$string" "$prefix" && echo "yes"
starts_with() {
  local string="${1:?starts_with requires string}"
  local prefix="${2:?starts_with requires prefix}"
  [[ "$string" == "$prefix"* ]]
}

# ends_with: Check if string ends with suffix
# Usage: ends_with "$string" "$suffix" && echo "yes"
ends_with() {
  local string="${1:?ends_with requires string}"
  local suffix="${2:?ends_with requires suffix}"
  [[ "$string" == *"$suffix" ]]
}

# ═══════════════════════════════════════════════════════════════
# Array Utilities
# ═══════════════════════════════════════════════════════════════

# array_join: Join array elements with delimiter
# Usage: result=$(array_join "," "${array[@]}")
array_join() {
  local delimiter="${1:?array_join requires delimiter}"
  shift
  local first=1
  for item in "$@"; do
    if ((first)); then
      printf '%s' "$item"
      first=0
    else
      printf '%s%s' "$delimiter" "$item"
    fi
  done
  printf '\n'
}

# array_contains: Check if array contains value
# Usage: array_contains "value" "${array[@]}" && echo "found"
array_contains() {
  local needle="${1:?array_contains requires needle}"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

# ═══════════════════════════════════════════════════════════════
# File Utilities
# ═══════════════════════════════════════════════════════════════

# file_sha256: Calculate SHA256 hash of file
# Usage: hash=$(file_sha256 "/path/to/file")
file_sha256() {
  local file="${1:?file_sha256 requires file path}"
  require_file "$file"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    die "No SHA256 tool available (need sha256sum or shasum)" "$EXIT_MISSING_DEPS"
  fi
}

# file_age: Get file age in seconds
# Usage: age=$(file_age "/path/to/file")
file_age() {
  local file="${1:?file_age requires file path}"
  require_file "$file"

  local now
  now="$(date +%s)"
  local mtime

  # macOS vs Linux stat
  if stat -f%m "$file" >/dev/null 2>&1; then
    mtime="$(stat -f%m "$file")"
  else
    mtime="$(stat -c%Y "$file")"
  fi

  echo $((now - mtime))
}

# ensure_executable: Make file executable
# Usage: ensure_executable "/path/to/file"
ensure_executable() {
  local file="${1:?ensure_executable requires file path}"
  require_file "$file"
  chmod +x "$file"
}

# ═══════════════════════════════════════════════════════════════
# Path Utilities
# ═══════════════════════════════════════════════════════════════

# resolve_path: Resolve absolute path
# Usage: abs_path=$(resolve_path "relative/path")
resolve_path() {
  local path="${1:?resolve_path requires path}"
  local dir
  dir="$(cd -P -- "$(dirname -- "$path")" && pwd -P)"
  local base
  base="$(basename -- "$path")"
  echo "${dir}/${base}"
}

# is_absolute: Check if path is absolute
# Usage: is_absolute "/path" && echo "absolute"
is_absolute() {
  local path="${1:?is_absolute requires path}"
  [[ "$path" == /* ]]
}

# basename_no_ext: Get filename without extension
# Usage: name=$(basename_no_ext "/path/to/file.txt")  # Returns: file
basename_no_ext() {
  local path="${1:?basename_no_ext requires path}"
  local filename
  filename="$(basename -- "$path")"
  echo "${filename%.*}"
}

# ═══════════════════════════════════════════════════════════════
# Process Utilities
# ═══════════════════════════════════════════════════════════════

# is_running: Check if process is running by PID
# Usage: is_running "$pid" && echo "running"
is_running() {
  local pid="${1:?is_running requires PID}"
  validate_int "$pid" || die "PID must be an integer" "$EXIT_INVALID_ARGS"
  kill -0 "$pid" 2>/dev/null
}

# ═══════════════════════════════════════════════════════════════
# Time Utilities
# ═══════════════════════════════════════════════════════════════

# parse_duration: Convert duration string to seconds
# Usage: seconds=$(parse_duration "2h30m")
# Supports: s(seconds), m(minutes), h(hours), d(days)
parse_duration() {
  local duration="${1:?parse_duration requires duration}"
  local total=0

  # Extract hours
  if [[ "$duration" =~ ([0-9]+)h ]]; then
    total=$((total + BASH_REMATCH[1] * 3600))
  fi

  # Extract minutes
  if [[ "$duration" =~ ([0-9]+)m ]]; then
    total=$((total + BASH_REMATCH[1] * 60))
  fi

  # Extract seconds
  if [[ "$duration" =~ ([0-9]+)s ]]; then
    total=$((total + BASH_REMATCH[1]))
  fi

  # Extract days
  if [[ "$duration" =~ ([0-9]+)d ]]; then
    total=$((total + BASH_REMATCH[1] * 86400))
  fi

  # If no units found, treat as seconds
  if ((total == 0)) && [[ "$duration" =~ ^[0-9]+$ ]]; then
    total="$duration"
  fi

  echo "$total"
}

# format_duration: Format seconds as human-readable duration
# Usage: formatted=$(format_duration 3661)  # Returns: 1h1m1s
format_duration() {
  local seconds="${1:?format_duration requires seconds}"
  validate_int "$seconds" || die "Seconds must be an integer" "$EXIT_INVALID_ARGS"

  local hours=$((seconds / 3600))
  local minutes=$(((seconds % 3600) / 60))
  local secs=$((seconds % 60))

  local result=""
  ((hours > 0)) && result="${hours}h"
  ((minutes > 0)) && result="${result}${minutes}m"
  ((secs > 0 || ${#result} == 0)) && result="${result}${secs}s"

  echo "$result"
}

# get_utc_timestamp: Get current UTC timestamp in ISO 8601 format
#
# Description:
#   Returns the current date/time as a UTC timestamp in ISO 8601 format.
#   This is the single source of truth for creating timestamps.
#
# Arguments:
#   None
#
# Returns:
#   0 - Always succeeds
#
# Outputs:
#   stdout: ISO 8601 UTC timestamp (YYYY-MM-DDTHH:MM:SSZ)
#
# Examples:
#   timestamp=$(get_utc_timestamp)
#   # Output: "2025-10-21T14:30:00Z"
#
# Notes:
#   - Always returns UTC (Z suffix)
#   - Format is compatible with iso8601_to_epoch()
#   - Single source of truth for timestamp creation
get_utc_timestamp() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

# get_utc_epoch: Get current UTC time as Unix epoch seconds
#
# Description:
#   Returns the current time as Unix epoch seconds (seconds since 1970-01-01 00:00:00 UTC).
#   This is the single source of truth for getting current epoch time.
#
# Arguments:
#   None
#
# Returns:
#   0 - Always succeeds
#
# Outputs:
#   stdout: Unix epoch seconds
#
# Examples:
#   now=$(get_utc_epoch)
#   # Output: "1729521000"
#
# Notes:
#   - Always returns UTC epoch
#   - Use for time calculations and comparisons
#   - Single source of truth for current epoch time
get_utc_epoch() {
  date -u +%s
}

# iso8601_to_epoch: Convert ISO 8601 UTC timestamp to Unix epoch
#
# Description:
#   Converts an ISO 8601 UTC timestamp to Unix epoch seconds.
#   Handles both GNU date (Linux) and BSD date (macOS) with proper UTC interpretation.
#   This fixes the timezone bug where BSD date was interpreting timestamps in local time.
#
# Arguments:
#   $1 - timestamp (string): ISO 8601 UTC timestamp (YYYY-MM-DDTHH:MM:SSZ)
#
# Returns:
#   0 - Conversion successful
#   1 - Conversion failed (fallback to current time)
#
# Outputs:
#   stdout: Unix epoch seconds
#   stderr: Warning if parsing fails
#
# Examples:
#   epoch=$(iso8601_to_epoch "2025-01-01T00:00:00Z")
#   # Output: "1735689600"
#
#   start_epoch=$(iso8601_to_epoch "$start_time")
#   current=$(get_utc_epoch)
#   duration=$((current - start_epoch))
#
# Notes:
#   - Requires Z suffix for UTC timestamps
#   - GNU date: uses -d flag
#   - BSD date: uses -j -u -f flags (the -u is CRITICAL for UTC interpretation)
#   - Falls back to current time with warning if parsing fails
#   - Single source of truth for timestamp parsing
#
# Bug Fix:
#   The original implementation was missing the -u flag on BSD date,
#   causing it to interpret UTC timestamps in local timezone,
#   resulting in incorrect time calculations offset by the timezone difference.
iso8601_to_epoch() {
  local timestamp="${1:?iso8601_to_epoch requires timestamp}"

  # Try GNU date first (Linux)
  if date -d "$timestamp" +%s 2>/dev/null; then
    return 0
  fi

  # Try BSD date (macOS) - CRITICAL: -u flag forces UTC interpretation
  # Without -u, BSD date interprets timestamp in local timezone causing bug
  # Strip the Z suffix as BSD date format strings don't handle it well
  local timestamp_no_z="${timestamp%Z}"
  if date -j -u -f '%Y-%m-%dT%H:%M:%S' "$timestamp_no_z" +%s 2>/dev/null; then
    return 0
  fi

  # Fallback: use current time
  warn_msg "Could not parse timestamp: $timestamp, using current time"
  get_utc_epoch
}

# ═══════════════════════════════════════════════════════════════
# JSON Utilities
# ═══════════════════════════════════════════════════════════════

# json_get: Extract value from JSON using jq
# Usage: value=$(json_get "$json" ".field.subfield")
json_get() {
  local json="${1:?json_get requires JSON}"
  local query="${2:?json_get requires jq query}"

  require_command jq "brew install jq"
  jq -r "$query" <<<"$json"
}

# json_validate: Validate JSON string
# Usage: json_validate "$json" && echo "valid"
json_validate() {
  local json="${1:?json_validate requires JSON}"
  require_command jq "brew install jq"
  jq -e . >/dev/null 2>&1 <<<"$json"
}

# ═══════════════════════════════════════════════════════════════
# Output Formatting Utilities
# ═══════════════════════════════════════════════════════════════

# format_command_response: Format command response (text or JSON)
#
# Description:
#   Unified response formatter supporting both text and JSON output.
#   Reduces duplication across commands by centralizing format logic.
#
# Arguments:
#   $1 - status (string): Status message (e.g., "set", "updated", "stopped")
#   $2+ - fields (key=value pairs): Data to include in response
#
# Environment:
#   HARM_CLI_FORMAT - Output format: "text" (default) or "json"
#
# Returns:
#   0 - Always succeeds
#
# Outputs:
#   stdout: Formatted response based on HARM_CLI_FORMAT
#
# Examples:
#   format_command_response "set" message="Goal set for today" goal="Write tests"
#   format_command_response "updated" status="success" progress=75
#   HARM_CLI_FORMAT=json format_command_response "stopped" duration_seconds=3661
#
# Notes:
#   - Text format: Prints message, then indented key-value pairs
#   - JSON format: Builds JSON object with status + all fields
#   - Automatically handles message vs other fields
format_command_response() {
  local status="${1:?format_command_response requires status}"
  shift

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    # Build JSON object
    local -a jq_args=("--arg" "status" "$status")
    # shellcheck disable=SC2016  # $status is for jq, not bash
    local jq_expr='{status: $status'

    # Add each field to JSON
    for arg in "$@"; do
      if [[ "$arg" =~ ^([^=]+)=(.*)$ ]]; then
        local key="${BASH_REMATCH[1]}"
        local value="${BASH_REMATCH[2]}"

        # Detect if value should be a number
        if [[ "$value" =~ ^[0-9]+$ ]]; then
          jq_args+=("--argjson" "$key" "$value")
          jq_expr+=", $key: \$$key"
        else
          jq_args+=("--arg" "$key" "$value")
          jq_expr+=", $key: \$$key"
        fi
      fi
    done

    jq_expr+='}'
    jq -n "${jq_args[@]}" "$jq_expr"
  else
    # Text format
    local message=""
    local -a details=()

    for arg in "$@"; do
      if [[ "$arg" =~ ^message=(.*)$ ]]; then
        message="${BASH_REMATCH[1]}"
      elif [[ "$arg" =~ ^([^=]+)=(.*)$ ]]; then
        local key="${BASH_REMATCH[1]}"
        local value="${BASH_REMATCH[2]}"
        # Convert snake_case to Title Case for display
        local display_key
        display_key=$(echo "$key" | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2));}1')
        details+=("  $display_key: $value")
      fi
    done

    # Print message if provided
    [[ -n "$message" ]] && success_msg "$message"

    # Print details
    for detail in "${details[@]}"; do
      echo "$detail"
    done
  fi
}

# validate_iso8601_timestamp: Validate ISO 8601 timestamp format
#
# Description:
#   Validates that a string matches ISO 8601 timestamp format.
#   Supports UTC timestamps (Z suffix) commonly used in this project.
#
# Arguments:
#   $1 - timestamp (string): Timestamp to validate
#
# Returns:
#   0 - Valid ISO 8601 format
#   1 - Invalid format
#
# Examples:
#   validate_iso8601_timestamp "2025-10-19T10:30:00Z"  # Valid
#   validate_iso8601_timestamp "2025-10-19 10:30:00"   # Invalid
#   validate_iso8601_timestamp "invalid"               # Invalid
#
# Notes:
#   - Accepts: YYYY-MM-DDTHH:MM:SSZ format
#   - Strict validation prevents malformed timestamps
#   - Used to validate external input and state files
validate_iso8601_timestamp() {
  local timestamp="${1:?validate_iso8601_timestamp requires timestamp}"

  # ISO 8601 pattern: YYYY-MM-DDTHH:MM:SSZ
  [[ "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

# ═══════════════════════════════════════════════════════════════
# Progress Indication Utilities
# ═══════════════════════════════════════════════════════════════

# show_spinner: Display spinner during long-running command
#
# Description:
#   Shows visual progress indicator during command execution.
#   Uses gum if available, falls back to simple text spinner.
#   Only shows in TTY (silent in scripts/CI).
#
# Arguments:
#   $1 - message (string): Progress message
#   $@ - command and args: Command to execute
#
# Returns:
#   Exit code of wrapped command
#
# Examples:
#   show_spinner "Analyzing..." docker system df
#   show_spinner "Running tests..." pytest -v
#
# Notes:
#   - TTY-aware (skips in non-interactive)
#   - Prefers gum for beautiful spinners
#   - Falls back to simple text indicator
show_spinner() {
  local message="${1:?show_spinner requires message}"
  shift

  # Skip if not in TTY (scripts/CI)
  if [[ ! -t 1 ]]; then
    "$@"
    return $?
  fi

  # Use gum if available (beautiful spinner)
  if command -v gum >/dev/null 2>&1; then
    gum spin --spinner dot --title "$message" -- "$@"
    return $?
  fi

  # Fallback: simple text indicator
  printf "%s " "$message" >&2
  local output
  if output=$("$@" 2>&1); then
    printf "✓\n" >&2
    echo "$output"
    return 0
  else
    local exit_code=$?
    printf "✗\n" >&2
    echo "$output"
    return $exit_code
  fi
}

# show_progress_dots: Show dots during command execution
#
# Description:
#   Displays animated dots (...) while command runs.
#   Simpler than spinner, good for file operations.
#
# Arguments:
#   $1 - message (string): Progress message
#   $@ - command and args: Command to execute
#
# Returns:
#   Exit code of wrapped command
show_progress_dots() {
  local message="${1:?show_progress_dots requires message}"
  shift

  # Skip if not in TTY
  if [[ ! -t 1 ]]; then
    "$@"
    return $?
  fi

  printf "%s" "$message" >&2

  # Start background dots animation
  {
    while true; do
      for dots in "" "." ".." "..."; do
        printf "\r%s%s   " "$message" "$dots" >&2
        sleep 0.3
      done
    done
  } &
  local dots_pid=$!

  # Run command
  local output exit_code
  if output=$("$@" 2>&1); then
    exit_code=0
  else
    exit_code=$?
  fi

  # Stop dots animation
  kill "$dots_pid" 2>/dev/null
  wait "$dots_pid" 2>/dev/null

  # Show result
  if [[ $exit_code -eq 0 ]]; then
    printf "\r%s ✓\n" "$message" >&2
  else
    printf "\r%s ✗\n" "$message" >&2
  fi

  echo "$output"
  return $exit_code
}

# ═══════════════════════════════════════════════════════════════
# Exports
# ═══════════════════════════════════════════════════════════════

export -f trim uppercase lowercase starts_with ends_with
export -f array_join array_contains
export -f file_sha256 file_age ensure_executable
export -f resolve_path is_absolute basename_no_ext
export -f is_running
export -f parse_duration format_duration get_utc_timestamp get_utc_epoch iso8601_to_epoch
export -f json_get json_validate
export -f format_command_response validate_iso8601_timestamp
export -f show_spinner show_progress_dots
