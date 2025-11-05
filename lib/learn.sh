#!/usr/bin/env bash
# shellcheck shell=bash
# learn.sh - Interactive learning and feature discovery for harm-cli
# Provides tutorials, feature exploration, and command discovery
#
# This module provides:
# - Interactive learning modules for different topics
# - Feature discovery (unused commands)
# - Command exploration
# - cheat.sh integration for quick reference

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_LEARN_LOADED:-}" ]] && return 0

# Source dependencies
LEARN_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly LEARN_SCRIPT_DIR

# shellcheck source=lib/common.sh
source "$LEARN_SCRIPT_DIR/common.sh"
# shellcheck source=lib/logging.sh
source "$LEARN_SCRIPT_DIR/logging.sh"
# shellcheck source=lib/activity.sh
source "$LEARN_SCRIPT_DIR/activity.sh" 2>/dev/null || true
# shellcheck source=lib/ai.sh
source "$LEARN_SCRIPT_DIR/ai.sh" 2>/dev/null || true

# Mark as loaded
readonly _HARM_LEARN_LOADED=1

# ═══════════════════════════════════════════════════════════════
# Learning Modules
# ═══════════════════════════════════════════════════════════════

# learn_topic: Interactive learning for a specific topic
#
# Description:
#   Provides AI-powered interactive tutorial for a topic.
#
# Arguments:
#   $1 - topic (string): Topic to learn
#
# Returns:
#   0 - Learning session completed
#   1 - Invalid topic or AI unavailable
learn_topic() {
  local topic="${1:?Topic required}"
  log_info "learn" "Starting learning session" "Topic: $topic"

  echo "📚 Learning: $topic"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  # Build comprehensive learning prompt
  local prompt
  prompt="I want to learn about: $topic\n\n"
  prompt+="Please provide:\n"
  prompt+="1. **Overview**: Brief explanation (2-3 sentences)\n"
  prompt+="2. **Key Concepts**: 3-5 most important concepts\n"
  prompt+="3. **Essential Commands**: Top 5 commands I should know\n"
  prompt+="4. **Common Patterns**: 2-3 common use cases with examples\n"
  prompt+="5. **Pro Tips**: 2-3 expert tips\n"
  prompt+="6. **Next Steps**: What to learn next\n\n"
  prompt+="Keep it practical and actionable. Use examples."

  # Query AI
  if type ai_query >/dev/null 2>&1; then
    log_debug "learn" "Querying AI for learning content" "Topic: $topic"
    ai_query "$prompt" --no-cache
  else
    log_error "learn" "AI assistant not available for learning session"
    echo "❌ AI assistant not available"
    echo "   Set up with: harm-cli ai --setup"
    return 1
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════════"
  log_info "learn" "Learning session completed" "topic=$topic"
  return 0
}

# learn_list: List available learning topics
#
# Description:
#   Shows all available topics with descriptions.
#
# Returns:
#   0 - Always succeeds
learn_list() {
  log_debug "learn" "Listing available learning topics"

  echo "📚 Available Learning Topics:"
  echo ""
  echo "  git          Advanced git workflows and commands"
  echo "  docker       Container management and Docker Compose"
  echo "  python       Python development, testing, and tools"
  echo "  bash         Shell scripting and advanced Bash"
  echo "  productivity Time management and focus techniques"
  echo "  harm-cli     Advanced harm-cli features and workflows"
  echo ""
  echo "Usage: harm-cli learn <topic>"
}

# ═══════════════════════════════════════════════════════════════
# Feature Discovery
# ═══════════════════════════════════════════════════════════════

# discover_features: Explore harm-cli features
#
# Description:
#   Uses AI to suggest harm-cli features based on user's work patterns.
#
# Returns:
#   0 - Discovery completed
#   1 - AI unavailable
discover_features() {
  log_info "learn" "Starting feature discovery"

  echo "🔍 Discovering harm-cli Features..."
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  # Get user's command patterns
  local recent_commands=""
  if type activity_query >/dev/null 2>&1; then
    recent_commands=$(activity_query week 2>/dev/null | jq -r 'select(.type == "command") | .command' | head -20 | paste -sd ',' -)
    log_debug "learn" "Analyzed user command patterns" "Commands: ${#recent_commands}"
  fi

  local prompt
  prompt="Based on these recent commands, suggest harm-cli features that would be helpful:\n\n"
  if [[ -n "$recent_commands" ]]; then
    prompt+="Recent commands: $recent_commands\n\n"
  fi
  prompt+="harm-cli has these features:\n"
  prompt+="- work: Session tracking\n"
  prompt+="- goal: Daily goals\n"
  prompt+="- activity: Command logging\n"
  prompt+="- insights: Analytics\n"
  prompt+="- focus: Pomodoro & focus checks\n"
  prompt+="- ai: AI assistance\n"
  prompt+="- git: Enhanced git workflows\n"
  prompt+="- proj: Project switching\n"
  prompt+="- docker: Container management\n"
  prompt+="- python: Python development\n\n"
  prompt+="Suggest 3-5 features I should try, with specific examples."

  if type ai_query >/dev/null 2>&1 && ai_check_requirements >/dev/null 2>&1; then
    log_debug "learn" "Querying AI for feature suggestions"
    ai_query "$prompt" --no-cache
  else
    log_info "learn" "AI not available, showing default suggestions"
    echo "📚 Recommended features to try:"
    echo ""

    if [[ -n "$recent_commands" ]]; then
      # Analyze patterns and suggest based on usage
      if echo "$recent_commands" | grep -q "git"; then
        echo "  🔸 harm-cli git commit-msg - Generate smart commit messages"
        echo "  🔸 harm-cli git workflow - Enhanced git workflows"
      fi

      if echo "$recent_commands" | grep -q "docker"; then
        echo "  🔸 harm-cli docker health - Check container health"
        echo "  🔸 harm-cli safe docker-prune - Smart Docker cleanup"
      fi
    fi

    # Always suggest these core features
    echo "  🎯 harm-cli work start - Track your work sessions with Pomodoro"
    echo "  🎯 harm-cli goal set - Set and track daily goals"
    echo "  🎯 harm-cli focus score - Check your focus level"
    echo "  🎯 harm-cli insights show - View productivity analytics"
    echo "  🎯 harm-cli ai --setup - Set up AI assistant for enhanced features"
    echo ""
    echo "💡 Tip: Run 'harm-cli --help' to see all available commands"
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════════"
  log_info "learn" "Feature discovery completed"
  return 0
}

# find_unused_commands: Find commands user hasn't tried
#
# Description:
#   Analyzes activity log to find harm-cli commands not yet used.
#
# Returns:
#   0 - Always succeeds
find_unused_commands() {
  log_info "learn" "Finding unused commands"

  echo "🔎 Finding Unused Commands..."
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  # All available harm-cli commands
  local all_commands=(
    "work start" "work stop" "work status" "work violations" "work set-mode"
    "goal set" "goal show" "goal progress" "goal complete"
    "activity query" "activity stats" "activity cleanup"
    "insights show" "insights daily" "insights export"
    "focus check" "focus pomodoro"
    "ai review" "ai daily" "ai explain-error"
    "git status" "git commit-msg"
    "proj list" "proj add" "proj switch"
    "docker up" "docker down" "docker logs" "docker status"
    "python test" "python lint" "python format"
    "health" "doctor"
  )

  # Get used commands
  local used_commands=""
  local has_activity_data=0

  if type activity_query >/dev/null 2>&1; then
    used_commands=$(activity_query all 2>/dev/null | jq -r 'select(.type == "command" and (.command | startswith("harm-cli"))) | .command' | sort -u)
    if [[ -n "$used_commands" ]]; then
      has_activity_data=1
    fi
  fi

  # If no activity data, show all commands as recommendations
  if [[ $has_activity_data -eq 0 ]]; then
    echo "ℹ️  No activity data found yet."
    echo ""
    echo "📋 Essential commands to get started:"
    echo ""
    echo "  Getting Started:"
    echo "   • harm-cli init          - Initialize harm-cli"
    echo "   • harm-cli doctor        - Check system setup"
    echo ""
    echo "  Work Tracking:"
    echo "   • harm-cli work start    - Start a work session"
    echo "   • harm-cli work stop     - Stop current session"
    echo "   • harm-cli work stats    - View statistics"
    echo ""
    echo "  Goal Setting:"
    echo "   • harm-cli goal set      - Set daily goals"
    echo "   • harm-cli goal show     - View current goals"
    echo ""
    echo "  AI Features:"
    echo "   • harm-cli ai --setup    - Configure AI assistant"
    echo "   • harm-cli ai daily      - Daily insights"
    echo ""
    echo "💡 Activity tracking will start once you begin using commands."
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    return 0
  fi

  # Find unused
  local unused=()
  local cmd
  for cmd in "${all_commands[@]}"; do
    if ! echo "$used_commands" | grep -q "harm-cli $cmd"; then
      unused+=("$cmd")
    fi
  done

  if [[ ${#unused[@]} -eq 0 ]]; then
    log_info "learn" "All commands tried" "User is a power user"
    echo "🎉 Amazing! You've tried all harm-cli commands!"
    echo ""
    echo "You're a power user! 💪"
  else
    log_info "learn" "Found unused commands" "Count: ${#unused[@]}"
    echo "📋 You haven't tried these yet:"
    echo ""
    for cmd in "${unused[@]}"; do
      echo "   • harm-cli $cmd"
    done
    echo ""
    echo "💡 Try running: harm-cli learn harm-cli"
    echo "   to learn more about these features!"
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════════"
  return 0
}

# ═══════════════════════════════════════════════════════════════
# Cheat Sheet Integration
# ═══════════════════════════════════════════════════════════════

# cheat_lookup: Query cheat.sh for command examples
#
# Description:
#   Fetches cheat sheet from cheat.sh for a command or topic.
#
# Arguments:
#   $1 - query (string): Command or topic to look up
#
# Returns:
#   0 - Cheat sheet retrieved
#   1 - Network error or invalid query
cheat_lookup() {
  local query="${1:?Query required}"

  echo "📖 Cheat Sheet: $query"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  # Query cheat.sh
  if command -v curl >/dev/null 2>&1; then
    curl -s "https://cheat.sh/${query}?T" || {
      echo "❌ Failed to fetch cheat sheet"
      echo "   Check network connection or query: $query"
      return 1
    }
  else
    echo "❌ curl not available"
    echo "   Install with: brew install curl"
    return 1
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "Source: https://cheat.sh/$query"
  return 0
}

# ═══════════════════════════════════════════════════════════════
# Exports
# ═══════════════════════════════════════════════════════════════

export -f learn_topic learn_list
export -f discover_features find_unused_commands
export -f cheat_lookup
