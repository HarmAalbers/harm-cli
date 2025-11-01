#!/usr/bin/env bash
# shellcheck shell=bash
# work.sh - Work session management facade for harm-cli
#
# SOLID REFACTORING: This module has been refactored into focused components
# following Single Responsibility Principle (SRP).
#
# Architecture:
#   work.sh (this file) - Facade pattern for backward compatibility
#   ├── work_timers.sh      - Timer management and notifications
#   ├── work_session.sh     - Session state and lifecycle
#   ├── work_breaks.sh      - Break session management
#   ├── work_stats.sh       - Statistics and reporting
#   └── work_enforcement.sh - Strict mode and focus discipline
#
# This facade maintains 100% backward compatibility with the original work.sh
# by re-exporting all functions from the specialized modules.
#
# Benefits:
#   ✅ Single Responsibility: Each module has one reason to change
#   ✅ Open/Closed: New features added without modifying existing code
#   ✅ Dependency Inversion: Modules depend on abstractions (options, util)
#   ✅ Testability: Smaller modules easier to test independently
#   ✅ Maintainability: ~500 lines per module vs 2,290 lines monolith
#   ✅ Zero Breaking Changes: All existing code works unchanged

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_WORK_LOADED:-}" ]] && return 0

# Source dependencies
WORK_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly WORK_SCRIPT_DIR

# ═══════════════════════════════════════════════════════════════
# Core Dependencies (Required by all work modules)
# ═══════════════════════════════════════════════════════════════

# shellcheck source=lib/common.sh
source "$WORK_SCRIPT_DIR/common.sh"
# shellcheck source=lib/error.sh
source "$WORK_SCRIPT_DIR/error.sh"
# shellcheck source=lib/logging.sh
source "$WORK_SCRIPT_DIR/logging.sh"
# shellcheck source=lib/util.sh
source "$WORK_SCRIPT_DIR/util.sh"
# shellcheck source=lib/options.sh
source "$WORK_SCRIPT_DIR/options.sh"

# ═══════════════════════════════════════════════════════════════
# Work Module Components (Dependency Order)
# ═══════════════════════════════════════════════════════════════

# 1. Timers (no dependencies on other work modules)
# shellcheck source=lib/work_timers.sh
source "$WORK_SCRIPT_DIR/work_timers.sh"

# 2. Enforcement (depends on: timers, util, options)
# shellcheck source=lib/work_enforcement.sh
source "$WORK_SCRIPT_DIR/work_enforcement.sh"

# 3. Session (depends on: timers, enforcement)
# shellcheck source=lib/work_session.sh
source "$WORK_SCRIPT_DIR/work_session.sh"

# 4. Breaks (depends on: timers, session for pomodoro count)
# shellcheck source=lib/work_breaks.sh
source "$WORK_SCRIPT_DIR/work_breaks.sh"

# 5. Stats (depends on: timers for pomodoro count, session for work_is_active)
# shellcheck source=lib/work_stats.sh
source "$WORK_SCRIPT_DIR/work_stats.sh"

# ═══════════════════════════════════════════════════════════════
# Configuration (Global for backward compatibility)
# ═══════════════════════════════════════════════════════════════

HARM_WORK_DIR="${HARM_WORK_DIR:-${HOME}/.harm-cli/work}"
readonly HARM_WORK_DIR
export HARM_WORK_DIR

HARM_WORK_STATE_FILE="${HARM_WORK_STATE_FILE:-${HARM_WORK_DIR}/current_session.json}"
readonly HARM_WORK_STATE_FILE
export HARM_WORK_STATE_FILE

HARM_WORK_TIMER_PID_FILE="${HARM_WORK_TIMER_PID_FILE:-${HARM_WORK_DIR}/timer.pid}"
readonly HARM_WORK_TIMER_PID_FILE
export HARM_WORK_TIMER_PID_FILE

HARM_WORK_REMINDER_PID_FILE="${HARM_WORK_REMINDER_PID_FILE:-${HARM_WORK_DIR}/reminder.pid}"
readonly HARM_WORK_REMINDER_PID_FILE
export HARM_WORK_REMINDER_PID_FILE

HARM_WORK_POMODORO_COUNT_FILE="${HARM_WORK_POMODORO_COUNT_FILE:-${HARM_WORK_DIR}/pomodoro_count}"
readonly HARM_WORK_POMODORO_COUNT_FILE
export HARM_WORK_POMODORO_COUNT_FILE

HARM_BREAK_STATE_FILE="${HARM_BREAK_STATE_FILE:-${HARM_WORK_DIR}/current_break.json}"
readonly HARM_BREAK_STATE_FILE
export HARM_BREAK_STATE_FILE

HARM_BREAK_TIMER_PID_FILE="${HARM_BREAK_TIMER_PID_FILE:-${HARM_WORK_DIR}/break_timer.pid}"
readonly HARM_BREAK_TIMER_PID_FILE
export HARM_BREAK_TIMER_PID_FILE

HARM_SCHEDULED_BREAK_PID_FILE="${HARM_SCHEDULED_BREAK_PID_FILE:-${HARM_WORK_DIR}/scheduled_break.pid}"
readonly HARM_SCHEDULED_BREAK_PID_FILE
export HARM_SCHEDULED_BREAK_PID_FILE

# Initialize work directory
ensure_dir "$HARM_WORK_DIR"

# Mark as loaded
readonly _HARM_WORK_LOADED=1

# ═══════════════════════════════════════════════════════════════
# Backward Compatibility: Re-export all functions
# ═══════════════════════════════════════════════════════════════

# All functions are already exported by their respective modules,
# but we list them here for documentation and explicit interface definition.

# From work_timers.sh:
# - work_send_notification
# - work_stop_timer
# - work_get_pomodoro_count
# - work_increment_pomodoro_count
# - work_reset_pomodoro_count

# From work_session.sh:
# - work_is_active
# - work_get_state
# - work_save_state
# - work_load_state
# - work_start
# - work_stop
# - work_status
# - work_require_active
# - work_remind
# - work_focus_score
# - parse_iso8601_to_epoch (deprecated, backward compatibility)

# From work_breaks.sh:
# - break_is_active
# - break_start
# - break_stop
# - break_status
# - break_countdown_interactive
# - scheduled_break_start_daemon
# - scheduled_break_stop_daemon
# - scheduled_break_status

# From work_stats.sh:
# - work_stats
# - work_stats_today
# - work_stats_week
# - work_stats_month
# - work_break_compliance

# From work_enforcement.sh:
# - work_enforcement_load_state
# - work_enforcement_save_state
# - work_enforcement_clear
# - work_check_project_switch
# - work_get_violations
# - work_reset_violations
# - work_set_enforcement
# - work_strict_cd
# - work_strict_enforce_break

# ═══════════════════════════════════════════════════════════════
# Module Information (for introspection)
# ═══════════════════════════════════════════════════════════════

# work_module_info: Display information about work module architecture
#
# Description:
#   Shows the refactored module structure and benefits.
#   Useful for documentation and understanding the architecture.
#
# Returns:
#   0 - Always succeeds
work_module_info() {
  cat <<'EOF'
╔══════════════════════════════════════════════════════════════╗
║         Work Module - SOLID Refactored Architecture          ║
╚══════════════════════════════════════════════════════════════╝

work.sh has been refactored into 5 focused modules:

📦 work_timers.sh (180 lines)
   Single Responsibility: Timer and notification management
   ├── Desktop notifications (macOS/Linux)
   ├── Background timer lifecycle
   ├── Pomodoro counter tracking
   └── Interval reminders

📦 work_session.sh (600 lines)
   Single Responsibility: Work session lifecycle
   ├── Session state management (active/inactive)
   ├── Start/stop/status operations
   ├── State persistence (JSON)
   └── Focus scoring

📦 work_breaks.sh (645 lines)
   Single Responsibility: Break session management
   ├── Break lifecycle (start/stop/status)
   ├── Interactive countdown UI
   ├── Popup window support
   └── Scheduled break daemon

📦 work_stats.sh (315 lines)
   Single Responsibility: Statistics and reporting
   ├── Work statistics (today/week/month)
   ├── Break compliance analysis
   ├── Historical data queries
   └── JSON/text output formats

📦 work_enforcement.sh (380 lines)
   Single Responsibility: Focus discipline enforcement
   ├── Violation tracking
   ├── Project switch detection/blocking
   ├── Break requirement enforcement
   └── Strict mode cd wrapper

Benefits:
✅ Maintainability: ~450 lines per module vs 2,290 line monolith
✅ Testability: Independent modules easier to test
✅ Single Responsibility: Each module has one reason to change
✅ Zero Breaking Changes: Facade maintains 100% compatibility
✅ Extensibility: New features added without modifying existing code

Dependency Graph (Zero Circular Dependencies):
work.sh (facade)
├── work_timers.sh (no work dependencies)
├── work_enforcement.sh → work_timers
├── work_session.sh → work_timers, work_enforcement
├── work_breaks.sh → work_timers, work_session
└── work_stats.sh → work_timers, work_session

All 43 functions remain available with identical behavior.
EOF
}

export -f work_module_info

# ═══════════════════════════════════════════════════════════════
# Notes
# ═══════════════════════════════════════════════════════════════

# This refactoring follows SOLID principles adapted for bash:
#
# S - Single Responsibility Principle:
#     Each module has one clear responsibility (timers, sessions, breaks, etc.)
#     Changes to break logic don't affect timer code.
#
# O - Open/Closed Principle:
#     New features (e.g., new break modes) can be added without modifying
#     existing code. Extension via inheritance/composition patterns.
#
# L - Liskov Substitution Principle:
#     All modules maintain consistent interfaces. Session state transitions
#     preserve invariants regardless of module.
#
# I - Interface Segregation Principle:
#     Each module exports only the functions it provides. No forced dependencies
#     on unused functions. work_stats doesn't need enforcement functions.
#
# D - Dependency Inversion Principle:
#     Modules depend on abstractions (options.sh, util.sh) not concrete
#     implementations. work_session depends on work_timers interface, not internals.
#
# Testing Strategy:
#   Each module can be tested independently by mocking its dependencies.
#   The facade can be tested to ensure integration works correctly.
#   ShellSpec tests should cover both unit (per-module) and integration (facade).
