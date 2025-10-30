#!/usr/bin/env bash
# ShellSpec tests for focus module

Describe 'lib/focus.sh'
Include spec/helpers/env.sh

BeforeAll 'setup_focus_test_env'
AfterAll 'cleanup_focus_test_env'

setup_focus_test_env() {
  export HARM_CLI_HOME="$TEST_TMP/harm-cli"
  export HARM_CLI_LOG_LEVEL="ERROR"
  export HARM_FOCUS_ENABLED=1
  export HARM_POMODORO_DURATION=25
  export HARM_BREAK_DURATION=5
  export HARM_FOCUS_CHECK_INTERVAL=900

  # Create necessary directories
  mkdir -p "$HARM_CLI_HOME"

  # Set up work module dependencies
  export HARM_WORK_DIR="$TEST_TMP/work"
  export HARM_WORK_STATE_FILE="$HARM_WORK_DIR/current_session.json"
  mkdir -p "$HARM_WORK_DIR"

  # Source dependencies in correct order
  source "$ROOT/lib/work.sh"
  source "$ROOT/lib/focus.sh"
}

cleanup_focus_test_env() {
  # Clean up pomodoro state
  rm -f "$HARM_CLI_HOME/pomodoro.state"
  # Clean up work sessions
  rm -rf "$HARM_WORK_DIR"
  rm -rf "$HARM_CLI_HOME"
  # Kill any background processes
  pkill -f "sleep.*pomodoro" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════
# Configuration Tests
# ═══════════════════════════════════════════════════════════════

Describe 'module initialization'
It 'defines required constants'
The variable HARM_FOCUS_CHECK_INTERVAL should equal 900
The variable HARM_POMODORO_DURATION should equal 25
The variable HARM_BREAK_DURATION should equal 5
The variable HARM_FOCUS_ENABLED should equal 1
End

It 'prevents double-loading'
source "$ROOT/lib/focus.sh"
source "$ROOT/lib/focus.sh"
The status should equal 0
End

It 'sets pomodoro state file location'
The variable HARM_POMODORO_STATE should include "pomodoro.state"
End

It 'exports public functions'
The variable "$(type -t focus_calculate_score)" should equal "function"
The variable "$(type -t focus_check)" should equal "function"
The variable "$(type -t pomodoro_start)" should equal "function"
The variable "$(type -t pomodoro_stop)" should equal "function"
The variable "$(type -t pomodoro_status)" should equal "function"
End
End

# ═══════════════════════════════════════════════════════════════
# Focus Scoring Tests
# ═══════════════════════════════════════════════════════════════

Describe 'focus_calculate_score'
BeforeEach 'cleanup_work_state'
AfterEach 'cleanup_work_state'

cleanup_work_state() {
  rm -f "$HARM_WORK_STATE_FILE"
}

Context 'when no work session active'
It 'returns neutral score of 5'
When call focus_calculate_score
The output should equal "5"
End
End

Context 'when work session active'
It 'increases score for active session'
# Start work session
work_start "Test goal" >/dev/null 2>&1
score=$(focus_calculate_score)
# Should be > 5 for active session
test "$score" -gt 5
The status should equal 0
End

It 'increases score when no violations'
work_start "Test goal" >/dev/null 2>&1
score=$(focus_calculate_score)
# Active session with no violations should be high (7+)
test "$score" -ge 7
The status should equal 0
End

It 'bounds score between 1 and 10'
work_start "Test goal" >/dev/null 2>&1
score=$(focus_calculate_score)
test "$score" -ge 1 && test "$score" -le 10
The status should equal 0
End
End

Context 'score components'
It 'adds points for active session'
work_start "Test goal" >/dev/null 2>&1
score=$(focus_calculate_score)
# With active session, score should be at least 7 (5 base + 2 active)
test "$score" -ge 7
The status should equal 0
End
End
End

# ═══════════════════════════════════════════════════════════════
# Focus Check Tests
# ═══════════════════════════════════════════════════════════════

Describe 'focus_check'
BeforeEach 'cleanup_work_state'
AfterEach 'cleanup_work_state'

cleanup_work_state() {
  work_stop 2>/dev/null || true
  rm -f "$HARM_WORK_STATE_FILE"
}

Context 'when no work session active'
It 'shows warning message'
When call focus_check
The output should include "No active work session"
End

It 'suggests starting work session'
When call focus_check
The output should include "harm-cli work start"
End

It 'returns success even without session'
When call focus_check
The status should equal 0
End
End

Context 'when work session active'
It 'shows focus check header'
work_start "Test goal" >/dev/null 2>&1
When call focus_check
The output should include "🎯 Focus Check"
End

It 'shows current goal'
work_start "Write comprehensive tests" >/dev/null 2>&1
When call focus_check
The output should include "Current Goal:"
The output should include "Write comprehensive tests"
End

It 'shows focus score'
work_start "Test goal" >/dev/null 2>&1
When call focus_check
The output should include "Focus Score:"
End

It 'shows violations count'
work_start "Test goal" >/dev/null 2>&1
When call focus_check
The output should include "No distractions detected"
End

It 'provides recommendations'
work_start "Test goal" >/dev/null 2>&1
When call focus_check
The output should include "💡 Recommendations:"
End
End

Context 'recommendations based on score'
It 'shows positive message for high score'
work_start "Test goal" >/dev/null 2>&1
result=$(focus_check)
# Should contain some positive feedback
echo "$result" | grep -q -E "(Excellent|Good|keep going|stay on track)"
The status should equal 0
End
End
End

# ═══════════════════════════════════════════════════════════════
# Pomodoro Timer Tests
# ═══════════════════════════════════════════════════════════════

Describe 'pomodoro_start'
BeforeEach 'cleanup_pomodoro'
AfterEach 'cleanup_pomodoro'

cleanup_pomodoro() {
  rm -f "$HARM_POMODORO_STATE"
  pkill -f "sleep.*pomodoro" 2>/dev/null || true
}

Context 'starting timer'
It 'creates pomodoro state file'
When call pomodoro_start
The status should equal 0
The file "$HARM_POMODORO_STATE" should exist
End

It 'shows start message'
When call pomodoro_start
The output should include "🍅 Pomodoro started:"
The output should include "25 minutes"
End

It 'accepts custom duration'
When call pomodoro_start 15
The output should include "15 minutes"
End

It 'saves start timestamp'
pomodoro_start >/dev/null 2>&1
timestamp=$(cat "$HARM_POMODORO_STATE")
# Should be a valid unix timestamp (10 digits)
test "${#timestamp}" -eq 10
The status should equal 0
End

It 'starts background timer process'
Skip if "Background process testing is complex in ShellSpec"
End
End

Context 'when timer already running'
It 'fails if pomodoro already active'
pomodoro_start >/dev/null 2>&1
When call pomodoro_start
The status should equal 1
The output should include "already running"
End

It 'suggests how to stop'
pomodoro_start >/dev/null 2>&1
When call pomodoro_start
The output should include "pomodoro-stop"
End
End
End

Describe 'pomodoro_stop'
BeforeEach 'cleanup_pomodoro'
AfterEach 'cleanup_pomodoro'

cleanup_pomodoro() {
  rm -f "$HARM_POMODORO_STATE"
  pkill -f "sleep.*pomodoro" 2>/dev/null || true
}

Context 'stopping timer'
It 'removes state file'
pomodoro_start >/dev/null 2>&1
pomodoro_stop >/dev/null 2>&1
The file "$HARM_POMODORO_STATE" should not exist
End

It 'shows elapsed time'
pomodoro_start >/dev/null 2>&1
sleep 0.3
When call pomodoro_stop
The output should include "stopped after"
The output should include "minutes"
End

It 'calculates elapsed minutes correctly'
pomodoro_start >/dev/null 2>&1
sleep 0.5
result=$(pomodoro_stop)
# Should show 0 minutes (less than 1 minute elapsed)
echo "$result" | grep -q "0 minutes"
The status should equal 0
End
End

Context 'when no timer active'
It 'returns success with message'
When call pomodoro_stop
The status should equal 0
The output should include "No active pomodoro"
End
End
End

Describe 'pomodoro_status'
BeforeEach 'cleanup_pomodoro'
AfterEach 'cleanup_pomodoro'

cleanup_pomodoro() {
  rm -f "$HARM_POMODORO_STATE"
}

Context 'when no timer active'
It 'shows inactive message'
When call pomodoro_status
The output should include "No active pomodoro"
End

It 'suggests how to start'
When call pomodoro_status
The output should include "harm-cli focus pomodoro"
End
End

Context 'when timer active'
It 'shows active status'
pomodoro_start >/dev/null 2>&1
When call pomodoro_status
The output should include "🍅 Pomodoro Active"
End

It 'shows elapsed time'
pomodoro_start >/dev/null 2>&1
sleep 0.3
When call pomodoro_status
The output should include "Started:"
The output should include "ago"
End

It 'shows remaining time'
pomodoro_start >/dev/null 2>&1
When call pomodoro_status
The output should include "Remaining:"
End

It 'calculates remaining time correctly'
pomodoro_start >/dev/null 2>&1
sleep 0.3
result=$(pomodoro_status)
# Should show ~25 minutes remaining (24-25 range)
echo "$result" | grep -q -E "(24|25) minutes"
The status should equal 0
End
End
End

# ═══════════════════════════════════════════════════════════════
# Context Switch Tracking
# ═══════════════════════════════════════════════════════════════

Describe 'focus_track_context_switch'
BeforeEach 'setup_context_tracking'
AfterEach 'cleanup_context_tracking'

setup_context_tracking() {
  rm -f "$HARM_WORK_STATE_FILE"
  _FOCUS_CONTEXT_SWITCHES=0
}

cleanup_context_tracking() {
  work_stop 2>/dev/null || true
  rm -f "$HARM_WORK_STATE_FILE"
}

Context 'when no work session'
It 'does not track switches'
initial_switches=$_FOCUS_CONTEXT_SWITCHES
focus_track_context_switch "/old/path" "/new/path"
The variable _FOCUS_CONTEXT_SWITCHES should equal "$initial_switches"
End
End

Context 'when work session active'
It 'increments counter on directory change'
work_start "Test goal" >/dev/null 2>&1
initial_switches=$_FOCUS_CONTEXT_SWITCHES
focus_track_context_switch "/home/user" "/tmp"
test "$_FOCUS_CONTEXT_SWITCHES" -gt "$initial_switches"
The status should equal 0
End

It 'does not increment for same directory'
work_start "Test goal" >/dev/null 2>&1
initial_switches=$_FOCUS_CONTEXT_SWITCHES
focus_track_context_switch "/same/path" "/same/path"
The variable _FOCUS_CONTEXT_SWITCHES should equal "$initial_switches"
End
End
End

# ═══════════════════════════════════════════════════════════════
# Periodic Check Hook
# ═══════════════════════════════════════════════════════════════

Describe 'focus_periodic_check'
BeforeEach 'setup_periodic_check'
AfterEach 'cleanup_periodic_check'

setup_periodic_check() {
  rm -f "$HARM_WORK_STATE_FILE"
  _FOCUS_LAST_CHECK=0
}

cleanup_periodic_check() {
  work_stop 2>/dev/null || true
  rm -f "$HARM_WORK_STATE_FILE"
}

Context 'when focus monitoring disabled'
It 'skips check when disabled'
HARM_FOCUS_ENABLED=0
When call focus_periodic_check 0 "test_command"
The status should equal 0
End
End

Context 'when no work session'
It 'skips check when no session'
HARM_FOCUS_ENABLED=1
When call focus_periodic_check 0 "test_command"
The status should equal 0
End
End

Context 'when work session active'
It 'updates last check time when interval passed'
Skip if "Timing-based test requires careful setup"
End

It 'skips check when interval not reached'
work_start "Test goal" >/dev/null 2>&1
_FOCUS_LAST_CHECK=$(date +%s)
When call focus_periodic_check 0 "test_command"
The status should equal 0
End
End
End

# ═══════════════════════════════════════════════════════════════
# Integration Tests
# ═══════════════════════════════════════════════════════════════

Describe 'focus module integration'
BeforeEach 'cleanup_integration'
AfterEach 'cleanup_integration'

cleanup_integration() {
  work_stop 2>/dev/null || true
  rm -f "$HARM_WORK_STATE_FILE"
  rm -f "$HARM_POMODORO_STATE"
  pkill -f "sleep.*pomodoro" 2>/dev/null || true
}

Context 'work session with focus tracking'
It 'calculates focus score during work session'
work_start "Integration test" >/dev/null 2>&1
score=$(focus_calculate_score)
test -n "$score" && test "$score" -ge 1 && test "$score" -le 10
The status should equal 0
End

It 'shows focus check during active session'
work_start "Integration test" >/dev/null 2>&1
result=$(focus_check)
echo "$result" | grep -q "Focus Check"
The status should equal 0
End
End

Context 'pomodoro with work session'
It 'can run pomodoro during work session'
work_start "Pomodoro test" >/dev/null 2>&1
When call pomodoro_start
The status should equal 0
The file "$HARM_POMODORO_STATE" should exist
End

It 'can check both work status and pomodoro status'
work_start "Test" >/dev/null 2>&1
pomodoro_start >/dev/null 2>&1
work_active=$(work_is_active && echo "yes" || echo "no")
test -f "$HARM_POMODORO_STATE"
pomo_active=$?
test "$work_active" = "yes" && test "$pomo_active" -eq 0
The status should equal 0
End
End
End
End
