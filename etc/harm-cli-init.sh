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

# Load hook system for advanced features (activity tracking, etc.)
# Only loads in interactive shells
if [[ -f "$HARM_CLI_ROOT/lib/hooks.sh" ]]; then
  source "$HARM_CLI_ROOT/lib/hooks.sh"
fi

# Load activity tracking (uses hooks for automatic logging)
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

# Optional: Remind about work session if not active
# Uncomment to enable:
# if command -v harm-cli >/dev/null 2>&1; then
#   # Check work session on new shell
#   if ! harm-cli work status >/dev/null 2>&1; then
#     echo "💡 Tip: Start work session with: harm-cli work start"
#   fi
# fi

echo "✓ harm-cli initialized"
