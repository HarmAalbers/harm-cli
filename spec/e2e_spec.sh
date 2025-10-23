#!/usr/bin/env bash
# ShellSpec E2E (End-to-End) Integration Tests
# Tests real workflows and cross-module integration

Describe 'E2E: harm-cli Integration Tests'
Include spec/helpers/env.sh

# Set up isolated test environment
BeforeAll '
    export HARM_GOALS_DIR="$TEST_TMP/goals"
    export HARM_WORK_DIR="$TEST_TMP/work"
    export HARM_WORK_STATE_FILE="$HARM_WORK_DIR/current_session.json"
    export HARM_CLI_HOME="$TEST_TMP/harm-cli"
    export HARM_CLI_LOG_LEVEL="ERROR"  # Quiet logs for cleaner test output
    mkdir -p "$HARM_GOALS_DIR" "$HARM_WORK_DIR" "$HARM_CLI_HOME"
  '

# Clean up after all tests
AfterAll '
    rm -rf "$HARM_GOALS_DIR" "$HARM_WORK_DIR" "$HARM_CLI_HOME"
  '

# Source all required modules for E2E tests
BeforeAll '
    source "$ROOT/lib/common.sh"
    source "$ROOT/lib/error.sh"
    source "$ROOT/lib/logging.sh"
    source "$ROOT/lib/util.sh"
    source "$ROOT/lib/work.sh"
    source "$ROOT/lib/goals.sh"
  '

#═══════════════════════════════════════════════════════════════════
# E2E Scenario 1: Complete Work Session Workflow
#═══════════════════════════════════════════════════════════════════

Describe 'Scenario 1: Complete Work Session with Goals'
# Clean state before each scenario
BeforeEach '
      rm -f "$HARM_WORK_STATE_FILE"*
      rm -f "$HARM_GOALS_DIR"/*.jsonl
    '

It 'starts work session, sets goals, tracks progress, completes work'
# Step 1: Start work session
export HARM_CLI_FORMAT=text
work_start "Phase 3 Implementation" >/dev/null 2>&1
When call work_is_active
The status should be success

# Step 2: Set multiple goals
goal_set "Write E2E tests" "2h" >/dev/null 2>&1
goal_set "Update documentation" "1h" >/dev/null 2>&1
goal_set "Review changes" "30m" >/dev/null 2>&1

# Step 3: Verify goals exist
When call goal_exists_today
The status should be success

# Step 4: Update progress on first goal
goal_update_progress 1 50 >/dev/null 2>&1
goal_file="$(goal_file_for_today)"
The contents of file "$goal_file" should include '"progress":50'

# Step 5: Complete second goal
goal_complete 2 >/dev/null 2>&1
The contents of file "$goal_file" should include '"completed":true'

# Step 6: Stop work session
When call work_stop
The status should be success
The output should include "Work session completed"

# Step 7: Verify session is inactive
When call work_is_active
The status should be failure
End

It 'handles work session with no goals gracefully'
export HARM_CLI_FORMAT=text

# Start work without setting goals
work_start "Quick task" >/dev/null 2>&1

# Verify work is active but no goals exist
work_is_active
goal_exists_today && return 1

# Should be able to stop work without goals
When call work_stop
The status should be success
End

It 'prevents starting multiple work sessions'
export HARM_CLI_FORMAT=text

# Start first session
work_start "Task 1" >/dev/null 2>&1

# Try to start second session (should fail)
When call work_start "Task 2"
The status should be failure
The error should include "already active"
End
End

#═══════════════════════════════════════════════════════════════════
# E2E Scenario 2: Goal Tracking Workflow
#═══════════════════════════════════════════════════════════════════

Describe 'Scenario 2: Complex Goal Tracking'
BeforeEach 'rm -f "$HARM_GOALS_DIR"/*.jsonl'

It 'tracks multiple goals with different durations'
export HARM_CLI_FORMAT=text

# Set goals with various duration formats
goal_set "Quick fix" "15m" >/dev/null 2>&1
goal_set "Feature development" "4h" >/dev/null 2>&1
goal_set "Code review" "2h30m" >/dev/null 2>&1
goal_set "Testing" 90 >/dev/null 2>&1 # Plain integer minutes

# Verify all goals exist
goal_file="$(goal_file_for_today)"
The file "$goal_file" should be exist

# Should have 4 goals (4 lines in JSONL)
When call wc -l <"$goal_file"
The output should equal "4"

# Verify duration parsing
The contents of file "$goal_file" should include '"estimated_minutes":15'
The contents of file "$goal_file" should include '"estimated_minutes":240'
The contents of file "$goal_file" should include '"estimated_minutes":150'
The contents of file "$goal_file" should include '"estimated_minutes":90'
End

It 'tracks goal progress incrementally'
goal_set "Incremental task" "1h" >/dev/null 2>&1
goal_file="$(goal_file_for_today)"

# Progress from 0% → 25% → 50% → 75% → 100%
goal_update_progress 1 25 >/dev/null 2>&1
goal_update_progress 1 50 >/dev/null 2>&1
goal_update_progress 1 75 >/dev/null 2>&1
goal_update_progress 1 100 >/dev/null 2>&1

# Should be marked complete
The contents of file "$goal_file" should include '"progress":100'
The contents of file "$goal_file" should include '"completed":true'
End

It 'handles goal completion shortcut'
goal_set "Task to complete" >/dev/null 2>&1
goal_file="$(goal_file_for_today)"

# Complete directly (should set progress=100 and completed=true)
When call goal_complete 1
The status should be success
The contents of file "$goal_file" should include '"progress":100'
The contents of file "$goal_file" should include '"completed":true'
End

It 'maintains goal order and numbering'
# Set 5 goals
goal_set "Goal 1" >/dev/null 2>&1
goal_set "Goal 2" >/dev/null 2>&1
goal_set "Goal 3" >/dev/null 2>&1
goal_set "Goal 4" >/dev/null 2>&1
goal_set "Goal 5" >/dev/null 2>&1

# Complete goals out of order (3, 1, 5)
goal_complete 3 >/dev/null 2>&1
goal_complete 1 >/dev/null 2>&1
goal_complete 5 >/dev/null 2>&1

goal_file="$(goal_file_for_today)"

# Verify file has 5 lines
When call wc -l <"$goal_file"
The output should equal "5"

# Extract completed status for each line
line1_completed=$(sed -n '1p' "$goal_file" | jq -r '.completed')
line2_completed=$(sed -n '2p' "$goal_file" | jq -r '.completed')
line3_completed=$(sed -n '3p' "$goal_file" | jq -r '.completed')
line4_completed=$(sed -n '4p' "$goal_file" | jq -r '.completed')
line5_completed=$(sed -n '5p' "$goal_file" | jq -r '.completed')

# Verify correct goals are completed (1, 3, 5)
test "$line1_completed" = "true"
test "$line2_completed" = "false"
test "$line3_completed" = "true"
test "$line4_completed" = "false"
When call test "$line5_completed" = "true"
The status should be success
End
End

#═══════════════════════════════════════════════════════════════════
# E2E Scenario 3: Error Handling & Recovery
#═══════════════════════════════════════════════════════════════════

Describe 'Scenario 3: Error Handling & Edge Cases'
BeforeEach '
      rm -f "$HARM_WORK_STATE_FILE"*
      rm -f "$HARM_GOALS_DIR"/*.jsonl
    '

It 'validates goal progress bounds (0-100)'
goal_set "Test goal" >/dev/null 2>&1

# Invalid: negative progress
When call goal_update_progress 1 -1
The status should be failure

# Invalid: over 100%
When call goal_update_progress 1 101
The status should be failure

# Valid: exactly 0%
goal_update_progress 1 0 >/dev/null 2>&1

# Valid: exactly 100%
When call goal_update_progress 1 100
The status should be success
End

It 'validates goal numbers'
goal_set "Goal 1" >/dev/null 2>&1
goal_set "Goal 2" >/dev/null 2>&1

# Invalid: goal 0
When call goal_update_progress 0 50
The status should be failure

# Invalid: non-existent goal
When call goal_update_progress 99 50
The status should be failure

# Valid: goal 1 and 2
goal_update_progress 1 50 >/dev/null 2>&1
When call goal_update_progress 2 75
The status should be success
End

It 'validates duration formats'
# Valid formats
goal_set "Task 1" "30m" >/dev/null 2>&1
goal_set "Task 2" "2h" >/dev/null 2>&1
goal_set "Task 3" "1h30m" >/dev/null 2>&1
goal_set "Task 4" 45 >/dev/null 2>&1

# Invalid: negative duration
When call goal_set "Invalid" "-1h"
The status should be failure

# Invalid: zero duration
When call goal_set "Invalid" 0
The status should be failure

# Invalid: bad format
When call goal_set "Invalid" "xyz"
The status should be failure
End

It 'handles missing goal file gracefully'
# No goals file exists
rm -f "$(goal_file_for_today)"

# Should show "no goals" message
export HARM_CLI_FORMAT=text
When call goal_show
The output should include "No goals set for today"
The status should be success

# Updating non-existent goal should fail
When call goal_update_progress 1 50
The status should be failure
End

It 'prevents clearing goals without --force'
goal_set "Important goal" >/dev/null 2>&1

# Try to clear without --force
When call goal_clear
The status should be failure

# Goals should still exist
When call goal_exists_today
The status should be success
End

It 'clears goals with --force'
goal_set "Goal to clear" >/dev/null 2>&1

# Clear with --force
goal_clear --force >/dev/null 2>&1

# Goals should not exist
When call goal_exists_today
The status should be failure
End
End

#═══════════════════════════════════════════════════════════════════
# E2E Scenario 4: JSON Output Format
#═══════════════════════════════════════════════════════════════════

Describe 'Scenario 4: JSON Output Consistency'
BeforeEach '
      rm -f "$HARM_WORK_STATE_FILE"*
      rm -f "$HARM_GOALS_DIR"/*.jsonl
      export HARM_CLI_FORMAT=json
    '

It 'outputs valid JSON for work commands'
# Start work
When call work_start "Test work"
The output should include '"status"'
The output should include '"goal"'

# Verify output is valid JSON
output=$(work_start "Test2" 2>&1 | grep -v '^\[')
When call jq -e '.status' <<<"$output"
The status should be success
End

It 'outputs valid JSON for goal commands'
# Set goal
When call goal_set "Test goal" "1h"
The output should include '"status"'
The output should include '"goal"'

# Show goals
When call goal_show
The output should start with '['
The output should end with ']'

# Update progress
goal_update_progress 1 50 >/dev/null 2>&1
When call goal_update_progress 1 50
The output should include '"progress"'
End

It 'returns JSON arrays for list operations'
goal_set "Goal 1" >/dev/null 2>&1
goal_set "Goal 2" >/dev/null 2>&1
goal_set "Goal 3" >/dev/null 2>&1

output=$(goal_show)

# Should be a JSON array
When call jq -e 'type == "array"' <<<"$output"
The status should be success

# Should have 3 elements
When call jq -e 'length == 3' <<<"$output"
The status should be success
End
End

#═══════════════════════════════════════════════════════════════════
# E2E Scenario 5: Real-World Workflows
#═══════════════════════════════════════════════════════════════════

Describe 'Scenario 5: Realistic Daily Workflows'
BeforeEach '
      rm -f "$HARM_WORK_STATE_FILE"*
      rm -f "$HARM_GOALS_DIR"/*.jsonl
      export HARM_CLI_FORMAT=text
    '

It 'simulates a full development day'
# Morning: Start work and set daily goals
work_start "Daily development tasks" >/dev/null 2>&1
goal_set "Review PRs" "1h" >/dev/null 2>&1
goal_set "Fix bugs" "2h" >/dev/null 2>&1
goal_set "Write tests" "1h30m" >/dev/null 2>&1
goal_set "Update docs" "30m" >/dev/null 2>&1

# Mid-morning: Complete PR review
goal_complete 1 >/dev/null 2>&1

# Afternoon: Make progress on bugs
goal_update_progress 2 50 >/dev/null 2>&1

# Late afternoon: Complete tests
goal_complete 3 >/dev/null 2>&1

# End of day: Stop work
work_stop >/dev/null 2>&1

# Verify state
goal_file="$(goal_file_for_today)"

# Should have 2 completed goals (1 and 3)
completed_count=$(jq -r 'select(.completed == true)' "$goal_file" | grep -c "goal" || echo "0")
When call test "$completed_count" -eq 2
The status should be success

# Work session should be inactive
When call work_is_active
The status should be failure
End

It 'handles interrupted work session'
# Start work and set goals
work_start "Feature development" >/dev/null 2>&1
goal_set "Implement feature" "4h" >/dev/null 2>&1

# Make some progress
goal_update_progress 1 30 >/dev/null 2>&1

# Simulate interruption (e.g., urgent meeting)
# Stop work session
work_stop >/dev/null 2>&1

# Later: Resume work (start new session)
work_start "Resume feature work" >/dev/null 2>&1

# Continue with existing goal (new day, but similar concept)
# Goals persist per day
When call goal_exists_today
The status should be success

# Update progress on resumed goal
When call goal_update_progress 1 60
The status should be success
End

It 'handles multi-day goal tracking'
# Day 1: Set goal
goal_set "Long-term refactoring" "8h" >/dev/null 2>&1
goal_update_progress 1 25 >/dev/null 2>&1
day1_file="$(goal_file_for_today)"

# Verify Day 1 goal exists
When call test -f "$day1_file"
The status should be success

# Goals are tracked per day (new day = new file)
# This test verifies file structure, not actual date change
When call basename "$day1_file"
The output should end with '.jsonl'
End

It 'handles empty goal description edge case'
# Empty goal should fail
When call goal_set ""
The status should be failure
End

It 'handles very long goal description'
long_goal=$(printf 'A%.0s' {1..1000}) # 1000 character goal

# Should still work (no arbitrary length limit)
When call goal_set "$long_goal" "1h"
The status should be success

# Verify it was saved
goal_file="$(goal_file_for_today)"
When call test -f "$goal_file"
The status should be success
End
End

#═══════════════════════════════════════════════════════════════════
# E2E Scenario 6: Concurrent Operations
#═══════════════════════════════════════════════════════════════════

Describe 'Scenario 6: State Consistency'
BeforeEach '
      rm -f "$HARM_WORK_STATE_FILE"*
      rm -f "$HARM_GOALS_DIR"/*.jsonl
    '

It 'maintains JSONL integrity with multiple updates'
export HARM_CLI_FORMAT=text

# Add 10 goals
for i in {1..10}; do
  goal_set "Goal $i" "1h" >/dev/null 2>&1
done

goal_file="$(goal_file_for_today)"

# Update each goal
for i in {1..10}; do
  goal_update_progress "$i" $((i * 10)) >/dev/null 2>&1
done

# Verify file is still valid JSONL
# Each line should be valid JSON
When call jq -r '.goal' <"$goal_file"
The status should be success

# Should have exactly 10 lines
When call wc -l <"$goal_file"
The output should equal "10"
End

It 'handles rapid goal updates'
goal_set "Rapidly updated goal" >/dev/null 2>&1

# Update progress rapidly
goal_update_progress 1 10 >/dev/null 2>&1
goal_update_progress 1 20 >/dev/null 2>&1
goal_update_progress 1 30 >/dev/null 2>&1
goal_update_progress 1 40 >/dev/null 2>&1
goal_update_progress 1 50 >/dev/null 2>&1

goal_file="$(goal_file_for_today)"

# Should still have 1 line
When call wc -l <"$goal_file"
The output should equal "1"

# Final progress should be 50%
When call jq -r '.progress' <"$goal_file"
The output should equal "50"
End
End

#═══════════════════════════════════════════════════════════════════
# E2E Scenario 7: Environment Variable Overrides
#═══════════════════════════════════════════════════════════════════

Describe 'Scenario 7: Configuration Overrides'
It 'respects HARM_GOALS_DIR override'
custom_dir="$TEST_TMP/custom_goals"
mkdir -p "$custom_dir"

HARM_GOALS_DIR="$custom_dir" goal_set "Custom dir goal" >/dev/null 2>&1

# Goal file should be in custom directory
When call test -f "$custom_dir/$(date '+%Y-%m-%d').jsonl"
The status should be success

rm -rf "$custom_dir"
End

It 'respects HARM_CLI_FORMAT environment variable'
export HARM_CLI_FORMAT=json

When call goal_set "JSON format goal"
The output should include '"status"'

export HARM_CLI_FORMAT=text

When call goal_set "Text format goal"
The output should include "Goal:"
End
End

End
