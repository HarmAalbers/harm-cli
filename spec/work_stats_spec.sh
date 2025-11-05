#!/usr/bin/env bash
# ShellSpec tests for work_stats.sh module

Describe 'lib/work_stats.sh'
Include spec/helpers/env.sh

setup_stats_test_env() {
  export HARM_LOG_LEVEL=ERROR # Suppress DEBUG/INFO logs during tests
  export HARM_WORK_DIR="$TEST_TMP/work"
  export HARM_CLI_HOME="$TEST_TMP/harm-cli"
  mkdir -p "$HARM_WORK_DIR" "$HARM_CLI_HOME"

  source "$ROOT/lib/work_stats.sh"
}

BeforeAll 'setup_stats_test_env'

cleanup_stats_test_env() {
  rm -rf "$HARM_WORK_DIR"
}

AfterAll 'cleanup_stats_test_env'

Describe 'Module Loading'
It 'sources work_stats.sh without errors'
The variable _HARM_WORK_STATS_LOADED should be defined
End

It 'exports work_stats_today function'
When call type work_stats_today
The status should be success
The output should include "function"
End

It 'exports work_stats function'
When call type work_stats
The status should be success
The output should include "function"
End
End

Describe 'work_stats_today'
It 'shows no sessions when file does not exist'
When call work_stats_today
The output should include "No sessions"
End
End

Describe 'work_stats'
It 'shows overall stats'
When call work_stats
The status should be success
The output should include "No sessions"
End
End
End
