#!/usr/bin/env bash
# harm-cli shell integration
# Usage: eval "$(harm-cli init)"
# Or: eval "$(~/harm-cli/bin/harm-cli init)"

# Detect harm-cli location
if [[ -n "${HARM_CLI_ROOT:-}" ]]; then
  # Already set
  :
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  # Sourced directly
  HARM_CLI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
else
  # Called via harm-cli init
  HARM_CLI_ROOT="$(cd "$(dirname "$(command -v harm-cli)")/.." 2>/dev/null && pwd || echo "$HOME/harm-cli")"
fi

# Add to PATH if not already present
if [[ ":$PATH:" != *":$HARM_CLI_ROOT/bin:"* ]]; then
  export PATH="$HARM_CLI_ROOT/bin:$PATH"
fi

# Set home directory
export HARM_CLI_HOME="${HARM_CLI_HOME:-$HOME/.harm-cli}"

# Create home directory if needed
[[ ! -d "$HARM_CLI_HOME" ]] && mkdir -p "$HARM_CLI_HOME"

# Load bash completions if available
if [[ -n "${BASH_VERSION:-}" ]] && [[ -f "$HARM_CLI_ROOT/completions/harm-cli.bash" ]]; then
  source "$HARM_CLI_ROOT/completions/harm-cli.bash"
fi

# Load hook system (uses PROMPT_COMMAND, DEBUG trap, BASH_COMMAND)
if [[ -f "$HARM_CLI_ROOT/lib/hooks.sh" ]]; then
  source "$HARM_CLI_ROOT/lib/hooks.sh"
fi
# Load activity tracking (depends on hooks.sh)
if [[ -f "$HARM_CLI_ROOT/lib/activity.sh" ]]; then
  source "$HARM_CLI_ROOT/lib/activity.sh"
fi
# Load focus monitoring (periodic checks, pomodoro)
if [[ -f "$HARM_CLI_ROOT/lib/focus.sh" ]]; then
  source "$HARM_CLI_ROOT/lib/focus.sh"
fi
# Load interactive learning (learn, discover, unused, cheat)
if [[ -f "$HARM_CLI_ROOT/lib/learn.sh" ]]; then
  source "$HARM_CLI_ROOT/lib/learn.sh"
fi
# ═══════════════════════════════════════════════════════════════
# Shell Helper Functions
# ═══════════════════════════════════════════════════════════════

# Remove any existing proj alias to avoid conflicts
builtin unalias proj 2>/dev/null || true

# Use 'function' keyword syntax to avoid alias expansion issues in zsh
# proj() - Wrapper for harm-cli proj with automatic directory switching
#
# This function wraps the 'harm-cli proj' command and automatically
# evaluates the 'switch' subcommand, making directory changes work seamlessly.
#
# Usage:
#   proj list          # Same as: harm-cli proj list
#   proj add ~/myapp   # Same as: harm-cli proj add ~/myapp
#   proj switch myapp  # Actually switches to the directory!
#   proj sw myapp      # Short alias for switch
#
# Note: For all other proj subcommands, this passes through to harm-cli.
#
# DESIGN RATIONALE:
# The function must filter stdout to extract ONLY the cd command line, because
# harm-cli proj switch may output log messages, debug info, or status text via
# stdout hooks or integrations. We cannot eval arbitrary text - only the actual
# 'cd "/path"' command. This approach is robust against stdout pollution while
# maintaining security by validating the cd command format before execution.
function proj {
  # Handle switch/sw subcommand specially
  if [[ "${1:-}" == "switch" || "${1:-}" == "sw" ]]; then
    # Execute harm-cli proj switch and capture output
    # stderr (logs) go directly to terminal; only stdout is captured
    local output
    output="$(harm-cli proj "$@")"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
      # proj switch succeeded - extract cd command from output
      # Use grep to find first line starting with "cd " (filters out pollution)
      local switch_cmd
      switch_cmd="$(echo "$output" | grep -m1 '^cd ')" || switch_cmd=""

      if [[ -n "$switch_cmd" ]]; then
        # cd command found - validate format to prevent command injection
        # Valid format: cd followed by space(s) and path (with optional quotes)
        if [[ "$switch_cmd" =~ ^cd\ +[\'\"]*/ ]]; then
          # Execute the cd command with error handling
          if eval "$switch_cmd"; then
            # Successfully changed directory
            return 0
          else
            # cd failed (directory not found, permission denied, etc.)
            echo "ERROR: Failed to change directory: $switch_cmd" >&2
            return 1
          fi
        else
          # Invalid cd command format - indicates possible malicious pollution
          echo "ERROR: Invalid cd command format detected" >&2
          [[ -n "$output" ]] && echo "$output" >&2
          return 1
        fi
      else
        # No cd command in output - proj succeeded but output contains only logs/pollution
        # Return original exit code and show output for debugging
        [[ -n "$output" ]] && echo "$output"
        return "$exit_code"
      fi
    else
      # proj switch failed - show output and return its exit code
      [[ -n "$output" ]] && echo "$output"
      return "$exit_code"
    fi
  else
    # Pass through all other commands (list, add, remove)
    harm-cli proj "$@"
  fi
}

# Optional: Remind about work session if not active
# Uncomment to enable (safe to use if not using instant prompt):
# if command -v harm-cli >/dev/null 2>&1; then
#   # Check work session on new shell
#   if ! harm-cli work status >/dev/null 2>&1; then
#     echo "💡 Tip: Start work session with: harm-cli work start"
#   fi
# fi

echo "✓ harm-cli initialized (with proj() helper function)"
