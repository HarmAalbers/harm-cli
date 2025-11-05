#!/usr/bin/env bash
# ShellSpec tests for work_enforcement.sh module

Describe 'lib/work_enforcement.sh'
Include spec/helpers/env.sh

# Set up test environment
setup_enforcement_test_env() {
  export HARM_LOG_LEVEL=ERROR # Suppress DEBUG/INFO logs during tests
  export HARM_WORK_DIR="$TEST_TMP/work"
  export HARM_WORK_ENFORCEMENT_FILE="$HARM_WORK_DIR/enforcement.json"
  export HARM_CLI_HOME="$TEST_TMP/harm-cli"
  export HARM_WORK_ENFORCEMENT="moderate"
  export HARM_WORK_DISTRACTION_THRESHOLD=3

  # Global violation tracking variables
  export _WORK_VIOLATIONS=0
  export _WORK_ACTIVE_PROJECT=""
  export _WORK_ACTIVE_GOAL=""

  mkdir -p "$HARM_WORK_DIR" "$HARM_CLI_HOME"

  # Source the module (will fail until created)
  source "$ROOT/lib/work_enforcement.sh"
}

BeforeAll 'setup_enforcement_test_env'

# Clean up after tests
cleanup_enforcement_test_env() {
  rm -rf "$HARM_WORK_DIR"
  unset _WORK_VIOLATIONS _WORK_ACTIVE_PROJECT _WORK_ACTIVE_GOAL
}

AfterAll 'cleanup_enforcement_test_env'

Describe 'Module Loading'
It 'sources work_enforcement.sh without errors'
The variable _HARM_WORK_ENFORCEMENT_LOADED should be defined
End

It 'exports work_enforcement_load_state function'
When call type work_enforcement_load_state
The status should be success
The output should include "work_enforcement_load_state"
End

It 'exports work_enforcement_save_state function'
When call type work_enforcement_save_state
The status should be success
The output should include "work_enforcement_save_state"
End
End

Describe 'work_enforcement_load_state'
It 'returns 1 when no state file exists'
rm -f "$HARM_WORK_ENFORCEMENT_FILE"
When call work_enforcement_load_state
The status should be failure
End

It 'loads state from existing file'
# Create state file
echo '{"violations":5,"project":"test-proj","goal":"test goal"}' >"$HARM_WORK_ENFORCEMENT_FILE"

When call work_enforcement_load_state
The status should be success
The variable _WORK_VIOLATIONS should equal 5
The variable _WORK_ACTIVE_PROJECT should equal "test-proj"
The variable _WORK_ACTIVE_GOAL should equal "test goal"
End

It 'defaults violations to 0 if missing from JSON'
echo '{"project":"test"}' >"$HARM_WORK_ENFORCEMENT_FILE"

When call work_enforcement_load_state
The status should be success
The variable _WORK_VIOLATIONS should equal 0
End

It 'handles empty strings gracefully'
echo '{"violations":3,"project":"","goal":""}' >"$HARM_WORK_ENFORCEMENT_FILE"

When call work_enforcement_load_state
The status should be success
The variable _WORK_VIOLATIONS should equal 3
The variable _WORK_ACTIVE_PROJECT should equal ""
End
End

Describe 'work_enforcement_save_state'
It 'creates state file with current values'
export _WORK_VIOLATIONS=2
export _WORK_ACTIVE_PROJECT="my-project"
export _WORK_ACTIVE_GOAL="finish feature"

When call work_enforcement_save_state
The status should be success
The path "$HARM_WORK_ENFORCEMENT_FILE" should be exist
End

It 'saves violations correctly'
export _WORK_VIOLATIONS=7
export _WORK_ACTIVE_PROJECT="test"
export _WORK_ACTIVE_GOAL=""

work_enforcement_save_state

When call jq -r '.violations' "$HARM_WORK_ENFORCEMENT_FILE"
The output should equal "7"
End

It 'saves project name correctly'
export _WORK_VIOLATIONS=0
export _WORK_ACTIVE_PROJECT="awesome-app"
export _WORK_ACTIVE_GOAL=""

work_enforcement_save_state

When call jq -r '.project' "$HARM_WORK_ENFORCEMENT_FILE"
The output should equal "awesome-app"
End

It 'includes timestamp in saved state'
export _WORK_VIOLATIONS=0
export _WORK_ACTIVE_PROJECT=""
export _WORK_ACTIVE_GOAL=""

work_enforcement_save_state

When call jq -r '.updated' "$HARM_WORK_ENFORCEMENT_FILE"
The output should not equal "null"
End
End

Describe 'work_enforcement_clear'
It 'resets violation counter to 0'
export _WORK_VIOLATIONS=10

work_enforcement_clear

The variable _WORK_VIOLATIONS should equal 0
End

It 'clears active project'
export _WORK_ACTIVE_PROJECT="some-project"

work_enforcement_clear

The variable _WORK_ACTIVE_PROJECT should equal ""
End

It 'clears active goal'
export _WORK_ACTIVE_GOAL="some goal"

work_enforcement_clear

The variable _WORK_ACTIVE_GOAL should equal ""
End

It 'removes enforcement file'
echo '{"violations":5}' >"$HARM_WORK_ENFORCEMENT_FILE"

When call work_enforcement_clear
The status should be success
The path "$HARM_WORK_ENFORCEMENT_FILE" should not be exist
End
End

Describe 'work_get_violations'
It 'returns current violation count'
export _WORK_VIOLATIONS=3

When call work_get_violations
The output should equal "3"
The status should be success
End

It 'loads from file if memory is 0 but file exists'
export _WORK_VIOLATIONS=0
echo '{"violations":8}' >"$HARM_WORK_ENFORCEMENT_FILE"

When call work_get_violations
The output should equal "8"
End

It 'returns 0 when no violations'
export _WORK_VIOLATIONS=0
rm -f "$HARM_WORK_ENFORCEMENT_FILE"

When call work_get_violations
The output should equal "0"
End
End

Describe 'work_reset_violations'
It 'resets violation counter to 0'
export _WORK_VIOLATIONS=15
export _WORK_ACTIVE_PROJECT="test"
export _WORK_ACTIVE_GOAL=""

When call work_reset_violations
The status should be success
The variable _WORK_VIOLATIONS should equal 0
The output should include "reset"
End

It 'saves state after reset'
export _WORK_VIOLATIONS=5
export _WORK_ACTIVE_PROJECT="project"
export _WORK_ACTIVE_GOAL=""

work_reset_violations >/dev/null

When call jq -r '.violations' "$HARM_WORK_ENFORCEMENT_FILE"
The output should equal "0"
End

It 'outputs success message'
export _WORK_VIOLATIONS=3
export _WORK_ACTIVE_PROJECT=""
export _WORK_ACTIVE_GOAL=""

When call work_reset_violations
The output should include "reset"
End
End

Describe 'work_set_enforcement'
# Note: This function modifies config file, tests need careful isolation

It 'requires enforcement mode parameter'
When run work_set_enforcement
The status should be failure
The stderr should include "required"
End

It 'accepts strict mode'
# Use isolated config file
export HOME="$TEST_TMP"
mkdir -p "$HOME/.harm-cli"
When call work_set_enforcement "strict"
The status should be success
The output should include "strict"
The path "$HOME/.harm-cli/config" should be exist
End

It 'accepts moderate mode'
# Use isolated config file
export HOME="$TEST_TMP"
mkdir -p "$HOME/.harm-cli"
When call work_set_enforcement "moderate"
The status should be success
The output should include "moderate"
End

It 'accepts off mode'
# Use isolated config file
export HOME="$TEST_TMP"
mkdir -p "$HOME/.harm-cli"
When call work_set_enforcement "off"
The status should be success
The output should include "off"
End

It 'rejects invalid mode'
When call work_set_enforcement "invalid"
The status should be failure
The stderr should include "Invalid"
End
End

Describe 'Strict mode enforcement'
Context 'work_strict_enforce_break'
It 'allows work when no break required'
export HARM_WORK_ENFORCEMENT="strict"
rm -f "$HARM_WORK_ENFORCEMENT_FILE"

When call work_strict_enforce_break
The status should be success
End

It 'blocks work when break is required'
export HARM_WORK_ENFORCEMENT="strict"
echo '{"break_required":true,"break_type_required":"short"}' >"$HARM_WORK_ENFORCEMENT_FILE"

When call work_strict_enforce_break
The status should be failure
The stderr should include "BREAK REQUIRED"
End

It 'allows work when enforcement is not strict'
export HARM_WORK_ENFORCEMENT="moderate"
echo '{"break_required":true,"break_type_required":"short"}' >"$HARM_WORK_ENFORCEMENT_FILE"

When call work_strict_enforce_break
The status should be success
End
End
End

Describe 'Logging behavior'
It 'work_enforcement_save_state logs successfully'
export _WORK_VIOLATIONS=0
export _WORK_ACTIVE_PROJECT=""
export _WORK_ACTIVE_GOAL=""

When call work_enforcement_save_state
The status should be success
End

It 'work_reset_violations logs at INFO level'
export _WORK_VIOLATIONS=5
export _WORK_ACTIVE_PROJECT=""
export _WORK_ACTIVE_GOAL=""

When call work_reset_violations
The status should be success
The output should include "reset"
End
End
End
