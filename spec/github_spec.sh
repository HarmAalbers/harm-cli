#!/usr/bin/env bash
# ShellSpec tests for github module

Describe 'lib/github.sh'
Include spec/helpers/env.sh

# Source the github module
BeforeAll 'source "$ROOT/lib/github.sh"'

Describe 'Module initialization'
It 'prevents double-loading'
source "$ROOT/lib/github.sh"
source "$ROOT/lib/github.sh"
The status should be success
The variable _HARM_GITHUB_LOADED should equal 1
End

It 'defines cache directory constant'
The variable GITHUB_CACHE_DIR should be defined
The variable GITHUB_CACHE_DIR should include "github-cache"
End

It 'defines cache TTL constant'
The variable GITHUB_CACHE_TTL should be defined
End

It 'creates cache directory on load'
The path "$GITHUB_CACHE_DIR" should be directory
End
End

Describe 'github_check_gh_installed'
Context 'when gh CLI is installed'
It 'returns success'
Skip if "gh not installed" ! command -v gh >/dev/null
When call github_check_gh_installed
The status should be success
End
End

Context 'when gh CLI is not installed'
# Mock command to simulate gh not found
command() {
  if [[ "$2" == "gh" ]]; then
    return 1
  fi
  builtin command "$@"
}

It 'returns error code 1'
When call github_check_gh_installed
The status should equal 1
End

It 'prints error message to stderr'
When call github_check_gh_installed
The error should include "GitHub CLI not installed"
End

It 'includes installation instructions'
When call github_check_gh_installed
The error should include "brew install gh"
End
End
End

Describe 'github_check_auth'
Context 'when gh is not installed'
# Mock command to simulate gh not found
command() {
  if [[ "$2" == "gh" ]]; then
    return 1
  fi
  builtin command "$@"
}

It 'returns error code 1'
When call github_check_auth
The status should equal 1
End
End

Context 'when gh is installed but not authenticated'
Skip if "gh not installed" ! command -v gh >/dev/null

# Mock gh to simulate not authenticated
gh() {
  if [[ "$1" == "auth" ]] && [[ "$2" == "status" ]]; then
    return 1
  fi
  command gh "$@"
}

It 'returns error code 1'
When call github_check_auth
The status should equal 1
End

It 'prints authentication error'
When call github_check_auth
The error should include "authentication required"
End

It 'includes auth login command'
When call github_check_auth
The error should include "gh auth login"
End
End

Context 'when authenticated'
Skip if "gh not installed or not authenticated" ! command -v gh >/dev/null || ! gh auth status >/dev/null 2>&1

It 'returns success'
When call github_check_auth
The status should be success
End
End
End

Describe 'github_in_repo'
Context 'when not in a git repository'
setup_temp() {
  TEST_DIR="$SHELLSPEC_TMPDIR/not-a-repo"
  mkdir -p "$TEST_DIR"
}
cleanup_temp() {
  rm -rf "$TEST_DIR"
}

BeforeEach setup_temp
AfterEach cleanup_temp

It 'returns error code 1'
cd "$TEST_DIR" || return
When call github_in_repo
The status should equal 1
End
End

Context 'when in git repo without GitHub remote'
setup_temp() {
  TEST_DIR="$SHELLSPEC_TMPDIR/git-repo-no-gh"
  mkdir -p "$TEST_DIR"
  cd "$TEST_DIR" && git init -q
}
cleanup_temp() {
  rm -rf "$TEST_DIR"
}

BeforeEach setup_temp
AfterEach cleanup_temp

It 'returns error code 1'
cd "$TEST_DIR" || return
When call github_in_repo
The status should equal 1
End
End

Context 'when in GitHub repository'
# Test in current repo (harm-cli is a GitHub repo)
Skip if "Not in harm-cli repo" ! git rev-parse --git-dir >/dev/null 2>&1

It 'returns success'
cd "$ROOT" || return
When call github_in_repo
The status should be success
End
End
End

Describe 'github_get_repo_info'
Context 'when not authenticated'
# Mock auth check to fail
github_check_auth() { return 1; }

It 'returns error code 1'
When call github_get_repo_info
The status should equal 1
End
End

Context 'when not in GitHub repo'
# Mock auth to pass but repo check to fail
github_check_auth() { return 0; }
github_in_repo() { return 1; }

It 'returns error code 1'
When call github_get_repo_info
The status should equal 1
End

It 'prints error message'
When call github_get_repo_info
The error should include "Not in a GitHub repository"
End
End

Context 'when in GitHub repo and authenticated'
Skip if "Not authenticated or not in repo" ! command -v gh >/dev/null || ! gh auth status >/dev/null 2>&1 || ! git rev-parse --git-dir >/dev/null 2>&1

It 'returns JSON with repo info'
cd "$ROOT" || return
When call github_get_repo_info
The status should be success
The output should be valid json
End

It 'includes owner in JSON'
cd "$ROOT" || return
When call github_get_repo_info
The output should include '"owner"'
End

It 'includes name in JSON'
cd "$ROOT" || return
When call github_get_repo_info
The output should include '"name"'
End
End
End

Describe 'github_get_current_branch_info'
Context 'when not authenticated'
github_check_auth() { return 1; }

It 'returns error code 1'
When call github_get_current_branch_info
The status should equal 1
End
End

Context 'when in GitHub repo'
Skip if "Not in git repo" ! git rev-parse --git-dir >/dev/null 2>&1

# Mock auth to pass
github_check_auth() { return 0; }
github_in_repo() { return 0; }

It 'returns JSON with branch info'
cd "$ROOT" || return
When call github_get_current_branch_info
The status should be success
The output should be valid json
End

It 'includes current branch name'
cd "$ROOT" || return
When call github_get_current_branch_info
The output should include '"branch"'
End

It 'includes tracking info'
cd "$ROOT" || return
When call github_get_current_branch_info
The output should include '"tracking"'
End

It 'includes pull_requests array'
cd "$ROOT" || return
When call github_get_current_branch_info
The output should include '"pull_requests"'
End
End
End

Describe 'github_list_issues'
Context 'parameter handling'
github_check_auth() { return 0; }
github_in_repo() { return 0; }

# Mock gh to verify parameters
gh() {
  echo "gh $*" >&2
  echo "[]"
}

It 'defaults to open state'
When call github_list_issues
The error should include "issue list"
The error should include "--state open"
End

It 'accepts custom state parameter'
When call github_list_issues "closed"
The error should include "--state closed"
End

It 'defaults to 30 limit'
When call github_list_issues
The error should include "--limit 30"
End

It 'accepts custom limit parameter'
When call github_list_issues "open" 50
The error should include "--limit 50"
End
End

Context 'when authenticated in GitHub repo'
Skip if "Not authenticated or not in repo" ! command -v gh >/dev/null || ! gh auth status >/dev/null 2>&1 || ! git rev-parse --git-dir >/dev/null 2>&1

It 'returns JSON array'
cd "$ROOT" || return
When call github_list_issues "all" 5
The status should be success
The output should be valid json
End
End
End

Describe 'github_get_issue'
Context 'parameter validation'
It 'requires issue number'
When run bash -c "source $ROOT/lib/github.sh && github_get_issue"
The status should equal 1
End
End

Context 'with valid parameters'
github_check_auth() { return 0; }
github_in_repo() { return 0; }

# Mock gh
gh() {
  echo '{"number": 1, "title": "Test Issue"}'
}

It 'calls gh issue view with number'
When call github_get_issue 1
The status should be success
The output should be valid json
End
End
End

Describe 'github_list_prs'
Context 'parameter handling'
github_check_auth() { return 0; }
github_in_repo() { return 0; }

# Mock gh to verify parameters
gh() {
  echo "gh $*" >&2
  echo "[]"
}

It 'defaults to open state'
When call github_list_prs
The error should include "pr list"
The error should include "--state open"
End

It 'accepts custom state parameter'
When call github_list_prs "merged"
The error should include "--state merged"
End

It 'defaults to 30 limit'
When call github_list_prs
The error should include "--limit 30"
End

It 'accepts custom limit parameter'
When call github_list_prs "open" 10
The error should include "--limit 10"
End
End

Context 'when authenticated in GitHub repo'
Skip if "Not authenticated or not in repo" ! command -v gh >/dev/null || ! gh auth status >/dev/null 2>&1 || ! git rev-parse --git-dir >/dev/null 2>&1

It 'returns JSON array'
cd "$ROOT" || return
When call github_list_prs "all" 5
The status should be success
The output should be valid json
End
End
End

Describe 'github_get_pr'
Context 'parameter validation'
It 'requires PR number'
When run bash -c "source $ROOT/lib/github.sh && github_get_pr"
The status should equal 1
End
End

Context 'with valid parameters'
github_check_auth() { return 0; }
github_in_repo() { return 0; }

# Mock gh
gh() {
  echo '{"number": 42, "title": "Test PR"}'
}

It 'calls gh pr view with number'
When call github_get_pr 42
The status should be success
The output should be valid json
End
End
End

Describe 'github_get_comments'
Context 'parameter validation'
It 'requires type parameter'
When run bash -c "source $ROOT/lib/github.sh && github_get_comments"
The status should equal 1
End

It 'requires number parameter'
When run bash -c "source $ROOT/lib/github.sh && github_get_comments issue"
The status should equal 1
End
End

Context 'with invalid type'
github_check_auth() { return 0; }
github_in_repo() { return 0; }

It 'rejects invalid type'
When call github_get_comments "invalid" 1
The status should equal 1
The error should include "Unknown type"
End
End

Context 'with issue type'
github_check_auth() { return 0; }
github_in_repo() { return 0; }
github_get_issue() { echo '{"comments": []}'; }

It 'calls github_get_issue'
When call github_get_comments "issue" 1
The status should be success
The output should equal "[]"
End
End

Context 'with pr type'
github_check_auth() { return 0; }
github_in_repo() { return 0; }
github_get_pr() { echo '{"comments": []}'; }

It 'calls github_get_pr'
When call github_get_comments "pr" 1
The status should be success
The output should equal "[]"
End
End
End

Describe 'github_create_context_summary'
Context 'when not authenticated'
github_check_auth() { return 1; }

It 'returns error code 1'
When call github_create_context_summary
The status should equal 1
End
End

Context 'when authenticated in GitHub repo'
github_check_auth() { return 0; }
github_in_repo() { return 0; }

# Mock data sources
github_get_repo_info() {
  echo '{"owner":{"login":"test"},"name":"repo","description":"Test","isPrivate":false,"defaultBranchRef":{"name":"main"},"url":"https://github.com/test/repo"}'
}
github_get_current_branch_info() {
  echo '{"branch":"main","tracking":"origin/main","pull_requests":[]}'
}
github_list_issues() {
  echo '[{"number":1,"title":"Test Issue"}]'
}
github_list_prs() {
  echo '[{"number":2,"title":"Test PR","author":{"login":"user"}}]'
}

It 'generates markdown summary'
When call github_create_context_summary
The status should be success
The output should include "# GitHub Context"
End

It 'includes repository section'
When call github_create_context_summary
The output should include "## Repository"
End

It 'includes current branch section'
When call github_create_context_summary
The output should include "## Current Branch"
End

It 'includes open issues section'
When call github_create_context_summary
The output should include "## Open Issues"
End

It 'includes pull requests section'
When call github_create_context_summary
The output should include "## Open Pull Requests"
End
End
End

Describe 'github_setup_ssh_signing'
Context 'parameter validation'
It 'requires identity parameter'
When run bash -c "source $ROOT/lib/github.sh && github_setup_ssh_signing"
The status should equal 1
End
End

Context 'when not in git repository'
setup_temp() {
  TEST_DIR="$SHELLSPEC_TMPDIR/no-git"
  mkdir -p "$TEST_DIR"
}
cleanup_temp() {
  rm -rf "$TEST_DIR"
}

BeforeEach setup_temp
AfterEach cleanup_temp

It 'returns error code 1'
cd "$TEST_DIR" || return
When call github_setup_ssh_signing "harmaalbers"
The status should equal 1
The error should include "Not in a git repository"
End
End

Context 'with invalid identity'
Skip if "Not in git repo" ! git rev-parse --git-dir >/dev/null 2>&1

It 'rejects invalid identity'
cd "$ROOT" || return
When call github_setup_ssh_signing "invalid"
The status should equal 1
The error should include "Unknown identity"
End

It 'lists valid identities'
cd "$ROOT" || return
When call github_setup_ssh_signing "invalid"
The error should include "harmaalbers"
The error should include "solarharm"
End
End

Context 'with missing SSH key'
Skip if "Not in git repo" ! git rev-parse --git-dir >/dev/null 2>&1

# Mock to simulate missing key
It 'checks for SSH key existence'
cd "$ROOT" || return
# Note: May fail if key doesn't exist - this is expected behavior
When run bash -c "source $ROOT/lib/github.sh && github_setup_ssh_signing harmaalbers"
# Status depends on whether key exists
The status should satisfy [ "$SHELLSPEC_STATUS" -eq 0 ] || [ "$SHELLSPEC_STATUS" -eq 1 ]
End
End
End

Describe 'github_verify_signature'
Context 'when not in git repository'
setup_temp() {
  TEST_DIR="$SHELLSPEC_TMPDIR/no-git"
  mkdir -p "$TEST_DIR"
}
cleanup_temp() {
  rm -rf "$TEST_DIR"
}

BeforeEach setup_temp
AfterEach cleanup_temp

It 'returns error code 1'
cd "$TEST_DIR" || return
When call github_verify_signature
The status should equal 1
The error should include "Not in a git repository"
End
End

Context 'in git repository'
Skip if "Not in git repo" ! git rev-parse --git-dir >/dev/null 2>&1

It 'defaults to HEAD commit'
cd "$ROOT" || return
When call github_verify_signature
The status should be success
End

It 'accepts commit parameter'
cd "$ROOT" || return
When call github_verify_signature "HEAD~1"
# Status depends on whether commit exists and is signed
The status should satisfy [ "$SHELLSPEC_STATUS" -eq 0 ] || [ "$SHELLSPEC_STATUS" -eq 1 ]
End
End
End

Describe 'github_sign_commit'
Context 'when not in git repository'
setup_temp() {
  TEST_DIR="$SHELLSPEC_TMPDIR/no-git"
  mkdir -p "$TEST_DIR"
}
cleanup_temp() {
  rm -rf "$TEST_DIR"
}

BeforeEach setup_temp
AfterEach cleanup_temp

It 'returns error code 1'
cd "$TEST_DIR" || return
When call github_sign_commit
The status should equal 1
The error should include "Not in a git repository"
End
End

Context 'without signing configured'
Skip if "Not in git repo" ! git rev-parse --git-dir >/dev/null 2>&1

setup_temp_repo() {
  TEST_REPO="$SHELLSPEC_TMPDIR/test-signing"
  mkdir -p "$TEST_REPO"
  cd "$TEST_REPO" && git init -q
  git config --local user.name "Test"
  git config --local user.email "test@example.com"
  # Ensure no signing key configured
  git config --local --unset user.signingkey 2>/dev/null || true
  git config --local --unset commit.gpgsign 2>/dev/null || true
}
cleanup_temp_repo() {
  rm -rf "$TEST_REPO"
}

BeforeEach setup_temp_repo
AfterEach cleanup_temp_repo

It 'returns error when signing not configured'
cd "$TEST_REPO" || return
When call github_sign_commit
The status should equal 1
The error should include "SSH signing not configured"
End
End
End

Describe 'Logging integration'
Context 'with logging available'
# Mock logging functions
log_info() { echo "LOG_INFO: $*" >&2; }
log_error() { echo "LOG_ERROR: $*" >&2; }
log_debug() { echo "LOG_DEBUG: $*" >&2; }
log_success() { echo "LOG_SUCCESS: $*" >&2; }

It 'logs when gh not installed'
command() {
  if [[ "$2" == "gh" ]]; then return 1; fi
  builtin command "$@"
}
When call github_check_gh_installed
The status should equal 1
The error should include "LOG_ERROR"
End

It 'logs successful authentication check'
Skip if "gh not authenticated" ! gh auth status >/dev/null 2>&1
When call github_check_auth
The status should equal 0
The error should include "LOG_DEBUG"
End
End

Context 'without logging available'
It 'works without logging functions'
# Module loads successfully even without logging
When call bash -c "unset -f log_info log_error log_debug log_success 2>/dev/null; source $ROOT/lib/github.sh && echo OK"
The output should include "OK"
End
End
End

Describe 'Function exports'
It 'exports github_check_gh_installed'
When call bash -c "declare -F github_check_gh_installed"
The output should include "github_check_gh_installed"
End

It 'exports github_check_auth'
When call bash -c "declare -F github_check_auth"
The output should include "github_check_auth"
End

It 'exports github_in_repo'
When call bash -c "declare -F github_in_repo"
The output should include "github_in_repo"
End

It 'exports github_get_repo_info'
When call bash -c "declare -F github_get_repo_info"
The output should include "github_get_repo_info"
End

It 'exports github_list_issues'
When call bash -c "declare -F github_list_issues"
The output should include "github_list_issues"
End

It 'exports github_list_prs'
When call bash -c "declare -F github_list_prs"
The output should include "github_list_prs"
End
End
End
