#!/usr/bin/env bash
# ShellSpec tests for hooks module
# Tests shell hooks system (chpwd, preexec, precmd)

Describe 'lib/hooks.sh'
Include spec/helpers/env.sh

# Setup for each test block
BeforeAll 'setup_hooks_env'
AfterAll 'cleanup_hooks_env'

setup_hooks_env() {
  export HARM_CLI_HOME="${SHELLSPEC_TMPBASE}/harm-cli"
  export HARM_HOOKS_ENABLED=1
  export HARM_HOOKS_DEBUG=0
  export HARM_HOOKS_TEST_MODE=1
  mkdir -p "$HARM_CLI_HOME"
}

cleanup_hooks_env() {
  rm -rf "$HARM_CLI_HOME"
}

# ═══════════════════════════════════════════════════════════════
# Module Loading
# ═══════════════════════════════════════════════════════════════

Describe 'Module loading'
It 'loads without errors'
When call source lib/hooks.sh
The status should be success
End
End

Describe 'Module state'
Include lib/hooks.sh

It 'sets _HARM_HOOKS_LOADED flag'
The variable _HARM_HOOKS_LOADED should equal 1
End

It 'exports hook management functions'
The function harm_add_hook should be defined
The function harm_remove_hook should be defined
The function harm_list_hooks should be defined
End
End

# ═══════════════════════════════════════════════════════════════
# Hook Registration
# ═══════════════════════════════════════════════════════════════

Describe 'harm_add_hook'
Include lib/hooks.sh

test_chpwd_hook() { echo "chpwd called"; }
test_preexec_hook() { echo "preexec: $1"; }
test_precmd_hook() { echo "precmd: $1"; }

It 'registers chpwd hook successfully'
When call harm_add_hook chpwd test_chpwd_hook
The status should be success
End

It 'registers preexec hook successfully'
When call harm_add_hook preexec test_preexec_hook
The status should be success
End

It 'registers precmd hook successfully'
When call harm_add_hook precmd test_precmd_hook
The status should be success
End

It 'fails with missing hook type'
When run harm_add_hook
The status should not be success
The error should include "Hook type required"
End

It 'fails with invalid hook type'
When call harm_add_hook invalid_type test_chpwd_hook
The status should equal 1
The stderr should include "Unknown hook type"
End

It 'fails when hook function does not exist'
When call harm_add_hook chpwd nonexistent_function
The status should equal 2
The stderr should include "Hook function not found"
End
End

# ═══════════════════════════════════════════════════════════════
# Hook Removal
# ═══════════════════════════════════════════════════════════════

Describe 'harm_remove_hook'
Include lib/hooks.sh

# shellcheck disable=SC2317
test_hook() { echo "test"; }

It 'removes registered hook successfully'
harm_add_hook chpwd test_hook
When call harm_remove_hook chpwd test_hook
The status should be success
End

It 'fails with invalid hook type'
When call harm_remove_hook invalid_type test_hook
The status should equal 1
The stderr should include "Unknown hook type"
End

It 'returns error when hook not found'
When call harm_remove_hook chpwd nonexistent_hook
The status should equal 2
The stderr should include "Hook not found"
End
End

# ═══════════════════════════════════════════════════════════════
# Hook Listing
# ═══════════════════════════════════════════════════════════════

Describe 'harm_list_hooks'
Include lib/hooks.sh

test_chpwd1() { echo "1"; }
test_chpwd2() { echo "2"; }
test_preexec1() { echo "3"; }

It 'lists all hooks when no filter specified'
harm_add_hook chpwd test_chpwd1
harm_add_hook chpwd test_chpwd2
harm_add_hook preexec test_preexec1

When call harm_list_hooks
The output should include "chpwd hooks"
The output should include "preexec hooks"
The output should include "precmd hooks"
End

It 'lists only chpwd hooks when filtered'
harm_add_hook chpwd test_chpwd1
harm_add_hook chpwd test_chpwd2

When call harm_list_hooks chpwd
The output should include "chpwd hooks"
The output should include "test_chpwd1"
The output should include "test_chpwd2"
End

It 'shows correct hook count'
harm_add_hook chpwd test_chpwd1
harm_add_hook chpwd test_chpwd2

When call harm_list_hooks chpwd
The output should include "chpwd hooks (2)"
End
End

# ═══════════════════════════════════════════════════════════════
# Hook Handlers
# ═══════════════════════════════════════════════════════════════

Describe '_harm_chpwd_handler'
Include lib/hooks.sh

chpwd_test_hook() {
  echo "Changed from $1 to $2"
}

It 'detects directory change'
harm_add_hook chpwd chpwd_test_hook
_HARM_LAST_PWD="/old/path"
_HARM_IN_HOOK=0

When call _harm_chpwd_handler
The output should include "Changed from /old/path"
End

It 'does not trigger when directory unchanged'
harm_add_hook chpwd chpwd_test_hook
_HARM_LAST_PWD="$PWD"
_HARM_IN_HOOK=0

When call _harm_chpwd_handler
The output should equal ""
End

It 'updates _HARM_LAST_PWD after execution'
harm_add_hook chpwd chpwd_test_hook
_HARM_LAST_PWD="/old/path"
_HARM_IN_HOOK=0
_harm_chpwd_handler >/dev/null 2>&1

The variable _HARM_LAST_PWD should equal "$PWD"
End
End

Describe '_harm_precmd_handler'
Include lib/hooks.sh

precmd_test_hook() {
  echo "Exit: $1"
}

It 'passes exit code to hook'
harm_add_hook precmd precmd_test_hook
_HARM_LAST_COMMAND="test command"
_HARM_IN_HOOK=0

When call _harm_precmd_handler
The output should include "Exit: 0"
End

It 'preserves exit code'
test_exit_preservation() {
  (exit 42)
  _harm_precmd_handler
}

harm_add_hook precmd precmd_test_hook
_HARM_IN_HOOK=0

When call test_exit_preservation
The status should equal 42
The output should include "Exit: 42"
End
End

Describe '_harm_preexec_handler'
Include lib/hooks.sh

preexec_test_hook() {
  echo "About to execute: $1"
}

It 'captures command before execution'
harm_add_hook preexec preexec_test_hook
_TEST_BASH_COMMAND="ls -la"
BASH_SUBSHELL=0
_HARM_SKIP_NEXT_DEBUG=0
_HARM_IN_HOOK=0

When call _harm_preexec_handler
The output should include "About to execute: ls -la"
End

It 'skips internal commands'
harm_add_hook preexec preexec_test_hook
_TEST_BASH_COMMAND="_harm_chpwd_handler"
BASH_SUBSHELL=0
_HARM_IN_HOOK=0

When call _harm_preexec_handler
The output should equal ""
End

It 'skips commands in subshells'
harm_add_hook preexec preexec_test_hook
BASH_COMMAND="echo test"
BASH_SUBSHELL=1
_HARM_IN_HOOK=0

When call _harm_preexec_handler
The output should equal ""
End

It 'respects skip flag'
harm_add_hook preexec preexec_test_hook
BASH_COMMAND="echo test"
BASH_SUBSHELL=0
_HARM_SKIP_NEXT_DEBUG=1
_HARM_IN_HOOK=0

When call _harm_preexec_handler
The output should equal ""
The variable _HARM_SKIP_NEXT_DEBUG should equal 0
End
End

# ═══════════════════════════════════════════════════════════════
# Hook System Initialization
# ═══════════════════════════════════════════════════════════════

Describe 'harm_hooks_init'
It 'does not initialize when hooks disabled'
export HARM_HOOKS_ENABLED=0
When call bash -c "source lib/hooks.sh && harm_hooks_init"
The status should equal 1
End
End

Describe 'harm_hooks_init function'
Include lib/hooks.sh

It 'function exists and is exported'
The function harm_hooks_init should be defined
End
End

# ═══════════════════════════════════════════════════════════════
# Safety and Edge Cases
# ═══════════════════════════════════════════════════════════════

Describe 'Hook system safety'
Include lib/hooks.sh

It 'prevents recursion in hooks'
recursive_hook() {
  _harm_chpwd_handler
  echo "recursive"
}

harm_add_hook chpwd recursive_hook
_HARM_LAST_PWD="/old"
_HARM_IN_HOOK=0

When call _harm_chpwd_handler
The output should include "recursive"
End

It 'handles hook function errors gracefully'
failing_hook() {
  return 1
}

harm_add_hook chpwd failing_hook
_HARM_LAST_PWD="/old"
_HARM_IN_HOOK=0

When call _harm_chpwd_handler
The status should be success
The stderr should include "chpwd hook failed"
End

It 'handles missing hook functions gracefully'
# Manually add invalid hook
_HARM_CHPWD_HOOKS+=("nonexistent_function")
_HARM_LAST_PWD="/old"
_HARM_IN_HOOK=0

When call _harm_chpwd_handler
The status should be success
The stderr should include "chpwd hook not found"
End
End

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════

Describe 'Hook system configuration'
It 'respects HARM_HOOKS_ENABLED=0'
export HARM_HOOKS_ENABLED=0

When run bash -c "source lib/hooks.sh && harm_hooks_init"
The status should equal 1
End
End

Describe 'Hook system debug mode'
export HARM_HOOKS_DEBUG=1
export HARM_CLI_LOG_LEVEL=DEBUG
Include lib/hooks.sh

It 'enables debug logging when HARM_HOOKS_DEBUG=1'
test_hook() { echo 'test'; }

When call harm_add_hook chpwd test_hook
The status should be success
End
End

# ═══════════════════════════════════════════════════════════════
# Integration
# ═══════════════════════════════════════════════════════════════

Describe 'Hook system integration'
Include lib/hooks.sh

It 'allows multiple hooks of same type'
hook1() { echo "hook1"; }
hook2() { echo "hook2"; }
hook3() { echo "hook3"; }

harm_add_hook chpwd hook1
harm_add_hook chpwd hook2
harm_add_hook chpwd hook3

_HARM_LAST_PWD="/old"
_HARM_IN_HOOK=0

When call _harm_chpwd_handler
The line 1 should equal "hook1"
The line 2 should equal "hook2"
The line 3 should equal "hook3"
End

It 'executes hooks in registration order'
hook_a() { echo "A"; }
hook_b() { echo "B"; }
hook_c() { echo "C"; }

harm_add_hook precmd hook_a
harm_add_hook precmd hook_b
harm_add_hook precmd hook_c

_HARM_IN_HOOK=0

When call _harm_precmd_handler
The line 1 should equal "A"
The line 2 should equal "B"
The line 3 should equal "C"
End

It 'works with all three hook types simultaneously'
chpwd_test() { echo "chpwd"; }
preexec_test() { echo "preexec: $1"; }
precmd_test() { echo "precmd: $1"; }

harm_add_hook chpwd chpwd_test
harm_add_hook preexec preexec_test
harm_add_hook precmd precmd_test

When call harm_list_hooks
The output should include "chpwd_test"
The output should include "preexec_test"
The output should include "precmd_test"
End
End

End
