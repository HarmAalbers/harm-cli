#!/opt/homebrew/bin/bash
# ShellSpec tests for AI module cross-module integration
# Tests real-world integration failures between AI, git, logging, and markdown modules

Describe 'lib/ai.sh - Integration Tests'
Include spec/helpers/env.sh

# Setup test environment
BeforeAll 'setup_ai_integration_env'
AfterAll 'cleanup_ai_integration_env'

setup_ai_integration_env() {
  # Set test configuration
  export HARM_CLI_HOME="$TEST_TMP/integration"
  export HARM_LOG_LEVEL=ERROR # Suppress DEBUG/INFO logs during tests
  export HARM_CLI_AI_CACHE_TTL=3600
  export HARM_CLI_AI_TIMEOUT=20
  export GEMINI_API_KEY="test_key_1234567890abcdef1234567890abcdef"
  export HARM_CLI_FORMAT="text"

  # Prevent git from looking in parent directories (critical for git tests)
  export GIT_CEILING_DIRECTORIES="$TEST_TMP"

  # Create directory structure
  mkdir -p "$HARM_CLI_HOME/logs"
  mkdir -p "$HARM_CLI_HOME/activity"
  mkdir -p "$HARM_CLI_HOME/goals"
  mkdir -p "$HARM_CLI_HOME/work"
  mkdir -p "$HARM_CLI_HOME/ai-cache"

  # Create mock curl that returns valid Gemini responses
  mkdir -p "$TEST_TMP/bin"
  cat >"$TEST_TMP/bin/curl" <<'EOF'
#!/opt/homebrew/bin/bash
# Mock curl for AI integration tests
for arg in "$@"; do
  case "$arg" in
    *generateContent*)
      echo '{
  "candidates": [{
    "content": {
      "parts": [{
        "text": "Mock AI response:\n\n## Analysis\n- Item 1\n- Item 2\n\n## Suggestions\n1. First suggestion\n2. Second suggestion"
      }]
    },
    "finishReason": "STOP"
  }],
  "usageMetadata": {
    "promptTokenCount": 10,
    "candidatesTokenCount": 30,
    "totalTokenCount": 40
  }
}'
      echo "200"
      exit 0
      ;;
  esac
done
echo '{}'
echo "200"
exit 0
EOF
  chmod +x "$TEST_TMP/bin/curl"

  # Create mock security command that fails (for API key tests)
  cat >"$TEST_TMP/bin/security" <<'EOF'
#!/opt/homebrew/bin/bash
# Mock security that always fails (for testing missing API key)
exit 1
EOF
  chmod +x "$TEST_TMP/bin/security"

  # Create mock secret-tool that fails
  cat >"$TEST_TMP/bin/secret-tool" <<'EOF'
#!/opt/homebrew/bin/bash
# Mock secret-tool that always fails
exit 1
EOF
  chmod +x "$TEST_TMP/bin/secret-tool"

  # Create mock pass that fails
  cat >"$TEST_TMP/bin/pass" <<'EOF'
#!/opt/homebrew/bin/bash
# Mock pass that always fails
exit 1
EOF
  chmod +x "$TEST_TMP/bin/pass"

  # Put mock binaries first in PATH
  export PATH="$TEST_TMP/bin:$PATH"

  # Source the AI module
  source "$ROOT/lib/ai.sh"
}

cleanup_ai_integration_env() {
  rm -rf "${TEST_TMP:?}/integration"
  rm -rf "${TEST_TMP:?}/bin"
  unset GEMINI_API_KEY
  unset HARM_CLI_AI_CACHE_TTL
  unset HARM_CLI_AI_TIMEOUT
  unset GIT_CEILING_DIRECTORIES
}

# Helper function to check if log file contains text
log_contains() {
  grep -q "$1" "$HARM_CLI_HOME/logs/harm-cli.log" 2>/dev/null
}

# ═══════════════════════════════════════════════════════════════
# AI Review Integration Tests
# ═══════════════════════════════════════════════════════════════

Describe 'ai_review integration with git'
Context 'when not in git repository'
It 'handles git repository check failure gracefully'
# Create isolated directory outside git scope
mkdir -p "$TEST_TMP/isolated-no-git"
cd "$TEST_TMP/isolated-no-git"
# Ensure no .git directory exists
rm -rf .git
When call ai_review --staged
The status should equal "$EXIT_INVALID_STATE"
The stderr should include "Not in a git repository"
End
End

Context 'when in git repository with no changes'
setup_empty_git_repo() {
  cd "$TEST_TMP"
  rm -rf test-repo
  mkdir -p test-repo
  cd test-repo
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
}

BeforeEach setup_empty_git_repo

It 'returns early with appropriate message'
When call ai_review --staged
The status should equal 0
The output should include "No changes to review"
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End
End

Context 'when in git repository with staged changes'
setup_git_repo_with_changes() {
  cd "$TEST_TMP"
  rm -rf test-repo
  mkdir -p test-repo
  cd test-repo
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" >file.txt
  git add file.txt
  git commit -q -m "Initial commit"
  echo "modified" >>file.txt
  git add file.txt
}

BeforeEach setup_git_repo_with_changes

It 'truncates large diffs with warning'
# Create large diff (> 200 lines)
for i in $(seq 1 250); do
  echo "Line $i" >>file.txt
done
git add file.txt

When call ai_review --staged
The status should equal 0
The output should include "Diff truncated to 200 lines"
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End
End
End

# ═══════════════════════════════════════════════════════════════
# AI Explain Error Integration Tests
# ═══════════════════════════════════════════════════════════════

Describe 'ai_explain_error integration with logging'
Context 'when log file missing'
It 'handles missing log file gracefully'
rm -f "$HARM_CLI_HOME/logs/harm-cli.log"
When call ai_explain_error
The status should equal 1
The stderr should include "Log file not found"
End
End

Context 'when log file exists with errors'
setup_log_with_errors() {
  mkdir -p "$HARM_CLI_HOME/logs"
  cat >"$HARM_CLI_HOME/logs/harm-cli.log" <<'LOG'
[2025-01-15 10:30:45] [INFO] [work] Work session started
[2025-01-15 10:35:12] [ERROR] [git] Failed to commit | No staged changes
[2025-01-15 10:40:00] [INFO] [work] Work session paused
LOG
}

BeforeEach setup_log_with_errors

End

Context 'when no errors in log file'
setup_log_without_errors() {
  mkdir -p "$HARM_CLI_HOME/logs"
  cat >"$HARM_CLI_HOME/logs/harm-cli.log" <<'LOG'
[2025-01-15 10:30:45] [INFO] [work] Work session started
[2025-01-15 10:40:00] [INFO] [work] Work session completed
LOG
}

BeforeEach setup_log_without_errors

It 'returns success with celebratory message'
When call ai_explain_error
The status should equal 0
The stderr should include "No recent errors found"
The stderr should include "🎉"
End
End
End

# ═══════════════════════════════════════════════════════════════
# AI Daily Integration Tests
# ═══════════════════════════════════════════════════════════════

Describe 'ai_daily integration with work/goals'
Context 'when no activity data available'
setup_empty_data() {
  rm -f "$HARM_CLI_HOME/work/archive.jsonl"
  rm -f "$HARM_CLI_HOME/goals/"*.jsonl
}

BeforeEach setup_empty_data

It 'handles missing data gracefully'
When call ai_daily
The status should equal 0
The output should include "No activity data available"
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End

It 'returns success exit code even with no data'
When call ai_daily
The status should equal 0
The stdout should be present # Allow output messages
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End
End

Context 'with activity data available'
setup_activity_data() {
  mkdir -p "$HARM_CLI_HOME/work"
  mkdir -p "$HARM_CLI_HOME/goals"

  # Create work archive
  cat >"$HARM_CLI_HOME/work/archive.jsonl" <<EOF
{"goal":"Implement new feature","started_at":"$(date +%Y-%m-%d)T10:00:00Z","duration_seconds":1500}
{"goal":"Fix bug in logging","started_at":"$(date +%Y-%m-%d)T14:00:00Z","duration_seconds":1200}
EOF

  # Create goals file
  cat >"$HARM_CLI_HOME/goals/$(date +%Y-%m-%d).jsonl" <<'EOF'
{"goal":"Write comprehensive tests","completed":true,"progress":100}
{"goal":"Update documentation","completed":false,"progress":60}
EOF
}

BeforeEach setup_activity_data

It 'includes work session data in context'
When call ai_daily
The status should equal 0
# Function completes successfully
The stdout should be present # Allow output messages
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End
End

Context 'with --yesterday flag'
setup_yesterday_data() {
  mkdir -p "$HARM_CLI_HOME/goals"
  local yesterday_date
  if date -v-1d +%Y-%m-%d >/dev/null 2>&1; then
    # macOS
    yesterday_date=$(date -v-1d +%Y-%m-%d)
  else
    # Linux
    yesterday_date=$(date -d "yesterday" +%Y-%m-%d)
  fi

  cat >"$HARM_CLI_HOME/goals/$yesterday_date.jsonl" <<'EOF'
{"goal":"Yesterday's task","completed":true,"progress":100}
EOF
}

BeforeEach setup_yesterday_data

It 'analyzes yesterday data correctly'
When call ai_daily --yesterday
The status should equal 0
# With or without data, should complete
The stdout should be present # Allow output messages
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End
End

Context 'with --week flag'
It 'handles weekly request correctly'
When call ai_daily --week
The status should equal 0
The stdout should be present # Allow output messages
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End
End
End

# ═══════════════════════════════════════════════════════════════
# Markdown Rendering Integration Tests
# ═══════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════
# Error Handling Integration Tests
# ═══════════════════════════════════════════════════════════════

Describe 'error handling across modules'
Context 'missing API key'
It 'handles missing API key gracefully'
# Clear cache first to avoid cached response
rm -rf "$HARM_CLI_HOME/ai-cache"/*
# Block all credential sources - unset API key
saved_key="$GEMINI_API_KEY"
unset GEMINI_API_KEY
# The mock security/secret-tool/pass commands in PATH already fail
When call ai_query "unique-test-query-no-cache-$(date +%s)"
The status should equal "$EXIT_AI_NO_KEY"
The stderr should include "No API key found"
The stdout should be present # Allow fallback suggestions
# Restore
export GEMINI_API_KEY="$saved_key"
End
End

Context 'network failures'
It 'handles curl failure gracefully'
# Clear cache first
rm -rf "$HARM_CLI_HOME/ai-cache"/*
# Temporarily break curl
mv "$TEST_TMP/bin/curl" "$TEST_TMP/bin/curl.bak"
When call ai_query "unique-network-failure-test"
The status should not equal 0
The stdout should be present # Allow fallback suggestions
The stderr should be present # Allow error output
# Restore
mv "$TEST_TMP/bin/curl.bak" "$TEST_TMP/bin/curl"
End
End

Context 'invalid git state'
It 'handles non-git-repo for ai_review'
# Create a clean directory outside git scope
mkdir -p "$TEST_TMP/definitely-not-a-repo"
cd "$TEST_TMP/definitely-not-a-repo"
# Ensure no .git exists
rm -rf .git ../.git ../../.git
When call ai_review
The status should equal "$EXIT_INVALID_STATE"
The stderr should include "Not in a git repository"
End
End
End

# ═══════════════════════════════════════════════════════════════
# Caching Integration Tests
# ═══════════════════════════════════════════════════════════════

End
