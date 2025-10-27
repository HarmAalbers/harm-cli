#!/usr/bin/env bash
# shellcheck shell=bash
# safety.sh - Safety wrappers for dangerous operations
# Ported from: ~/.zsh/70_dangerous_operations.zsh
#
# Features:
# - Confirmation prompts with timeout for destructive operations
# - Dry-run mode to preview changes
# - Comprehensive logging of all dangerous operations
# - Safety guards for rm, docker, git operations
#
# Public API:
#   safe_rm <files>            - Safe file deletion with confirmation
#   safe_docker_prune          - Docker system prune with preview
#   safe_git_reset <ref>       - Git reset with backup
#
# Dependencies: None (uses core commands)

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_SAFETY_LOADED:-}" ]] && return 0

# Source dependencies
SAFETY_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SAFETY_SCRIPT_DIR

# shellcheck source=lib/common.sh
source "$SAFETY_SCRIPT_DIR/common.sh"
# shellcheck source=lib/error.sh
source "$SAFETY_SCRIPT_DIR/error.sh"
# shellcheck source=lib/logging.sh
source "$SAFETY_SCRIPT_DIR/logging.sh"

# ═══════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════

readonly SAFETY_CONFIRM_TIMEOUT=30 # 30 seconds to confirm
readonly SAFETY_LOG_FILE="${HARM_CLI_HOME:-$HOME/.harm-cli}/logs/dangerous_ops.log"

# ═══════════════════════════════════════════════════════════════════
# Safety Utilities
# ═══════════════════════════════════════════════════════════════════

# _safety_confirm: Get user confirmation with timeout
#
# Arguments:
#   $1 - operation (string): What operation needs confirmation
#   $2 - expected_input (string): What user must type to confirm
#
# Returns:
#   0 - User confirmed
#   130 - User cancelled or timeout
_safety_confirm() {
  local operation="$1"
  local expected="${2:-yes}"

  echo ""
  echo "⚠️  DANGEROUS OPERATION: $operation"
  echo ""
  echo "Type '$expected' to confirm (timeout: ${SAFETY_CONFIRM_TIMEOUT}s): "

  local response
  if read -r -t "$SAFETY_CONFIRM_TIMEOUT" response; then
    if [[ "$response" == "$expected" ]]; then
      log_info "safety" "Operation confirmed" "$operation"
      return 0
    else
      echo "Cancelled (incorrect confirmation)"
      log_info "safety" "Operation cancelled" "Wrong input: $response"
      return 130
    fi
  else
    echo ""
    echo "Timeout - operation cancelled for safety"
    log_warn "safety" "Operation timeout" "$operation"
    return 130
  fi
}

# _safety_log: Log dangerous operation
_safety_log() {
  local operation="$1"
  local details="${2:-}"

  # Ensure log directory exists
  local log_dir
  log_dir=$(dirname "$SAFETY_LOG_FILE")
  [[ ! -d "$log_dir" ]] && mkdir -p "$log_dir"

  # Log to file
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $operation${details:+ | $details}" >>"$SAFETY_LOG_FILE"

  # Also log via logging system
  log_warn "safety" "Dangerous operation" "$operation${details:+ | $details}"
}

# ═══════════════════════════════════════════════════════════════════
# Safety Wrappers
# ═══════════════════════════════════════════════════════════════════

# safe_rm: Safe file deletion with confirmation
#
# Description:
#   Wrapper around rm command that requires confirmation for recursive
#   or force operations. Shows preview of what will be deleted.
#
# Arguments:
#   $@ - Files/directories to remove (same as rm)
#
# Returns:
#   0 - Files removed successfully
#   130 - User cancelled
#   EXIT_INVALID_ARGS - No files specified
#
# Outputs:
#   stdout: Preview and confirmation prompt
#   stderr: Log messages
#
# Examples:
#   safe_rm -rf node_modules/
#   safe_rm *.tmp
#   harm-cli safe rm -rf build/
#
# Notes:
#   - Detects -r, -R, -f, --force flags
#   - Shows file count before deletion
#   - Requires typing "delete" to confirm
#   - Logs all operations
#   - 30 second timeout for safety
#
# Safety:
#   - Preview before delete
#   - Confirmation required
#   - Logged to dangerous_ops.log
safe_rm() {
  if [[ $# -eq 0 ]]; then
    error_msg "No files specified"
    echo "Usage: safe_rm [OPTIONS] <files>"
    return "$EXIT_INVALID_ARGS"
  fi

  # Check if recursive or force
  local is_dangerous=0
  local args=("$@")

  for arg in "$@"; do
    if [[ "$arg" =~ ^-.*[rRf] ]] || [[ "$arg" == "--force" ]] || [[ "$arg" == "--recursive" ]]; then
      is_dangerous=1
      break
    fi
  done

  # Preview what will be deleted
  echo "Files to delete:"
  local count=0
  for arg in "$@"; do
    if [[ ! "$arg" =~ ^- ]]; then
      if [[ -e "$arg" ]]; then
        if [[ -d "$arg" ]]; then
          local size
          size=$(du -sh "$arg" 2>/dev/null | awk '{print $1}')
          echo "  📁 $arg/ ($size)"
        else
          echo "  📄 $arg"
        fi
        ((++count))
      fi
    fi
  done

  if [[ $count -eq 0 ]]; then
    echo "No files found to delete"
    return 0
  fi

  # SECURITY: ALWAYS require confirmation for any deletion
  # This is "safe_rm" - it should be safer than regular rm
  # Users can use regular rm if they want no confirmation
  echo ""
  if [[ $is_dangerous -eq 1 ]]; then
    echo "⚠️  WARNING: Recursive or force deletion detected"
  fi
  _safety_confirm "Delete $count items" "delete" || return 130

  # Perform deletion
  _safety_log "rm" "Args: $*, Count: $count"

  if rm "$@"; then
    echo "✓ Deleted $count items"
    log_info "safety" "Files deleted" "Count: $count"
    return 0
  else
    error_msg "Deletion failed"
    return "$EXIT_COMMAND_FAILED"
  fi
}

# safe_docker_prune: Safe Docker system prune with preview
#
# Description:
#   Safely removes unused Docker data (containers, networks, images, volumes)
#   with preview and confirmation. Shows space to be reclaimed.
#
# Arguments:
#   --all - Remove all unused images (not just dangling)
#   --volumes - Also remove volumes
#
# Returns:
#   0 - Pruned successfully
#   130 - User cancelled
#   EXIT_INVALID_STATE - Docker not running
#
# Examples:
#   safe_docker_prune
#   safe_docker_prune --all --volumes
#
# Safety:
#   - Shows space to reclaim
#   - Requires confirmation
#   - Logged
safe_docker_prune() {
  log_info "safety" "Docker prune requested"

  # Check if docker available and running
  if ! command -v docker >/dev/null 2>&1; then
    error_msg "Docker not installed"
    return "$EXIT_DEPENDENCY_MISSING"
  fi

  if ! docker info >/dev/null 2>&1; then
    error_msg "Docker daemon not running"
    return "$EXIT_INVALID_STATE"
  fi

  # Show what will be removed (with progress indicator)
  echo "Docker System Prune Preview:"
  echo ""

  # Use progress indicator for potentially slow df command
  local space
  if command -v show_spinner >/dev/null 2>&1; then
    space=$(show_spinner "Analyzing Docker disk usage..." docker system df 2>/dev/null)
  else
    # Fallback if util.sh not loaded yet
    echo "Analyzing Docker disk usage..." >&2
    space=$(docker system df 2>/dev/null || echo "")
  fi

  if [[ -n "$space" ]]; then
    echo "$space"
    echo ""
  fi

  _safety_confirm "Prune Docker system" "prune" || return 130

  # Log operation
  _safety_log "docker system prune" "Args: $*"

  # Perform prune (with progress indicator)
  echo ""
  if command -v show_spinner >/dev/null 2>&1; then
    if show_spinner "Pruning Docker system..." docker system prune -f "$@"; then
      echo "✓ Docker system pruned"
      log_info "safety" "Docker pruned successfully"
      return 0
    else
      error_msg "Docker prune failed"
      return "$EXIT_COMMAND_FAILED"
    fi
  else
    # Fallback without progress
    if docker system prune -f "$@"; then
      echo "✓ Docker system pruned"
      log_info "safety" "Docker pruned successfully"
      return 0
    else
      error_msg "Docker prune failed"
      return "$EXIT_COMMAND_FAILED"
    fi
  fi
}

# safe_git_reset: Safe git reset with backup
#
# Description:
#   Safely resets git branch with automatic backup branch creation.
#   Requires confirmation and shows what will be lost.
#
# Arguments:
#   $1 - ref (string): Git reference to reset to (default: origin/main)
#
# Returns:
#   0 - Reset successful
#   130 - User cancelled
#   EXIT_INVALID_STATE - Not in git repo
#
# Examples:
#   safe_git_reset
#   safe_git_reset origin/develop
#   safe_git_reset HEAD~1
#
# Safety:
#   - Creates backup branch automatically
#   - Shows commits that will be lost
#   - Requires confirmation
safe_git_reset() {
  local ref="${1:-origin/main}"

  log_info "safety" "Git reset requested" "Ref: $ref"

  # Check if in git repo
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    error_msg "Not in a git repository"
    return "$EXIT_INVALID_STATE"
  fi

  # Get current branch
  local current_branch
  current_branch=$(git branch --show-current)

  # Create backup branch
  local backup_branch="backup-${current_branch}-$(date +%Y%m%d-%H%M%S)"

  echo "Git Reset Safety Check:"
  echo ""
  echo "Current branch: $current_branch"
  echo "Reset to: $ref"
  echo "Backup will be created: $backup_branch"
  echo ""

  # Show what will be lost - COMPREHENSIVE CHECK
  echo "═══════════════════════════════════════════"
  echo "  RESET IMPACT ANALYSIS"
  echo "═══════════════════════════════════════════"
  echo ""

  # 1. Commits that will be lost
  echo "1. Commits that will be lost:"
  local lost_commits
  lost_commits=$(git log "$ref..HEAD" --oneline 2>/dev/null)
  if [[ -n "$lost_commits" ]]; then
    echo "$lost_commits" | sed 's/^/     /'
    echo ""
    local commit_count
    commit_count=$(echo "$lost_commits" | wc -l | tr -d ' ')
    echo "     Total: $commit_count commit(s)"
  else
    echo "     (none)"
  fi
  echo ""

  # 2. Staged changes that will be lost
  echo "2. Staged changes that will be lost:"
  local staged_files
  staged_files=$(git diff --cached --name-only 2>/dev/null)
  if [[ -n "$staged_files" ]]; then
    echo "     ⚠️  WARNING: You have staged changes!"
    echo "$staged_files" | sed 's/^/       - /'
  else
    echo "     (none)"
  fi
  echo ""

  # 3. Uncommitted changes that will be lost
  echo "3. Uncommitted changes in working directory:"
  local working_files
  working_files=$(git diff --name-only 2>/dev/null)
  if [[ -n "$working_files" ]]; then
    echo "     ⚠️  WARNING: You have uncommitted changes!"
    echo "$working_files" | sed 's/^/       - /'
  else
    echo "     (none)"
  fi
  echo ""

  # Overall risk assessment
  local risk_level="LOW"
  if [[ -n "$working_files" ]] || [[ -n "$staged_files" ]]; then
    risk_level="⚠️  HIGH - UNCOMMITTED WORK WILL BE LOST"
  elif [[ -n "$lost_commits" ]]; then
    risk_level="⚠️  MEDIUM - COMMITS WILL BE LOST"
  else
    risk_level="✓ LOW - No local changes"
  fi

  echo "═══════════════════════════════════════════"
  echo "  RISK LEVEL: $risk_level"
  echo "═══════════════════════════════════════════"
  echo ""

  _safety_confirm "Reset $current_branch to $ref" "reset" || return 130

  # Create backup
  if git branch "$backup_branch"; then
    echo "✓ Backup created: $backup_branch"
  else
    error_msg "Failed to create backup branch"
    return "$EXIT_COMMAND_FAILED"
  fi

  # Log operation
  _safety_log "git reset" "Branch: $current_branch, Ref: $ref, Backup: $backup_branch"

  # Perform reset
  if git reset --hard "$ref"; then
    echo "✓ Reset complete"
    echo ""
    echo "Recovery: git checkout $backup_branch"
    log_info "safety" "Git reset successful" "Backup: $backup_branch"
    return 0
  else
    error_msg "Git reset failed"
    return "$EXIT_COMMAND_FAILED"
  fi
}

# Export public functions
export -f safe_rm
export -f safe_docker_prune
export -f safe_git_reset

# Mark module as loaded
readonly _HARM_SAFETY_LOADED=1
