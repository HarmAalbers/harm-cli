#!/usr/bin/env bash
# shellcheck shell=bash
# work.sh - Work session management facade for harm-cli
#
# SOLID REFACTORING COMPLETE: This module has been refactored into 5 focused components
# following Single Responsibility Principle (SRP).
#
# Architecture:
#   work.sh (this file) - Facade pattern for backward compatibility
#   ├── work_timers.sh      - Timer management and notifications
#   ├── work_enforcement.sh - Strict mode and focus discipline
#   ├── work_session.sh     - Session state and lifecycle
#   ├── work_breaks.sh      - Break session management
#   └── work_stats.sh       - Statistics and reporting
#
# This facade maintains 100% backward compatibility with the original work.sh
# by sourcing all specialized modules in correct dependency order.
#
# Benefits:
#   ✅ Single Responsibility: Each module has one reason to change
#   ✅ Open/Closed: New features added without modifying existing code
#   ✅ Dependency Inversion: Modules depend on abstractions (options, util)
#   ✅ Testability: Smaller modules easier to test independently
#   ✅ Maintainability: ~450 lines per module vs 2,289 lines monolith
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
# shellcheck source=lib/terminal_launcher.sh
source "$WORK_SCRIPT_DIR/terminal_launcher.sh"

# ═══════════════════════════════════════════════════════════════
# Work Module Components (SOLID Refactoring - Dependency Order)
# ═══════════════════════════════════════════════════════════════

# 1. Timers (no dependencies on other work modules)
# shellcheck source=lib/work_timers.sh
source "$WORK_SCRIPT_DIR/work_timers.sh"

# 2. Enforcement (depends on: timers)
# shellcheck source=lib/work_enforcement.sh
source "$WORK_SCRIPT_DIR/work_enforcement.sh"

# 3. Session (depends on: timers, enforcement)
# shellcheck source=lib/work_session.sh
source "$WORK_SCRIPT_DIR/work_session.sh"

# 4. Breaks (depends on: timers, session)
# shellcheck source=lib/work_breaks.sh
source "$WORK_SCRIPT_DIR/work_breaks.sh"

# 5. Stats (depends on: timers, session)
# shellcheck source=lib/work_stats.sh
source "$WORK_SCRIPT_DIR/work_stats.sh"

# ═══════════════════════════════════════════════════════════════
# Module Information (For Documentation)
# ═══════════════════════════════════════════════════════════════

work_module_info() {
  cat <<'EOF'
╔══════════════════════════════════════════════════════════════╗
║         Work Module - SOLID Refactored Architecture          ║
╚══════════════════════════════════════════════════════════════╝

work.sh has been refactored into 5 focused modules:

📦 work_timers.sh (248 lines)
   Single Responsibility: Timer and notification management
   ├── Desktop notifications (macOS/Linux)
   ├── Background timer lifecycle
   ├── Pomodoro counter tracking
   └── Interval reminders

📦 work_enforcement.sh (414 lines)
   Single Responsibility: Focus discipline enforcement
   ├── Violation tracking
   ├── Project switch detection/blocking
   ├── Break requirement enforcement
   └── Strict mode cd wrapper

📦 work_session.sh (554 lines)
   Single Responsibility: Work session lifecycle
   ├── Session state management (active/inactive)
   ├── Start/stop/status operations
   ├── State persistence (JSON)
   └── Focus scoring

📦 work_breaks.sh (625 lines)
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

Benefits:
✅ Maintainability: ~450 lines per module vs 2,289 line monolith
✅ Testability: Independent modules easier to test
✅ Single Responsibility: Each module has one reason to change
✅ Zero Breaking Changes: Facade maintains 100% compatibility
✅ Extensibility: New features added without modifying existing code

Dependency Graph (Zero Circular Dependencies):
work.sh (facade)
├── work_timers.sh (no work dependencies)
├── work_enforcement.sh → work_timers
├── work_session.sh → work_timers, work_enforcement
├── work_breaks.sh → work_timers, work_session, work_enforcement
└── work_stats.sh → work_timers, work_session

All functions remain available with identical behavior.
EOF
}

export -f work_module_info

# ═══════════════════════════════════════════════════════════════
# Module Loaded
# ═══════════════════════════════════════════════════════════════

readonly _HARM_WORK_LOADED=1
export _HARM_WORK_LOADED
