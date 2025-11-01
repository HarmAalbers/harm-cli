#!/usr/bin/env bash
# lib/config_validation.sh
# Shared validation functions for harm-cli configuration
#
# Used by both install.sh and lib/options.sh to ensure consistent validation

set -Eeuo pipefail

# Prevent multiple loading
[[ -n "${_HARM_CONFIG_VALIDATION_LOADED:-}" ]] && return 0

# Source logging if available
if [[ -n "${HARM_LIB_DIR:-}" ]] && [[ -f "${HARM_LIB_DIR}/logging.sh" ]]; then
  # shellcheck source=lib/logging.sh
  source "${HARM_LIB_DIR}/logging.sh"
fi

# ═══════════════════════════════════════════════════════════════
# Validation Functions
# ═══════════════════════════════════════════════════════════════

# Validate log level
#
# Arguments:
#   $1 - Level to validate (DEBUG|INFO|WARN|ERROR)
#
# Returns:
#   0 if valid, 1 if invalid
validate_log_level() {
  local level="$1"
  case "$level" in
    DEBUG | INFO | WARN | ERROR) return 0 ;;
    *)
      if declare -F log_warn >/dev/null 2>&1; then
        log_warn "Invalid log level: $level (expected DEBUG|INFO|WARN|ERROR)"
      fi
      return 1
      ;;
  esac
}

# Validate yes/no input
#
# Arguments:
#   $1 - Input to validate (Y/N/yes/no or empty for yes)
#
# Returns:
#   0 if valid, 1 if invalid
validate_yes_no() {
  local value="$1"
  case "$value" in
    [Yy] | [Yy][Ee][Ss] | "") return 0 ;; # Empty = yes (default)
    [Nn] | [Nn][Oo]) return 0 ;;
    *)
      if declare -F log_warn >/dev/null 2>&1; then
        log_warn "Invalid yes/no value: '$value' (expected Y/N/yes/no)"
      fi
      return 1
      ;;
  esac
}

# Validate boolean value (0 or 1)
#
# Arguments:
#   $1 - Value to validate
#
# Returns:
#   0 if valid (0 or 1), 1 if invalid
validate_bool() {
  local value="$1"
  case "$value" in
    0 | 1) return 0 ;;
    *)
      if declare -F log_warn >/dev/null 2>&1; then
        log_warn "Invalid boolean value: '$value' (expected 0 or 1)"
      fi
      return 1
      ;;
  esac
}

# Validate number (non-negative integer)
#
# Arguments:
#   $1 - Value to validate
#
# Returns:
#   0 if valid number, 1 if invalid
validate_number() {
  local value="$1"
  [[ "$value" =~ ^[0-9]+$ ]]
}

# Validate positive integer (> 0)
#
# Arguments:
#   $1 - Value to validate
#
# Returns:
#   0 if valid positive integer, 1 if invalid
validate_positive_int() {
  local value="$1"
  if ! validate_number "$value"; then
    if declare -F log_warn >/dev/null 2>&1; then
      log_warn "Invalid positive integer: '$value' (not a number)"
    fi
    return 1
  fi
  if ! ((value > 0)); then
    if declare -F log_warn >/dev/null 2>&1; then
      log_warn "Invalid positive integer: '$value' (must be > 0)"
    fi
    return 1
  fi
  return 0
}

# Validate output format
#
# Arguments:
#   $1 - Format to validate (text|json)
#
# Returns:
#   0 if valid, 1 if invalid
validate_format() {
  local format="$1"
  case "$format" in
    text | json) return 0 ;;
    *)
      if declare -F log_warn >/dev/null 2>&1; then
        log_warn "Invalid format: '$format' (expected text|json)"
      fi
      return 1
      ;;
  esac
}

# Validate AI model
#
# Arguments:
#   $1 - Model name to validate
#
# Returns:
#   0 if valid, 1 if invalid
validate_ai_model() {
  local model="$1"
  case "$model" in
    gemini-2.0-flash-exp | gemini-1.5-pro | gemini-1.5-flash | gemini-1.5-flash-8b) return 0 ;;
    *)
      if declare -F log_warn >/dev/null 2>&1; then
        log_warn "Invalid AI model: '$model' (expected gemini-2.0-flash-exp|gemini-1.5-pro|gemini-1.5-flash|gemini-1.5-flash-8b)"
      fi
      return 1
      ;;
  esac
}

# Validate break skip mode
#
# Arguments:
#   $1 - Skip mode to validate (never|after50|always|type-based)
#
# Returns:
#   0 if valid, 1 if invalid
validate_break_skip_mode() {
  local mode="$1"
  case "$mode" in
    never | after50 | always | type-based) return 0 ;;
    *) return 1 ;;
  esac
}

# Validate string (generic)
#
# Arguments:
#   $1 - String to validate
#
# Returns:
#   0 always (strings are always valid)
validate_string() {
  return 0
}

# Export functions for use in other scripts
export -f validate_log_level
export -f validate_yes_no
export -f validate_bool
export -f validate_number
export -f validate_positive_int
export -f validate_format
export -f validate_ai_model
export -f validate_break_skip_mode
export -f validate_string

# Mark module as loaded
readonly _HARM_CONFIG_VALIDATION_LOADED=1
