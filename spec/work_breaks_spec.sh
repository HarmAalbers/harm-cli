#!/usr/bin/env bash
# ShellSpec tests for work_breaks.sh module

export HARM_LOG_LEVEL=ERROR

Describe 'lib/work_breaks.sh'
Include spec/helpers/env.sh

BeforeAll 'setup_breaks_test_env'
AfterAll 'cleanup_breaks_test_env'

setup_breaks_test_env() {
  export HARM_WORK_DIR="$TEST_TMP/work"
  export HARM_BREAK_STATE_FILE="$HARM_WORK_DIR/current_break.json"
  export HARM_BREAK_TIMER_PID_FILE="$HARM_WORK_DIR/break_timer.pid"
  export HARM_SCHEDULED_BREAK_PID_FILE="$HARM_WORK_DIR/scheduled_break.pid"
  export HARM_CLI_HOME="$TEST_TMP/harm-cli"
  export HARM_LOG_LEVEL=ERROR
  export HARM_TEST_MODE=1
  export HARM_WORK_STATE_FILE="$HARM_WORK_DIR/current_session.json"
  export HARM_WORK_ENFORCEMENT=off

  mkdir -p "$HARM_WORK_DIR" "$HARM_CLI_HOME"

  # Disable Homebrew command-not-found handler
  unset -f homebrew_command_not_found_handle 2>/dev/null || true
  export HOMEBREW_COMMAND_NOT_FOUND_CI=1

  # Mock time to prevent hangs
  MOCK_TIME=$(command date +%s)

  date() {
    if [[ "$1" == "+%s" ]]; then
      echo "$MOCK_TIME"
    else
      command date "$@"
    fi
  }

  # Mock blocking/external commands that could hang
  sleep() { :; }
  activity_query() { return 0; }
  pkill() { :; }
  kill() { :; }
  ps() { echo "bash"; }
  osascript() { :; }
  notify-send() { :; }
  paplay() { :; }

  # Mock options_get to avoid config file reads
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
      *) echo "0" ;;
    esac
  }

  # Export all mocked functions
  export -f date sleep activity_query pkill kill ps osascript notify-send paplay options_get

  # Source modules with redirects to prevent hangs
  source "$ROOT/lib/work.sh" 2>/dev/null </dev/null
  source "$ROOT/lib/work_breaks.sh" 2>/dev/null </dev/null
}

cleanup_breaks_test_env() {
  # Kill any background jobs that might be running
  jobs -p | xargs -r kill 2>/dev/null || true
  wait 2>/dev/null || true

  # Clean up state files
  rm -rf "$HARM_WORK_DIR" "$HARM_CLI_HOME"

  # Kill any stray sleep processes from tests
  pkill -f "sleep.*break" 2>/dev/null || true
}

Describe 'Module Loading'
It 'sources work_breaks.sh without errors'
The variable _HARM_WORK_BREAKS_LOADED should be defined
End

It 'exports break_is_active function'
When call type break_is_active
The status should be success
The output should include "function"
End

It 'exports break_start function'
When call type break_start
The status should be success
The output should include "function"
End

It 'exports break_stop function'
When call type break_stop
The status should be success
The output should include "function"
End
End

Describe 'break_is_active'
It 'returns false when no break file exists'
rm -f "$HARM_BREAK_STATE_FILE"
When call break_is_active
The status should be failure
End

It 'returns true when break is active'
echo '{"status":"active"}' >"$HARM_BREAK_STATE_FILE"
When call break_is_active
The status should be success
End
End

Describe 'break_stop'
It 'fails when no active break'
rm -f "$HARM_BREAK_STATE_FILE"
When run break_stop
The status should be failure
The stderr should include "No active break"
End
End

Describe 'break_status'
It 'shows inactive when no break'
rm -f "$HARM_BREAK_STATE_FILE"
When call break_status
The output should include "No active"
The status should be success
End
End

Describe 'scheduled_break_status'
It 'shows daemon not running when no PID file'
rm -f "$HARM_SCHEDULED_BREAK_PID_FILE"
When call scheduled_break_status
The output should include "DISABLED"
End
End
End
