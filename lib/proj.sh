#!/usr/bin/env bash
# shellcheck shell=bash
# proj.sh - Project management and switching
# Ported from: ~/.zsh/10_project_management.zsh
#
# Features:
# - Project registry (JSONL format)
# - Quick project switching
# - Project type detection
# - CRUD operations for projects
#
# Public API:
#   proj_list                  - List all registered projects
#   proj_add <path> [name]     - Add project to registry
#   proj_remove <name>         - Remove project from registry
#   proj_switch <name>         - Output cd command for project switching
#
# Dependencies: jq for JSON handling

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_PROJ_LOADED:-}" ]] && return 0

# Source dependencies
PROJ_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly PROJ_SCRIPT_DIR

# shellcheck source=lib/common.sh
source "$PROJ_SCRIPT_DIR/common.sh"
# shellcheck source=lib/error.sh
source "$PROJ_SCRIPT_DIR/error.sh"
# shellcheck source=lib/logging.sh
source "$PROJ_SCRIPT_DIR/logging.sh"
# shellcheck source=lib/util.sh
source "$PROJ_SCRIPT_DIR/util.sh"

# ═══════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════

readonly PROJ_CONFIG_DIR="${HARM_CLI_HOME:-$HOME/.harm-cli}/projects"
readonly PROJ_REGISTRY="$PROJ_CONFIG_DIR/registry.jsonl"

# ═══════════════════════════════════════════════════════════════════
# Project Utilities
# ═══════════════════════════════════════════════════════════════════

# _proj_ensure_config: Ensure project config directory exists
#
# Description:
#   Creates project configuration directory if it doesn't exist.
#   Internal helper function.
#
# Performance:
#   - First call: ~10ms (mkdir)
#   - Subsequent: <1ms (directory exists check)
_proj_ensure_config() {
  if [[ ! -d "$PROJ_CONFIG_DIR" ]]; then
    mkdir -p "$PROJ_CONFIG_DIR" || {
      log_error "proj" "Failed to create config directory" "$PROJ_CONFIG_DIR"
      return "$EXIT_IO_ERROR"
    }
    log_debug "proj" "Created config directory" "$PROJ_CONFIG_DIR"
  fi
  return 0
}

# _proj_detect_type: Detect project type from directory contents
#
# Arguments:
#   $1 - path (string): Project directory path
#
# Returns:
#   0 - Always succeeds
#
# Outputs:
#   stdout: Project type (nodejs, python, rust, go, shell, unknown)
_proj_detect_type() {
  local path="${1:?_proj_detect_type requires path}"

  if [[ -f "$path/package.json" ]]; then
    echo "nodejs"
  elif [[ -f "$path/pyproject.toml" ]] || [[ -f "$path/setup.py" ]]; then
    echo "python"
  elif [[ -f "$path/Cargo.toml" ]]; then
    echo "rust"
  elif [[ -f "$path/go.mod" ]]; then
    echo "go"
  elif [[ -f "$path/Justfile" ]] && [[ -f "$path/.shellspec" ]]; then
    echo "shell"
  else
    echo "unknown"
  fi
}

# _proj_exists: Check if project exists in registry
#
# Arguments:
#   $1 - name (string): Project name
#
# Returns:
#   0 - Project exists
#   1 - Project not found
_proj_exists() {
  local name="${1:?_proj_exists requires name}"

  if [[ ! -f "$PROJ_REGISTRY" ]]; then
    return 1
  fi

  jq -e --arg name "$name" 'select(.name == $name)' "$PROJ_REGISTRY" >/dev/null 2>&1
}

# ═══════════════════════════════════════════════════════════════════
# Project Operations
# ═══════════════════════════════════════════════════════════════════

# proj_list: List all registered projects
#
# Description:
#   Displays all projects in the registry with their paths and types.
#   Supports both text and JSON output formats.
#
# Arguments:
#   None
#
# Returns:
#   0 - Projects listed successfully (even if empty)
#
# Outputs:
#   stdout: Project list (text or JSON format)
#   stderr: Log messages via log_info/log_debug
#
# Examples:
#   proj_list
#   HARM_CLI_FORMAT=json proj_list
#   harm-cli proj list
#
# Notes:
#   - Reads from: ${HARM_CLI_HOME}/projects/registry.jsonl
#   - Returns empty message if no projects registered
#   - JSON format: array of project objects
#   - Text format: formatted table
#
# Performance:
#   - Empty registry: <10ms
#   - 10 projects: <50ms
#   - 100 projects: <200ms
proj_list() {
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

  # Only log in non-JSON mode
  [[ "$format" != "json" ]] && log_info "proj" "Listing projects"

  _proj_ensure_config || return "$EXIT_IO_ERROR"

  # Check if registry exists and has content
  if [[ ! -f "$PROJ_REGISTRY" ]] || [[ ! -s "$PROJ_REGISTRY" ]]; then
    log_debug "proj" "No projects in registry"

    if [[ "$format" == "json" ]]; then
      echo "[]"
    else
      echo "No projects registered"
      echo ""
      echo "Add a project with: harm-cli proj add <path> [name]"
    fi
    return 0
  fi

  # Count projects
  local count
  count=$(wc -l <"$PROJ_REGISTRY" | tr -d ' ')
  log_debug "proj" "Found projects" "Count: $count"

  # Output format
  if [[ "$format" == "json" ]]; then
    jq -s '.' "$PROJ_REGISTRY"
  else
    echo "Projects ($count):"
    echo ""
    jq -r '"\(.name)\t\(.path)\t\(.type)"' "$PROJ_REGISTRY" \
      | while IFS=$'\t' read -r name path type; do
        printf "  %-20s %s (%s)\n" "$name" "$path" "$type"
      done
  fi

  return 0
}

# proj_add: Register a new project
#
# Description:
#   Adds a project to the registry with name, path, and auto-detected type.
#   Validates that path exists and project name is unique.
#
# Arguments:
#   $1 - path (string): Absolute or relative path to project directory
#   $2 - name (string, optional): Project name (default: directory basename)
#
# Returns:
#   0 - Project added successfully
#   EXIT_INVALID_ARGS - Invalid path or duplicate name
#   EXIT_IO_ERROR - Failed to write to registry
#
# Outputs:
#   stdout: Success message with project details
#   stderr: Log messages via log_info/log_error
#
# Examples:
#   proj_add ~/harm-cli
#   proj_add ~/projects/myapp myapp
#   proj_add . current-project
#
# Notes:
#   - Path is converted to absolute path
#   - Path must exist and be a directory
#   - Name must be unique in registry
#   - Type auto-detected from project contents
#   - Registry: JSONL format with atomic writes
#
# Performance:
#   - Typical: 20-50ms
#   - Includes path validation and type detection
proj_add() {
  local path="${1:?proj_add requires path}"
  local name="${2:-}"

  log_info "proj" "Adding project" "Path: $path"

  _proj_ensure_config || return "$EXIT_IO_ERROR"

  # Convert to absolute path
  path=$(cd "$path" && pwd 2>/dev/null) || {
    error_msg "Invalid project path: $path"
    log_error "proj" "Invalid path" "$path"
    return "$EXIT_INVALID_ARGS"
  }

  # Validate path is a directory
  if [[ ! -d "$path" ]]; then
    error_msg "Path is not a directory: $path"
    return "$EXIT_INVALID_ARGS"
  fi

  # Use directory name as default project name
  if [[ -z "$name" ]]; then
    name=$(basename "$path")
  fi

  log_debug "proj" "Project details" "Name: $name, Path: $path"

  # Check if project already exists
  if _proj_exists "$name"; then
    error_msg "Project already exists: $name"
    log_warn "proj" "Duplicate project name" "$name"
    return "$EXIT_INVALID_ARGS"
  fi

  # Detect project type
  local type
  type=$(_proj_detect_type "$path")

  # Create project entry
  local timestamp
  timestamp=$(get_utc_timestamp)

  jq -nc \
    --arg name "$name" \
    --arg path "$path" \
    --arg type "$type" \
    --arg timestamp "$timestamp" \
    '{name: $name, path: $path, type: $type, added: $timestamp}' \
    >>"$PROJ_REGISTRY"

  echo "✓ Project added: $name"
  echo "  Path: $path"
  echo "  Type: $type"

  log_info "proj" "Project added" "Name: $name, Type: $type"
  return 0
}

# proj_remove: Remove project from registry
#
# Description:
#   Removes a project from the registry by name. Does not delete the
#   actual project directory, only removes it from harm-cli's registry.
#
# Arguments:
#   $1 - name (string): Project name to remove
#
# Returns:
#   0 - Project removed successfully
#   EXIT_INVALID_ARGS - Project not found
#   EXIT_IO_ERROR - Failed to update registry
#
# Outputs:
#   stdout: Success message
#   stderr: Log messages via log_info/log_warn
#
# Examples:
#   proj_remove myapp
#   harm-cli proj remove old-project
#
# Notes:
#   - Only removes from registry (directory untouched)
#   - Rewrites registry file without the removed project
#   - Safe: creates temp file first, then replaces atomically
#
# Performance:
#   - Typical: 20-50ms
#   - Uses jq to filter and rewrite registry
proj_remove() {
  local name="${1:?proj_remove requires project name}"

  log_info "proj" "Removing project" "Name: $name"

  _proj_ensure_config || return "$EXIT_IO_ERROR"

  # Check if project exists
  if ! _proj_exists "$name"; then
    error_msg "Project not found: $name"
    log_warn "proj" "Cannot remove non-existent project" "$name"
    return "$EXIT_INVALID_ARGS"
  fi

  # Remove project from registry (filter out matching name)
  local temp_file
  temp_file=$(mktemp)

  jq --arg name "$name" 'select(.name != $name)' "$PROJ_REGISTRY" >"$temp_file"

  if mv "$temp_file" "$PROJ_REGISTRY"; then
    echo "✓ Project removed: $name"
    log_info "proj" "Project removed" "Name: $name"
    return 0
  else
    error_msg "Failed to remove project"
    log_error "proj" "Failed to update registry"
    rm -f "$temp_file"
    return "$EXIT_IO_ERROR"
  fi
}

# proj_switch: Get cd command to switch to project directory
#
# Description:
#   Retrieves the path for a registered project and outputs a cd command.
#   Cannot change directory directly (shell limitation), so outputs command
#   for user to eval or use via shell function wrapper.
#
# Arguments:
#   $1 - name (string): Project name to switch to
#
# Returns:
#   0 - Project found, cd command output
#   EXIT_INVALID_ARGS - Project not found
#
# Outputs:
#   stdout: cd command or project path
#   stderr: Log messages via log_info/log_debug/log_error
#
# Examples:
#   proj_switch harm-cli
#   # Output: cd /Users/harm/harm-cli
#
#   eval "$(proj_switch harm-cli)"  # Actually switch
#
#   # Shell function wrapper (add to ~/.bashrc):
#   proj() { eval "$(harm-cli proj switch "$@")"; }
#
# Notes:
#   - Shell limitation: Cannot change parent process directory
#   - Outputs cd command for user to eval
#   - Validates project exists in registry
#   - Logs the switch operation
#
# Performance:
#   - Typical: <20ms (registry lookup)
#
# Future:
#   - Could activate Python venv
#   - Could source project-specific config
#   - Could start work session automatically
proj_switch() {
  local name="${1:?proj_switch requires project name}"

  log_info "proj" "Switching to project" "Name: $name"

  _proj_ensure_config || return "$EXIT_IO_ERROR"

  # Check if project exists and get path
  local path
  path=$(jq -r --arg name "$name" 'select(.name == $name) | .path' "$PROJ_REGISTRY" 2>/dev/null)

  if [[ -z "$path" ]]; then
    error_msg "Project not found: $name"
    log_error "proj" "Project not found" "Name: $name"
    echo ""
    echo "Available projects:"
    proj_list
    return "$EXIT_INVALID_ARGS"
  fi

  # Verify path still exists
  if [[ ! -d "$path" ]]; then
    error_msg "Project directory no longer exists: $path"
    log_error "proj" "Project path invalid" "Path: $path"
    echo "Consider running: harm-cli proj remove $name"
    return "$EXIT_INVALID_ARGS"
  fi

  # Output cd command with helpful hint
  echo "cd \"$path\""

  # If in TTY, show helpful message about shell function
  if [[ -t 1 ]] && [[ "${HARM_CLI_FORMAT:-text}" == "text" ]]; then
    echo "" >&2
    echo "💡 To automatically switch directories, use the shell function:" >&2
    echo "   eval \"\$(harm-cli proj switch $name)\"" >&2
    echo "" >&2
    echo "Or initialize once to get the 'proj' helper function:" >&2
    echo "   eval \"\$(harm-cli init)\"" >&2
    echo "   proj switch $name  # Will switch automatically!" >&2
  fi

  log_info "proj" "Project switch prepared" "Path: $path"

  return 0
}

# Export public functions
export -f proj_list
export -f proj_add
export -f proj_remove
export -f proj_switch

# Mark module as loaded
readonly _HARM_PROJ_LOADED=1
