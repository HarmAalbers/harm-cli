#!/usr/bin/env bash
# ShellSpec tests for goal tracking

Describe 'lib/goals.sh'
Include spec/helpers/env.sh

# Set up test goals directory
BeforeAll 'export HARM_LOG_LEVEL=ERROR && export HARM_GOALS_DIR="$TEST_TMP/goals" && mkdir -p "$HARM_GOALS_DIR"'

# Clean up after tests
AfterAll 'rm -rf "$HARM_GOALS_DIR"'

# Source the goals module
BeforeAll 'source "$ROOT/lib/goals.sh"'

Describe 'Configuration'
It 'creates goals directory'
The directory "$HARM_GOALS_DIR" should be exist
End

It 'exports configuration variables'
The variable HARM_GOALS_DIR should be exported
End
End

Describe 'goal_file_for_today'
It 'returns path to today goal file'
When call goal_file_for_today
The output should include "$(date '+%Y-%m-%d').jsonl"
End
End

Describe 'goal_exists_today'
It 'returns false when no goals exist'
rm -f "$(goal_file_for_today)"
When call goal_exists_today
The status should be failure
End

It 'returns true when goals exist'
echo '{"goal":"test"}' >"$(goal_file_for_today)"
When call goal_exists_today
The status should be success
End
End

Describe 'goal_set'
BeforeEach 'rm -f "$(goal_file_for_today)"'

It 'sets a new goal'
export HARM_CLI_FORMAT=text
When call goal_set "Complete refactoring"
The status should be success
The output should include "Goal: Complete refactoring"
The error should include "Goal set"
The file "$(goal_file_for_today)" should be exist
End

It 'saves goal as JSON Lines'
goal_set "Test goal" >/dev/null 2>&1
goal_file="$(goal_file_for_today)"
The contents of file "$goal_file" should include '"goal"'
The contents of file "$goal_file" should include '"progress"'
The contents of file "$goal_file" should include '"completed"'
End

It 'supports time estimation'
goal_set "Test goal" 120 >/dev/null 2>&1
The contents of file "$(goal_file_for_today)" should include '"estimated_minutes"'
The contents of file "$(goal_file_for_today)" should include '120'
End

It 'outputs JSON format when requested'
export HARM_CLI_FORMAT=json
When call goal_set "Test goal" 60
The output should include '"status"'
The output should include '"goal"'
The output should include '"estimated_minutes"'
The error should include "[INFO]"
End

Describe 'Duration format parsing'
It 'accepts minutes format (30m)'
goal_set "Test goal" "30m" >/dev/null 2>&1
goal_file="$(goal_file_for_today)"
# Should parse 30m to 30 minutes
The contents of file "$goal_file" should include '"estimated_minutes":30'
End

It 'accepts hours format (4h)'
rm -f "$(goal_file_for_today)"
goal_set "Test goal" "4h" >/dev/null 2>&1
goal_file="$(goal_file_for_today)"
# Should parse 4h (14400s) to 240 minutes
The contents of file "$goal_file" should include '"estimated_minutes":240'
End

It 'accepts combined format (2h30m)'
rm -f "$(goal_file_for_today)"
goal_set "Test goal" "2h30m" >/dev/null 2>&1
goal_file="$(goal_file_for_today)"
# Should parse 2h30m (9000s) to 150 minutes
The contents of file "$goal_file" should include '"estimated_minutes":150'
End

It 'accepts plain integer (90)'
rm -f "$(goal_file_for_today)"
goal_set "Test goal" 90 >/dev/null 2>&1
goal_file="$(goal_file_for_today)"
# Plain integer should work as-is
The contents of file "$goal_file" should include '"estimated_minutes":90'
End

It 'displays formatted duration in text output'
export HARM_CLI_FORMAT=text
rm -f "$(goal_file_for_today)"
When call goal_set "Test goal" "2h"
The output should include "Estimated time: 2h"
The error should include "Goal set"
End

It 'rejects invalid duration format'
When run bash -c "source $ROOT/lib/goals.sh && goal_set 'Test' 'invalid_format'"
The status should equal "$EXIT_INVALID_ARGS"
The error should include "Invalid duration"
End

It 'rejects negative values'
When run bash -c "source $ROOT/lib/goals.sh && goal_set 'Test' '-30'"
The status should equal "$EXIT_INVALID_ARGS"
The error should include "must be greater than 0"
End

It 'rejects zero values'
When run bash -c "source $ROOT/lib/goals.sh && goal_set 'Test' '0'"
The status should equal "$EXIT_INVALID_ARGS"
The error should include "must be greater than 0"
End
End

It 'validates estimated minutes is integer (legacy)'
When run bash -c "source $ROOT/lib/goals.sh && goal_set 'Test' 'not_a_number'"
The status should equal "$EXIT_INVALID_ARGS"
The error should include "Invalid duration"
End
End

Describe 'goal_show'
It 'shows message when no goals'
rm -f "$(goal_file_for_today)"
export HARM_CLI_FORMAT=text
When call goal_show
The output should include "No goals set"
End

It 'lists goals'
export HARM_CLI_FORMAT=text
goal_set "First goal" >/dev/null 2>&1
goal_set "Second goal" >/dev/null 2>&1
When call goal_show
The output should include "First goal"
The output should include "Second goal"
End

It 'outputs JSON format'
export HARM_CLI_FORMAT=json
goal_set "Test goal" >/dev/null 2>&1
When call goal_show
The output should include '"goal"'
End
End

Describe 'goal_update_progress'
BeforeEach 'rm -f "$(goal_file_for_today)" && goal_set "Test goal" >/dev/null 2>&1'

It 'updates goal progress'
export HARM_CLI_FORMAT=text
When call goal_update_progress 1 50
The status should be success
The error should include "updated to 50%"
End

It 'updates JSON file'
goal_update_progress 1 75 >/dev/null 2>&1
The contents of file "$(goal_file_for_today)" should include '"progress"'
The contents of file "$(goal_file_for_today)" should include '75'
End

It 'marks as completed at 100%'
goal_update_progress 1 100 >/dev/null 2>&1
The contents of file "$(goal_file_for_today)" should include '"completed"'
The contents of file "$(goal_file_for_today)" should include 'true'
End

It 'validates progress is 0-100'
When run bash -c "source $ROOT/lib/goals.sh && goal_set 'Test' >/dev/null 2>&1 && goal_update_progress 1 150"
The status should equal "$EXIT_INVALID_ARGS"
The error should include "between 0-100"
End
End

Describe 'goal_complete'
BeforeEach 'rm -f "$(goal_file_for_today)" && goal_set "Test goal" >/dev/null 2>&1'

It 'marks goal as 100% complete'
goal_complete 1 >/dev/null 2>&1
The contents of file "$(goal_file_for_today)" should include '"progress"'
The contents of file "$(goal_file_for_today)" should include '100'
The contents of file "$(goal_file_for_today)" should include '"completed"'
The contents of file "$(goal_file_for_today)" should include 'true'
End
End

Describe 'goal_reopen'
BeforeEach 'rm -f "$(goal_file_for_today)"'

It 'reopens a completed goal with new progress'
export HARM_CLI_FORMAT=text
goal_set "Test goal" >/dev/null 2>&1
goal_complete 1 >/dev/null 2>&1
When call goal_reopen 1 50
The status should be success
The error should include "Goal reopened"
End

It 'sets completed=false when reopening'
goal_set "Test goal" >/dev/null 2>&1
goal_complete 1 >/dev/null 2>&1
goal_reopen 1 0 >/dev/null 2>&1
The contents of file "$(goal_file_for_today)" should include '"completed":false'
End

It 'updates progress to specified value'
goal_set "Test goal" >/dev/null 2>&1
goal_complete 1 >/dev/null 2>&1
goal_reopen 1 75 >/dev/null 2>&1
The contents of file "$(goal_file_for_today)" should include '"progress":75'
End

It 'reopens non-completed goals (for fixing mistakes)'
goal_set "Test goal" >/dev/null 2>&1
goal_update_progress 1 30 >/dev/null 2>&1
goal_reopen 1 0 >/dev/null 2>&1
The contents of file "$(goal_file_for_today)" should include '"progress":0'
The contents of file "$(goal_file_for_today)" should include '"completed":false'
End

It 'outputs JSON format when requested'
export HARM_CLI_FORMAT=json
goal_set "Test goal" >/dev/null 2>&1
goal_complete 1 >/dev/null 2>&1
When call goal_reopen 1 50
The output should include '"status"'
The output should include '"reopened"'
The output should include '"progress"'
The output should include '50'
The output should include '"completed"'
The output should include 'false'
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End

It 'validates progress is 0-100'
goal_set "Test goal" >/dev/null 2>&1
goal_complete 1 >/dev/null 2>&1
When run bash -c "source $ROOT/lib/goals.sh && goal_reopen 1 150"
The status should equal "$EXIT_INVALID_ARGS"
The error should include "between 0-100"
End

It 'requires both goal_number and progress arguments'
goal_set "Test goal" >/dev/null 2>&1
When run bash -c "source $ROOT/lib/goals.sh && goal_reopen 1"
The status should be failure
The error should include "requires progress"
End

It 'validates goal_number is integer'
goal_set "Test goal" >/dev/null 2>&1
When run bash -c "source $ROOT/lib/goals.sh && goal_reopen 'not_a_number' 50"
The status should equal "$EXIT_INVALID_ARGS"
The error should include "must be an integer"
End

It 'validates progress is integer'
goal_set "Test goal" >/dev/null 2>&1
When run bash -c "source $ROOT/lib/goals.sh && goal_reopen 1 'not_a_number'"
The status should equal "$EXIT_INVALID_ARGS"
The error should include "must be an integer"
End
End

Describe 'goal_clear'
BeforeEach 'rm -f "$(goal_file_for_today)" && goal_set "Test goal" >/dev/null 2>&1'

It 'requires --force flag'
When call goal_clear
The status should be failure
The error should include "--force"
End

It 'clears goals with --force'
When call goal_clear --force
The status should be success
The error should include "Goals cleared"
The file "$(goal_file_for_today)" should not be exist
End
End
End
