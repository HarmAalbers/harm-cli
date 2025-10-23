#!/usr/bin/env bash
# lib/interactive.sh - Interactive prompts and selections for harm-cli
#
# Provides a unified interface for interactive CLI prompts with automatic
# fallback from gum -> fzf -> bash select based on availability.
#
# Functions:
#   interactive_detect_tool       - Detect and set the interactive tool preference
#   interactive_choose            - Single selection from options
#   interactive_choose_multi      - Multi-selection from options
#   interactive_input             - Text input prompt
#   interactive_password          - Password input prompt
#   interactive_confirm           - Yes/no confirmation
#   interactive_filter            - Fuzzy filter from stdin
#
# Environment Variables:
#   INTERACTIVE_TOOL    - Override tool selection (gum|fzf|select)
#   NO_COLOR           - Disable colored output

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_LIB_INTERACTIVE_LOADED:-}" ]] && return 0
declare -g _LIB_INTERACTIVE_LOADED=1

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=lib/error.sh
source "${SCRIPT_DIR}/error.sh"
# shellcheck source=lib/logging.sh
source "${SCRIPT_DIR}/logging.sh"

# Global variable to store detected tool
declare -g INTERACTIVE_TOOL=""

# Detect and set the interactive tool preference
interactive_detect_tool() {
  if [[ -n "${INTERACTIVE_TOOL:-}" ]]; then
    log_debug "interactive" "Using override: ${INTERACTIVE_TOOL}"
    return 0
  fi

  if command -v gum >/dev/null 2>&1; then
    INTERACTIVE_TOOL="gum"
  elif command -v fzf >/dev/null 2>&1; then
    INTERACTIVE_TOOL="fzf"
  else
    INTERACTIVE_TOOL="select"
  fi

  log_debug "interactive" "Detected tool: ${INTERACTIVE_TOOL}"
  return 0
}

# Verify TTY is available
_interactive_check_tty() {
  if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
    log_error "interactive" "No TTY available"
    return 2
  fi
  return 0
}

# Single selection using gum
_interactive_choose_gum() {
  local prompt="$1"
  shift
  printf '%s\n' "$@" | gum choose --header="${prompt}"
}

# Single selection using fzf
_interactive_choose_fzf() {
  local prompt="$1"
  shift
  printf '%s\n' "$@" | fzf --prompt="${prompt}: " --height=40% --reverse
}

# Single selection using bash select
_interactive_choose_select() {
  local prompt="$1"
  shift
  echo "${prompt}" >&2
  local PS3="> "
  select selected in "$@"; do
    if [[ -n "${selected}" ]]; then
      echo "${selected}"
      return 0
    fi
  done
  return 1
}

# Single selection from options
interactive_choose() {
  [[ "$#" -lt 2 ]] && {
    log_error "interactive" "Requires prompt and options"
    return 1
  }
  _interactive_check_tty || return 2
  [[ -z "${INTERACTIVE_TOOL}" ]] && interactive_detect_tool

  case "${INTERACTIVE_TOOL}" in
    gum) _interactive_choose_gum "$@" ;;
    fzf) _interactive_choose_fzf "$@" ;;
    select) _interactive_choose_select "$@" ;;
    *) return 1 ;;
  esac
}

# Multi-selection using gum
_interactive_multi_gum() {
  local prompt="$1"
  shift
  printf '%s\n' "$@" | gum choose --no-limit --header="${prompt}"
}

# Multi-selection using fzf
_interactive_multi_fzf() {
  local prompt="$1"
  shift
  printf '%s\n' "$@" | fzf --multi --prompt="${prompt}: " --height=40% --reverse
}

# Multi-selection using bash select (sequential)
_interactive_multi_select() {
  local prompt="$1"
  shift
  local options=("$@")
  local -a selected=()

  echo "${prompt}" >&2
  echo "(Select multiple, enter 'done' when finished)" >&2
  local PS3="> "
  select opt in "${options[@]}" "done"; do
    if [[ "$opt" == "done" ]]; then
      break
    elif [[ -n "$opt" ]]; then
      selected+=("$opt")
      echo "✓ Added: $opt" >&2
    fi
  done
  printf '%s\n' "${selected[@]}"
  [[ "${#selected[@]}" -gt 0 ]]
}

# Multi-selection from options
interactive_choose_multi() {
  [[ "$#" -lt 2 ]] && {
    log_error "interactive" "Requires prompt and options"
    return 1
  }
  _interactive_check_tty || return 2
  [[ -z "${INTERACTIVE_TOOL}" ]] && interactive_detect_tool

  case "${INTERACTIVE_TOOL}" in
    gum) _interactive_multi_gum "$@" ;;
    fzf) _interactive_multi_fzf "$@" ;;
    select) _interactive_multi_select "$@" ;;
    *) return 1 ;;
  esac
}

# Text input prompt
interactive_input() {
  [[ "$#" -lt 1 ]] && {
    log_error "interactive" "Requires prompt"
    return 1
  }
  _interactive_check_tty || return 2

  local prompt="$1"
  local default="${2:-}"
  local placeholder="${3:-}"
  [[ -z "${INTERACTIVE_TOOL}" ]] && interactive_detect_tool

  case "${INTERACTIVE_TOOL}" in
    gum)
      local args=(--prompt="${prompt}: ")
      [[ -n "${default}" ]] && args+=(--value="${default}")
      [[ -n "${placeholder}" ]] && args+=(--placeholder="${placeholder}")
      gum input "${args[@]}"
      ;;
    *)
      local prompt_text="${prompt}"
      [[ -n "${default}" ]] && prompt_text="${prompt} [${default}]"
      read -r -p "${prompt_text}: " input
      echo "${input:-$default}"
      ;;
  esac
}

# Password input prompt
interactive_password() {
  [[ "$#" -lt 1 ]] && {
    log_error "interactive" "Requires prompt"
    return 1
  }
  _interactive_check_tty || return 2

  local prompt="$1"
  [[ -z "${INTERACTIVE_TOOL}" ]] && interactive_detect_tool

  case "${INTERACTIVE_TOOL}" in
    gum)
      gum input --password --prompt="${prompt}: "
      ;;
    *)
      read -r -s -p "${prompt}: " password
      echo "" >&2
      echo "${password}"
      ;;
  esac
}

# Confirmation prompt
interactive_confirm() {
  [[ "$#" -lt 1 ]] && {
    log_error "interactive" "Requires prompt"
    return 1
  }
  _interactive_check_tty || return 2

  local prompt="$1"
  local default="${2:-no}"
  [[ -z "${INTERACTIVE_TOOL}" ]] && interactive_detect_tool

  case "${INTERACTIVE_TOOL}" in
    gum)
      local default_flag="--default=false"
      [[ "${default}" == "yes" ]] && default_flag="--default=true"
      gum confirm "${prompt}" ${default_flag}
      ;;
    *)
      local yn="[y/N]"
      [[ "${default}" == "yes" ]] && yn="[Y/n]"
      read -r -p "${prompt} ${yn}: " response
      response="${response,,}"
      [[ -z "${response}" ]] && [[ "${default}" == "yes" ]] && return 0
      [[ "${response}" == "y" ]] || [[ "${response}" == "yes" ]]
      ;;
  esac
}

# Fuzzy filter from stdin
interactive_filter() {
  _interactive_check_tty || return 2
  local prompt="${1:-Filter}"
  [[ -z "${INTERACTIVE_TOOL}" ]] && interactive_detect_tool

  case "${INTERACTIVE_TOOL}" in
    gum) gum filter --placeholder="${prompt}" ;;
    fzf) fzf --prompt="${prompt}: " --height=40% --reverse ;;
    select)
      local -a options=()
      while IFS= read -r line; do options+=("${line}"); done
      [[ "${#options[@]}" -eq 0 ]] && return 1
      _interactive_choose_select "${prompt}" "${options[@]}"
      ;;
    *) return 1 ;;
  esac
}

# Export functions
export -f interactive_detect_tool interactive_choose interactive_choose_multi
export -f interactive_input interactive_password interactive_confirm interactive_filter
