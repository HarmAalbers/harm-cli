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
# Exports
# ═══════════════════════════════════════════════════════════════

export -f trim uppercase lowercase starts_with ends_with
export -f array_join array_contains
export -f file_sha256 file_age ensure_executable
export -f resolve_path is_absolute basename_no_ext
export -f is_running
export -f parse_duration format_duration
export -f json_get json_validate
