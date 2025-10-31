#!/usr/bin/env bash
# libexec/break-timer-ui.sh - Standalone break timer UI for popup windows
#
# This script runs in a separate terminal window and displays an interactive
# break countdown timer. It blocks the terminal and provides visual feedback
# for break time remaining.
#
# Usage:
#   break-timer-ui.sh --duration SECONDS --type TYPE [--skip-mode MODE]
#
# Arguments:
#   --duration SECS    Break duration in seconds (required)
#   --type TYPE        Break type: short|long|custom (required)
#   --skip-mode MODE   Skip behavior: never|after50|always|type-based (default: always)
#
# Exit Codes:
#   0 - Break completed successfully
#   1 - Break skipped/interrupted
#   2 - Invalid arguments

set -Eeuo pipefail
IFS=$'\n\t'

# ═══════════════════════════════════════════════════════════════
# Configuration & Constants
# ═══════════════════════════════════════════════════════════════

# Find harm-cli root directory
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly ROOT_DIR

# Source only essential utilities (avoid config conflicts)
# Don't source common.sh because it loads logging.sh which makes HARM_LOG_DIR readonly,
# then config.sh tries to set it again causing "readonly variable" errors

# Minimal color definitions (avoid full common.sh)
if [[ -t 1 ]]; then
  SUCCESS_GREEN="$(tput setaf 2 2>/dev/null || echo '')"
  WARN_YELLOW="$(tput setaf 3 2>/dev/null || echo '')"
  ERROR_RED="$(tput setaf 1 2>/dev/null || echo '')"
  RESET="$(tput sgr0 2>/dev/null || echo '')"
else
  SUCCESS_GREEN=""
  WARN_YELLOW=""
  ERROR_RED=""
  RESET=""
fi

# Minimal format_duration function (avoid sourcing util.sh)
format_duration() {
  local seconds="${1:?format_duration requires seconds}"
  local hours=$((seconds / 3600))
  local minutes=$(((seconds % 3600) / 60))
  local secs=$((seconds % 60))

  local result=""
  ((hours > 0)) && result="${hours}h"
  ((minutes > 0)) && result="${result}${minutes}m"
  ((secs > 0 || ${#result} == 0)) && result="${result}${secs}s"

  echo "$result"
}

# ═══════════════════════════════════════════════════════════════
# Argument Parsing
# ═══════════════════════════════════════════════════════════════

DURATION=""
BREAK_TYPE=""
SKIP_MODE="always"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --duration)
      DURATION="${2:?--duration requires value}"
      shift 2
      ;;
    --type)
      BREAK_TYPE="${2:?--type requires value}"
      shift 2
      ;;
    --skip-mode)
      SKIP_MODE="${2:?--skip-mode requires value}"
      shift 2
      ;;
    --help | -h)
      cat <<'EOF'
break-timer-ui.sh - Standalone break timer UI

Usage:
  break-timer-ui.sh --duration SECONDS --type TYPE [--skip-mode MODE]

Arguments:
  --duration SECS    Break duration in seconds (required)
  --type TYPE        Break type: short|long|custom (required)
  --skip-mode MODE   Skip behavior (default: always)
                     - never: Cannot skip, must complete full break
                     - after50: Can skip after 50% completion
                     - always: Can skip anytime with Ctrl+C
                     - type-based: short=always, long=after50

Examples:
  break-timer-ui.sh --duration 300 --type short
  break-timer-ui.sh --duration 900 --type long --skip-mode after50
  break-timer-ui.sh --duration 600 --type custom --skip-mode never
EOF
      exit 0
      ;;
    *)
      echo "Error: Unknown argument: $1" >&2
      echo "Run with --help for usage" >&2
      exit 2
      ;;
  esac
done

# Validate required arguments
if [[ -z "$DURATION" ]]; then
  echo "Error: --duration is required" >&2
  exit 2
fi

if [[ -z "$BREAK_TYPE" ]]; then
  echo "Error: --type is required" >&2
  exit 2
fi

# Validate skip mode
case "$SKIP_MODE" in
  never | after50 | always | type-based) ;;
  *)
    echo "Error: Invalid skip mode: $SKIP_MODE" >&2
    echo "Valid modes: never, after50, always, type-based" >&2
    exit 2
    ;;
esac

# Resolve type-based skip mode
if [[ "$SKIP_MODE" == "type-based" ]]; then
  case "$BREAK_TYPE" in
    short)
      SKIP_MODE="always"
      ;;
    long)
      SKIP_MODE="after50"
      ;;
    *)
      SKIP_MODE="always"
      ;;
  esac
fi

# ═══════════════════════════════════════════════════════════════
# Notification Functions
# ═══════════════════════════════════════════════════════════════

send_notification() {
  local title="$1"
  local message="$2"

  if [[ "$(uname)" == "Darwin" ]]; then
    # macOS notification
    osascript 2>/dev/null <<EOF || true
display notification "$message" with title "$title" sound name "Glass"
EOF
  elif command -v notify-send &>/dev/null; then
    # Linux notification
    notify-send "$title" "$message" 2>/dev/null || true
  fi
}

# ═══════════════════════════════════════════════════════════════
# Skip Mode Handling
# ═══════════════════════════════════════════════════════════════

# Check if skip is allowed at current progress
can_skip_now() {
  local elapsed="$1"
  local total="$2"

  case "$SKIP_MODE" in
    never)
      return 1 # Never allow skip
      ;;
    always)
      return 0 # Always allow skip
      ;;
    after50)
      local percent=$((elapsed * 100 / total))
      [[ $percent -ge 50 ]] # Allow after 50%
      ;;
    *)
      return 0 # Default: allow
      ;;
  esac
}

# Install trap handler for Ctrl+C
setup_interrupt_handler() {
  trap 'handle_interrupt' INT TERM
}

# shellcheck disable=SC2317  # Called via trap
handle_interrupt() {
  local current_time elapsed

  current_time=$(date +%s)
  elapsed=$((current_time - start_time))

  echo ""
  echo ""

  if can_skip_now "$elapsed" "$DURATION"; then
    echo -e "${WARN_YELLOW}⚠️  Break interrupted!${RESET}"
    echo ""
    echo "You skipped the break early."
    echo "Elapsed: $(format_duration "$elapsed") / $(format_duration "$DURATION")"
    echo ""
    echo "Press Enter to close..."
    read -r
    exit 1
  else
    local percent=$((elapsed * 100 / DURATION))
    echo -e "${ERROR_RED}❌ Cannot skip yet!${RESET}"
    echo ""
    echo "Current progress: ${percent}%"

    case "$SKIP_MODE" in
      never)
        echo "Skip mode: NEVER - You must complete the full break"
        ;;
      after50)
        echo "Skip mode: AFTER 50% - You can skip after reaching 50%"
        echo "Keep going! You're at ${percent}% completion."
        ;;
    esac

    echo ""
    echo "Press Enter to continue the break..."
    read -r

    # Resume countdown (trap will be re-triggered if they try again)
    return 0
  fi
}

# ═══════════════════════════════════════════════════════════════
# Countdown Display
# ═══════════════════════════════════════════════════════════════

show_break_timer() {
  local start_time end_time elapsed remaining

  start_time=$(date +%s)
  end_time=$((start_time + DURATION))

  # Setup interrupt handler
  setup_interrupt_handler

  # Clear screen and show header
  clear
  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║                    ☕ BREAK TIME ☕                         ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  echo "  Type: ${BREAK_TYPE^} break"
  echo "  Duration: $(format_duration "$DURATION")"
  echo ""

  # Show skip mode info
  case "$SKIP_MODE" in
    never)
      echo -e "  ${ERROR_RED}⚠️  Skip: DISABLED - Must complete full break${RESET}"
      ;;
    after50)
      echo -e "  ${WARN_YELLOW}⚠️  Skip: After 50% completion${RESET}"
      ;;
    always)
      echo "  ℹ️  Skip: Press Ctrl+C anytime to exit"
      ;;
  esac

  echo ""
  echo "  💡 Tip: Step away from the screen, stretch, hydrate!"
  echo ""
  echo "─────────────────────────────────────────────────────────────"
  echo ""

  # Pre-generate progress bar characters (PERF: once outside loop)
  local bar_width=50
  local progress_full="████████████████████████████████████████████████████" # 50 filled chars
  local progress_empty="░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"  # 50 empty chars

  # Countdown loop (PERF: using $SECONDS instead of date +%s)
  SECONDS=0
  while true; do
    elapsed=$SECONDS
    remaining=$((DURATION - elapsed))

    # Break completed
    if [[ $remaining -le 0 ]]; then
      remaining=0
      break
    fi

    # Calculate progress
    local percent=$((elapsed * 100 / DURATION))
    local filled=$((percent * bar_width / 100))
    local empty=$((bar_width - filled))

    # Build progress bar (PERF: pure bash substring, no loops)
    local bar="[${progress_full:0:filled}${progress_empty:0:empty}]"

    # Format remaining time
    local min=$((remaining / 60))
    local sec=$((remaining % 60))
    local time_str=$(printf "%02d:%02d" "$min" "$sec")

    # Update display (using ANSI escape codes)
    printf "\033[4A" # Move cursor up 4 lines
    printf "\033[J"  # Clear from cursor to end of screen
    printf "  %s %d%%\n" "$bar" "$percent"
    printf "  Time remaining: ${SUCCESS_GREEN}%s${RESET}\n" "$time_str"
    printf "\n"

    # Show skip message based on current state
    if can_skip_now "$elapsed" "$DURATION"; then
      printf "  Press Ctrl+C to skip break early\n"
    else
      case "$SKIP_MODE" in
        never)
          printf "  %sCannot skip - complete the break%s\n" "$ERROR_RED" "$RESET"
          ;;
        after50)
          printf "  %sCan skip after %d%% (at 50%%)%s\n" "$WARN_YELLOW" "$percent" "$RESET"
          ;;
      esac
    fi

    # Sleep for 1 second
    sleep 1
  done

  # Show completion (PERF: single printf)
  printf "\033[4A\033[J  [%s] 100%%\n  Time remaining: ${SUCCESS_GREEN}00:00${RESET}\n\n\n" "$progress_full"
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║              ✅ BREAK COMPLETE! ✅                         ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  echo -e "  ${SUCCESS_GREEN}Great job!${RESET} You've recharged. Ready to work!"
  echo ""

  # Send completion notification
  send_notification "✅ Break Complete!" "You've recharged! Time to get back to work."

  # Pause for 3 seconds to show completion, then auto-close
  echo "  Closing in 3 seconds..."
  sleep 3

  return 0
}

# ═══════════════════════════════════════════════════════════════
# Main Entry Point
# ═══════════════════════════════════════════════════════════════

main() {
  # Run the break timer
  show_break_timer
  exit_code=$?

  # Clean exit
  exit $exit_code
}

# Run main function
main
