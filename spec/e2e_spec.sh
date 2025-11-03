#!/usr/bin/env bash
# ShellSpec E2E (End-to-End) Integration Tests
# Tests real workflows and cross-module integration

Describe 'E2E: harm-cli Integration Tests'
Include spec/helpers/env.sh

# Set up isolated test environment
# IMPORTANT: Must run BEFORE sourcing modules (HARM_GOALS_DIR is readonly)
setup_e2e_env() {
  # Set environment variables BEFORE sourcing modules
  export HARM_GOALS_DIR="$TEST_TMP/goals"
  export HARM_WORK_DIR="$TEST_TMP/work"
  export HARM_WORK_STATE_FILE="$HARM_WORK_DIR/current_session.json"
  export HARM_CLI_HOME="$TEST_TMP/harm-cli"
  export HARM_CLI_LOG_LEVEL="ERROR"
  export HARM_TEST_MODE=1
  export HARM_WORK_ENFORCEMENT=off
  mkdir -p "$HARM_GOALS_DIR" "$HARM_WORK_DIR" "$HARM_CLI_HOME"

  # Disable homebrew command not found handler
  unset -f homebrew_command_not_found_handle 2>/dev/null || true
  export HOMEBREW_COMMAND_NOT_FOUND_CI=1

  # Mock system commands to prevent background processes and external dependencies
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

  # Source all required modules AFTER setting env vars (redirect stdin to prevent hangs)
  source "$ROOT/lib/common.sh" 2>/dev/null </dev/null
  source "$ROOT/lib/error.sh" 2>/dev/null </dev/null
  source "$ROOT/lib/logging.sh" 2>/dev/null </dev/null
  source "$ROOT/lib/util.sh" 2>/dev/null </dev/null
  source "$ROOT/lib/options.sh" 2>/dev/null </dev/null
  source "$ROOT/lib/work.sh" 2>/dev/null </dev/null
  source "$ROOT/lib/goals.sh" 2>/dev/null </dev/null
}

# Clean state function - defined at top level so it's accessible
cleanup_work_state() {
  rm -f "$HARM_WORK_STATE_FILE"* 2>/dev/null || true
  rm -f "$HARM_GOALS_DIR"/*.jsonl 2>/dev/null || true
}

BeforeAll 'setup_e2e_env'
AfterAll 'cleanup_e2e_env'

cleanup_e2e_env() {
  # Kill any background jobs to prevent hanging
  jobs -p | xargs -r kill 2>/dev/null || true
  wait 2>/dev/null || true
  rm -rf "$HARM_GOALS_DIR" "$HARM_WORK_DIR" "$HARM_CLI_HOME"
  pkill -f "sleep.*pomodoro" 2>/dev/null || true
}

#═══════════════════════════════════════════════════════════════════
# E2E Scenario 1: Complete Work Session Workflow
#═══════════════════════════════════════════════════════════════════

Describe 'Scenario 1: Complete Work Session with Goals'
BeforeEach 'cleanup_work_state'

It 'starts work session, sets goals, tracks progress, completes work'
# Complete workflow wrapper function
full_workflow() {
  export HARM_CLI_FORMAT=text

  # Step 1: Start work session
  work_start "Phase 3 Implementation" >/dev/null 2>&1 || return 1
  work_is_active || return 1

  # Step 2: Set multiple goals
  goal_set "Write E2E tests" "2h" >/dev/null 2>&1 || return 1
  goal_set "Update documentation" "1h" >/dev/null 2>&1 || return 1
  goal_set "Review changes" "30m" >/dev/null 2>&1 || return 1

  # Step 3: Verify goals exist
  goal_exists_today || return 1

  # Step 4: Update progress on first goal
  goal_update_progress 1 50 >/dev/null 2>&1 || return 1
  local goal_file
  goal_file="$(goal_file_for_today)"
  grep -q '"progress":50' "$goal_file" || return 1

  # Step 5: Complete second goal
  goal_complete 2 >/dev/null 2>&1 || return 1
  grep -q '"completed":true' "$goal_file" || return 1

  # Step 6: Stop work session
  local output
  output="$(work_stop 2>&1)"
  echo "$output" | grep -q "Work session stopped" || return 1

  # Step 7: Verify session is inactive
  work_is_active && return 1

  return 0
}

When call full_workflow
The status should equal 0
End

It 'handles work session with no goals gracefully'
no_goals_workflow() {
  export HARM_CLI_FORMAT=text

  # Start work without setting goals
  work_start "Quick task" >/dev/null 2>&1 || return 1

  # Verify work is active but no goals exist
  work_is_active || return 1
  ! goal_exists_today || return 1

  # Should be able to stop work without goals
  work_stop >/dev/null 2>&1 || return 1

  return 0
}

When call no_goals_workflow
The status should equal 0
End

It 'prevents starting multiple work sessions'
multiple_sessions() {
  export HARM_CLI_FORMAT=text

  # Start first session
  work_start "Task 1" >/dev/null 2>&1 || return 1

  # Try to start second session (should fail and output error)
  local output
  output="$(work_start "Task 2" 2>&1)"
  local exit_code=$?

  # Should have failed
  [[ $exit_code -ne 0 ]] || return 1

  # Error message should mention "already active"
  echo "$output" | grep -qi "already active" || return 1

  return 0
}

When call multiple_sessions
The status should equal 0
End
End

#═══════════════════════════════════════════════════════════════════
# E2E Scenario 2: Goal Tracking Workflow
#═══════════════════════════════════════════════════════════════════

Describe 'Scenario 2: Complex Goal Tracking'
BeforeEach 'cleanup_work_state'

It 'tracks multiple goals with different durations'
multi_duration() {
  export HARM_CLI_FORMAT=text

  # Set goals with various duration formats
  goal_set "Quick fix" "15m" >/dev/null 2>&1 || return 1
  goal_set "Feature development" "4h" >/dev/null 2>&1 || return 1
  goal_set "Code review" "2h30m" >/dev/null 2>&1 || return 1
  goal_set "Testing" 90 >/dev/null 2>&1 || return 1

  # Verify all goals exist
  local goal_file
  goal_file="$(goal_file_for_today)"
  [[ -f "$goal_file" ]] || return 1

  # Should have 4 goals (4 lines in JSONL)
  local line_count
  line_count=$(wc -l <"$goal_file" | tr -d ' ')
  [[ "$line_count" == "4" ]] || return 1

  # Verify duration parsing
  grep -q '"estimated_minutes":15' "$goal_file" || return 1
  grep -q '"estimated_minutes":240' "$goal_file" || return 1
  grep -q '"estimated_minutes":150' "$goal_file" || return 1
  grep -q '"estimated_minutes":90' "$goal_file" || return 1

  return 0
}

When call multi_duration
The status should equal 0
End

It 'tracks goal progress incrementally'
incremental_progress() {
  export HARM_CLI_FORMAT=text

  goal_set "Incremental task" "1h" >/dev/null 2>&1 || return 1
  local goal_file
  goal_file="$(goal_file_for_today)"

  # Progress from 0% → 25% → 50% → 75% → 100%
  goal_update_progress 1 25 >/dev/null 2>&1 || return 1
  goal_update_progress 1 50 >/dev/null 2>&1 || return 1
  goal_update_progress 1 75 >/dev/null 2>&1 || return 1
  goal_update_progress 1 100 >/dev/null 2>&1 || return 1

  # Should be marked complete
  grep -q '"progress":100' "$goal_file" || return 1
  grep -q '"completed":true' "$goal_file" || return 1

  return 0
}

When call incremental_progress
The status should equal 0
End

It 'handles goal completion shortcut'
complete_shortcut() {
  export HARM_CLI_FORMAT=text

  goal_set "Task to complete" >/dev/null 2>&1 || return 1
  local goal_file
  goal_file="$(goal_file_for_today)"

  # Complete directly (should set progress=100 and completed=true)
  goal_complete 1 >/dev/null 2>&1 || return 1

  grep -q '"progress":100' "$goal_file" || return 1
  grep -q '"completed":true' "$goal_file" || return 1

  return 0
}

When call complete_shortcut
The status should equal 0
End

It 'maintains goal order and numbering'
goal_ordering() {
  export HARM_CLI_FORMAT=text

  # Set 5 goals
  goal_set "Goal 1" >/dev/null 2>&1 || return 1
  goal_set "Goal 2" >/dev/null 2>&1 || return 1
  goal_set "Goal 3" >/dev/null 2>&1 || return 1
  goal_set "Goal 4" >/dev/null 2>&1 || return 1
  goal_set "Goal 5" >/dev/null 2>&1 || return 1

  # Complete goals out of order (3, 1, 5)
  goal_complete 3 >/dev/null 2>&1 || return 1
  goal_complete 1 >/dev/null 2>&1 || return 1
  goal_complete 5 >/dev/null 2>&1 || return 1

  local goal_file
  goal_file="$(goal_file_for_today)"

  # Verify file has 5 lines
  local line_count
  line_count=$(wc -l <"$goal_file" | tr -d ' ')
  [[ "$line_count" == "5" ]] || return 1

  # Extract completed status for each line
  local line1_completed line2_completed line3_completed line4_completed line5_completed
  line1_completed=$(sed -n '1p' "$goal_file" | jq -r '.completed')
  line2_completed=$(sed -n '2p' "$goal_file" | jq -r '.completed')
  line3_completed=$(sed -n '3p' "$goal_file" | jq -r '.completed')
  line4_completed=$(sed -n '4p' "$goal_file" | jq -r '.completed')
  line5_completed=$(sed -n '5p' "$goal_file" | jq -r '.completed')

  # Verify correct goals are completed (1, 3, 5)
  [[ "$line1_completed" == "true" ]] || return 1
  [[ "$line2_completed" == "false" ]] || return 1
  [[ "$line3_completed" == "true" ]] || return 1
  [[ "$line4_completed" == "false" ]] || return 1
  [[ "$line5_completed" == "true" ]] || return 1

  return 0
}

When call goal_ordering
The status should equal 0
End
End

#═══════════════════════════════════════════════════════════════════
# E2E Scenario 3: Error Handling & Recovery
#═══════════════════════════════════════════════════════════════════

Describe 'Scenario 3: Error Handling & Edge Cases'
BeforeEach 'cleanup_work_state'

It 'validates goal progress bounds (0-100)'
progress_bounds() {
  export HARM_CLI_FORMAT=text

  goal_set "Test goal" >/dev/null 2>&1 || return 1

  # Invalid: negative progress (run in subshell to catch die())
  (goal_update_progress 1 -1 2>/dev/null) && return 1

  # Invalid: over 100% (run in subshell to catch die())
  (goal_update_progress 1 101 2>/dev/null) && return 1

  # Valid: exactly 0%
  goal_update_progress 1 0 >/dev/null 2>&1 || return 1

  # Valid: exactly 100%
  goal_update_progress 1 100 >/dev/null 2>&1 || return 1

  return 0
}

When call progress_bounds
The status should equal 0
End

It 'validates goal numbers'
goal_number_validation() {
  export HARM_CLI_FORMAT=text

  goal_set "Goal 1" >/dev/null 2>&1 || return 1
  goal_set "Goal 2" >/dev/null 2>&1 || return 1

  local goal_file
  goal_file="$(goal_file_for_today)"

  # Invalid: goal 0 should fail or do nothing
  # Since awk doesn't match NR==0, it should leave file unchanged
  local before_md5 after_md5
  before_md5=$(md5 -q "$goal_file" 2>/dev/null || md5sum "$goal_file" | cut -d' ' -f1)
  goal_update_progress 0 50 >/dev/null 2>&1
  after_md5=$(md5 -q "$goal_file" 2>/dev/null || md5sum "$goal_file" | cut -d' ' -f1)
  # File should be unchanged (goal 0 doesn't exist)
  [[ "$before_md5" == "$after_md5" ]] || return 1

  # Invalid: non-existent goal 99 should do nothing
  before_md5=$(md5 -q "$goal_file" 2>/dev/null || md5sum "$goal_file" | cut -d' ' -f1)
  goal_update_progress 99 50 >/dev/null 2>&1
  after_md5=$(md5 -q "$goal_file" 2>/dev/null || md5sum "$goal_file" | cut -d' ' -f1)
  [[ "$before_md5" == "$after_md5" ]] || return 1

  # Valid: goal 1 and 2
  goal_update_progress 1 50 >/dev/null 2>&1 || return 1
  goal_update_progress 2 75 >/dev/null 2>&1 || return 1

  # Verify updates actually happened
  grep -q '"progress":50' "$goal_file" || return 1
  grep -q '"progress":75' "$goal_file" || return 1

  return 0
}

When call goal_number_validation
The status should equal 0
End

It 'validates duration formats'
duration_validation() {
  export HARM_CLI_FORMAT=text

  # Valid formats
  goal_set "Task 1" "30m" >/dev/null 2>&1 || return 1
  goal_set "Task 2" "2h" >/dev/null 2>&1 || return 1
  goal_set "Task 3" "1h30m" >/dev/null 2>&1 || return 1
  goal_set "Task 4" 45 >/dev/null 2>&1 || return 1

  # Invalid: zero duration (run in subshell to catch die())
  (goal_set "Invalid" 0 2>/dev/null) && return 1

  # Invalid: bad format (run in subshell to catch die())
  # Note: "xyz" parses to 0 seconds, which fails the >0 validation
  (goal_set "Invalid" "xyz" 2>/dev/null) && return 1

  # Invalid: negative integer (run in subshell to catch die())
  (goal_set "Invalid" -5 2>/dev/null) && return 1

  return 0
}

When call duration_validation
The status should equal 0
End

It 'handles missing goal file gracefully'
missing_file() {
  export HARM_CLI_FORMAT=text

  # No goals file exists
  local goal_file
  goal_file="$(goal_file_for_today)"
  rm -f "$goal_file" 2>/dev/null || true

  # Should show "no goals" message
  local output
  output="$(goal_show 2>&1)"
  echo "$output" | grep -q "No goals set for today" || return 1

  # Updating non-existent goal should fail (run in subshell)
  (goal_update_progress 1 50 2>/dev/null) && return 1

  return 0
}

When call missing_file
The status should equal 0
End

It 'prevents clearing goals without --force'
clear_no_force() {
  export HARM_CLI_FORMAT=text

  goal_set "Important goal" >/dev/null 2>&1 || return 1

  # Try to clear without --force
  goal_clear 2>/dev/null && return 1

  # Goals should still exist
  goal_exists_today || return 1

  return 0
}

When call clear_no_force
The status should equal 0
End

It 'clears goals with --force'
clear_with_force() {
  export HARM_CLI_FORMAT=text

  goal_set "Goal to clear" >/dev/null 2>&1 || return 1

  # Clear with --force
  goal_clear --force >/dev/null 2>&1 || return 1

  # Goals should not exist
  ! goal_exists_today || return 1

  return 0
}

When call clear_with_force
The status should equal 0
End
End

#═══════════════════════════════════════════════════════════════════
# E2E Scenario 4: JSON Output Format
#═══════════════════════════════════════════════════════════════════

Describe 'Scenario 4: JSON Output Consistency'
BeforeEach 'cleanup_work_state'

It 'outputs valid JSON for work commands'
Skip "work_start spawns background processes that interfere with test isolation"
# Note: JSON output from work commands is tested in work_spec.sh unit tests.
# This E2E test is skipped due to background timer/notification processes
# interfering with ShellSpec test isolation in E2E scenarios.
End

It 'outputs valid JSON for goal commands'
json_goals() {
  export HARM_CLI_FORMAT=json

  # Set goal
  local output
  output="$(goal_set "Test goal" "1h" 2>&1)"
  echo "$output" | grep -v '^\[' | jq -e '.status' >/dev/null 2>&1 || return 1

  # Show goals
  goal_set "Another goal" >/dev/null 2>&1 || return 1
  output="$(goal_show 2>&1)"
  echo "$output" | jq -e 'type == "array"' >/dev/null 2>&1 || return 1

  return 0
}

When call json_goals
The status should equal 0
End

It 'returns JSON arrays for list operations'
json_arrays() {
  export HARM_CLI_FORMAT=json

  goal_set "Goal 1" >/dev/null 2>&1 || return 1
  goal_set "Goal 2" >/dev/null 2>&1 || return 1
  goal_set "Goal 3" >/dev/null 2>&1 || return 1

  local output
  output="$(goal_show 2>&1)"

  # Should be a JSON array
  echo "$output" | jq -e 'type == "array"' >/dev/null 2>&1 || return 1

  # Should have 3 elements
  echo "$output" | jq -e 'length == 3' >/dev/null 2>&1 || return 1

  return 0
}

When call json_arrays
The status should equal 0
End
End

#═══════════════════════════════════════════════════════════════════
# E2E Scenario 5: Real-World Workflows
#═══════════════════════════════════════════════════════════════════

Describe 'Scenario 5: Realistic Daily Workflows'
BeforeEach 'cleanup_work_state'

It 'simulates a full development day'
full_dev_day() {
  export HARM_CLI_FORMAT=text

  # Morning: Start work and set daily goals
  work_start "Daily development tasks" >/dev/null 2>&1 || return 1
  goal_set "Review PRs" "1h" >/dev/null 2>&1 || return 1
  goal_set "Fix bugs" "2h" >/dev/null 2>&1 || return 1
  goal_set "Write tests" "1h30m" >/dev/null 2>&1 || return 1
  goal_set "Update docs" "30m" >/dev/null 2>&1 || return 1

  # Mid-morning: Complete PR review
  goal_complete 1 >/dev/null 2>&1 || return 1

  # Afternoon: Make progress on bugs
  goal_update_progress 2 50 >/dev/null 2>&1 || return 1

  # Late afternoon: Complete tests
  goal_complete 3 >/dev/null 2>&1 || return 1

  # End of day: Stop work
  work_stop >/dev/null 2>&1 || return 1

  # Verify state
  local goal_file
  goal_file="$(goal_file_for_today)"

  # Should have 2 completed goals (1 and 3)
  local completed_count
  completed_count=$(jq -r 'select(.completed == true)' "$goal_file" | grep -c "goal" || echo "0")
  [[ "$completed_count" -eq 2 ]] || return 1

  # Work session should be inactive
  ! work_is_active || return 1

  return 0
}

When call full_dev_day
The status should equal 0
End

It 'handles interrupted work session'
interrupted_session() {
  export HARM_CLI_FORMAT=text

  # Start work and set goals
  work_start "Feature development" >/dev/null 2>&1 || return 1
  goal_set "Implement feature" "4h" >/dev/null 2>&1 || return 1

  # Make some progress
  goal_update_progress 1 30 >/dev/null 2>&1 || return 1

  # Simulate interruption (e.g., urgent meeting)
  work_stop >/dev/null 2>&1 || return 1

  # Later: Resume work (start new session)
  work_start "Resume feature work" >/dev/null 2>&1 || return 1

  # Goals persist
  goal_exists_today || return 1

  # Update progress on resumed goal
  goal_update_progress 1 60 >/dev/null 2>&1 || return 1

  return 0
}

When call interrupted_session
The status should equal 0
End

It 'handles multi-day goal tracking'
multi_day() {
  export HARM_CLI_FORMAT=text

  # Day 1: Set goal
  goal_set "Long-term refactoring" "8h" >/dev/null 2>&1 || return 1
  goal_update_progress 1 25 >/dev/null 2>&1 || return 1
  local day1_file
  day1_file="$(goal_file_for_today)"

  # Verify Day 1 goal exists
  [[ -f "$day1_file" ]] || return 1

  # Goals are tracked per day (new day = new file)
  local basename_output
  basename_output="$(basename "$day1_file")"
  echo "$basename_output" | grep -q '.jsonl$' || return 1

  return 0
}

When call multi_day
The status should equal 0
End

It 'handles empty goal description edge case'
empty_goal() {
  export HARM_CLI_FORMAT=text

  # Empty goal should fail (run in subshell to catch parameter expansion error)
  (goal_set "" 2>/dev/null) && return 1

  return 0
}

When call empty_goal
The status should equal 0
End

It 'handles very long goal description'
long_goal() {
  export HARM_CLI_FORMAT=text

  local long_goal_text
  long_goal_text=$(printf 'A%.0s' {1..1000})

  # Should still work (no arbitrary length limit)
  goal_set "$long_goal_text" "1h" >/dev/null 2>&1 || return 1

  # Verify it was saved
  local goal_file
  goal_file="$(goal_file_for_today)"
  [[ -f "$goal_file" ]] || return 1

  return 0
}

When call long_goal
The status should equal 0
End
End

#═══════════════════════════════════════════════════════════════════
# E2E Scenario 6: Concurrent Operations
#═══════════════════════════════════════════════════════════════════

Describe 'Scenario 6: State Consistency'
BeforeEach 'cleanup_work_state'

It 'maintains JSONL integrity with multiple updates'
jsonl_integrity() {
  export HARM_CLI_FORMAT=text

  # Add 10 goals
  for i in {1..10}; do
    goal_set "Goal $i" "1h" >/dev/null 2>&1 || return 1
  done

  local goal_file
  goal_file="$(goal_file_for_today)"

  # Update each goal
  for i in {1..10}; do
    goal_update_progress "$i" $((i * 10)) >/dev/null 2>&1 || return 1
  done

  # Verify file is still valid JSONL
  jq -r '.goal' <"$goal_file" >/dev/null 2>&1 || return 1

  # Should have exactly 10 lines
  local line_count
  line_count=$(wc -l <"$goal_file" | tr -d ' ')
  [[ "$line_count" == "10" ]] || return 1

  return 0
}

When call jsonl_integrity
The status should equal 0
End

It 'handles rapid goal updates'
rapid_updates() {
  export HARM_CLI_FORMAT=text

  goal_set "Rapidly updated goal" >/dev/null 2>&1 || return 1

  # Update progress rapidly
  goal_update_progress 1 10 >/dev/null 2>&1 || return 1
  goal_update_progress 1 20 >/dev/null 2>&1 || return 1
  goal_update_progress 1 30 >/dev/null 2>&1 || return 1
  goal_update_progress 1 40 >/dev/null 2>&1 || return 1
  goal_update_progress 1 50 >/dev/null 2>&1 || return 1

  local goal_file
  goal_file="$(goal_file_for_today)"

  # Should still have 1 line
  local line_count
  line_count=$(wc -l <"$goal_file" | tr -d ' ')
  [[ "$line_count" == "1" ]] || return 1

  # Final progress should be 50%
  local progress
  progress=$(jq -r '.progress' <"$goal_file")
  [[ "$progress" == "50" ]] || return 1

  return 0
}

When call rapid_updates
The status should equal 0
End
End

#═══════════════════════════════════════════════════════════════════
# E2E Scenario 7: Environment Variable Overrides
#═══════════════════════════════════════════════════════════════════

Describe 'Scenario 7: Configuration Overrides'
BeforeEach 'cleanup_work_state'

It 'respects HARM_GOALS_DIR override'
custom_dir_test() {
  export HARM_CLI_FORMAT=text

  # Note: HARM_GOALS_DIR is readonly after module load, so we test
  # that it was set correctly during setup, not runtime override
  local goal_file
  goal_file="$(goal_file_for_today)"

  # Verify it's using our test directory
  echo "$goal_file" | grep -q "$TEST_TMP/goals" || return 1

  # Set a goal to verify the path works
  goal_set "Test goal" >/dev/null 2>&1 || return 1
  [[ -f "$goal_file" ]] || return 1

  return 0
}

When call custom_dir_test
The status should equal 0
End

It 'respects HARM_CLI_FORMAT environment variable'
format_override() {
  # Test JSON format
  local output
  HARM_CLI_FORMAT=json output="$(goal_set "JSON format goal" 2>&1)"
  echo "$output" | grep -v '^\[' | jq -e '.status' >/dev/null 2>&1 || return 1

  # Clean up for text test
  cleanup_work_state

  # Test text format
  HARM_CLI_FORMAT=text output="$(goal_set "Text format goal" 2>&1)"
  echo "$output" | grep -q "Goal:" || return 1

  return 0
}

When call format_override
The status should equal 0
End
End

End
