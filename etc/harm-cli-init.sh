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
# Design: The function filters stdout to extract only the cd command line.
# This makes it robust against any stdout pollution from hooks or integrations.
# Only the first line starting with "cd " is evaluated.
function proj {
  # Handle switch/sw subcommand specially
  if [[ "${1:-}" == "switch" || "${1:-}" == "sw" ]]; then
    # Execute harm-cli proj switch and capture output (stdout only)
    # Note: stderr (logs) go directly to terminal, only cd command captured
    local output
    output="$(harm-cli proj "$@")"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
      # Extract only the first line starting with "cd " using grep
      # This filters out any stdout pollution from hooks or integrations
      # Explicitly handle grep exit codes: 1=no match (expected), others=error
      local switch_cmd
      if switch_cmd="$(echo "$output" | grep -m1 '^cd ' 2>&1)"; then
        # grep succeeded - cd command found
        eval "$switch_cmd"
      else
        local grep_exit=$?
        if [[ $grep_exit -eq 1 ]]; then
          # Expected: grep found no match (no cd command in output)
          # This means output contains only pollution, preserve original exit code
          [[ -n "$output" ]] && echo "$output"
          return "$exit_code"
        else
          # Unexpected: grep failed for other reasons
          [[ -n "$output" ]] && echo "$output"
          return "$exit_code"
        fi
      fi
    else
      # Command failed, show output (if any) and return exit code
      [[ -n "$output" ]] && echo "$output"
      return "$exit_code"
    fi
  else
    # Pass through all other commands
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
