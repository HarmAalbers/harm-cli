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
  log_debug "safety" "safe_rm called" "Args: $*"

  if [[ $# -eq 0 ]]; then
    log_error "safety" "safe_rm called with no arguments"
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
      log_warn "safety" "Dangerous deletion flags detected" "Arg: $arg"
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

  # Always require confirmation - this is a safety wrapper
  echo ""
  if [[ $is_dangerous -eq 1 ]]; then
    echo "⚠️  WARNING: Recursive or force deletion detected"
  fi
  echo "Total: $count item(s)"
  _safety_confirm "Delete $count items" "delete" || return 130

  # Perform deletion
  _safety_log "rm" "Args: $*, Count: $count"

  if rm "$@"; then
    echo "✓ Deleted $count items"
    log_info "safety" "Files deleted" "Count: $count"
    return 0
  else
    error_msg "Deletion failed"
    return "$EXIT_ERROR"
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
    log_error "safety" "Docker command not found"
    error_msg "Docker not installed"
    return "$EXIT_MISSING_DEPS"
  fi

  if ! docker info >/dev/null 2>&1; then
    log_error "safety" "Docker daemon not running"
    error_msg "Docker daemon not running"
    return "$EXIT_INVALID_STATE"
  fi

  echo "🐳 Docker Cleanup Assistant"
  echo "══════════════════════════════════════════"
  echo ""

  # Quick analysis mode by default
  local quick_mode=1
  local ai_analysis=0

  # Parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --detailed | -d)
        quick_mode=0
        shift
        ;;
      --ai | -a)
        ai_analysis=1
        shift
        ;;
      *)
        break
        ;;
    esac
  done

  # Cache file for docker system df (5 min TTL)
  local cache_file="/tmp/.docker_df_cache"
  local cache_ttl=300 # 5 minutes
  local use_cache=0

  # Check if cache exists and is fresh
  if [[ -f "$cache_file" ]]; then
    local cache_age=$(($(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
    if [[ $cache_age -lt $cache_ttl ]]; then
      use_cache=1
      echo "📊 Using cached analysis (${cache_age}s old)"
    fi
  fi

  # Gather information efficiently
  echo "Analyzing Docker resources..."
  echo ""

  # Get detailed information about what can be pruned
  local stopped_containers dangling_images unused_volumes build_cache

  if [[ $use_cache -eq 1 ]] && [[ -f "${cache_file}.details" ]]; then
    source "${cache_file}.details"
  else
    # Count resources that would be removed
    stopped_containers=$(docker ps -aq -f status=exited -f status=dead 2>/dev/null | wc -l | tr -d ' ')
    dangling_images=$(docker images -q -f dangling=true 2>/dev/null | wc -l | tr -d ' ')
    unused_volumes=$(docker volume ls -q -f dangling=true 2>/dev/null | wc -l | tr -d ' ')

    # Save to cache
    cat >"${cache_file}.details" <<EOF
stopped_containers=$stopped_containers
dangling_images=$dangling_images
unused_volumes=$unused_volumes
EOF
  fi

  # Display analysis
  echo "📋 Cleanup Candidates:"
  echo "──────────────────────"

  local has_cleanup=0

  if [[ $stopped_containers -gt 0 ]]; then
    echo "  🔸 Stopped containers: $stopped_containers"
    has_cleanup=1
  fi

  if [[ $dangling_images -gt 0 ]]; then
    echo "  🔸 Dangling images: $dangling_images"
    has_cleanup=1
  fi

  if [[ $unused_volumes -gt 0 ]]; then
    echo "  🔸 Unused volumes: $unused_volumes"
    has_cleanup=1
  fi

  if [[ $has_cleanup -eq 0 ]]; then
    echo "  ✓ System is already clean!"
    return 0
  fi

  echo ""

  # Show space usage if requested
  if [[ $quick_mode -eq 0 ]]; then
    echo "💾 Space Analysis:"
    echo "──────────────────────"

    if [[ $use_cache -eq 1 ]] && [[ -f "$cache_file" ]]; then
      cat "$cache_file"
    else
      docker system df 2>/dev/null | tee "$cache_file"
    fi
    echo ""
  fi

  # AI Safety Analysis if requested
  if [[ $ai_analysis -eq 1 ]] && command -v ai_query >/dev/null 2>&1; then
    echo "🤖 AI Safety Analysis:"
    echo "──────────────────────"

    local ai_prompt="I have $stopped_containers stopped containers, $dangling_images dangling images, and $unused_volumes unused volumes in Docker. "
    ai_prompt+="Is it safe to remove these? What should I be careful about? Keep response brief (2-3 lines)."

    local ai_response
    if ai_response=$(ai_query "$ai_prompt" 2>/dev/null); then
      echo "$ai_response" | fold -s -w 70 | sed 's/^/  /'
    else
      echo "  (AI analysis unavailable)"
    fi
    echo ""
  fi

  # Provide selective cleanup options
  echo "🛠  Cleanup Options:"
  echo "──────────────────────"
  echo "  1) Remove all (containers, images, volumes, build cache)"
  echo "  2) Remove stopped containers only"
  echo "  3) Remove dangling images only"
  echo "  4) Remove unused volumes only"
  echo "  5) Custom docker prune command"
  echo "  6) Cancel"
  echo ""

  local choice
  read -r -p "Select option [1-6]: " choice

  case "$choice" in
    1)
      echo ""
      _safety_confirm "Remove ALL unused Docker resources" "prune-all" || return 130
      _safety_log "docker system prune --all" "Full cleanup"

      echo "Cleaning all resources..."
      docker system prune -af --volumes
      echo "✓ All unused resources removed"
      ;;
    2)
      echo ""
      _safety_confirm "Remove stopped containers" "prune-containers" || return 130
      _safety_log "docker container prune" "Container cleanup"

      echo "Removing stopped containers..."
      docker container prune -f
      echo "✓ Stopped containers removed"
      ;;
    3)
      echo ""
      _safety_confirm "Remove dangling images" "prune-images" || return 130
      _safety_log "docker image prune" "Image cleanup"

      echo "Removing dangling images..."
      docker image prune -f
      echo "✓ Dangling images removed"
      ;;
    4)
      echo ""
      _safety_confirm "Remove unused volumes" "prune-volumes" || return 130
      _safety_log "docker volume prune" "Volume cleanup"

      echo "Removing unused volumes..."
      docker volume prune -f
      echo "✓ Unused volumes removed"
      ;;
    5)
      echo ""
      echo "Enter custom docker prune command:"
      local custom_cmd
      read -r -p "> docker " custom_cmd

      _safety_confirm "Run: docker $custom_cmd" "custom-prune" || return 130
      _safety_log "docker $custom_cmd" "Custom cleanup"

      echo "Executing custom command..."
      eval "docker $custom_cmd"
      ;;
    6)
      echo "Cleanup cancelled"
      return 130
      ;;
    *)
      echo "Invalid option"
      return 1
      ;;
  esac

  # Clear cache after cleanup
  rm -f "$cache_file" "${cache_file}.details"

  log_info "safety" "Docker cleanup completed" "Choice: $choice"
  return 0
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
  local ref="${1:-}"

  # If no ref specified, try to auto-detect default branch
  if [[ -z "$ref" ]]; then
    # Try origin/main first, then origin/master
    if git rev-parse --verify origin/main >/dev/null 2>&1; then
      ref="origin/main"
    elif git rev-parse --verify origin/master >/dev/null 2>&1; then
      ref="origin/master"
    else
      error_msg "No reference specified and no origin/main or origin/master found"
      echo "Usage: safe_git_reset [ref]"
      echo "Examples:"
      echo "  safe_git_reset origin/main"
      echo "  safe_git_reset HEAD~1"
      return "$EXIT_INVALID_ARGS"
    fi
  fi

  log_info "safety" "Git reset requested" "Ref: $ref"

  # Check if in git repo
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    log_error "safety" "Not in a git repository"
    error_msg "Not in a git repository"
    return "$EXIT_INVALID_STATE"
  fi

  # Verify the ref exists
  if ! git rev-parse --verify "$ref" >/dev/null 2>&1; then
    log_error "safety" "Invalid git reference" "Ref: $ref"
    error_msg "Invalid git reference: $ref"
    echo "The specified ref '$ref' does not exist"
    return "$EXIT_INVALID_ARGS"
  fi

  # Get current branch
  local current_branch
  current_branch=$(git branch --show-current)

  if [[ -z "$current_branch" ]]; then
    error_msg "Not on a branch (detached HEAD state)"
    echo "Cannot reset in detached HEAD state"
    return "$EXIT_INVALID_STATE"
  fi

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
    while IFS= read -r line; do
      echo "     $line"
    done <<<"$lost_commits"
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
    while IFS= read -r file; do
      echo "       - $file"
    done <<<"$staged_files"
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
    while IFS= read -r file; do
      echo "       - $file"
    done <<<"$working_files"
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
    log_info "safety" "Backup branch created" "Branch: $backup_branch"
  else
    log_error "safety" "Failed to create backup branch" "Branch: $backup_branch"
    error_msg "Failed to create backup branch"
    return "$EXIT_ERROR"
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
    return "$EXIT_ERROR"
  fi
}

# Export public functions
export -f safe_rm
export -f safe_docker_prune
export -f safe_git_reset

# Export internal functions for testing
export -f _safety_confirm
export -f _safety_log

# Mark module as loaded
readonly _HARM_SAFETY_LOADED=1
