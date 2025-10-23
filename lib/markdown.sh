#!/usr/bin/env bash
# shellcheck shell=bash
# markdown.sh - Markdown rendering utilities for harm-cli
#
# Provides intelligent markdown rendering with tiered fallback:
#   1. glow (primary) - Beautiful rendering with TUI
#   2. bat (secondary) - Syntax-highlighted source view
#   3. rich-cli (optional) - Python-based rendering
#   4. cat (fallback) - Plain text output
#
# Public API:
#   render_markdown <file> [options]     - Render markdown file
#   render_markdown_pipe [options]       - Render from stdin
#   markdown_tui [directory]             - Interactive markdown browser (glow only)
#   detect_markdown_tool                 - Get best available tool
#   suggest_markdown_tools               - Show installation suggestions
#
# Dependencies: None required (glow/bat recommended)

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_MARKDOWN_LOADED:-}" ]] && return 0

# Source dependencies
MARKDOWN_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly MARKDOWN_SCRIPT_DIR

# shellcheck source=lib/common.sh
source "$MARKDOWN_SCRIPT_DIR/common.sh"
# shellcheck source=lib/error.sh
source "$MARKDOWN_SCRIPT_DIR/error.sh"
# shellcheck source=lib/logging.sh
source "$MARKDOWN_SCRIPT_DIR/logging.sh"

# ═══════════════════════════════════════════════════════════════
# Terminal Capability Detection
# ═══════════════════════════════════════════════════════════════

# detect_color_support: Detect terminal color capabilities
#
# Returns:
#   0 - Truecolor (24-bit) supported
#   1 - 256-color supported
#   2 - 8-color supported
#   3 - No color support
detect_color_support() {
  local colors
  colors=$(tput colors 2>/dev/null || echo 0)

  # Check for truecolor
  if [[ "${COLORTERM:-}" =~ ^(truecolor|24bit)$ ]]; then
    return 0
  # Check for 256-color
  elif ((colors >= 256)); then
    return 1
  # Check for 8-color
  elif ((colors >= 8)); then
    return 2
  else
    return 3
  fi
}

# get_color_level: Get color support level as string
#
# Outputs:
#   stdout: truecolor|256color|8color|nocolor
get_color_level() {
  if detect_color_support; then
    echo "truecolor"
  else
    case $? in
      1) echo "256color" ;;
      2) echo "8color" ;;
      3) echo "nocolor" ;;
    esac
  fi
}

# ═══════════════════════════════════════════════════════════════
# Tool Detection
# ═══════════════════════════════════════════════════════════════

# has_glow: Check if glow is available
has_glow() {
  command -v glow >/dev/null 2>&1
}

# has_bat: Check if bat is available
has_bat() {
  command -v bat >/dev/null 2>&1 || command -v batcat >/dev/null 2>&1
}

# get_bat_command: Get the correct bat command (bat or batcat)
#
# Outputs:
#   stdout: bat|batcat
#
# Returns:
#   0 - bat found
#   1 - bat not found
get_bat_command() {
  if command -v bat >/dev/null 2>&1; then
    echo "bat"
  elif command -v batcat >/dev/null 2>&1; then
    echo "batcat"
  else
    return 1
  fi
}

# has_rich: Check if rich-cli is available
has_rich() {
  command -v rich >/dev/null 2>&1
}

# detect_markdown_tool: Detect best available markdown renderer
#
# Outputs:
#   stdout: glow|bat|rich|cat
detect_markdown_tool() {
  if has_glow; then
    echo "glow"
  elif has_bat; then
    echo "bat"
  elif has_rich; then
    echo "rich"
  else
    echo "cat"
  fi
}

# ═══════════════════════════════════════════════════════════════
# Rendering Functions
# ═══════════════════════════════════════════════════════════════

# render_markdown: Render markdown file with best available tool
#
# Arguments:
#   $1 - file (string): Path to markdown file
#   Optional flags:
#     --width WIDTH     Set output width (default: auto, max 120)
#     --style STYLE     Set glow style (auto|dark|light)
#     --pager           Use pager for output
#     --no-color        Disable colors
#     --tool TOOL       Force specific tool (glow|bat|rich|cat)
#
# Returns:
#   0 - Success
#   EXIT_INVALID_ARGS - Missing file or invalid arguments
#   EXIT_IO_ERROR - File not found
#
# Outputs:
#   stdout: Rendered markdown
#   stderr: Error messages
#
# Examples:
#   render_markdown README.md
#   render_markdown docs/guide.md --width 100 --pager
#   render_markdown file.md --tool glow --style dark
render_markdown() {
  local file=""
  local width=""
  local style="auto"
  local use_pager=false
  local no_color=false
  local force_tool=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --width)
        width="${2:?--width requires a value}"
        shift 2
        ;;
      --style)
        style="${2:?--style requires a value}"
        shift 2
        ;;
      --pager)
        use_pager=true
        shift
        ;;
      --no-color)
        no_color=true
        shift
        ;;
      --tool)
        force_tool="${2:?--tool requires a value}"
        shift 2
        ;;
      -*)
        die "Unknown option: $1" "$EXIT_INVALID_ARGS"
        ;;
      *)
        file="$1"
        shift
        ;;
    esac
  done

  # Validate file
  if [[ -z "$file" ]]; then
    echo "Error: render_markdown requires a file path" >&2
    return 1
  fi

  if [[ ! -f "$file" ]]; then
    echo "Error: File not found: $file" >&2
    return 1
  fi

  # Determine tool to use
  local tool="${force_tool:-$(detect_markdown_tool)}"

  # Set default width if not specified
  if [[ -z "$width" ]]; then
    width=$(tput cols 2>/dev/null || echo 120)
    # Cap at 120 for readability
    ((width > 120)) && width=120
  fi

  # Render based on tool
  case "$tool" in
    glow)
      _render_with_glow "$file" "$width" "$style" "$use_pager" "$no_color"
      ;;
    bat)
      _render_with_bat "$file" "$use_pager" "$no_color"
      ;;
    rich)
      _render_with_rich "$file" "$width" "$use_pager" "$no_color"
      ;;
    cat)
      cat "$file"
      ;;
    *)
      die "Unknown rendering tool: $tool" "$EXIT_INVALID_ARGS"
      ;;
  esac
}

# _render_with_glow: Internal - render with glow
_render_with_glow() {
  local file="$1"
  local width="$2"
  local style="$3"
  local use_pager="$4"
  local no_color="$5"

  local args=(
    "--style" "$style"
    "--width" "$width"
  )

  if [[ "$use_pager" == true ]]; then
    args+=("--pager")
  fi

  if [[ "$no_color" == true ]]; then
    # glow respects NO_COLOR env var
    NO_COLOR=1 glow "${args[@]}" "$file"
  else
    glow "${args[@]}" "$file"
  fi
}

# _render_with_bat: Internal - render with bat
_render_with_bat() {
  local file="$1"
  local use_pager="$2"
  local no_color="$3"

  local bat_cmd
  bat_cmd="$(get_bat_command)"

  local args=(
    "--style=grid,numbers"
    "--language=markdown"
    "--color=always"
  )

  if [[ "$use_pager" == false ]]; then
    args+=("--paging=never")
  fi

  if [[ "$no_color" == true ]]; then
    args=("--plain" "--language=markdown")
  fi

  "$bat_cmd" "${args[@]}" "$file"
}

# _render_with_rich: Internal - render with rich-cli
_render_with_rich() {
  local file="$1"
  local width="$2"
  local use_pager="$3"
  local no_color="$4"

  local args=(
    "--markdown"
  )

  if [[ -n "$width" ]]; then
    args+=("--width" "$width")
  fi

  if [[ "$no_color" == true ]]; then
    NO_COLOR=1 rich "${args[@]}" "$file"
  else
    rich "${args[@]}" "$file"
  fi

  # rich doesn't have built-in pager, use less if requested
  if [[ "$use_pager" == true ]]; then
    rich "${args[@]}" "$file" | less -R
  fi
}

# render_markdown_pipe: Render markdown from stdin
#
# Arguments:
#   Optional flags (same as render_markdown)
#
# Returns:
#   0 - Success
#   EXIT_INVALID_ARGS - Invalid arguments
#
# Outputs:
#   stdout: Rendered markdown
#
# Examples:
#   echo "# Hello" | render_markdown_pipe
#   cat file.md | render_markdown_pipe --width 80
render_markdown_pipe() {
  local tmpfile
  tmpfile=$(mktemp "${TMPDIR:-/tmp}/harm-cli-md-XXXXXX.md") || {
    echo "Error: Failed to create temp file" >&2
    return 1
  }

  # Ensure cleanup on function exit
  trap 'rm -f "$tmpfile"' RETURN

  # Read stdin to temp file
  cat >"$tmpfile"

  # Render the temp file
  render_markdown "$tmpfile" "$@"
}

# ═══════════════════════════════════════════════════════════════
# Interactive TUI
# ═══════════════════════════════════════════════════════════════

# markdown_tui: Launch interactive markdown browser (glow only)
#
# Arguments:
#   $1 - directory (optional): Directory to browse (default: current)
#
# Returns:
#   0 - Success
#   EXIT_DEPENDENCY_MISSING - glow not installed
#   EXIT_IO_ERROR - Directory not found
#
# Examples:
#   markdown_tui
#   markdown_tui docs/
markdown_tui() {
  if ! has_glow; then
    echo "Error: Interactive TUI requires glow" >&2
    echo "Install with: brew install glow" >&2
    return 1
  fi

  local dir="${1:-.}"

  if [[ ! -d "$dir" ]]; then
    echo "Error: Directory not found: $dir" >&2
    return 1
  fi

  glow "$dir"
}

# ═══════════════════════════════════════════════════════════════
# Installation Helpers
# ═══════════════════════════════════════════════════════════════

# suggest_markdown_tools: Suggest missing markdown tools
#
# Outputs:
#   stdout: Tool status and installation suggestions
suggest_markdown_tools() {
  echo "Markdown rendering tools status:"
  echo ""

  if has_glow; then
    local version
    version=$(glow --version 2>&1 | head -1 || echo "unknown")
    echo "  ✅ glow - Available ($version)"
  else
    echo "  ❌ glow - Not installed (recommended)"
    echo "     Install: brew install glow"
    echo "     Or: https://github.com/charmbracelet/glow"
  fi

  if has_bat; then
    local bat_cmd version
    bat_cmd=$(get_bat_command)
    version=$($bat_cmd --version 2>&1 | head -1 || echo "unknown")
    echo "  ✅ bat - Available ($version)"
  else
    echo "  ⚠️  bat - Not installed (optional)"
    echo "     Install: brew install bat"
  fi

  if has_rich; then
    local version
    version=$(rich --version 2>&1 | head -1 || echo "unknown")
    echo "  ✅ rich-cli - Available ($version)"
  else
    echo "  ⚠️  rich-cli - Not installed (optional)"
    echo "     Install: pipx install rich-cli"
  fi

  echo ""
  echo "Color support: $(get_color_level)"
  echo ""
  echo "Current default tool: $(detect_markdown_tool)"
}

# ═══════════════════════════════════════════════════════════════
# Exports
# ═══════════════════════════════════════════════════════════════

export -f detect_color_support
export -f get_color_level
export -f detect_markdown_tool
export -f render_markdown
export -f render_markdown_pipe
export -f markdown_tui
export -f suggest_markdown_tools

# Mark module as loaded
readonly _HARM_MARKDOWN_LOADED=1
