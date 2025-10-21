#!/usr/bin/env bash
# shellcheck shell=bash
# hooks.sh - Shell hook system for harm-cli
# Provides ZSH-style hooks (chpwd, preexec, precmd) in pure Bash
#
# This module provides:
# - chpwd hooks: Triggered on directory changes
# - preexec hooks: Triggered before command execution
# - precmd hooks: Triggered before prompt display
# - Hook registration and management
# - Performance optimization (throttling, caching)

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_HOOKS_LOADED:-}" ]] && return 0

# Source dependencies
HOOKS_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly HOOKS_SCRIPT_DIR

# shellcheck source=lib/common.sh
source "$HOOKS_SCRIPT_DIR/common.sh"
# shellcheck source=lib/logging.sh
source "$HOOKS_SCRIPT_DIR/logging.sh"

# Mark as loaded
readonly _HARM_HOOKS_LOADED=1

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════

# Enable/disable hook system
HARM_HOOKS_ENABLED="${HARM_HOOKS_ENABLED:-1}"
readonly HARM_HOOKS_ENABLED

# Debug mode for hooks
HARM_HOOKS_DEBUG="${HARM_HOOKS_DEBUG:-0}"
readonly HARM_HOOKS_DEBUG

# ═══════════════════════════════════════════════════════════════
# Hook Storage Arrays
# ═══════════════════════════════════════════════════════════════

# Storage for registered hooks
# Using arrays to store hook function names
declare -ga _HARM_CHPWD_HOOKS=()   # Directory change hooks
declare -ga _HARM_PREEXEC_HOOKS=() # Pre-command execution hooks
declare -ga _HARM_PRECMD_HOOKS=()  # Pre-prompt hooks

# ═══════════════════════════════════════════════════════════════
# Hook State Management
# ═══════════════════════════════════════════════════════════════

# Track last directory for chpwd detection
declare -g _HARM_LAST_PWD="${PWD}"

# Track if we're in a hook to prevent recursion
declare -gi _HARM_IN_HOOK=0

# Track last command for preexec (set by DEBUG trap)
declare -g _HARM_LAST_COMMAND=""

# Flag to skip next DEBUG trap (used internally)
declare -gi _HARM_SKIP_NEXT_DEBUG=0

# ═══════════════════════════════════════════════════════════════
# Utility Functions
# ═══════════════════════════════════════════════════════════════

# _hooks_debug: Log debug message if debug mode enabled
#
# Description:
#   Internal logging function for hook system debugging.
#   Only logs when HARM_HOOKS_DEBUG=1.
#
# Arguments:
#   $1 - message (string): Debug message to log
#
# Returns:
#   0 - Always succeeds
_hooks_debug() {
  [[ $HARM_HOOKS_DEBUG -eq 1 ]] || return 0
  log_debug "hooks" "$1"
}

# _hooks_is_interactive: Check if shell is interactive
#
# Description:
#   Determines if the current shell session is interactive.
#   Hooks are only active in interactive shells.
#
# Returns:
#   0 - Shell is interactive
#   1 - Shell is non-interactive
_hooks_is_interactive() {
  [[ $- == *i* ]]
}

# _hooks_should_run: Check if hooks should run
#
# Description:
#   Safety check to prevent hook execution in inappropriate contexts:
#   - Non-interactive shells
#   - Recursive hook calls
#   - Disabled hook system
#
# Returns:
#   0 - Hooks should run
#   1 - Hooks should not run
_hooks_should_run() {
  # Don't run if hooks disabled
  [[ $HARM_HOOKS_ENABLED -eq 1 ]] || return 1

  # Don't run if not interactive
  _hooks_is_interactive || return 1

  # Don't run if already in a hook (prevent recursion)
  [[ $_HARM_IN_HOOK -eq 0 ]] || return 1

  return 0
}

# ═══════════════════════════════════════════════════════════════
# Hook Handlers
# ═══════════════════════════════════════════════════════════════

# _harm_chpwd_handler: Directory change hook handler
#
# Description:
#   Detects directory changes and executes all registered chpwd hooks.
#   Called from PROMPT_COMMAND on every prompt display.
#
# Arguments:
#   None
#
# Returns:
#   0 - Always succeeds (errors in hooks are logged but don't fail)
#
# Side Effects:
#   - Updates _HARM_LAST_PWD
#   - Executes all registered chpwd hooks
#
# Notes:
#   - Only runs if directory actually changed
#   - Hooks run in registration order
#   - Individual hook failures don't stop other hooks
_harm_chpwd_handler() {
  _hooks_should_run || return 0

  # Check if directory changed
  [[ "$PWD" != "$_HARM_LAST_PWD" ]] || return 0

  _hooks_debug "Directory changed: $_HARM_LAST_PWD → $PWD"

  # Update last directory
  local old_pwd="$_HARM_LAST_PWD"
  _HARM_LAST_PWD="$PWD"

  # No hooks registered
  [[ ${#_HARM_CHPWD_HOOKS[@]} -eq 0 ]] && return 0

  # Set recursion guard
  _HARM_IN_HOOK=1

  # Execute all registered chpwd hooks
  local hook
  for hook in "${_HARM_CHPWD_HOOKS[@]}"; do
    if type "$hook" >/dev/null 2>&1; then
      _hooks_debug "Running chpwd hook: $hook"
      "$hook" "$old_pwd" "$PWD" 2>/dev/null || {
        log_warn "hooks" "chpwd hook failed: $hook"
      }
    else
      log_warn "hooks" "chpwd hook not found: $hook"
    fi
  done

  # Clear recursion guard
  _HARM_IN_HOOK=0
}

# _harm_preexec_handler: Pre-command execution hook handler
#
# Description:
#   Captures commands before execution and runs registered preexec hooks.
#   Called from DEBUG trap before each command.
#
# Arguments:
#   None (reads $BASH_COMMAND)
#
# Returns:
#   0 - Always succeeds
#
# Side Effects:
#   - Updates _HARM_LAST_COMMAND
#   - Executes all registered preexec hooks
#
# Notes:
#   - Filters out PROMPT_COMMAND and trap internals
#   - Only runs for top-level commands (BASH_SUBSHELL == 0)
#   - Individual hook failures don't stop other hooks
_harm_preexec_handler() {
  _hooks_should_run || return 0

  # Skip if flagged to skip
  if [[ $_HARM_SKIP_NEXT_DEBUG -eq 1 ]]; then
    _HARM_SKIP_NEXT_DEBUG=0
    return 0
  fi

  # Get the command being executed
  local cmd="$BASH_COMMAND"

  # Skip if in subshell (not top-level command)
  [[ $BASH_SUBSHELL -eq 0 ]] || return 0

  # Skip internal commands (PROMPT_COMMAND, trap handlers)
  case "$cmd" in
    _harm_* | *PROMPT_COMMAND*) return 0 ;;
  esac

  # Skip if this is part of PROMPT_COMMAND execution
  [[ "$cmd" == "$PROMPT_COMMAND" ]] && return 0

  # No hooks registered
  [[ ${#_HARM_PREEXEC_HOOKS[@]} -eq 0 ]] && return 0

  _hooks_debug "Command about to execute: $cmd"
  _HARM_LAST_COMMAND="$cmd"

  # Set recursion guard
  _HARM_IN_HOOK=1

  # Execute all registered preexec hooks
  local hook
  for hook in "${_HARM_PREEXEC_HOOKS[@]}"; do
    if type "$hook" >/dev/null 2>&1; then
      _hooks_debug "Running preexec hook: $hook"
      "$hook" "$cmd" 2>/dev/null || {
        log_warn "hooks" "preexec hook failed: $hook"
      }
    else
      log_warn "hooks" "preexec hook not found: $hook"
    fi
  done

  # Clear recursion guard
  _HARM_IN_HOOK=0
}

# _harm_precmd_handler: Pre-prompt hook handler
#
# Description:
#   Executes registered precmd hooks before each prompt display.
#   Called from PROMPT_COMMAND.
#
# Arguments:
#   None
#
# Returns:
#   0 - Always succeeds
#
# Side Effects:
#   - Executes all registered precmd hooks
#   - Passes last command exit code to hooks
#
# Notes:
#   - Captures exit code of last command ($?)
#   - Individual hook failures don't stop other hooks
#   - Runs after command completion but before prompt
_harm_precmd_handler() {
  # Capture exit code of last command FIRST (before any other commands)
  local last_exit=$?

  _hooks_should_run || return 0

  # No hooks registered
  [[ ${#_HARM_PRECMD_HOOKS[@]} -eq 0 ]] && return 0

  _hooks_debug "Running precmd hooks (last_exit=$last_exit)"

  # Set recursion guard
  _HARM_IN_HOOK=1

  # Execute all registered precmd hooks
  local hook
  for hook in "${_HARM_PRECMD_HOOKS[@]}"; do
    if type "$hook" >/dev/null 2>&1; then
      _hooks_debug "Running precmd hook: $hook"
      "$hook" "$last_exit" "$_HARM_LAST_COMMAND" 2>/dev/null || {
        log_warn "hooks" "precmd hook failed: $hook"
      }
    else
      log_warn "hooks" "precmd hook not found: $hook"
    fi
  done

  # Clear recursion guard
  _HARM_IN_HOOK=0

  # Return original exit code so it's preserved
  return "$last_exit"
}

# ═══════════════════════════════════════════════════════════════
# Hook Registration API
# ═══════════════════════════════════════════════════════════════

# harm_add_hook: Register a new hook
#
# Description:
#   Registers a function to be called when a specific hook event occurs.
#   This is the main API for adding hooks.
#
# Arguments:
#   $1 - hook_type (string): Type of hook (chpwd|preexec|precmd)
#   $2 - hook_fn (string): Name of function to call
#
# Returns:
#   0 - Hook registered successfully
#   1 - Invalid hook type
#   2 - Hook function doesn't exist
#   3 - Hook already registered
#
# Outputs:
#   stderr: Error messages via log_error()
#
# Examples:
#   harm_add_hook chpwd my_dir_change_handler
#   harm_add_hook preexec my_command_logger
#   harm_add_hook precmd my_prompt_updater
#
# Notes:
#   - Hook function must exist before registration
#   - Duplicate registrations are prevented
#   - Hooks are called in registration order
harm_add_hook() {
  local hook_type="${1:?Hook type required (chpwd|preexec|precmd)}"
  local hook_fn="${2:?Hook function name required}"

  # Validate hook function exists
  if ! type "$hook_fn" >/dev/null 2>&1; then
    log_error "hooks" "Hook function not found: $hook_fn"
    return 2
  fi

  # Add to appropriate hook array
  case "$hook_type" in
    chpwd)
      # Check if already registered
      local existing
      for existing in "${_HARM_CHPWD_HOOKS[@]}"; do
        if [[ "$existing" == "$hook_fn" ]]; then
          log_warn "hooks" "Hook already registered: $hook_fn"
          return 3
        fi
      done
      _HARM_CHPWD_HOOKS+=("$hook_fn")
      log_debug "hooks" "Registered chpwd hook: $hook_fn"
      ;;

    preexec)
      # Check if already registered
      local existing
      for existing in "${_HARM_PREEXEC_HOOKS[@]}"; do
        if [[ "$existing" == "$hook_fn" ]]; then
          log_warn "hooks" "Hook already registered: $hook_fn"
          return 3
        fi
      done
      _HARM_PREEXEC_HOOKS+=("$hook_fn")
      log_debug "hooks" "Registered preexec hook: $hook_fn"
      ;;

    precmd)
      # Check if already registered
      local existing
      for existing in "${_HARM_PRECMD_HOOKS[@]}"; do
        if [[ "$existing" == "$hook_fn" ]]; then
          log_warn "hooks" "Hook already registered: $hook_fn"
          return 3
        fi
      done
      _HARM_PRECMD_HOOKS+=("$hook_fn")
      log_debug "hooks" "Registered precmd hook: $hook_fn"
      ;;

    *)
      log_error "hooks" "Unknown hook type: $hook_type"
      return 1
      ;;
  esac

  return 0
}

# harm_remove_hook: Unregister a hook
#
# Description:
#   Removes a previously registered hook function.
#
# Arguments:
#   $1 - hook_type (string): Type of hook (chpwd|preexec|precmd)
#   $2 - hook_fn (string): Name of function to remove
#
# Returns:
#   0 - Hook removed successfully
#   1 - Invalid hook type
#   2 - Hook not found
#
# Examples:
#   harm_remove_hook chpwd my_dir_change_handler
harm_remove_hook() {
  local hook_type="${1:?Hook type required}"
  local hook_fn="${2:?Hook function name required}"

  local -a new_hooks=()
  local found=0

  case "$hook_type" in
    chpwd)
      for hook in "${_HARM_CHPWD_HOOKS[@]}"; do
        if [[ "$hook" != "$hook_fn" ]]; then
          new_hooks+=("$hook")
        else
          found=1
        fi
      done
      _HARM_CHPWD_HOOKS=("${new_hooks[@]}")
      ;;

    preexec)
      for hook in "${_HARM_PREEXEC_HOOKS[@]}"; do
        if [[ "$hook" != "$hook_fn" ]]; then
          new_hooks+=("$hook")
        else
          found=1
        fi
      done
      _HARM_PREEXEC_HOOKS=("${new_hooks[@]}")
      ;;

    precmd)
      for hook in "${_HARM_PRECMD_HOOKS[@]}"; do
        if [[ "$hook" != "$hook_fn" ]]; then
          new_hooks+=("$hook")
        else
          found=1
        fi
      done
      _HARM_PRECMD_HOOKS=("${new_hooks[@]}")
      ;;

    *)
      log_error "hooks" "Unknown hook type: $hook_type"
      return 1
      ;;
  esac

  if [[ $found -eq 0 ]]; then
    log_warn "hooks" "Hook not found: $hook_fn"
    return 2
  fi

  log_debug "hooks" "Removed $hook_type hook: $hook_fn"
  return 0
}

# harm_list_hooks: List all registered hooks
#
# Description:
#   Displays all currently registered hooks by type.
#   Useful for debugging and verification.
#
# Arguments:
#   $1 - hook_type (string, optional): Filter by hook type
#
# Returns:
#   0 - Always succeeds
#
# Outputs:
#   stdout: List of registered hooks
#
# Examples:
#   harm_list_hooks           # List all hooks
#   harm_list_hooks chpwd     # List only chpwd hooks
harm_list_hooks() {
  local filter="${1:-all}"

  if [[ "$filter" == "all" || "$filter" == "chpwd" ]]; then
    echo "chpwd hooks (${#_HARM_CHPWD_HOOKS[@]}):"
    for hook in "${_HARM_CHPWD_HOOKS[@]}"; do
      echo "  • $hook"
    done
  fi

  if [[ "$filter" == "all" || "$filter" == "preexec" ]]; then
    echo "preexec hooks (${#_HARM_PREEXEC_HOOKS[@]}):"
    for hook in "${_HARM_PREEXEC_HOOKS[@]}"; do
      echo "  • $hook"
    done
  fi

  if [[ "$filter" == "all" || "$filter" == "precmd" ]]; then
    echo "precmd hooks (${#_HARM_PRECMD_HOOKS[@]}):"
    for hook in "${_HARM_PRECMD_HOOKS[@]}"; do
      echo "  • $hook"
    done
  fi
}

# ═══════════════════════════════════════════════════════════════
# Hook System Initialization
# ═══════════════════════════════════════════════════════════════

# harm_hooks_init: Initialize the hook system
#
# Description:
#   Sets up PROMPT_COMMAND and DEBUG trap to enable hook functionality.
#   Must be called once during shell initialization.
#
# Arguments:
#   None
#
# Returns:
#   0 - Hook system initialized successfully
#   1 - Already initialized or hooks disabled
#
# Side Effects:
#   - Modifies PROMPT_COMMAND
#   - Sets DEBUG trap
#   - Enables extdebug shell option
#
# Notes:
#   - Safe to call multiple times (idempotent)
#   - Only works in interactive shells
#   - Preserves existing PROMPT_COMMAND if present
harm_hooks_init() {
  # Skip if not interactive
  _hooks_is_interactive || return 1

  # Skip if hooks disabled
  [[ $HARM_HOOKS_ENABLED -eq 1 ]] || return 1

  # Check if already initialized (look for our handlers in PROMPT_COMMAND)
  if [[ "$PROMPT_COMMAND" == *"_harm_chpwd_handler"* ]]; then
    _hooks_debug "Hook system already initialized"
    return 1
  fi

  log_info "hooks" "Initializing hook system"

  # Build new PROMPT_COMMAND that includes our handlers
  # Order matters: chpwd before precmd (directory change detection first)
  local new_prompt_command="_harm_chpwd_handler; _harm_precmd_handler"

  # Preserve existing PROMPT_COMMAND if present
  if [[ -n "${PROMPT_COMMAND:-}" ]]; then
    PROMPT_COMMAND="${new_prompt_command}; ${PROMPT_COMMAND}"
  else
    PROMPT_COMMAND="$new_prompt_command"
  fi

  # Set up DEBUG trap for preexec
  trap '_harm_preexec_handler' DEBUG

  # Enable extdebug to make DEBUG trap work with functions
  shopt -s extdebug 2>/dev/null || true

  log_info "hooks" "Hook system initialized successfully"
  return 0
}

# ═══════════════════════════════════════════════════════════════
# Auto-initialization
# ═══════════════════════════════════════════════════════════════

# Only auto-initialize if in interactive shell and hooks enabled
if _hooks_is_interactive && [[ $HARM_HOOKS_ENABLED -eq 1 ]]; then
  harm_hooks_init
fi
