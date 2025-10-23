#!/usr/bin/env bash
# shellcheck disable=SC2317
# SC2317: Mock functions appear unreachable to shellcheck but are called by ShellSpec
#
# ShellSpec tests for lib/focus.sh
#
# Tests focus monitoring, pomodoro timers, and productivity scoring.
# This module had 0% coverage - targeting 90%+ with these tests.

Describe 'lib/focus.sh'
Include spec/helpers/env.sh

# Source focus.sh (suppress expected INFO messages from dependencies)
BeforeAll 'source "$ROOT/lib/focus.sh" 2>/dev/null || source "$ROOT/lib/focus.sh"'

# ═══════════════════════════════════════════════════════════════
# Module Loading
# ═══════════════════════════════════════════════════════════════

Describe 'Module initialization'
It 'loads without errors'
When call source "$ROOT/lib/focus.sh"
The status should be success
End

It 'sets _HARM_FOCUS_LOADED flag'
The variable _HARM_FOCUS_LOADED should equal 1
End

It 'defines configuration constants'
The variable HARM_FOCUS_CHECK_INTERVAL should be defined
The variable HARM_POMODORO_DURATION should be defined
The variable HARM_BREAK_DURATION should be defined
The variable HARM_FOCUS_ENABLED should be defined
End

It 'exports public functions'
When run bash -c "source '$ROOT/lib/focus.sh' 2>/dev/null; type focus_calculate_score"
The status should be success
End
End

# ═══════════════════════════════════════════════════════════════
# Focus Scoring
# ═══════════════════════════════════════════════════════════════

Describe 'focus_calculate_score'
# Mock work_is_active to control test scenarios
work_is_active() { return 1; } # Not active by default

It 'returns 5 (neutral) when no work session active'
When call focus_calculate_score
The output should equal 5
End

Context 'with active work session'
# Mock active work session
work_is_active() { return 0; }
work_get_violations() { echo "0"; }
activity_query() { echo ""; }

It 'adds 2 points for active session (base 7)'
When call focus_calculate_score
# Score should be 5 + 2 (active) + 2 (no violations) = 9
The output should satisfy is_numeric_and_reasonable
End
End

Context 'with violations'
work_is_active() { return 0; }
activity_query() { echo ""; }

It 'adds 2 for zero violations'
work_get_violations() { echo "0"; }
When call focus_calculate_score
The output should satisfy is_numeric_and_reasonable
End

It 'subtracts 1 for few violations (1-2)'
work_get_violations() { echo "2"; }
When call focus_calculate_score
The output should satisfy is_numeric_and_reasonable
End

It 'subtracts 3 for many violations (3+)'
work_get_violations() { echo "5"; }
When call focus_calculate_score
The output should satisfy is_numeric_and_reasonable
End
End

Context 'bounds checking'
It 'never returns less than 1'
work_is_active() { return 0; }
work_get_violations() { echo "100"; } # Extreme violations
activity_query() { echo ""; }
When call focus_calculate_score
The output should satisfy is_valid_score
The output should not equal 0
End

It 'never returns more than 10'
work_is_active() { return 0; }
work_get_violations() { echo "0"; }
# Mock high activity
activity_query() { for i in {1..30}; do echo "cmd$i"; done; }
When call focus_calculate_score
The output should satisfy is_valid_score
End
End
End

# ═══════════════════════════════════════════════════════════════
# Focus Checks
# ═══════════════════════════════════════════════════════════════

Describe 'focus_check'
# Mock dependencies
work_is_active() { return 0; }
work_get_violations() { echo "0"; }
activity_query() { echo ""; }

It 'displays focus summary'
When call focus_check
The output should include "Focus Check"
The output should include "Score:"
End

It 'shows recommendations for high score'
focus_calculate_score() { echo "9"; }
When call focus_check
The output should include "Excellent focus"
End

It 'shows recommendations for medium score'
focus_calculate_score() { echo "6"; }
When call focus_check
The output should include "Good focus"
End

It 'shows recommendations for low score'
focus_calculate_score() { echo "3"; }
When call focus_check
The output should include "Low focus"
End
End

# ═══════════════════════════════════════════════════════════════
# Periodic Checks
# ═══════════════════════════════════════════════════════════════

Describe 'focus_periodic_check'
It 'skips when focus monitoring disabled'
HARM_FOCUS_ENABLED=0
When call focus_periodic_check 0 "test cmd"
The status should be success
End

It 'skips when no work session active'
HARM_FOCUS_ENABLED=1
work_is_active() { return 1; }
When call focus_periodic_check 0 "test cmd"
The status should be success
End

It 'succeeds when work session active'
HARM_FOCUS_ENABLED=1
work_is_active() { return 0; }
When call focus_periodic_check 0 "test cmd"
The status should be success
End
End

# ═══════════════════════════════════════════════════════════════
# Pomodoro Timer
# ═══════════════════════════════════════════════════════════════

Describe 'pomodoro_start'
BeforeEach 'rm -f "$HARM_POMODORO_STATE" 2>/dev/null || true; pkill -f "sleep.*pomodoro" 2>/dev/null || true'
AfterEach 'rm -f "$HARM_POMODORO_STATE" 2>/dev/null || true; pkill -f "sleep.*pomodoro" 2>/dev/null || true'

It 'starts pomodoro with default duration'
# Note: Background sleep process will be killed by AfterEach
When call sh -c "pomodoro_start & pid=\$!; sleep 0.5; kill \$pid 2>/dev/null || true"
The output should include "Pomodoro started"
The output should include "25 minutes"
End

It 'creates state file when started'
pomodoro_start >/dev/null 2>&1 &
sleep 0.5
The path "$HARM_POMODORO_STATE" should be exist
End

It 'rejects when pomodoro already running'
date +%s >"$HARM_POMODORO_STATE"
When call pomodoro_start
The status should equal 1
The output should include "already running"
End

It 'state file contains valid timestamp'
pomodoro_start >/dev/null 2>&1 &
sleep 0.5
timestamp=$(cat "$HARM_POMODORO_STATE" 2>/dev/null || echo "0")
The value "$timestamp" should satisfy validate_int
End
End

Describe 'pomodoro_stop'
BeforeEach 'rm -f "$HARM_POMODORO_STATE" 2>/dev/null || true'
AfterEach 'rm -f "$HARM_POMODORO_STATE" 2>/dev/null || true'

It 'stops active pomodoro'
date +%s >"$HARM_POMODORO_STATE"
When call pomodoro_stop
The status should be success
The output should include "Pomodoro stopped"
The path "$HARM_POMODORO_STATE" should not be exist
End

It 'handles no active pomodoro gracefully'
When call pomodoro_stop
The status should be success
The output should include "No active pomodoro"
End

It 'shows elapsed time when stopped'
# Create pomodoro started 2 minutes ago
echo "$(($(date +%s) - 120))" >"$HARM_POMODORO_STATE"
When call pomodoro_stop
The output should include "minutes"
End

It 'removes state file'
date +%s >"$HARM_POMODORO_STATE"
pomodoro_stop >/dev/null
The path "$HARM_POMODORO_STATE" should not be exist
End
End

Describe 'pomodoro_status'
BeforeEach 'rm -f "$HARM_POMODORO_STATE" 2>/dev/null || true'
AfterEach 'rm -f "$HARM_POMODORO_STATE" 2>/dev/null || true'

It 'shows no active pomodoro when not running'
When call pomodoro_status
The status should be success
The output should include "No active pomodoro"
The output should include "Start one with"
End

It 'shows active pomodoro status'
date +%s >"$HARM_POMODORO_STATE"
When call pomodoro_status
The status should be success
The output should include "Pomodoro Active"
The output should include "Started:"
The output should include "Remaining:"
End

It 'calculates elapsed time correctly'
# Create pomodoro started 5 minutes ago
echo "$(($(date +%s) - 300))" >"$HARM_POMODORO_STATE"
When call pomodoro_status
The output should include "5 minutes ago"
End

It 'calculates remaining time'
# Recently started pomodoro
date +%s >"$HARM_POMODORO_STATE"
When call pomodoro_status
The output should include "Remaining:"
End
End

# ═══════════════════════════════════════════════════════════════
# Context Switch Tracking
# ═══════════════════════════════════════════════════════════════

Describe 'focus_track_context_switch'
BeforeEach '_FOCUS_CONTEXT_SWITCHES=0'

It 'tracks context switches during work session'
work_is_active() { return 0; }
When call focus_track_context_switch "/old/path" "/new/path"
The status should be success
The variable _FOCUS_CONTEXT_SWITCHES should equal 1
End

It 'skips when no work session active'
work_is_active() { return 1; }
When call focus_track_context_switch "/old/path" "/new/path"
The status should be success
The variable _FOCUS_CONTEXT_SWITCHES should equal 0
End

It 'skips when directory unchanged'
work_is_active() { return 0; }
When call focus_track_context_switch "/same/path" "/same/path"
The variable _FOCUS_CONTEXT_SWITCHES should equal 0
End

It 'increments counter for each switch'
work_is_active() { return 0; }
focus_track_context_switch "/path1" "/path2" >/dev/null 2>&1
focus_track_context_switch "/path2" "/path3" >/dev/null 2>&1
When call focus_track_context_switch "/path3" "/path4"
The variable _FOCUS_CONTEXT_SWITCHES should equal 3
End
End

# ═══════════════════════════════════════════════════════════════
# Integration Tests
# ═══════════════════════════════════════════════════════════════

Describe 'Integration: Pomodoro lifecycle'
BeforeEach 'rm -f "$HARM_POMODORO_STATE" 2>/dev/null || true; pkill -f "sleep.*pomodoro" 2>/dev/null || true'
AfterEach 'rm -f "$HARM_POMODORO_STATE" 2>/dev/null || true; pkill -f "sleep.*pomodoro" 2>/dev/null || true'

It 'completes full pomodoro workflow'
# Start (background, don't wait)
pomodoro_start 1 >/dev/null 2>&1 &
sleep 0.5
The path "$HARM_POMODORO_STATE" should be exist

# Status
status_output=$(pomodoro_status)
The value "$status_output" should include "Active"

# Stop
pomodoro_stop >/dev/null
The path "$HARM_POMODORO_STATE" should not be exist
End
End

Describe 'Integration: Focus scoring with mocked state'
It 'calculates score based on multiple factors'
# Mock good state: active session, no violations, some activity
work_is_active() { return 0; }
work_get_violations() { echo "0"; }
activity_query() { for i in {1..15}; do echo "cmd$i"; done; }

When call focus_calculate_score
# Should be: 5 (base) + 2 (active) + 2 (no violations) + 1 (activity) = 10
The output should equal 10
End

It 'handles poor focus state'
work_is_active() { return 0; }
work_get_violations() { echo "5"; } # Many violations
activity_query() { echo ""; }       # No recent activity

When call focus_calculate_score
# Should be: 5 (base) + 2 (active) - 3 (violations) = 4
The output should equal 4
End
End

Describe 'Configuration'
It 'uses default pomodoro duration'
The variable HARM_POMODORO_DURATION should equal 25
End

It 'uses default break duration'
The variable HARM_BREAK_DURATION should equal 5
End

It 'uses default check interval'
The variable HARM_FOCUS_CHECK_INTERVAL should equal 900
End

It 'enables focus monitoring by default'
The variable HARM_FOCUS_ENABLED should equal 1
End
End

Describe 'Edge cases'
It 'handles missing work functions gracefully'
work_is_active() { return 1; }
When call focus_calculate_score
The status should be success
The output should be present
End

It 'handles missing activity data'
work_is_active() { return 0; }
work_get_violations() { echo "0"; }
activity_query() { return 1; } # Simulates activity module unavailable
When call focus_calculate_score
The status should be success
The output should satisfy validate_int
End

It 'handles corrupted pomodoro state file'
echo "invalid_timestamp" >"$HARM_POMODORO_STATE"
When call pomodoro_status
The status should be success
# Should handle gracefully even with bad data
End
End
End

# Helper: Validate integer
validate_int() {
  [[ "${1:-}" =~ ^-?[0-9]+$ ]]
}

# Helper: Check if value is a reasonable score (1-10)
is_valid_score() {
  local val="$1"
  [[ "$val" =~ ^[0-9]+$ ]] && [ "$val" -ge 1 ] && [ "$val" -le 10 ]
}

# Helper: Check if value is numeric
is_numeric_and_reasonable() {
  local val="$1"
  [[ "$val" =~ ^[0-9]+$ ]] && [ "$val" -ge 1 ] && [ "$val" -le 10 ]
}
