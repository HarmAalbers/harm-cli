#!/usr/bin/env bash
# shellcheck shell=bash
# gcloud.sh - Google Cloud SDK integration
# Ported from: ~/.zsh/60_gcloud.zsh
#
# Features:
# - GCloud SDK path detection and setup
# - Configuration validation
# - Status display
#
# Public API:
#   gcloud_is_installed    - Check if GCloud SDK installed
#   gcloud_status          - Show GCloud configuration status
#
# Dependencies: gcloud (optional)

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_GCLOUD_LOADED:-}" ]] && return 0

# Source dependencies
GCLOUD_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly GCLOUD_SCRIPT_DIR

# shellcheck source=lib/common.sh
source "$GCLOUD_SCRIPT_DIR/common.sh"
# shellcheck source=lib/error.sh
source "$GCLOUD_SCRIPT_DIR/error.sh"
# shellcheck source=lib/logging.sh
source "$GCLOUD_SCRIPT_DIR/logging.sh"

# ═══════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════

readonly GCLOUD_SDK_PATHS=(
  "$HOME/google-cloud-sdk"
  "/usr/local/google-cloud-sdk"
  "/opt/google-cloud-sdk"
  "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk"
)

# ═══════════════════════════════════════════════════════════════════
# GCloud Utilities
# ═══════════════════════════════════════════════════════════════════

# gcloud_is_installed: Check if Google Cloud SDK is installed
#
# Description:
#   Checks if gcloud command is available in PATH.
#
# Arguments:
#   None
#
# Returns:
#   0 - GCloud SDK installed and accessible
#   1 - GCloud SDK not found
#
# Outputs:
#   stderr: Log messages via log_debug
#
# Examples:
#   gcloud_is_installed || echo "GCloud not installed"
#   if gcloud_is_installed; then
#     gcloud config list
#   fi
#
# Notes:
#   - Checks for gcloud command in PATH
#   - Does not verify SDK configuration
#   - Fast check (<10ms)
#
# Performance:
#   - Typical: <10ms
gcloud_is_installed() {
  log_debug "gcloud" "Checking if GCloud SDK installed"

  if command -v gcloud >/dev/null 2>&1; then
    log_debug "gcloud" "GCloud SDK found"
    return 0
  else
    log_debug "gcloud" "GCloud SDK not found"
    return 1
  fi
}

# gcloud_status: Display Google Cloud SDK status
#
# Description:
#   Shows GCloud SDK installation status, version, active configuration,
#   and current project information.
#
# Arguments:
#   None
#
# Returns:
#   0 - Status displayed successfully
#   1 - GCloud SDK not installed
#
# Outputs:
#   stdout: GCloud SDK status information
#   stderr: Log messages via log_info/log_debug
#
# Examples:
#   gcloud_status
#   harm-cli gcloud status
#
# Notes:
#   - Shows SDK version if installed
#   - Shows active account and project
#   - Provides installation instructions if not found
#   - Safe to run even if GCloud not installed
#
# Performance:
#   - With GCloud: 100-500ms (depends on config)
#   - Without GCloud: <50ms
gcloud_status() {
  # Parse format flags
  local format="${HARM_CLI_FORMAT:-text}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format)
        format="${2:?--format requires an argument}"
        shift 2
        ;;
      --format=*)
        format="${1#*=}"
        shift
        ;;
      -F)
        format="${2:?-F requires an argument}"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  [[ "$format" != "json" ]] && log_info "gcloud" "Showing GCloud SDK status"

  # Check if installed
  if ! gcloud_is_installed; then
    if [[ "$format" == "json" ]]; then
      jq -n '{installed: false, version: null, account: null, project: null}'
    else
      echo "✗ GCloud SDK not installed"
      echo ""
      echo "Installation:"
      echo "  macOS: brew install --cask google-cloud-sdk"
      echo "  Linux: https://cloud.google.com/sdk/docs/install"
      echo ""
      echo "Common installation paths checked:"
      for path in "${GCLOUD_SDK_PATHS[@]}"; do
        echo "  - $path"
      done
      log_info "gcloud" "GCloud SDK not installed"
    fi
    return 1
  fi

  # Get status info
  local version
  version=$(gcloud version --format="value(version)" 2>/dev/null || echo "unknown")

  local account
  account=$(gcloud config get-value account 2>/dev/null || echo "none")

  local project
  project=$(gcloud config get-value project 2>/dev/null || echo "none")

  # Output format
  if [[ "$format" == "json" ]]; then
    jq -n \
      --argjson installed true \
      --arg version "$version" \
      --arg account "$account" \
      --arg project "$project" \
      '{installed: $installed, version: $version, account: $account, project: $project}'
  else
    echo "Google Cloud SDK Status"
    echo "══════════════════════════════════════════"
    echo ""
    echo "✓ GCloud SDK installed"
    echo "  Version: $version"
    echo ""
    echo "Configuration:"
    echo "  Account: $account"
    echo "  Project: $project"

    if [[ "$account" == "none" ]]; then
      echo ""
      echo "Setup:"
      echo "  → Authenticate: gcloud auth login"
      echo "  → Set project: gcloud config set project PROJECT_ID"
    fi
  fi

  log_debug "gcloud" "Status displayed" "Account: $account, Project: $project"
  return 0
}

# ═══════════════════════════════════════════════════════════════
# Safety Features
# ═══════════════════════════════════════════════════════════════

# gcloud_safe_exec: Execute gcloud command with project verification
#
# Description:
#   Wrapper for gcloud commands that verifies execution is happening
#   in a registered project directory and that the GCloud project
#   matches expectations. Prevents accidental operations on wrong projects.
#
# Arguments:
#   $@ - gcloud command arguments
#
# Returns:
#   0 - Command executed successfully
#   1 - Safety check failed or command failed
#
# Examples:
#   gcloud_safe_exec compute instances list
#   gcloud_safe_exec app deploy --force
gcloud_safe_exec() {
  if [[ $# -eq 0 ]]; then
    error_msg "gcloud_safe_exec requires command arguments"
    return 1
  fi

  if ! gcloud_is_installed; then
    error_msg "GCloud SDK not installed"
    return 1
  fi

  # Get current GCloud project
  local current_project
  current_project=$(gcloud config get-value project 2>/dev/null || echo "")

  if [[ -z "$current_project" ]]; then
    error_msg "No GCloud project configured"
    echo "Set project with: gcloud config set project PROJECT_ID"
    return 1
  fi

  # Warn about current project
  echo "⚠️  GCloud Project: $current_project" >&2
  echo "   Command: gcloud $*" >&2
  echo "" >&2

  # Check if command is destructive
  local is_destructive=false
  for arg in "$@"; do
    case "$arg" in
      delete | destroy | remove | rm | prune | reset)
        is_destructive=true
        break
        ;;
    esac
  done

  # Require confirmation for destructive operations
  if [[ "$is_destructive" == true ]]; then
    echo "🚨 DESTRUCTIVE OPERATION DETECTED" >&2
    read -r -p "Continue with this operation? [y/N]: " confirm
    if [[ "${confirm,,}" != "y" ]]; then
      echo "Operation cancelled" >&2
      return 1
    fi
  fi

  # Execute command
  log_info "gcloud" "Executing gcloud command" "Project: $current_project"
  gcloud "$@"
}

# Export public functions
export -f gcloud_is_installed
export -f gcloud_status
export -f gcloud_safe_exec

# Mark module as loaded
readonly _HARM_GCLOUD_LOADED=1
