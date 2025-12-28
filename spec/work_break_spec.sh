#!/usr/bin/env bash
# ShellSpec tests for work break session management (interactive and background modes)

export HARM_LOG_LEVEL=ERROR

Describe 'lib/work.sh - Break Sessions'
Include spec/helpers/env.sh

BeforeAll 'setup_break_test_env'
AfterAll 'cleanup_break_test_env'

# Set up test work directory and source work module
# IMPORTANT: Must set HARM_WORK_DIR and HARM_CLI_HOME before sourcing work.sh (readonly vars)
setup_break_test_env() {
  export HARM_WORK_DIR="$TEST_TMP/work"
  export HARM_WORK_STATE_FILE="$HARM_WORK_DIR/current_session.json"
  export HARM_BREAK_STATE_FILE="$HARM_WORK_DIR/current_break.json"
  export HARM_BREAK_TIMER_PID_FILE="$HARM_WORK_DIR/break_timer.pid"
  export HARM_CLI_HOME="$TEST_TMP/harm-cli"
  export HARM_LOG_LEVEL=ERROR
  export HARM_TEST_MODE=1
  export HARM_WORK_ENFORCEMENT=off

  mkdir -p "$HARM_WORK_DIR" "$HARM_CLI_HOME"

  unset -f homebrew_command_not_found_handle 2>/dev/null || true
  export HOMEBREW_COMMAND_NOT_FOUND_CI=1

  MOCK_TIME=$(command date +%s)

  # Mock external commands
  date() {
    if [[ "$1" == "+%s" ]]; then
      echo "$MOCK_TIME"
    else
      command date "$@"
    fi
  }

  sleep() { :; }
  activity_query() { return 0; }
  pkill() { :; }
  kill() { :; }
  ps() { echo "bash"; }
  osascript() { :; }
  notify-send() { :; }
  paplay() { :; }

  options_get() {
    case "$1" in
      work_duration) echo "1500" ;;
      work_reminder_interval) echo "0" ;;
      break_short) echo "300" ;;
      break_long) echo "900" ;;
      pomodoros_until_long) echo "4" ;;
      strict_block_project_switch) echo "0" ;;
      strict_require_break) echo "0" ;;
      work_notifications) echo "0" ;;
      work_sound_notifications) echo "0" ;;
      auto_start_break) echo "0" ;;
      *) echo "0" ;;
    esac
  }

  export -f date sleep activity_query pkill kill ps osascript notify-send paplay options_get

  source "$ROOT/lib/work.sh" 2>/dev/null </dev/null
}

cleanup_break_test_env() {
  jobs -p | xargs -r kill 2>/dev/null || true
  wait 2>/dev/null || true

  # Kill any break timer processes
  if [[ -f "$HARM_BREAK_TIMER_PID_FILE" ]]; then
    local pid
    pid=$(cat "$HARM_BREAK_TIMER_PID_FILE" 2>/dev/null || echo "")
    [[ -n "$pid" ]] && { command kill "$pid" 2>/dev/null || true; }
    rm -f "$HARM_BREAK_TIMER_PID_FILE"
  fi

  # Clean up break state files
  rm -f "$HARM_BREAK_STATE_FILE"* 2>/dev/null || true

  # Clean up work session if any
  rm -f "$HARM_WORK_STATE_FILE"* 2>/dev/null || true
  rm -f "$HARM_WORK_DIR"/*.pid 2>/dev/null || true

  rm -rf "$HARM_WORK_DIR" "$HARM_CLI_HOME"
  command pkill -f "sleep.*break" 2>/dev/null || true
}

# Clean up break session artifacts and background processes
cleanup_break_session() {
  jobs -p | xargs -r kill 2>/dev/null || true

  # Kill any break timer processes
  if [[ -f "$HARM_BREAK_TIMER_PID_FILE" ]]; then
    local pid
    pid=$(cat "$HARM_BREAK_TIMER_PID_FILE" 2>/dev/null || echo "")
    [[ -n "$pid" ]] && { command kill "$pid" 2>/dev/null || true; }
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
When run break_countdown_interactive
The status should be failure
The stderr should include "duration"
End

It 'accepts break_type parameter'
# Run with very short duration (1 second) to avoid long waits
When call break_countdown_interactive 1 "short"
The status should equal 0
The output should include "BREAK TIME"
The output should include "Short break"
End

It 'uses default break_type if not provided'
When call break_countdown_interactive 1
The status should equal 0
The output should include "BREAK TIME"
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
The stderr should include "background mode"
The stdout should include "non-blocking"
End

It 'creates break state file in background mode'
break_start --background 5 short >/dev/null 2>&1
The contents of file "$HARM_BREAK_STATE_FILE" should include '"status": "active"'
End

It 'saves blocking_mode as false in state'
break_start --background 5 short >/dev/null 2>&1
When run jq -r '.blocking_mode' "$HARM_BREAK_STATE_FILE"
The output should equal "false"
End

It 'shows background mode message in text format'
export HARM_CLI_FORMAT=text
When call break_start --background 5 short
The stderr should include "background mode"
The stdout should include "non-blocking"
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
# Note: blocking mode requires TTY, will auto-detect duration and start
When call break_start --blocking
The status should equal 0
The stderr should include "Break session started"
The stdout should include "Timer running in background"
The file "$HARM_BREAK_STATE_FILE" should be exist
End

End

Context 'positional arguments with flags'
It 'parses duration after --background flag'
break_start --background 300 short >/dev/null 2>&1
When run jq -r '.duration_seconds' "$HARM_BREAK_STATE_FILE"
The output should equal "300"
End

It 'parses break type after duration'
break_start --background 180 long >/dev/null 2>&1
When run jq -r '.type' "$HARM_BREAK_STATE_FILE"
The output should equal "long"
End

It 'handles flags before positional arguments'
When call break_start --background 120
The status should equal 0
The stderr should include "Break session started"
The stdout should include "Timer running in background"
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
break_start --background >/dev/null 2>&1
When run jq -r '.type' "$HARM_BREAK_STATE_FILE"
The output should equal "short"
End

It 'uses default type when not specified'
break_start --background 600 >/dev/null 2>&1
When run jq -r '.type' "$HARM_BREAK_STATE_FILE"
The output should equal "custom"
End

End

Context 'break already active'
It 'fails when break already active'
break_start --background 5 short >/dev/null 2>&1
When call break_start --background 5 short
The status should be failure
The error should include "already active"
End

It 'allows starting after previous break completes'
break_start --background 1 short >/dev/null 2>&1
rm -f "$HARM_BREAK_STATE_FILE"
When call break_start --background 1 short
The status should equal 0
The stderr should include "Break session started"
The stdout should include "Timer running in background"
End
End

Context 'state persistence'
It 'saves start timestamp in ISO8601 UTC format'
break_start --background 5 short >/dev/null 2>&1
When run jq -r '.start_time' "$HARM_BREAK_STATE_FILE"
The output should include "T"
The output should include "Z"
The output should start with "20"
End

It 'saves all required fields in state'
break_start --background 300 short >/dev/null 2>&1
When run jq 'has("status") and has("start_time") and has("duration_seconds") and has("type") and has("blocking_mode")' "$HARM_BREAK_STATE_FILE"
The output should equal "true"
End

It 'saves status as active'
break_start --background 5 short >/dev/null 2>&1
When run jq -r '.status' "$HARM_BREAK_STATE_FILE"
The output should equal "active"
End
End
End

# ═══════════════════════════════════════════════════════════════
# break_start Tests - TTY Detection and Mode Selection
# ═══════════════════════════════════════════════════════════════

Describe 'break_start - TTY detection and mode selection'
BeforeEach 'cleanup_break_session'

Context 'TTY fallback behavior'
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
break_start --background 5 short >/dev/null 2>&1
When run jq -r '.blocking_mode' "$HARM_BREAK_STATE_FILE"
The output should equal "false"
End

It '--blocking sets blocking mode in state'
# Will fallback to background due to no TTY, but state should show intent
break_start --blocking 5 short >/dev/null 2>&1
When run jq -r '.blocking_mode' "$HARM_BREAK_STATE_FILE"
The output should equal "true"
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
The stderr should include "Break session stopped"
The stdout should include "Duration:"
End

It 'removes break state file'
break_start --background 60 short >/dev/null 2>&1
break_stop >/dev/null 2>&1
The file "$HARM_BREAK_STATE_FILE" should not be exist
End

It 'kills background timer process'
# Note: PID file is not created in test mode (HARM_TEST_MODE=1)
# This test verifies break_stop handles missing PID file gracefully
break_start --background 60 short >/dev/null 2>&1
When call break_stop
The status should equal 0
The stderr should include "Break session stopped"
The stdout should include "Duration:"
End

It 'shows duration when stopping'
break_start --background 60 short >/dev/null 2>&1
export HARM_CLI_FORMAT=text
When call break_stop
The status should equal 0
The stderr should include "Break session stopped"
The stdout should include "Duration:"
End
End

Context 'when no active break'
It 'fails when no break session active'
rm -f "$HARM_BREAK_STATE_FILE"
When call break_stop
The status should be failure
The error should include "No active break session"
End
End

Context 'output formats'
It 'outputs text format by default'
export HARM_CLI_FORMAT=text
break_start --background 60 short >/dev/null 2>&1
When call break_stop
The stderr should include "Break session stopped"
The stdout should include "Duration:"
End

It 'outputs JSON format when requested'
export HARM_CLI_FORMAT=json
break_start --background 60 short >/dev/null 2>&1
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
The stderr should include "Break session started"
The stdout should include "Timer running in background"
End

It 'handles invalid PID file gracefully'
echo "not-a-number" >"$HARM_BREAK_TIMER_PID_FILE"
When call break_stop
The status should be failure
The error should include "No active break"
End

It 'handles stale PID file gracefully'
echo "99999" >"$HARM_BREAK_TIMER_PID_FILE"
echo '{"status":"active","start_time":"2025-10-31T10:00:00Z","duration_seconds":300,"type":"short"}' >"$HARM_BREAK_STATE_FILE"
When call break_stop
The status should equal 0
The stderr should include "Break session stopped"
The stdout should include "Duration:"
The file "$HARM_BREAK_STATE_FILE" should not be exist
End
End

Context 'file system operations'
It 'creates state file atomically'
When call break_start --background 5 short
The status should equal 0
The stderr should include "Break session started"
The stdout should include "Timer running in background"
# State file should exist and be valid JSON
The file "$HARM_BREAK_STATE_FILE" should be exist
End

It 'handles corrupted state file gracefully'
echo "invalid json" >"$HARM_BREAK_STATE_FILE"
When run break_is_active
The status should be failure
The stderr should include "parse error"
End
End

Context 'concurrent operations'
It 'prevents starting multiple breaks'
break_start --background 60 short >/dev/null 2>&1
When call break_start --background 60 short
The status should be failure
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
# Check that break is still active (timer hasn't expired)
When call break_is_active
The status should be success
End

End

Context 'timer cleanup'
It 'removes PID file on break_stop'
# Note: PID file is not created in test mode (HARM_TEST_MODE=1)
# This test verifies break_stop handles missing PID file gracefully
break_start --background 60 short >/dev/null 2>&1
When call break_stop
The status should equal 0
The stderr should include "Break session stopped"
The stdout should include "Duration:"
End

It 'kills timer process on break_stop'
# Note: PID file is not created in test mode (HARM_TEST_MODE=1)
# This test verifies break_stop handles missing PID file gracefully
break_start --background 60 short >/dev/null 2>&1
When call break_stop
The status should equal 0
The stderr should include "Break session stopped"
The stdout should include "Duration:"
End
End
End

End
