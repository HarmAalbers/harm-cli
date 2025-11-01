#!/usr/bin/env bash
# shellcheck shell=bash
# cleanup.sh - Large file discovery and cleanup for harm-cli
#
# This module provides:
# - Discovery of largest files on the system
# - Interactive multi-select interface for marking files
# - Safe deletion with confirmation and audit logging
# - Configurable size thresholds and search paths
#
# Public API:
#   cleanup_scan [--path PATH] [--min-size SIZE] [--max-results N]
#   cleanup_delete <file1> [file2 ...]
#   cleanup_preview <file1> [file2 ...]
#
# Dependencies: find, du, jq, numfmt (optional)

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_CLEANUP_LOADED:-}" ]] && return 0

# Source dependencies
CLEANUP_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CLEANUP_SCRIPT_DIR

# shellcheck source=lib/common.sh
source "$CLEANUP_SCRIPT_DIR/common.sh"
# shellcheck source=lib/error.sh
source "$CLEANUP_SCRIPT_DIR/error.sh"
# shellcheck source=lib/logging.sh
source "$CLEANUP_SCRIPT_DIR/logging.sh"
# shellcheck source=lib/util.sh
source "$CLEANUP_SCRIPT_DIR/util.sh"
# shellcheck source=lib/options.sh
source "$CLEANUP_SCRIPT_DIR/options.sh"
# Note: interactive.sh and safety.sh loaded conditionally when needed

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════

# Default minimum file size (in bytes) - 100MB
readonly CLEANUP_DEFAULT_MIN_SIZE=$((100 * 1024 * 1024))

# Default maximum results to return
readonly CLEANUP_DEFAULT_MAX_RESULTS=50

# Default search path
readonly CLEANUP_DEFAULT_SEARCH_PATH="${HOME}"

# Default exclude patterns
readonly CLEANUP_DEFAULT_EXCLUDES=".git,node_modules,.Trash,.npm,.cache"

# Find command timeout (seconds)
readonly CLEANUP_FIND_TIMEOUT=300

# Cleanup logs directory
readonly CLEANUP_LOG_DIR="${HARM_CLI_HOME:-$HOME/.harm-cli}/logs"
readonly CLEANUP_AUDIT_LOG="${CLEANUP_LOG_DIR}/cleanup_audit.log"

# ═══════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════

# _cleanup_get_min_size: Get configured minimum file size in bytes
#
# Returns:
#   Minimum size in bytes (integer)
_cleanup_get_min_size() {
  local size
  size=$(options_get cleanup_min_size 2>/dev/null || echo "")

  if [[ -z "$size" ]]; then
    echo "$CLEANUP_DEFAULT_MIN_SIZE"
    return 0
  fi

  # Parse size string (e.g., "100M", "1G", "500000")
  _cleanup_parse_size_to_bytes "$size"
}

# _cleanup_get_max_results: Get configured maximum results
#
# Returns:
#   Maximum results (integer)
_cleanup_get_max_results() {
  local max
  max=$(options_get cleanup_max_results 2>/dev/null || echo "")

  if [[ -z "$max" ]]; then
    echo "$CLEANUP_DEFAULT_MAX_RESULTS"
  else
    echo "$max"
  fi
}

# _cleanup_get_search_path: Get configured search path
#
# Returns:
#   Search path (string)
_cleanup_get_search_path() {
  local path
  path=$(options_get cleanup_search_path 2>/dev/null || echo "")

  if [[ -z "$path" ]]; then
    echo "$CLEANUP_DEFAULT_SEARCH_PATH"
  else
    echo "$path"
  fi
}

# _cleanup_get_excludes: Get configured exclude patterns
#
# Returns:
#   Comma-separated exclude patterns
_cleanup_get_excludes() {
  local excludes
  excludes=$(options_get cleanup_exclude_patterns 2>/dev/null || echo "")

  if [[ -z "$excludes" ]]; then
    echo "$CLEANUP_DEFAULT_EXCLUDES"
  else
    echo "$excludes"
  fi
}

# _cleanup_parse_size_to_bytes: Convert human-readable size to bytes
#
# Arguments:
#   $1 - size (string): Size like "100M", "1G", "500K", or "1234567"
#
# Returns:
#   Size in bytes (integer)
#
# Examples:
#   _cleanup_parse_size_to_bytes "100M"  # Returns 104857600
#   _cleanup_parse_size_to_bytes "1G"    # Returns 1073741824
#   _cleanup_parse_size_to_bytes "500K"  # Returns 512000
_cleanup_parse_size_to_bytes() {
  local size="${1:?_cleanup_parse_size_to_bytes requires size}"

  # If already a number, return as-is
  if [[ "$size" =~ ^[0-9]+$ ]]; then
    echo "$size"
    return 0
  fi

  # Parse with suffix
  local number="${size//[^0-9]/}"
  local suffix="${size//[0-9]/}"
  suffix=$(echo "$suffix" | tr '[:lower:]' '[:upper:]')

  case "$suffix" in
    K | KB)
      echo $((number * 1024))
      ;;
    M | MB)
      echo $((number * 1024 * 1024))
      ;;
    G | GB)
      echo $((number * 1024 * 1024 * 1024))
      ;;
    T | TB)
      echo $((number * 1024 * 1024 * 1024 * 1024))
      ;;
    *)
      die "Invalid size format: $size (use 100M, 1G, etc.)" "$EXIT_INVALID_ARGS"
      ;;
  esac
}

# _cleanup_format_size: Convert bytes to human-readable format
#
# Arguments:
#   $1 - bytes (integer): Size in bytes
#
# Returns:
#   Human-readable size (string) like "1.2G", "500M", "50K"
#
# Notes:
#   Tries to use numfmt if available, falls back to bash calculation
_cleanup_format_size() {
  local bytes="${1:?_cleanup_format_size requires bytes}"

  # Try numfmt first (GNU coreutils)
  if command -v numfmt &>/dev/null; then
    numfmt --to=iec-i --suffix=B --format="%.1f" "$bytes" 2>/dev/null && return 0
  fi

  # Fallback to bash calculation
  local -i kb=$((bytes / 1024))
  local -i mb=$((bytes / 1024 / 1024))
  local -i gb=$((bytes / 1024 / 1024 / 1024))

  if ((gb > 0)); then
    printf "%.1fG" "$(echo "scale=1; $bytes / 1024 / 1024 / 1024" | bc 2>/dev/null || echo "$gb")"
  elif ((mb > 0)); then
    printf "%.1fM" "$(echo "scale=1; $bytes / 1024 / 1024" | bc 2>/dev/null || echo "$mb")"
  elif ((kb > 0)); then
    printf "%.1fK" "$(echo "scale=1; $bytes / 1024" | bc 2>/dev/null || echo "$kb")"
  else
    printf "%dB" "$bytes"
  fi
}

# _cleanup_build_excludes: Build find command exclude patterns
#
# Arguments:
#   $1 - excludes (string): Comma-separated exclude patterns
#
# Returns:
#   Find command exclude arguments (string)
_cleanup_build_excludes() {
  local excludes="${1:-}"
  [[ -z "$excludes" ]] && return 0

  local exclude_args=()
  IFS=',' read -ra patterns <<<"$excludes"

  for pattern in "${patterns[@]}"; do
    pattern=$(trim "$pattern")
    [[ -z "$pattern" ]] && continue
    exclude_args+=("-path" "*/${pattern}/*" "-prune" "-o")
  done

  echo "${exclude_args[@]}"
}

# _cleanup_validate_path: Validate search path exists, is accessible, and is safe
#
# SECURITY FIX (HIGH-1): Prevents path traversal attacks by validating paths
# against an allowlist of permitted directories. This prevents users from
# scanning sensitive system directories like /etc, /var, or ~/.ssh
#
# Arguments:
#   $1 - path (string): Path to validate
#
# Returns:
#   0 - Path is valid and within allowed directories
#   EXIT_NOT_FOUND - Path doesn't exist
#   EXIT_PERMISSION - Path is not accessible or outside allowed directories
_cleanup_validate_path() {
  local path="${1:?_cleanup_validate_path requires path}"

  # Resolve symlinks and get absolute canonical path
  local resolved_path
  if command -v realpath >/dev/null 2>&1; then
    resolved_path=$(realpath -e "$path" 2>/dev/null) || {
      error_msg "Invalid or non-existent path: $path" "$EXIT_NOT_FOUND"
      return "$EXIT_NOT_FOUND"
    }
  else
    # Fallback for systems without realpath
    if [[ ! -e "$path" ]]; then
      error_msg "Search path does not exist: $path" "$EXIT_NOT_FOUND"
      return "$EXIT_NOT_FOUND"
    fi
    resolved_path=$(cd "$path" && pwd -P) || {
      error_msg "Cannot resolve path: $path" "$EXIT_NOT_FOUND"
      return "$EXIT_NOT_FOUND"
    }
  fi

  # Define allowed base directories (security allowlist)
  local allowed_paths=(
    "$HOME"
    "/tmp"
    "/var/tmp"
    "$PWD"
  )

  # If CLEANUP_ALLOW_SYSTEM_PATHS is set, allow system directories (opt-in only)
  if [[ "${CLEANUP_ALLOW_SYSTEM_PATHS:-0}" == "1" ]]; then
    allowed_paths+=(
      "/var/log"
      "/var/cache"
    )
  fi

  # Verify resolved path is under an allowed directory
  local allowed=0
  for base in "${allowed_paths[@]}"; do
    # Get canonical path for base directory
    local base_resolved
    if command -v realpath >/dev/null 2>&1; then
      base_resolved=$(realpath -e "$base" 2>/dev/null) || continue
    else
      base_resolved=$(cd "$base" 2>/dev/null && pwd -P) || continue
    fi

    # Check if resolved path is under this base
    if [[ "$resolved_path" == "$base_resolved"* ]]; then
      allowed=1
      break
    fi
  done

  if [[ $allowed -eq 0 ]]; then
    error_msg "Path outside allowed directories: $path" "$EXIT_PERMISSION"
    if declare -F log_warn >/dev/null 2>&1; then
      log_warn "cleanup" "Blocked path traversal attempt" "requested=$path resolved=$resolved_path"
    fi
    return "$EXIT_PERMISSION"
  fi

  # Check read permission
  if [[ ! -r "$resolved_path" ]]; then
    error_msg "Search path is not readable: $path" "$EXIT_PERMISSION"
    return "$EXIT_PERMISSION"
  fi

  return 0
}

# _cleanup_find_files: Execute find command to discover large files
#
# Arguments:
#   $1 - search_path (string): Directory to search
#   $2 - min_size_bytes (integer): Minimum file size in bytes
#   $3 - max_results (integer): Maximum number of results
#   $4 - excludes (string): Comma-separated exclude patterns
#
# Output:
#   TSV format: size_bytes<TAB>human_size<TAB>path
#   One line per file, sorted by size descending
#
# Returns:
#   0 - Success
#   EXIT_ERROR - Find command failed
_cleanup_find_files() {
  local search_path="${1:?_cleanup_find_files requires search_path}"
  local min_size_bytes="${2:?_cleanup_find_files requires min_size_bytes}"
  local max_results="${3:?_cleanup_find_files requires max_results}"
  local excludes="${4:-}"

  log_debug "cleanup" "Finding files" "path=$search_path, min_size=$min_size_bytes, max=$max_results"

  # Build find command with excludes
  local find_cmd=(find "$search_path")

  # Add exclude patterns
  if [[ -n "$excludes" ]]; then
    IFS=',' read -ra patterns <<<"$excludes"
    for pattern in "${patterns[@]}"; do
      pattern=$(trim "$pattern")
      [[ -z "$pattern" ]] && continue
      find_cmd+=(-path "*/${pattern}/*" -prune -o)
    done
  fi

  # Add file tests
  find_cmd+=(-type f -size "+${min_size_bytes}c" -print0)

  log_debug "cleanup" "Executing find" "${find_cmd[*]}"

  # Execute find with timeout
  # Note: find exits with 1 if it encounters permission errors, which is expected
  # when scanning directories. We only treat timeout (124) as fatal error.
  local tmp_file
  tmp_file=$(mktemp)

  log_info "cleanup" "find started" "timeout=${CLEANUP_FIND_TIMEOUT}s, path=$search_path"

  local find_exit_code=0
  timeout "$CLEANUP_FIND_TIMEOUT" "${find_cmd[@]}" 2>/dev/null >"$tmp_file" || find_exit_code=$?

  if ((find_exit_code == 124)); then
    rm -f "$tmp_file"
    log_error "cleanup" "find timeout" "duration=${CLEANUP_FIND_TIMEOUT}s, path=$search_path"
    error_msg "Find operation timed out after ${CLEANUP_FIND_TIMEOUT}s" "$EXIT_TIMEOUT"
    return "$EXIT_TIMEOUT"
  fi

  # Exit codes 0 (success) and 1 (some paths inaccessible) are both acceptable
  if ((find_exit_code > 1)); then
    rm -f "$tmp_file"
    log_warn "cleanup" "Find command failed" "exit_code=$find_exit_code"
    return "$EXIT_ERROR"
  fi

  log_debug "cleanup" "Find command completed" "exit_code=$find_exit_code"

  # Process results: get sizes, format, sort, limit
  local count=0
  while IFS= read -r -d '' filepath; do
    [[ ! -f "$filepath" ]] && continue

    local size_bytes
    if ! size_bytes=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null); then
      log_debug "cleanup" "Failed to stat file" "$filepath"
      continue
    fi

    local human_size
    human_size=$(_cleanup_format_size "$size_bytes")

    echo -e "${size_bytes}\t${human_size}\t${filepath}"

    ((++count))
    if ((count >= max_results * 2)); then
      # Get more than needed so we can sort and take top N
      break
    fi
  done <"$tmp_file" | sort -rn | head -n "$max_results"

  rm -f "$tmp_file"

  log_debug "cleanup" "Found files" "count=$count"
  return 0
}

# _cleanup_audit_log: Log cleanup operation to audit file
#
# Arguments:
#   $1 - operation (string): Operation type (scan, delete)
#   $2 - details (string): Operation details
_cleanup_audit_log() {
  local operation="${1:?_cleanup_audit_log requires operation}"
  local details="${2:-}"

  # Ensure log directory exists
  ensure_dir "$CLEANUP_LOG_DIR"

  # Log to file
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $operation${details:+ | $details}" >>"$CLEANUP_AUDIT_LOG"

  log_info "cleanup" "$operation" "$details"
}

# ═══════════════════════════════════════════════════════════════
# Public API Functions
# ═══════════════════════════════════════════════════════════════

# cleanup_scan: Scan for large files and optionally select for deletion
#
# Usage:
#   cleanup_scan [--path PATH] [--min-size SIZE] [--max-results N]
#
# Options:
#   --path PATH         Search path (default: $HOME)
#   --min-size SIZE     Minimum file size like "100M", "1G" (default: 100M)
#   --max-results N     Maximum results to return (default: 50)
#
# Output:
#   Text format: Table with columns (Size | Path)
#   JSON format: {"files": [{"size_bytes": N, "size_human": "1.2G", "path": "/path"}]}
#
# Returns:
#   0 - Success
#   EXIT_INVALID_ARGS - Invalid arguments
#   EXIT_NOT_FOUND - Search path not found
cleanup_scan() {
  local format="${HARM_CLI_FORMAT:-text}"
  local search_path=""
  local min_size=""
  local max_results=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --path)
        search_path="${2:?--path requires argument}"
        shift 2
        ;;
      --min-size)
        min_size="${2:?--min-size requires argument}"
        shift 2
        ;;
      --max-results)
        max_results="${2:?--max-results requires argument}"
        shift 2
        ;;
      --help | -h)
        cat <<EOF
Usage: harm-cli cleanup scan [OPTIONS]

Scan for large files on the system.

Options:
  --path PATH           Search path (default: \$HOME)
  --min-size SIZE       Minimum file size like "100M", "1G" (default: 100M)
  --max-results N       Maximum results to return (default: 50)
  --format json         Output JSON format

Examples:
  harm-cli cleanup scan
  harm-cli cleanup scan --path /var/log --min-size 500M
  harm-cli cleanup scan --format json | jq '.files[].path'
EOF
        return 0
        ;;
      *)
        die "Unknown option: $1" "$EXIT_INVALID_ARGS"
        ;;
    esac
  done

  # Apply defaults
  [[ -z "$search_path" ]] && search_path=$(_cleanup_get_search_path)
  [[ -z "$min_size" ]] && min_size=$(_cleanup_get_min_size)
  [[ -z "$max_results" ]] && max_results=$(_cleanup_get_max_results)

  # Convert min_size to bytes if it's not already
  if [[ ! "$min_size" =~ ^[0-9]+$ ]]; then
    min_size=$(_cleanup_parse_size_to_bytes "$min_size")
  fi

  # Validate path
  _cleanup_validate_path "$search_path" || return $?

  # Log scan operation entry
  log_info "cleanup" "scan started" "path=$search_path, min_size=$(_cleanup_format_size "$min_size"), max=$max_results"

  # Log scan operation
  _cleanup_audit_log "scan" "path=$search_path, min_size=$min_size, max=$max_results"

  # Find files
  local results
  results=$(_cleanup_find_files "$search_path" "$min_size" "$max_results" "$(_cleanup_get_excludes)")

  if [[ -z "$results" ]]; then
    log_info "cleanup" "scan complete" "files_found=0, criteria_matched=false"
    if [[ "$format" == "json" ]]; then
      jq -n '{files: [], message: "No large files found"}'
    else
      echo "No large files found matching criteria."
      echo "  Search path: $search_path"
      echo "  Minimum size: $(_cleanup_format_size "$min_size")"
    fi
    return 0
  fi

  # Count results and calculate total size
  local file_count=0
  local total_size=0
  while IFS=$'\t' read -r size_bytes human_size filepath; do
    file_count=$((file_count + 1))
    total_size=$((total_size + size_bytes))
  done <<<"$results"

  # Log scan completion with results
  log_info "cleanup" "scan complete" "files_found=$file_count, total_size=$total_size"

  # Output results
  if [[ "$format" == "json" ]]; then
    # JSON output
    echo "$results" | {
      echo '{"files":['
      local first=1
      while IFS=$'\t' read -r size_bytes human_size filepath; do
        [[ $first -eq 0 ]] && echo ","
        jq -n \
          --arg sb "$size_bytes" \
          --arg hs "$human_size" \
          --arg fp "$filepath" \
          '{size_bytes: ($sb | tonumber), size_human: $hs, path: $fp}'
        first=0
      done
      echo '],'
      echo "\"total_files\": $file_count"
      echo '}'
    }
  else
    # Text output
    echo ""
    echo "Found $file_count large files (minimum size: $(_cleanup_format_size "$min_size")):"
    echo ""
    printf "%-12s  %s\n" "SIZE" "PATH"
    printf "%-12s  %s\n" "────────────" "────────────────────────────────────────────"

    echo "$results" | while IFS=$'\t' read -r size_bytes human_size filepath; do
      printf "%-12s  %s\n" "$human_size" "$filepath"
    done

    echo ""

    # Interactive mode: offer to select files for deletion
    if [[ -t 0 ]] && [[ -t 1 ]]; then
      echo "To delete files, select them interactively:"
      echo "  harm-cli cleanup delete --interactive"
      echo ""
      echo "Or delete specific files:"
      echo "  harm-cli cleanup delete <file1> [file2 ...]"
    fi
  fi

  return 0
}

# cleanup_preview: Preview file deletion without actually deleting
#
# Usage:
#   cleanup_preview <file1> [file2 ...]
#
# Arguments:
#   file1, file2, ... - Files to preview
#
# Output:
#   Text: Table showing files and total size
#   JSON: {"files": [...], "total_size_bytes": N, "total_size_human": "1.2G"}
#
# Returns:
#   0 - Success
#   EXIT_INVALID_ARGS - No files provided
cleanup_preview() {
  local format="${HARM_CLI_FORMAT:-text}"

  if [[ $# -eq 0 ]]; then
    die "cleanup_preview requires at least one file" "$EXIT_INVALID_ARGS"
  fi

  log_debug "cleanup" "preview requested" "file_count=$#"

  local total_bytes=0
  local file_count=0
  local files_data=()

  # Collect file information
  for filepath in "$@"; do
    if [[ ! -f "$filepath" ]]; then
      warn_msg "File not found: $filepath"
      continue
    fi

    local size_bytes
    if ! size_bytes=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null); then
      warn_msg "Cannot stat file: $filepath"
      continue
    fi

    local human_size
    human_size=$(_cleanup_format_size "$size_bytes")

    files_data+=("${size_bytes}|${human_size}|${filepath}")
    total_bytes=$((total_bytes + size_bytes))
    file_count=$((file_count + 1))
  done

  if ((file_count == 0)); then
    error_msg "No valid files to preview" "$EXIT_NOT_FOUND"
    return "$EXIT_NOT_FOUND"
  fi

  local total_human
  total_human=$(_cleanup_format_size "$total_bytes")

  # Output
  if [[ "$format" == "json" ]]; then
    echo '{"files":['
    local first=1
    for data in "${files_data[@]}"; do
      IFS='|' read -r size_bytes human_size filepath <<<"$data"
      [[ $first -eq 0 ]] && echo ","
      jq -n \
        --arg sb "$size_bytes" \
        --arg hs "$human_size" \
        --arg fp "$filepath" \
        '{size_bytes: ($sb | tonumber), size_human: $hs, path: $fp}'
      first=0
    done
    echo ']'
    echo ','
    printf '"total_size_bytes": %s, "total_size_human": "%s", "file_count": %s\n' "$total_bytes" "$total_human" "$file_count"
    echo '}'
  else
    echo ""
    echo "Files to delete ($file_count files, $total_human total):"
    echo ""
    printf "%-12s  %s\n" "SIZE" "PATH"
    printf "%-12s  %s\n" "────────────" "────────────────────────────────────────────"

    for data in "${files_data[@]}"; do
      IFS='|' read -r size_bytes human_size filepath <<<"$data"
      printf "%-12s  %s\n" "$human_size" "$filepath"
    done

    echo ""
    echo "Total space to be freed: $total_human"
    echo ""
  fi

  return 0
}

# _cleanup_select_files_fzf: Interactive file selection using fzf
#
# Arguments:
#   $1 - results (TSV format from _cleanup_find_files)
#
# Returns:
#   0 - Success
#   EXIT_CANCELLED - User cancelled
_cleanup_select_files_fzf() {
  local results="${1:?_cleanup_select_files_fzf requires results}"

  # Build arrays
  local -a file_options=()
  local -a file_paths=()

  while IFS=$'\t' read -r size_bytes human_size filepath; do
    # Format: "SIZE | PATH"
    file_options+=("${human_size}|${filepath}")
    file_paths+=("${filepath}")
  done <<<"$results"

  echo "🎯 Use Tab to select/deselect, Enter to confirm, Esc to cancel"
  echo ""

  # Use fzf with multi-select
  local selected
  # SECURITY FIX (CRITICAL-2): Prevent command injection in fzf preview
  # Use xargs -I @ to safely substitute filepath, preventing shell metacharacter injection
  # The @ placeholder ensures filepath is treated as single argument, not interpreted
  selected=$(printf '%s\n' "${file_options[@]}" | fzf \
    --multi \
    --cycle \
    --height=80% \
    --border=rounded \
    --prompt="Select files to delete > " \
    --header="Tab: select | Enter: confirm | Esc: cancel" \
    --preview='echo {} | cut -d"|" -f2 | xargs -I @ sh -c "[ -f \"@\" ] && ls -lh \"@\" 2>/dev/null || echo \"File not found\""' \
    --preview-window=right:40%:wrap \
    --bind='ctrl-a:select-all,ctrl-d:deselect-all' \
    --color='fg:#d0d0d0,bg:#121212,hl:#5f87af' \
    --color='fg+:#d0d0d0,bg+:#262626,hl+:#5fd7ff' \
    --color='info:#afaf87,prompt:#d7005f,pointer:#af5fff' \
    --color='marker:#87ff00,spinner:#af5fff,header:#87afaf')

  local fzf_exit=$?

  # Check if user cancelled (ESC or Ctrl-C)
  if ((fzf_exit != 0)); then
    echo ""
    echo "Cancelled - no files deleted"
    return "$EXIT_CANCELLED"
  fi

  # Check if any files selected
  if [[ -z "$selected" ]]; then
    echo ""
    echo "No files selected - nothing to delete"
    return 0
  fi

  # Extract file paths from selected items
  local -a files_to_delete=()
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # Extract path (after the | separator)
    local filepath
    filepath=$(echo "$line" | cut -d'|' -f2)
    files_to_delete+=("$filepath")
  done <<<"$selected"

  if ((${#files_to_delete[@]} == 0)); then
    echo ""
    echo "No files selected - nothing to delete"
    return 0
  fi

  # Call cleanup_delete with selected files
  echo ""
  cleanup_delete "${files_to_delete[@]}"
  return $?
}

# _cleanup_select_files_fallback: Simple bash select fallback for file selection
#
# Arguments:
#   $1 - results (TSV format from _cleanup_find_files)
#
# Returns:
#   0 - Success
#   EXIT_CANCELLED - User cancelled
_cleanup_select_files_fallback() {
  local results="${1:?_cleanup_select_files_fallback requires results}"

  # Build arrays
  local -a file_options=()
  local -a file_paths=()
  local -a file_sizes=()

  while IFS=$'\t' read -r size_bytes human_size filepath; do
    file_options+=("${human_size} - ${filepath}")
    file_paths+=("${filepath}")
    file_sizes+=("${human_size}")
  done <<<"$results"

  echo "Select files to delete (enter numbers separated by spaces, or 'q' to quit):"
  echo ""

  # Display options with numbers
  local i=1
  for option in "${file_options[@]}"; do
    printf "%2d) %s\n" "$i" "$option"
    ((++i))
  done

  echo ""
  echo "Enter selection (e.g., '1 3 5' or 'all' or 'q' to quit): "

  local selection
  read -r selection

  # Handle quit
  if [[ "$selection" == "q" ]] || [[ "$selection" == "quit" ]]; then
    echo ""
    echo "Cancelled - no files deleted"
    return "$EXIT_CANCELLED"
  fi

  # Handle empty selection
  if [[ -z "$selection" ]]; then
    echo ""
    echo "No files selected - nothing to delete"
    return 0
  fi

  # Build list of files to delete
  local -a files_to_delete=()

  if [[ "$selection" == "all" ]]; then
    files_to_delete=("${file_paths[@]}")
  else
    # Parse space-separated numbers
    for num in $selection; do
      # Validate it's a number
      if [[ ! "$num" =~ ^[0-9]+$ ]]; then
        warn_msg "Invalid selection: $num (not a number)"
        continue
      fi

      # Check bounds (1-indexed)
      if ((num < 1 || num > ${#file_paths[@]})); then
        warn_msg "Invalid selection: $num (out of range 1-${#file_paths[@]})"
        continue
      fi

      # Add to deletion list (convert to 0-indexed)
      files_to_delete+=("${file_paths[$((num - 1))]}")
    done
  fi

  if ((${#files_to_delete[@]} == 0)); then
    echo ""
    echo "No valid files selected - nothing to delete"
    return 0
  fi

  # Call cleanup_delete with selected files
  echo ""
  cleanup_delete "${files_to_delete[@]}"
  return $?
}

# _cleanup_delete_interactive: Interactive file selection and deletion
#
# Arguments:
#   Same as cleanup_scan (--path, --min-size, --max-results)
#
# Returns:
#   0 - Success
#   EXIT_CANCELLED - User cancelled
#   EXIT_ERROR - Deletion failed
_cleanup_delete_interactive() {
  local search_path=""
  local min_size=""
  local max_results=""

  # Parse arguments (same as scan)
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --path)
        search_path="${2:?--path requires argument}"
        shift 2
        ;;
      --min-size)
        min_size="${2:?--min-size requires argument}"
        shift 2
        ;;
      --max-results)
        max_results="${2:?--max-results requires argument}"
        shift 2
        ;;
      *)
        die "Unknown option: $1" "$EXIT_INVALID_ARGS"
        ;;
    esac
  done

  # Apply defaults
  [[ -z "$search_path" ]] && search_path=$(_cleanup_get_search_path)
  [[ -z "$min_size" ]] && min_size=$(_cleanup_get_min_size)
  [[ -z "$max_results" ]] && max_results=$(_cleanup_get_max_results)

  # Convert min_size to bytes if needed
  if [[ ! "$min_size" =~ ^[0-9]+$ ]]; then
    min_size=$(_cleanup_parse_size_to_bytes "$min_size")
  fi

  # Validate path
  _cleanup_validate_path "$search_path" || return $?

  # Check if we're in a TTY
  if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
    die "Interactive mode requires a TTY (terminal)" "$EXIT_ERROR"
  fi

  echo ""
  echo "🔍 Scanning for large files..."
  echo "  Path: $search_path"
  echo "  Min size: $(_cleanup_format_size "$min_size")"
  echo ""

  # Find files
  local results
  results=$(_cleanup_find_files "$search_path" "$min_size" "$max_results" "$(_cleanup_get_excludes)")

  if [[ -z "$results" ]]; then
    echo "No large files found matching criteria."
    return 0
  fi

  # Count and display results
  local file_count
  file_count=$(echo "$results" | wc -l | tr -d ' ')

  echo "Found $file_count large files"
  echo ""

  # Use fzf directly for best interactive experience
  if command -v fzf &>/dev/null; then
    _cleanup_select_files_fzf "$results"
    return $?
  else
    # Fallback to simple bash select if fzf not available
    log_debug "cleanup" "fzf not found, using bash select fallback"
    _cleanup_select_files_fallback "$results"
    return $?
  fi
}

# cleanup_delete: Delete files with confirmation
#
# Usage:
#   cleanup_delete <file1> [file2 ...]
#   cleanup_delete --interactive [OPTIONS]
#
# Arguments:
#   file1, file2, ... - Files to delete
#   --interactive     - Scan and interactively select files to delete
#
# Options for --interactive mode:
#   --path PATH       - Search path (default: $HOME)
#   --min-size SIZE   - Minimum file size (default: 100M)
#   --max-results N   - Maximum results (default: 50)
#
# Output:
#   Text: Deletion summary
#   JSON: {"deleted": [...], "failed": [...], "total_freed_bytes": N}
#
# Returns:
#   0 - Success (all files deleted)
#   EXIT_INVALID_ARGS - No files provided
#   EXIT_CANCELLED - User cancelled
#   EXIT_ERROR - Some deletions failed
cleanup_delete() {
  local format="${HARM_CLI_FORMAT:-text}"

  # Handle interactive mode
  if [[ "${1:-}" == "--interactive" ]]; then
    shift
    _cleanup_delete_interactive "$@"
    return $?
  fi

  if [[ $# -eq 0 ]]; then
    die "cleanup_delete requires at least one file" "$EXIT_INVALID_ARGS"
  fi

  log_info "cleanup" "delete initiated" "file_count=$#, interactive=no"

  # Show preview
  if [[ "$format" != "json" ]]; then
    cleanup_preview "$@"
  fi

  # Get confirmation
  if [[ -t 0 ]]; then
    echo "⚠️  DANGEROUS OPERATION: Delete files"
    echo ""
    echo "Type 'delete' to confirm: "

    log_warn "cleanup" "delete confirmation requested" "file_count=$#"

    local response
    if ! read -r -t 30 response; then
      echo ""
      echo "Timeout - operation cancelled for safety"
      log_error "cleanup" "delete confirmation timeout" "safety_abort=true"
      return "$EXIT_CANCELLED"
    fi

    if [[ "$response" != "delete" ]]; then
      echo "Cancelled (incorrect confirmation)"
      return "$EXIT_CANCELLED"
    fi
  fi

  # Delete files
  local deleted_files=()
  local failed_files=()
  local total_freed=0

  for filepath in "$@"; do
    if [[ ! -f "$filepath" ]]; then
      warn_msg "File not found: $filepath"
      failed_files+=("$filepath")
      continue
    fi

    local size_bytes
    size_bytes=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null || echo "0")

    if rm -f "$filepath" 2>/dev/null; then
      deleted_files+=("$filepath")
      total_freed=$((total_freed + size_bytes))
      _cleanup_audit_log "delete" "file=$filepath, size=$size_bytes"
      log_info "cleanup" "Deleted file" "$filepath ($(_cleanup_format_size "$size_bytes"))"
    else
      failed_files+=("$filepath")
      log_error "cleanup" "delete failed" "file=$filepath"
      warn_msg "Failed to delete: $filepath"
    fi
  done

  # Log completion summary
  log_info "cleanup" "delete complete" "deleted=${#deleted_files[@]}, failed=${#failed_files[@]}, freed=$total_freed"

  # Output results
  if [[ "$format" == "json" ]]; then
    jq -n \
      --argjson deleted "$(printf '%s\n' "${deleted_files[@]}" | jq -R . | jq -s .)" \
      --argjson failed "$(printf '%s\n' "${failed_files[@]}" | jq -R . | jq -s .)" \
      --arg freed "$total_freed" \
      '{deleted: $deleted, failed: $failed, total_freed_bytes: ($freed | tonumber)}'
  else
    echo ""
    echo "✓ Deleted ${#deleted_files[@]} files (freed $(_cleanup_format_size "$total_freed"))"

    if ((${#failed_files[@]} > 0)); then
      echo "✗ Failed to delete ${#failed_files[@]} files"
    fi
  fi

  if ((${#failed_files[@]} > 0)); then
    return "$EXIT_ERROR"
  fi

  return 0
}

# Mark as loaded
readonly _HARM_CLEANUP_LOADED=1
