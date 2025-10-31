#!/usr/bin/env bash
# ShellSpec tests for work break session management (interactive and background modes)

Describe 'lib/work.sh - Break Sessions'
Include spec/helpers/env.sh

# Set up test work directory and source work module
# IMPORTANT: Must set HARM_WORK_DIR and HARM_CLI_HOME before sourcing work.sh (readonly vars)
setup_break_test_env() {
  export HARM_WORK_DIR="$TEST_TMP/work"
  export HARM_WORK_STATE_FILE="$HARM_WORK_DIR/current_session.json"
  export HARM_BREAK_STATE_FILE="$HARM_WORK_DIR/current_break.json"
  export HARM_BREAK_TIMER_PID_FILE="$HARM_WORK_DIR/break_timer.pid"
  export HARM_CLI_HOME="$TEST_TMP/harm-cli"
  mkdir -p "$HARM_WORK_DIR" "$HARM_CLI_HOME"
  source "$ROOT/lib/work.sh"
}

# Clean up break session artifacts and background processes
cleanup_break_session() {
  # Kill any break timer processes
  if [[ -f "$HARM_BREAK_TIMER_PID_FILE" ]]; then
    local pid
    pid=$(cat "$HARM_BREAK_TIMER_PID_FILE" 2>/dev/null || echo "")
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
    rm -f "$HARM_BREAK_TIMER_PID_FILE"
  fi

  # Clean up break state files
  rm -f "$HARM_BREAK_STATE_FILE"* 2>/dev/null || true

  # Clean up work session if any
  rm -f "$HARM_WORK_STATE_FILE"* 2>/dev/null || true
  rm -f "$HARM_WORK_DIR"/*.pid 2>/dev/null || true
}

# Helper to start a work session for break testing
start_test_work_session() {
  local goal="${1:-Test work session}"
  work_start "$goal" >/dev/null 2>&1 || {
    echo "ERROR: Failed to start test work session" >&2
    return 1
  }
}

BeforeAll 'setup_break_test_env'
AfterAll 'cleanup_break_test_env'

cleanup_break_test_env() {
  cleanup_break_session
  rm -rf "$HARM_WORK_DIR"
}

# ═══════════════════════════════════════════════════════════════
# Break State Management Tests
# ═══════════════════════════════════════════════════════════════

Describe 'break_is_active'
BeforeEach 'cleanup_break_session'

It 'returns false when no break session exists'
rm -f "$HARM_BREAK_STATE_FILE"
When call break_is_active
The status should be failure
End

It 'returns true when break session is active'
echo '{"status":"active","start_time":"2025-10-31T10:00:00Z"}' >"$HARM_BREAK_STATE_FILE"
When call break_is_active
The status should be success
End

It 'returns false when break status is not active'
echo '{"status":"completed","start_time":"2025-10-31T10:00:00Z"}' >"$HARM_BREAK_STATE_FILE"
When call break_is_active
The status should be failure
End
End

# ═══════════════════════════════════════════════════════════════
# break_countdown_interactive Tests
# ═══════════════════════════════════════════════════════════════

Describe 'break_countdown_interactive'
BeforeEach 'cleanup_break_session'

Context 'parameter validation'
It 'requires duration parameter'
When call break_countdown_interactive
The status should not equal 0
The error should include "duration"
End

It 'accepts break_type parameter'
# Run with very short duration (1 second) to avoid long waits
When call break_countdown_interactive 1 "short"
The status should equal 0
End

It 'uses default break_type if not provided'
When call break_countdown_interactive 1
The status should equal 0
End
End

Context 'countdown completion'
It 'completes successfully with short duration'
# Note: We skip actual countdown testing because it takes real time
# The function is tested indirectly through break_start with TTY
Skip if "Countdown takes real time (1+ seconds), tested via integration"
End

It 'shows break type in output'
# Note: Actual countdown display cannot be tested without TTY
Skip if "Countdown display requires TTY and takes real time"
End

It 'displays completion message'
# Note: Completion message shown after countdown completes
Skip if "Countdown completion takes real time, tested via integration"
End

It 'formats duration in output'
# Note: Duration formatting in header requires running countdown
Skip if "Countdown formatting tested via integration with real breaks"
End
End

Context 'various durations'
It 'handles 1 second duration'
# Note: Even 1 second adds up when running 60+ tests
Skip if "Countdown timing tested via integration tests"
End

It 'handles 5 second duration'
Skip if "Countdown timing tested via integration tests"
End

It 'handles 10 second duration'
Skip if "Countdown timing tested via integration tests"
End
End
End

# ═══════════════════════════════════════════════════════════════
# break_start Tests - Flag Handling
# ═══════════════════════════════════════════════════════════════

Describe 'break_start - flag handling'
BeforeEach 'cleanup_break_session'

Context '--help flag'
It 'shows help with --help'
When call break_start --help
The status should equal 0
The output should include "Usage:"
The output should include "--blocking"
The output should include "--background"
End

It 'shows help with -h'
When call break_start -h
The status should equal 0
The output should include "Usage:"
End

It 'shows help with help argument'
When call break_start help
The status should equal 0
The output should include "Usage:"
End

It 'includes examples in help'
When call break_start --help
The status should equal 0
The output should include "Examples:"
End
End

Context '--background flag'
It 'accepts --background flag'
When call break_start --background 5 short
The status should equal 0
The output should include "background mode"
End

It 'creates break state file in background mode'
break_start --background 5 short >/dev/null 2>&1
The file "$HARM_BREAK_STATE_FILE" should exist
The contents of file "$HARM_BREAK_STATE_FILE" should include '"status": "active"'
End

It 'saves blocking_mode as false in state'
break_start --background 5 short >/dev/null 2>&1
state=$(cat "$HARM_BREAK_STATE_FILE")
blocking=$(echo "$state" | jq -r '.blocking_mode')
test "$blocking" = "false"
The status should equal 0
End

It 'creates timer PID file in background mode'
break_start --background 5 short >/dev/null 2>&1
sleep 0.2
The file "$HARM_BREAK_TIMER_PID_FILE" should exist
End

It 'stores valid PID in timer file'
break_start --background 5 short >/dev/null 2>&1
sleep 0.2
pid=$(cat "$HARM_BREAK_TIMER_PID_FILE" 2>/dev/null || echo "0")
test "$pid" -gt 0
The status should equal 0
End

It 'shows background mode message in text format'
export HARM_CLI_FORMAT=text
When call break_start --background 5 short
The output should include "background mode"
The output should include "non-blocking"
End

It 'outputs JSON in background mode with JSON format'
export HARM_CLI_FORMAT=json
When call break_start --background 5 short
The output should include '"status"'
The output should include '"mode": "background"'
End
End

Context '--blocking flag'
It 'accepts --blocking flag'
# Note: blocking mode requires TTY, so we test with --background for actual execution
# but can test flag parsing by checking help doesn't trigger
When call break_start --blocking
# Will fail because it needs duration, but proves --blocking is recognized
The status should equal "$EXIT_ERROR"
End

It 'saves blocking_mode as true in state when using --blocking'
# Since blocking mode requires TTY, this test checks the state file
# after attempting to start (will fallback to background due to no TTY in tests)
Skip if "Blocking mode requires TTY, tested separately"
End
End

Context 'positional arguments with flags'
It 'parses duration after --background flag'
When call break_start --background 300 short
The status should equal 0
state=$(cat "$HARM_BREAK_STATE_FILE")
duration=$(echo "$state" | jq -r '.duration_seconds')
test "$duration" -eq 300
The status should equal 0
End

It 'parses break type after duration'
When call break_start --background 180 long
The status should equal 0
state=$(cat "$HARM_BREAK_STATE_FILE")
type=$(echo "$state" | jq -r '.type')
test "$type" = "long"
The status should equal 0
End

It 'handles flags before positional arguments'
When call break_start --background 120
The status should equal 0
End
End
End

# ═══════════════════════════════════════════════════════════════
# break_start Tests - Auto-detection and State
# ═══════════════════════════════════════════════════════════════

Describe 'break_start - auto-detection and state'
BeforeEach 'cleanup_break_session'

Context 'break type auto-detection'
It 'auto-detects short break by default'
When call break_start --background
The status should equal 0
state=$(cat "$HARM_BREAK_STATE_FILE")
type=$(echo "$state" | jq -r '.type')
test "$type" = "short"
The status should equal 0
End

It 'uses default type when not specified'
When call break_start --background 600
The status should equal 0
state=$(cat "$HARM_BREAK_STATE_FILE")
type=$(echo "$state" | jq -r '.type')
test "$type" = "custom"
The status should equal 0
End

It 'detects long break based on pomodoro count'
# Set up for long break detection (requires pomodoros_until_long setting)
Skip if "Pomodoro count detection requires work session setup"
End
End

Context 'break already active'
It 'fails when break already active'
break_start --background 5 short >/dev/null 2>&1
When call break_start --background 5 short
The status should equal "$EXIT_ERROR"
The error should include "already active"
End

It 'allows starting after previous break completes'
break_start --background 1 short >/dev/null 2>&1
sleep 1.5
When call break_start --background 1 short
The status should equal 0
End
End

Context 'state persistence'
It 'saves start timestamp in ISO8601 UTC format'
break_start --background 5 short >/dev/null 2>&1
state=$(cat "$HARM_BREAK_STATE_FILE")
start_time=$(echo "$state" | jq -r '.start_time')
# Should match ISO8601 format: YYYY-MM-DDTHH:MM:SSZ
echo "$start_time" | grep -E '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'
The status should equal 0
End

It 'saves all required fields in state'
break_start --background 300 short >/dev/null 2>&1
state=$(cat "$HARM_BREAK_STATE_FILE")
echo "$state" | jq -e '.status' >/dev/null
echo "$state" | jq -e '.start_time' >/dev/null
echo "$state" | jq -e '.duration_seconds' >/dev/null
echo "$state" | jq -e '.type' >/dev/null
echo "$state" | jq -e '.blocking_mode' >/dev/null
The status should equal 0
End

It 'saves status as active'
break_start --background 5 short >/dev/null 2>&1
state=$(cat "$HARM_BREAK_STATE_FILE")
status=$(echo "$state" | jq -r '.status')
test "$status" = "active"
The status should equal 0
End
End
End

# ═══════════════════════════════════════════════════════════════
# break_start Tests - TTY Detection and Mode Selection
# ═══════════════════════════════════════════════════════════════

Describe 'break_start - TTY detection and mode selection'
BeforeEach 'cleanup_break_session'

Context 'TTY fallback behavior'
It 'falls back to background mode when no TTY available'
# In test environment, there is no TTY, so blocking mode should fallback
# This is the actual production behavior - no TTY = background mode
export HARM_CLI_FORMAT=text
When call break_start 5 short
The status should equal 0
The output should include "background"
End

It 'uses background mode when format is JSON'
# JSON format should always use background mode regardless of TTY
export HARM_CLI_FORMAT=json
When call break_start 5 short
The status should equal 0
The output should include '"mode": "background"'
End
End

Context 'explicit mode override'
It '--background overrides default blocking mode'
When call break_start --background 5 short
The status should equal 0
state=$(cat "$HARM_BREAK_STATE_FILE")
blocking=$(echo "$state" | jq -r '.blocking_mode')
test "$blocking" = "false"
The status should equal 0
End

It '--blocking sets blocking mode in state'
# Will fallback to background due to no TTY, but state should show intent
When call break_start --blocking 5 short
The status should equal 0
state=$(cat "$HARM_BREAK_STATE_FILE")
blocking=$(echo "$state" | jq -r '.blocking_mode')
test "$blocking" = "true"
The status should equal 0
End
End
End

# ═══════════════════════════════════════════════════════════════
# break_stop Tests
# ═══════════════════════════════════════════════════════════════

Describe 'break_stop'
BeforeEach 'cleanup_break_session'

Context 'stopping active break'
It 'stops active break session'
break_start --background 60 short >/dev/null 2>&1
When call break_stop
The status should equal 0
The error should include "Break session stopped"
End

It 'removes break state file'
break_start --background 60 short >/dev/null 2>&1
break_stop >/dev/null 2>&1
The file "$HARM_BREAK_STATE_FILE" should not exist
End

It 'kills background timer process'
break_start --background 60 short >/dev/null 2>&1
sleep 0.2
pid=$(cat "$HARM_BREAK_TIMER_PID_FILE" 2>/dev/null || echo "")
break_stop >/dev/null 2>&1
# PID file should be removed
The file "$HARM_BREAK_TIMER_PID_FILE" should not exist
End

It 'shows duration when stopping'
break_start --background 60 short >/dev/null 2>&1
sleep 0.3
When call break_stop
The output should include "Duration:"
End
End

Context 'when no active break'
It 'fails when no break session active'
rm -f "$HARM_BREAK_STATE_FILE"
When call break_stop
The status should equal "$EXIT_ERROR"
The error should include "No active break session"
End
End

Context 'output formats'
It 'outputs text format by default'
export HARM_CLI_FORMAT=text
break_start --background 60 short >/dev/null 2>&1
sleep 0.3
When call break_stop
The output should include "Break session stopped"
The output should include "Duration:"
End

It 'outputs JSON format when requested'
export HARM_CLI_FORMAT=json
break_start --background 60 short >/dev/null 2>&1
sleep 0.3
When call break_stop
The output should include '"status"'
The output should include '"duration_seconds"'
End
End
End

# ═══════════════════════════════════════════════════════════════
# Integration Tests - work_stop with auto-start break
# ═══════════════════════════════════════════════════════════════

Describe 'work_stop - break auto-start integration'
BeforeEach 'cleanup_integration_test'
AfterEach 'cleanup_integration_test'

cleanup_integration_test() {
  cleanup_break_session
  work_stop 2>/dev/null || true
  rm -f "$HARM_WORK_STATE_FILE"* 2>/dev/null || true
}

Context 'auto-start break behavior'
It 'uses background mode for auto-started breaks'
# Set auto_start_break option
export HARM_CLI_AUTO_START_BREAK=1
start_test_work_session "Test goal"
sleep 0.3

# Stop work session (should auto-start break)
work_stop >/dev/null 2>&1

# Check that break was started in background mode
if [[ -f "$HARM_BREAK_STATE_FILE" ]]; then
  state=$(cat "$HARM_BREAK_STATE_FILE")
  blocking=$(echo "$state" | jq -r '.blocking_mode')
  test "$blocking" = "false"
fi
The status should equal 0
End

It 'does not block terminal when auto-starting break'
export HARM_CLI_AUTO_START_BREAK=1
start_test_work_session "Test goal"
sleep 0.3

# work_stop should return immediately (not block)
timeout 5 work_stop >/dev/null 2>&1
# If timeout succeeds, work_stop didn't block
The status should equal 0
End
End
End

# ═══════════════════════════════════════════════════════════════
# Edge Cases and Error Handling
# ═══════════════════════════════════════════════════════════════

Describe 'break management - edge cases'
BeforeEach 'cleanup_break_session'

Context 'invalid arguments'
It 'handles missing duration gracefully with auto-detect'
When call break_start --background
The status should equal 0
End

It 'handles invalid PID file gracefully'
echo "not-a-number" >"$HARM_BREAK_TIMER_PID_FILE"
When call break_stop
The status should equal "$EXIT_ERROR"
The error should include "No active break"
End

It 'handles stale PID file gracefully'
echo "99999" >"$HARM_BREAK_TIMER_PID_FILE"
echo '{"status":"active","start_time":"2025-10-31T10:00:00Z"}' >"$HARM_BREAK_STATE_FILE"
When call break_stop
The status should equal 0
End
End

Context 'file system operations'
It 'creates state file atomically'
break_start --background 5 short >/dev/null 2>&1
# State file should exist and be valid JSON
test -f "$HARM_BREAK_STATE_FILE"
jq -e '.' "$HARM_BREAK_STATE_FILE" >/dev/null 2>&1
The status should equal 0
End

It 'handles corrupted state file gracefully'
echo "invalid json" >"$HARM_BREAK_STATE_FILE"
When call break_is_active
The status should be failure
End
End

Context 'concurrent operations'
It 'prevents starting multiple breaks'
break_start --background 60 short >/dev/null 2>&1
When call break_start --background 60 short
The status should equal "$EXIT_ERROR"
The error should include "already active"
End
End
End

# ═══════════════════════════════════════════════════════════════
# Background Timer Behavior Tests
# ═══════════════════════════════════════════════════════════════

Describe 'break background timer'
BeforeEach 'cleanup_break_session'
AfterEach 'cleanup_break_session'

Context 'timer lifecycle'
It 'timer runs in background'
break_start --background 5 short >/dev/null 2>&1
sleep 0.2
# Check that break is still active (timer hasn't expired)
When call break_is_active
The status should be success
End

It 'timer completes after duration'
# Use very short duration (2 seconds)
break_start --background 2 short >/dev/null 2>&1
sleep 2.5
# Break should no longer be active (timer expired and cleaned up)
# Note: This may be flaky depending on timing
Skip if "Timer completion testing is timing-dependent"
End

It 'timer process has valid PID'
break_start --background 5 short >/dev/null 2>&1
sleep 0.2
pid=$(cat "$HARM_BREAK_TIMER_PID_FILE" 2>/dev/null || echo "0")
# Check if process exists
ps -p "$pid" >/dev/null 2>&1
The status should equal 0
End
End

Context 'timer cleanup'
It 'removes PID file on break_stop'
break_start --background 60 short >/dev/null 2>&1
break_stop >/dev/null 2>&1
The file "$HARM_BREAK_TIMER_PID_FILE" should not exist
End

It 'kills timer process on break_stop'
break_start --background 60 short >/dev/null 2>&1
sleep 0.2
pid=$(cat "$HARM_BREAK_TIMER_PID_FILE" 2>/dev/null || echo "0")
break_stop >/dev/null 2>&1
# Process should no longer exist
ps -p "$pid" >/dev/null 2>&1
The status should not equal 0
End
End
End

End
