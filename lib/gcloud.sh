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
  log_info "gcloud" "Showing GCloud SDK status"

  echo "Google Cloud SDK Status"
  echo "══════════════════════════════════════════"
  echo ""

  # Check if installed
  if ! gcloud_is_installed; then
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
    return 1
  fi

  # Show version
  local version
  version=$(gcloud version --format="value(version)" 2>/dev/null || echo "unknown")
  echo "✓ GCloud SDK installed"
  echo "  Version: $version"
  echo ""

  # Show active configuration
  echo "Configuration:"
  local account
  account=$(gcloud config get-value account 2>/dev/null || echo "none")
  echo "  Account: $account"

  local project
  project=$(gcloud config get-value project 2>/dev/null || echo "none")
  echo "  Project: $project"

  if [[ "$account" == "none" ]]; then
    echo ""
    echo "Setup:"
    echo "  → Authenticate: gcloud auth login"
    echo "  → Set project: gcloud config set project PROJECT_ID"
  fi

  log_debug "gcloud" "Status displayed" "Account: $account, Project: $project"
  return 0
}

# Export public functions
export -f gcloud_is_installed
export -f gcloud_status

# Mark module as loaded
readonly _HARM_GCLOUD_LOADED=1
