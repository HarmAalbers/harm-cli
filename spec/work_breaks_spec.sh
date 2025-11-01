#!/usr/bin/env bash
# ShellSpec tests for work_breaks.sh module

Describe 'lib/work_breaks.sh'
Include spec/helpers/env.sh

setup_breaks_test_env() {
  export HARM_WORK_DIR="$TEST_TMP/work"
  export HARM_BREAK_STATE_FILE="$HARM_WORK_DIR/current_break.json"
  export HARM_BREAK_TIMER_PID_FILE="$HARM_WORK_DIR/break_timer.pid"
  export HARM_SCHEDULED_BREAK_PID_FILE="$HARM_WORK_DIR/scheduled_break.pid"
  export HARM_CLI_HOME="$TEST_TMP/harm-cli"
  mkdir -p "$HARM_WORK_DIR" "$HARM_CLI_HOME"

  source "$ROOT/lib/work_breaks.sh"
}

BeforeAll 'setup_breaks_test_env'

cleanup_breaks_test_env() {
  rm -rf "$HARM_WORK_DIR"
}

AfterAll 'cleanup_breaks_test_env'

Describe 'Module Loading'
It 'sources work_breaks.sh without errors'
The variable _HARM_WORK_BREAKS_LOADED should be defined
End

It 'exports break_is_active function'
When call type break_is_active
The status should be success
End

It 'exports break_start function'
When call type break_start
The status should be success
End

It 'exports break_stop function'
When call type break_stop
The status should be success
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
The output should include "not running"
End
End
End
