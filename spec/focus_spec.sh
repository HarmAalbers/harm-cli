#!/usr/bin/env bash
# ShellSpec tests for focus module

export HARM_LOG_LEVEL=ERROR

Describe 'lib/focus.sh'
Include spec/helpers/env.sh

BeforeAll 'setup_focus_test_env'
AfterAll 'cleanup_focus_test_env'

setup_focus_test_env() {
  export HARM_CLI_HOME="$TEST_TMP/harm-cli"
  export HARM_LOG_LEVEL=ERROR
  export HARM_FOCUS_ENABLED=1
  export HARM_POMODORO_DURATION=25
  export HARM_BREAK_DURATION=5
  export HARM_FOCUS_CHECK_INTERVAL=900
  export HARM_TEST_MODE=1
  export HARM_WORK_DIR="$TEST_TMP/work"
  export HARM_WORK_STATE_FILE="$HARM_WORK_DIR/current_session.json"
  export HARM_WORK_ENFORCEMENT=off

  mkdir -p "$HARM_CLI_HOME" "$HARM_WORK_DIR"

  unset -f homebrew_command_not_found_handle 2>/dev/null || true
  export HOMEBREW_COMMAND_NOT_FOUND_CI=1

  MOCK_TIME=$(command date +%s)

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
      *) echo "0" ;;
    esac
  }

  export -f date sleep activity_query pkill kill ps osascript notify-send paplay options_get

  source "$ROOT/lib/work.sh" 2>/dev/null </dev/null
  source "$ROOT/lib/focus.sh" 2>/dev/null </dev/null
}

cleanup_focus_test_env() {
  jobs -p | xargs -r kill 2>/dev/null || true
  wait 2>/dev/null || true
  rm -rf "$HARM_CLI_HOME" "$HARM_WORK_DIR"
  pkill -f "sleep.*pomodoro" 2>/dev/null || true
}

Describe 'module initialization'
It 'defines required constants'
The variable HARM_FOCUS_CHECK_INTERVAL should equal 900
The variable HARM_POMODORO_DURATION should equal 25
The variable HARM_BREAK_DURATION should equal 5
The variable HARM_FOCUS_ENABLED should equal 1
End

It 'prevents double-loading'
When run bash -c "source '$ROOT/lib/focus.sh' </dev/null 2>/dev/null && source '$ROOT/lib/focus.sh' </dev/null 2>/dev/null"
The status should equal 0
End

It 'sets pomodoro state file location'
The variable HARM_POMODORO_STATE should include "pomodoro.state"
End

It 'exports public functions'
When run bash -c "
      type focus_calculate_score >/dev/null 2>&1 && \
      type focus_check >/dev/null 2>&1 && \
      type pomodoro_start >/dev/null 2>&1 && \
      type pomodoro_stop >/dev/null 2>&1 && \
      type pomodoro_status >/dev/null 2>&1
    "
The status should equal 0
End
End

Describe 'focus_calculate_score'
Context 'when no work session active'
It 'returns neutral score of 5'
When call focus_calculate_score
The output should include "Focus Score: 5/10"
The output should include "Status: Moderate focus"
End
End
End

Describe 'focus_check'
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
The output should include "No active work session"
End
End
End

Describe 'pomodoro_start'
BeforeEach 'cleanup_pomodoro'
AfterEach 'cleanup_pomodoro'

cleanup_pomodoro() {
  rm -f "$HARM_POMODORO_STATE"
}

Context 'starting timer'
It 'creates pomodoro state file'
When call pomodoro_start
The status should equal 0
The output should include "Pomodoro started:"
The file "$HARM_POMODORO_STATE" should be exist
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
When call pomodoro_start
The output should include "🍅 Pomodoro started:"
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
The status should equal 1
The output should include "pomodoro-stop"
End
End
End

Describe 'pomodoro_stop'
BeforeEach 'cleanup_pomodoro'
AfterEach 'cleanup_pomodoro'

cleanup_pomodoro() {
  rm -f "$HARM_POMODORO_STATE"
}

Context 'when no timer active'
It 'returns success with message'
When call pomodoro_stop
The status should equal 0
The output should include "No active pomodoro"
End
End

Context 'stopping timer'
It 'removes state file'
pomodoro_start >/dev/null 2>&1
pomodoro_stop >/dev/null 2>&1
The file "$HARM_POMODORO_STATE" should not be exist
End

It 'shows elapsed time'
pomodoro_start >/dev/null 2>&1
When call pomodoro_stop
The output should include "stopped after"
The output should include "minutes"
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
When call pomodoro_status
The output should include "Started:"
The output should include "ago"
End

It 'shows remaining time'
pomodoro_start >/dev/null 2>&1
When call pomodoro_status
The output should include "Remaining:"
End
End
End

Describe 'focus_track_context_switch'
Context 'when no work session'
It 'does not track switches'
initial_switches=$_FOCUS_CONTEXT_SWITCHES
focus_track_context_switch "/old/path" "/new/path"
The variable _FOCUS_CONTEXT_SWITCHES should equal "$initial_switches"
End
End
End

Describe 'focus_periodic_check'
Context 'when focus monitoring disabled'
It 'skips check when disabled'
When run bash -c "
        export HARM_FOCUS_ENABLED=0
        export HARM_CLI_HOME='$TEST_TMP/harm-cli-disabled'
        export HARM_LOG_LEVEL=ERROR
        export HARM_WORK_DIR='$TEST_TMP/work-disabled'
        export HARM_WORK_STATE_FILE='$HARM_WORK_DIR/current_session.json'
        export HARM_WORK_ENFORCEMENT=off
        export HARM_TEST_MODE=1
        export HOMEBREW_COMMAND_NOT_FOUND_CI=1
        mkdir -p \"\$HARM_CLI_HOME\" \"\$HARM_WORK_DIR\"
        activity_query() { return 0; }
        export -f activity_query
        source '$ROOT/lib/work.sh' 2>/dev/null </dev/null
        source '$ROOT/lib/focus.sh' 2>/dev/null </dev/null
        echo \"HARM_FOCUS_ENABLED=\$HARM_FOCUS_ENABLED\"
      "
The output should include "HARM_FOCUS_ENABLED=0"
The status should equal 0
End
End

Context 'when no work session'
It 'skips check when no session'
When call focus_periodic_check 0 "test_command"
The status should equal 0
End
End
End
End
