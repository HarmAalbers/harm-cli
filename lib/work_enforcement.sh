#!/usr/bin/env bash
# shellcheck shell=bash
# work_enforcement.sh - Strict mode and focus discipline for harm-cli
#
# Part of SOLID refactoring: Single Responsibility = Enforcement & Violations
#
# This module provides:
# - Violation tracking (context switches)
# - Project switch detection/blocking
# - Break requirement enforcement
# - Strict mode cd wrapper
#
# Dependencies:
# - lib/options.sh (for configuration)
# - lib/logging.sh (for log functions)
# - lib/work_timers.sh (for work_send_notification)
# - lib/util.sh (for atomic_write)

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_WORK_ENFORCEMENT_LOADED:-}" ]] && return 0

# Get script directory for sourcing dependencies
WORK_ENFORCEMENT_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly WORK_ENFORCEMENT_SCRIPT_DIR

# Source dependencies
# shellcheck source=lib/options.sh
source "$WORK_ENFORCEMENT_SCRIPT_DIR/options.sh"
# shellcheck source=lib/logging.sh
source "$WORK_ENFORCEMENT_SCRIPT_DIR/logging.sh"
# shellcheck source=lib/util.sh
source "$WORK_ENFORCEMENT_SCRIPT_DIR/util.sh"
# shellcheck source=lib/work_timers.sh
source "$WORK_ENFORCEMENT_SCRIPT_DIR/work_timers.sh"

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════

# Enforcement state file
HARM_WORK_ENFORCEMENT_FILE="${HARM_WORK_ENFORCEMENT_FILE:-${HARM_WORK_DIR:-${HOME}/.harm-cli/work}/enforcement.json}"
readonly HARM_WORK_ENFORCEMENT_FILE
export HARM_WORK_ENFORCEMENT_FILE

# Enforcement mode (off|coaching|moderate|strict)
HARM_WORK_ENFORCEMENT="${HARM_WORK_ENFORCEMENT:-moderate}"
export HARM_WORK_ENFORCEMENT

# Distraction threshold
HARM_WORK_DISTRACTION_THRESHOLD="${HARM_WORK_DISTRACTION_THRESHOLD:-3}"
export HARM_WORK_DISTRACTION_THRESHOLD

# Global state variables
_WORK_VIOLATIONS=0
_WORK_ACTIVE_PROJECT=""
_WORK_ACTIVE_GOAL=""
export _WORK_VIOLATIONS _WORK_ACTIVE_PROJECT _WORK_ACTIVE_GOAL

# ═══════════════════════════════════════════════════════════════
# State Management Functions
# ═══════════════════════════════════════════════════════════════

# work_enforcement_load_state: Load enforcement state from disk
#
# Description:
#   Loads violation count and active project/goal from state file.
#
# Returns:
#   0 - State loaded
#   1 - No state file
work_enforcement_load_state() {
  [[ -f "$HARM_WORK_ENFORCEMENT_FILE" ]] || return 1

  local state
  state=$(cat "$HARM_WORK_ENFORCEMENT_FILE")

  _WORK_VIOLATIONS=$(echo "$state" | jq -r '.violations // 0')
  _WORK_ACTIVE_PROJECT=$(echo "$state" | jq -r '.project // ""')
  _WORK_ACTIVE_GOAL=$(echo "$state" | jq -r '.goal // ""')

  return 0
}

# work_enforcement_save_state: Save enforcement state to disk
#
# Description:
#   Persists violation count and active project/goal.
#
# Returns:
#   0 - State saved
work_enforcement_save_state() {
  jq -n \
    --argjson violations "$_WORK_VIOLATIONS" \
    --arg project "$_WORK_ACTIVE_PROJECT" \
    --arg goal "$_WORK_ACTIVE_GOAL" \
    --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      violations: $violations,
      project: $project,
      goal: $goal,
      updated: $updated
    }' | atomic_write "$HARM_WORK_ENFORCEMENT_FILE"
}

# work_enforcement_clear: Clear enforcement state
#
# Description:
#   Resets violations and clears active project/goal.
#
# Returns:
#   0 - Always succeeds
work_enforcement_clear() {
  _WORK_VIOLATIONS=0
  _WORK_ACTIVE_PROJECT=""
  _WORK_ACTIVE_GOAL=""
  rm -f "$HARM_WORK_ENFORCEMENT_FILE" 2>/dev/null || true
}

# work_check_project_switch: Hook for detecting project switches
#
# Description:
#   Chpwd hook that detects when user switches projects during
#   a work session in strict mode. Can warn or block depending on
#   strict_block_project_switch option.
#
# Arguments:
#   $1 - old_pwd (string): Previous directory
#   $2 - new_pwd (string): New directory
#
# Returns:
#   0 - Switch allowed or warning only
#   1 - Switch blocked (if strict_block_project_switch enabled)
work_check_project_switch() {
  # Only enforce in strict mode
  [[ "$HARM_WORK_ENFORCEMENT" == "strict" ]] || return 0

  # Check if work_is_active is available (depends on work_session.sh being loaded)
  if ! declare -F work_is_active >/dev/null 2>&1; then
    return 0
  fi

  # Only enforce during active work session
  work_is_active || return 0

  local old_pwd="$1"
  local new_pwd="$2"

  # Get project names
  local old_project new_project
  old_project=$(basename "$old_pwd")
  new_project=$(basename "$new_pwd")

  # Skip if same project
  [[ "$old_project" == "$new_project" ]] && return 0

  # First time setting active project
  if [[ -z "$_WORK_ACTIVE_PROJECT" ]]; then
    _WORK_ACTIVE_PROJECT="$new_project"
    work_enforcement_save_state
    log_info "work" "Active project set" "project=$new_project"
    return 0
  fi

  # Project switch detected!
  if [[ "$new_project" != "$_WORK_ACTIVE_PROJECT" ]]; then
    # Check if blocking is enabled
    local block_enabled
    block_enabled=$(options_get strict_block_project_switch 2>/dev/null || echo "0")

    if [[ "$block_enabled" == "1" ]]; then
      # BLOCKING MODE: Prevent the switch
      echo "" >&2
      echo "🚫 PROJECT SWITCH BLOCKED!" >&2
      echo "   Active work session in: $_WORK_ACTIVE_PROJECT" >&2
      echo "   Cannot switch to: $new_project" >&2
      echo "" >&2
      echo "   To switch projects:" >&2
      echo "   1. Stop current session: harm-cli work stop" >&2
      echo "   2. Then switch projects" >&2
      echo "" >&2

      log_error "work" "Project switch blocked" "from=$_WORK_ACTIVE_PROJECT to=$new_project"

      # Change back to original directory
      cd "$old_pwd" || true
      return 1
    else
      # WARNING MODE: Increment violations and warn
      _WORK_VIOLATIONS=$((_WORK_VIOLATIONS + 1))
      work_enforcement_save_state

      echo "" >&2
      echo "⚠️  CONTEXT SWITCH DETECTED!" >&2
      echo "   Active project: $_WORK_ACTIVE_PROJECT" >&2
      echo "   Switched to: $new_project" >&2
      echo "   Violations: $_WORK_VIOLATIONS" >&2

      # Warning threshold
      if [[ $_WORK_VIOLATIONS -ge $HARM_WORK_DISTRACTION_THRESHOLD ]]; then
        echo "" >&2
        echo "❌ TOO MANY DISTRACTIONS!" >&2
        echo "   Consider:" >&2
        echo "   1. Stop work: harm-cli work stop" >&2
        echo "   2. Review goal: harm-cli goal show" >&2
        echo "   3. Refocus on: $_WORK_ACTIVE_PROJECT" >&2
        echo "" >&2
        echo "   💡 Tip: Enable strict_block_project_switch to prevent this" >&2
      fi
      echo "" >&2

      log_warn "work" "Project switch violation" "from=$_WORK_ACTIVE_PROJECT to=$new_project violations=$_WORK_VIOLATIONS"
    fi
  fi

  return 0
}

# work_get_violations: Get current violation count
#
# Description:
#   Returns the number of context switches/violations.
#
# Returns:
#   0 - Always succeeds
#
# Outputs:
#   stdout: Violation count (integer)
work_get_violations() {
  # Try to load from file if not in memory
  if [[ $_WORK_VIOLATIONS -eq 0 ]] && [[ -f "$HARM_WORK_ENFORCEMENT_FILE" ]]; then
    work_enforcement_load_state 2>/dev/null || true
  fi

  echo "$_WORK_VIOLATIONS"
}

# work_reset_violations: Reset violation counter
#
# Description:
#   Clears violation count (useful after refocusing).
#
# Returns:
#   0 - Always succeeds
work_reset_violations() {
  _WORK_VIOLATIONS=0
  work_enforcement_save_state
  log_info "work" "Violations reset"
  echo "✓ Violation counter reset"
}

# work_set_enforcement: Change enforcement mode
#
# Description:
#   Changes work enforcement level.
#
# Arguments:
#   $1 - mode (string): strict|moderate|coaching|off
#
# Returns:
#   0 - Mode set successfully
#   1 - Invalid mode
work_set_enforcement() {
  local mode="${1:?Enforcement mode required}"

  case "$mode" in
    strict | moderate | coaching | off)
      echo "HARM_WORK_ENFORCEMENT=$mode" >>"${HOME}/.harm-cli/config"
      log_info "work" "Enforcement mode changed" "mode=$mode"
      echo "✓ Enforcement mode set to: $mode"
      echo "  Restart shell for changes to take effect"
      ;;
    *)
      log_error "work" "Invalid enforcement mode: $mode"
      echo "Error: Invalid mode. Options: strict, moderate, coaching, off" >&2
      return 1
      ;;
  esac
}

# work_set_strict_mode: Enable/disable maximum enforcement (all strict features)
#
# Description:
#   Convenience function to enable or disable all strict mode features at once.
#   When enabled: Sets HARM_WORK_ENFORCEMENT=strict and enables all strict_* options.
#   When disabled: Sets HARM_WORK_ENFORCEMENT=moderate and disables all strict_* options.
#
# Arguments:
#   $1 - action (string): on|off
#
# Returns:
#   0 - Strict mode toggled successfully
#   1 - Invalid action
work_set_strict_mode() {
  local action="${1:?Action required: on|off}"

  # Entry logging
  if declare -F log_info >/dev/null 2>&1; then
    log_info "work" "strict mode toggle requested" "action=$action"
  fi

  case "$action" in
    on | enable)
      echo ""
      echo "🔒 Enabling MAXIMUM STRICT MODE..."
      echo ""

      # Set enforcement mode to strict (atomic operation)
      local config_file="${HOME}/.harm-cli/config.sh"
      local temp_file="${config_file}.tmp.$$"

      if ! grep -q "^export HARM_WORK_ENFORCEMENT=" "$config_file" 2>/dev/null; then
        # File doesn't have the setting, append it
        echo 'export HARM_WORK_ENFORCEMENT=strict' >>"$config_file"
      else
        # File has the setting, update it atomically
        sed 's|^export HARM_WORK_ENFORCEMENT=.*|export HARM_WORK_ENFORCEMENT=strict|' "$config_file" >"$temp_file"
        mv "$temp_file" "$config_file"
      fi

      # Enable all strict options
      options_set strict_block_project_switch 1 >/dev/null 2>&1 || true
      options_set strict_require_break 1 >/dev/null 2>&1 || true
      options_set strict_confirm_early_stop 1 >/dev/null 2>&1 || true
      options_set strict_track_breaks 1 >/dev/null 2>&1 || true

      echo "✅ Enforcement mode: strict"
      echo "✅ Project switch blocking: enabled"
      echo "✅ Break requirements: enabled"
      echo "✅ Early stop confirmation: enabled"
      echo "✅ Break tracking: enabled"
      echo ""
      echo "⚠️  IMPORTANT: Restart your shell for changes to take effect:"
      echo "   source ~/.bashrc   # For bash users"
      echo "   source ~/.zshrc    # For zsh users"
      echo "   Or restart your terminal"
      echo ""

      # Success logging
      if declare -F log_info >/dev/null 2>&1; then
        log_info "work" "Strict mode enabled" "all_features=on"
      fi
      ;;

    off | disable)
      echo ""
      echo "🔓 Disabling strict mode..."
      echo ""

      # Set enforcement mode to moderate (atomic operation)
      local config_file="${HOME}/.harm-cli/config.sh"
      local temp_file="${config_file}.tmp.$$"

      if ! grep -q "^export HARM_WORK_ENFORCEMENT=" "$config_file" 2>/dev/null; then
        # File doesn't have the setting, append it
        echo 'export HARM_WORK_ENFORCEMENT=moderate' >>"$config_file"
      else
        # File has the setting, update it atomically
        sed 's|^export HARM_WORK_ENFORCEMENT=.*|export HARM_WORK_ENFORCEMENT=moderate|' "$config_file" >"$temp_file"
        mv "$temp_file" "$config_file"
      fi

      # Disable all strict options
      options_set strict_block_project_switch 0 >/dev/null 2>&1 || true
      options_set strict_require_break 0 >/dev/null 2>&1 || true
      options_set strict_confirm_early_stop 0 >/dev/null 2>&1 || true
      options_set strict_track_breaks 0 >/dev/null 2>&1 || true

      echo "✅ Enforcement mode: moderate"
      echo "✅ Project switch blocking: disabled"
      echo "✅ Break requirements: disabled"
      echo "✅ Early stop confirmation: disabled"
      echo "✅ Break tracking: disabled"
      echo ""
      echo "⚠️  Restart your shell for changes to take effect:"
      echo "   source ~/.bashrc   # For bash users"
      echo "   source ~/.zshrc    # For zsh users"
      echo "   Or restart your terminal"
      echo ""

      # Success logging
      if declare -F log_info >/dev/null 2>&1; then
        log_info "work" "Strict mode disabled" "all_features=off"
      fi
      ;;

    *)
      # Error logging
      if declare -F log_error >/dev/null 2>&1; then
        log_error "work" "invalid strict mode action" "action=$action, expected=on|off|enable|disable"
      fi
      echo "Error: Invalid action '$action'. Use: on, off, enable, or disable" >&2
      return 1
      ;;
  esac

  return 0
}

# work_strict_cd: Wrapper for cd command in strict mode
#
# Description:
#   Blocks directory changes to different projects during work sessions.
#   Only active when HARM_WORK_ENFORCEMENT=strict.
#
# Arguments:
#   $@ - Arguments to pass to builtin cd
#
# Returns:
#   0 - Directory change allowed
#   1 - Directory change blocked
work_strict_cd() {
  # Get target directory (handle various cd formats)
  local target="${1:-.}"

  # Resolve to absolute path
  local target_path
  if [[ "$target" == "-" ]]; then
    # cd - (go back)
    target_path="${OLDPWD:-$HOME}"
  elif [[ "${target:0:1}" != "/" ]]; then
    # Relative path
    target_path="$(cd "$target" 2>/dev/null && pwd)" || target_path="$HOME"
  else
    # Absolute path
    target_path="$target"
  fi

  # Get current and target project names
  local current_project target_project
  current_project=$(basename "$PWD")
  target_project=$(basename "$target_path")

  # Check if work_is_active is available (depends on work_session.sh being loaded)
  if ! declare -F work_is_active >/dev/null 2>&1; then
    # Dependency not loaded yet, allow cd
    builtin cd "$@"
    return $?
  fi

  # First time - set the active project
  if [[ -z "$_WORK_ACTIVE_PROJECT" ]] && work_is_active; then
    _WORK_ACTIVE_PROJECT="$target_project"
    work_enforcement_save_state
    builtin cd "$@"
    return $?
  fi

  # Check if this would switch projects during active work session
  if work_is_active && [[ -n "$_WORK_ACTIVE_PROJECT" ]] && [[ "$target_project" != "$_WORK_ACTIVE_PROJECT" ]]; then
    echo "" >&2
    echo "🚫 BLOCKED: Project switch during work session" >&2
    echo "   Active project: $_WORK_ACTIVE_PROJECT" >&2
    echo "   Attempted: $target_project" >&2
    echo "" >&2
    echo "   You are in STRICT mode. To switch projects:" >&2
    echo "   1. Stop work: harm-cli work stop" >&2
    echo "   2. Then change directory" >&2
    echo "" >&2

    # Increment violation counter
    _WORK_VIOLATIONS=$((_WORK_VIOLATIONS + 1))
    work_enforcement_save_state

    log_warn "work" "Blocked project switch" "from=$_WORK_ACTIVE_PROJECT to=$target_project"

    return 1
  fi

  # Allow the cd
  builtin cd "$@"
  return $?
}

# work_strict_enforce_break: Check if break is required before new work
#
# Description:
#   In strict mode, after certain violations or completing work sessions,
#   a break may be required before starting new work.
#
# Returns:
#   0 - No break required or break completed
#   1 - Break required but not taken
work_strict_enforce_break() {
  [[ "$HARM_WORK_ENFORCEMENT" == "strict" ]] || return 0

  if [[ -f "$HARM_WORK_ENFORCEMENT_FILE" ]]; then
    local state
    state=$(cat "$HARM_WORK_ENFORCEMENT_FILE" 2>/dev/null || echo '{}')

    local break_required
    break_required=$(echo "$state" | jq -r '.break_required // false')

    if [[ "$break_required" == "true" ]]; then
      local break_type
      break_type=$(echo "$state" | jq -r '.break_type_required // "short"')

      echo "" >&2
      echo "🚫 BREAK REQUIRED" >&2
      echo "   You must take a $break_type break before starting new work" >&2
      echo "   Run: harm-cli break start" >&2
      echo "" >&2

      return 1
    fi
  fi

  return 0
}

# ═══════════════════════════════════════════════════════════════
# Hook Registration
# ═══════════════════════════════════════════════════════════════

# Register enforcement hooks if in strict mode
if [[ "$HARM_WORK_ENFORCEMENT" == "strict" ]]; then
  # Load existing state
  work_enforcement_load_state 2>/dev/null || true

  # Register project switch detection (if hooks module available)
  # Using declare -F instead of type for performance (type is extremely slow in large PATH environments)
  if declare -F harm_add_hook >/dev/null 2>&1; then
    harm_add_hook chpwd work_check_project_switch 2>/dev/null || true
  fi

  log_debug "work" "Work enforcement enabled" "mode=$HARM_WORK_ENFORCEMENT"

  # Override cd with strict wrapper
  if [[ "${BASH_VERSION:-}" != "" ]]; then
    cd() {
      work_strict_cd "$@"
    }
    export -f cd
    log_debug "work" "Strict cd wrapper enabled"
  fi
fi

# ═══════════════════════════════════════════════════════════════
# Module Initialization
# ═══════════════════════════════════════════════════════════════

readonly _HARM_WORK_ENFORCEMENT_LOADED=1
export _HARM_WORK_ENFORCEMENT_LOADED
