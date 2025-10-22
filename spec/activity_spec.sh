#!/usr/bin/env bash
# ShellSpec tests for activity tracking module
# Tests command logging, performance tracking, and activity queries

Describe 'lib/activity.sh'
Include spec/helpers/env.sh

# Setup for each test block
BeforeAll 'setup_activity_env'
AfterAll 'cleanup_activity_env'

setup_activity_env() {
  export HARM_CLI_HOME="${SHELLSPEC_TMPBASE}/harm-cli"
  export HARM_ACTIVITY_DIR="${HARM_CLI_HOME}/activity"
  export HARM_ACTIVITY_LOG="${HARM_ACTIVITY_DIR}/activity.jsonl"
  export HARM_ACTIVITY_ENABLED=1
  export HARM_ACTIVITY_MIN_DURATION_MS=0 # Log everything for testing
  export HARM_ACTIVITY_EXCLUDE="ls cd pwd"

  mkdir -p "$HARM_ACTIVITY_DIR"
}

cleanup_activity_env() {
  rm -rf "$HARM_CLI_HOME"
}

# ═══════════════════════════════════════════════════════════════
# Module Loading
# ═══════════════════════════════════════════════════════════════

Describe 'Module loading'
It 'loads without errors'
When call source lib/activity.sh
The status should be success
End

It 'sets _HARM_ACTIVITY_LOADED flag'
Include lib/hooks.sh
Include lib/activity.sh
The variable _HARM_ACTIVITY_LOADED should equal 1
End

It 'creates activity directory'
Include lib/hooks.sh
Include lib/activity.sh
The directory "$HARM_ACTIVITY_DIR" should be exist
End

It 'exports activity functions'
Include lib/hooks.sh
Include lib/activity.sh
The function activity_query should be defined
The function activity_stats should be defined
The function activity_clear should be defined
The function activity_cleanup should be defined
End
End

# ═══════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════

Describe '_activity_should_log'
Include lib/hooks.sh
Include lib/activity.sh

It 'returns true for commands above duration threshold'
export HARM_ACTIVITY_MIN_DURATION_MS=100

When call _activity_should_log "git status" 150
The status should be success
End

It 'returns false for commands below duration threshold'
export HARM_ACTIVITY_MIN_DURATION_MS=100

When call _activity_should_log "git status" 50
The status should not be success
End

It 'excludes commands in exclude list'
export HARM_ACTIVITY_EXCLUDE="ls cd pwd"

When call _activity_should_log "ls" 200
The status should not be success
End

It 'allows commands not in exclude list'
export HARM_ACTIVITY_EXCLUDE="ls cd pwd"

When call _activity_should_log "git status" 200
The status should be success
End

It 'excludes harm-cli commands'
When call _activity_should_log "harm-cli work status" 200
The status should not be success
End

It 'excludes internal _harm functions'
When call _activity_should_log "_harm_chpwd_handler" 200
The status should not be success
End
End

Describe '_activity_get_project'
Include lib/hooks.sh
Include lib/activity.sh

It 'returns directory name when not in git repo'
cd "$HARM_CLI_HOME" || exit 1

When call _activity_get_project
The output should equal "harm-cli"
End

It 'returns git repo name when in git repo'
Skip if "Not in harm-cli git repo" test ! -d "$PROJECT_ROOT/.git"
cd "$PROJECT_ROOT" || exit 1

When call _activity_get_project
The output should equal "harm-cli"
End
End

# ═══════════════════════════════════════════════════════════════
# Logging Functions
# ═══════════════════════════════════════════════════════════════

Describe '_activity_log_command'
Include lib/hooks.sh
Include lib/activity.sh

It 'logs command to JSONL file'
When call _activity_log_command "git status" 0 150
The status should be success
The file "$HARM_ACTIVITY_LOG" should be exist
End

It 'creates valid JSON entry'
_activity_log_command "git status" 0 150 >/dev/null

When run jq -r '.command' "$HARM_ACTIVITY_LOG"
The output should equal "git status"
End

It 'includes exit code in log entry'
_activity_log_command "false" 1 50 >/dev/null

When run jq -r '.exit_code' "$HARM_ACTIVITY_LOG"
The output should equal "1"
End

It 'includes duration in log entry'
_activity_log_command "sleep 1" 0 1234 >/dev/null

When run jq -r '.duration_ms' "$HARM_ACTIVITY_LOG"
The output should equal "1234"
End

It 'includes timestamp in ISO 8601 format'
_activity_log_command "echo test" 0 10 >/dev/null

When run jq -r '.timestamp' "$HARM_ACTIVITY_LOG"
The output should match pattern "^[0-9]{4}-[0-9]{2}-[0-9]{2}T"
End

It 'includes current directory'
_activity_log_command "pwd" 0 10 >/dev/null

When run jq -r '.pwd' "$HARM_ACTIVITY_LOG"
The output should equal "$PWD"
End

It 'includes project name'
_activity_log_command "git log" 0 100 >/dev/null

When run jq -r '.project' "$HARM_ACTIVITY_LOG"
The output should not equal ""
End

It 'sets type to "command"'
_activity_log_command "echo test" 0 10 >/dev/null

When run jq -r '.type' "$HARM_ACTIVITY_LOG"
The output should equal "command"
End
End

Describe '_activity_log_project_switch'
Include lib/hooks.sh
Include lib/activity.sh

It 'logs project switch to JSONL file'
When call _activity_log_project_switch "/old/path" "/new/path"
The status should be success
The file "$HARM_ACTIVITY_LOG" should be exist
End

It 'sets type to "project_switch"'
_activity_log_project_switch "/old" "/new" >/dev/null

When run jq -r '.type' "$HARM_ACTIVITY_LOG"
The output should equal "project_switch"
End

It 'includes old and new paths'
_activity_log_project_switch "/old/path" "/new/path" >/dev/null

result=$(jq -r '.old_pwd + " -> " + .new_pwd' "$HARM_ACTIVITY_LOG")
When call echo "$result"
The output should equal "/old/path -> /new/path"
End
End

# ═══════════════════════════════════════════════════════════════
# Query Functions
# ═══════════════════════════════════════════════════════════════

Describe 'activity_query'
Include lib/hooks.sh
Include lib/activity.sh

setup_test_data() {
  # Create test data with different dates
  today=$(date -u +%Y-%m-%d)
  yesterday=$(date -u -d '1 day ago' +%Y-%m-%d 2>/dev/null || date -u -v-1d +%Y-%m-%d)

  cat >"$HARM_ACTIVITY_LOG" <<EOF
{"timestamp":"${today}T10:00:00Z","type":"command","command":"git status","exit_code":0,"duration_ms":100}
{"timestamp":"${today}T10:05:00Z","type":"command","command":"npm test","exit_code":0,"duration_ms":5000}
{"timestamp":"${yesterday}T15:00:00Z","type":"command","command":"docker ps","exit_code":0,"duration_ms":200}
EOF
}

It 'queries today by default'
setup_test_data

result=$(activity_query today | wc -l | tr -d ' ')
When call echo "$result"
The output should equal "2"
End

It 'queries yesterday data'
setup_test_data

result=$(activity_query yesterday | wc -l | tr -d ' ')
When call echo "$result"
The output should equal "1"
End

It 'returns JSONL format'
setup_test_data

When run sh -c "activity_query today | jq -r '.command' | head -1"
The output should satisfy _is_not_empty
End

It 'handles missing log file gracefully'
rm -f "$HARM_ACTIVITY_LOG"

When call activity_query today
The status should not be success
The stderr should include "No activity log found"
End

It 'supports all period'
setup_test_data

result=$(activity_query all | wc -l | tr -d ' ')
When call echo "$result"
The output should equal "3"
End
End

Describe 'activity_stats'
Include lib/hooks.sh
Include lib/activity.sh

setup_stats_data() {
  today=$(date -u +%Y-%m-%d)

  cat >"$HARM_ACTIVITY_LOG" <<EOF
{"timestamp":"${today}T10:00:00Z","type":"command","command":"git status","exit_code":0,"duration_ms":100,"project":"myapp"}
{"timestamp":"${today}T10:05:00Z","type":"command","command":"npm test","exit_code":0,"duration_ms":5000,"project":"myapp"}
{"timestamp":"${today}T10:10:00Z","type":"command","command":"git commit","exit_code":1,"duration_ms":50,"project":"myapp"}
{"timestamp":"${today}T10:15:00Z","type":"command","command":"docker ps","exit_code":0,"duration_ms":200,"project":"backend"}
EOF
}

It 'shows total command count'
setup_stats_data

When call activity_stats today
The output should include "Total Commands: 4"
End

It 'calculates error rate'
setup_stats_data

When call activity_stats today
The output should include "Error Rate"
End

It 'shows average duration'
setup_stats_data

When call activity_stats today
The output should include "Average Duration"
End

It 'lists top commands'
setup_stats_data

When call activity_stats today
The output should include "Top Commands"
End

It 'lists projects'
setup_stats_data

When call activity_stats today
The output should include "Projects"
The output should include "myapp"
End

It 'handles empty data gracefully'
rm -f "$HARM_ACTIVITY_LOG"
touch "$HARM_ACTIVITY_LOG"

When call activity_stats today
The output should include "No activity data"
End
End

# ═══════════════════════════════════════════════════════════════
# Maintenance Functions
# ═══════════════════════════════════════════════════════════════

Describe 'activity_clear'
Include lib/hooks.sh
Include lib/activity.sh

It 'removes activity log file'
touch "$HARM_ACTIVITY_LOG"

activity_clear >/dev/null 2>&1
The file "$HARM_ACTIVITY_LOG" should not be exist
End

It 'handles missing log file gracefully'
rm -f "$HARM_ACTIVITY_LOG"

When call activity_clear
The status should be success
End
End

Describe 'activity_cleanup'
Include lib/hooks.sh
Include lib/activity.sh

It 'removes old entries'
# Create entries with old dates
old_date=$(date -u -d '100 days ago' +%Y-%m-%d 2>/dev/null || date -u -v-100d +%Y-%m-%d)
today=$(date -u +%Y-%m-%d)

cat >"$HARM_ACTIVITY_LOG" <<EOF
{"timestamp":"${old_date}T10:00:00Z","type":"command","command":"old command"}
{"timestamp":"${today}T10:00:00Z","type":"command","command":"new command"}
EOF

activity_cleanup >/dev/null 2>&1

# Should only have 1 entry left (today's)
result=$(wc -l <"$HARM_ACTIVITY_LOG" | tr -d ' ')
When call echo "$result"
The output should equal "1"
End

It 'keeps recent entries'
today=$(date -u +%Y-%m-%d)

echo "{\"timestamp\":\"${today}T10:00:00Z\",\"type\":\"command\",\"command\":\"test\"}" >"$HARM_ACTIVITY_LOG"

activity_cleanup >/dev/null 2>&1

When run wc -l <"$HARM_ACTIVITY_LOG"
The output should match pattern "^[ ]*1"
End

It 'handles missing log file gracefully'
rm -f "$HARM_ACTIVITY_LOG"

When call activity_cleanup
The status should be success
End
End

# ═══════════════════════════════════════════════════════════════
# Hook Integration
# ═══════════════════════════════════════════════════════════════

Describe 'Hook integration'
Include lib/hooks.sh
Include lib/activity.sh

It 'registers preexec hook'
When call harm_list_hooks preexec
The output should include "_activity_preexec_hook"
End

It 'registers precmd hook'
When call harm_list_hooks precmd
The output should include "_activity_precmd_hook"
End

It 'registers chpwd hook'
When call harm_list_hooks chpwd
The output should include "_activity_chpwd_hook"
End
End

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════

Describe 'Activity configuration'
It 'respects HARM_ACTIVITY_ENABLED=0'
export HARM_ACTIVITY_ENABLED=0
Include lib/hooks.sh
Include lib/activity.sh

When call harm_list_hooks
The output should not include "_activity_preexec_hook"
End

It 'uses configured activity directory'
custom_dir="${SHELLSPEC_TMPBASE}/custom-activity"
export HARM_ACTIVITY_DIR="$custom_dir"
export HARM_ACTIVITY_LOG="${custom_dir}/activity.jsonl"

Include lib/hooks.sh
Include lib/activity.sh

The directory "$custom_dir" should be exist
End

It 'respects minimum duration threshold'
export HARM_ACTIVITY_MIN_DURATION_MS=500

When call _activity_should_log "git status" 100
The status should not be success
End

It 'respects exclude list'
export HARM_ACTIVITY_EXCLUDE="git npm docker"

When call _activity_should_log "git status" 200
The status should not be success
End
End

# ═══════════════════════════════════════════════════════════════
# End-to-End Scenarios
# ═══════════════════════════════════════════════════════════════

Describe 'End-to-end activity tracking'
Include lib/hooks.sh
Include lib/activity.sh

It 'logs command execution lifecycle'
# Simulate command execution
_activity_preexec_hook "git status"
sleep 0.1 # Simulate command duration
_activity_precmd_hook 0 "git status"

# Check log was created
The file "$HARM_ACTIVITY_LOG" should be exist
End

It 'creates valid JSON for each entry'
_activity_preexec_hook "echo test"
sleep 0.05
_activity_precmd_hook 0 "echo test"

When run jq -e '.' "$HARM_ACTIVITY_LOG"
The status should be success
End

It 'logs project switches'
_activity_chpwd_hook "/old/path" "/new/path"

result=$(jq -r 'select(.type == "project_switch") | .old_pwd' "$HARM_ACTIVITY_LOG")
When call echo "$result"
The output should equal "/old/path"
End
End
