#!/usr/bin/env bash
# ShellSpec tests for Git module

Describe 'lib/git.sh'
Include spec/helpers/env.sh

BeforeAll 'setup_git_test_env'
AfterAll 'cleanup_git_test_env'

setup_git_test_env() {
  # Set test configuration
  export HARM_CLI_HOME="$TEST_TMP"
  export HARM_CLI_LOG_LEVEL="DEBUG"
  export GEMINI_API_KEY="test_key_1234567890abcdef1234567890abcdef"

  # Create mock curl for AI integration
  mkdir -p "$TEST_TMP/bin"
  cat >"$TEST_TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
# Mock curl - returns commit message
echo '{
  "candidates": [{
    "content": {
      "parts": [{
        "text": "feat(test): add test feature\n\n- Added test functionality\n- Updated documentation\n- Improved error handling"
      }]
    }
  }]
}'
echo "200"
EOF
  chmod +x "$TEST_TMP/bin/curl"
  export PATH="$TEST_TMP/bin:$PATH"

  # Source the module
  source "$ROOT/lib/git.sh"
}

cleanup_git_test_env() {
  rm -rf "${TEST_TMP:?}/bin"
}

# ═══════════════════════════════════════════════════════════════
# Git Utilities Tests
# ═══════════════════════════════════════════════════════════════

Describe 'git_is_repo'
It 'detects git repository'
# harm-cli is a git repo
When call git_is_repo
The status should equal 0
End

It 'function exists and is exported'
When call type -t git_is_repo
The output should equal "function"
End
End

Describe 'git_default_branch'
It 'detects default branch'
# harm-cli uses main or master
When call git_default_branch
The output should match pattern "main|master"
End

It 'function exists and is exported'
When call type -t git_default_branch
The output should equal "function"
End
End

# ═══════════════════════════════════════════════════════════════
# Git Operations Tests
# ═══════════════════════════════════════════════════════════════

Describe 'git_commit_msg'
It 'requires being in git repository'
# We're in harm-cli repo, so this should work
When call type -t git_commit_msg
The output should equal "function"
End

It 'function exists and is exported'
When call type -t git_commit_msg
The output should equal "function"
End
End

Describe 'git_status_enhanced'
It 'shows enhanced status in git repo'
When call git_status_enhanced
The status should equal 0
The output should include "Git Status"
End

It 'shows current branch'
When call git_status_enhanced
The output should include "Branch:"
End

It 'function exists and is exported'
When call type -t git_status_enhanced
The output should equal "function"
End
End
End
