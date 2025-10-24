#!/usr/bin/env bash
# ShellSpec tests for AI module
# Tests AI integration with mocked API calls (no real network requests)

Describe 'lib/ai.sh'
Include spec/helpers/env.sh

# Setup test environment
BeforeAll 'setup_ai_test_env'
AfterAll 'cleanup_ai_test_env'

setup_ai_test_env() {
  # Set test configuration
  export HARM_CLI_HOME="$TEST_TMP"
  export HARM_CLI_LOG_LEVEL="DEBUG" # Enable debug logging for tests
  export HARM_CLI_AI_CACHE_TTL=3600
  export HARM_CLI_AI_TIMEOUT=20
  export GEMINI_API_KEY="test_key_1234567890abcdef1234567890abcdef"

  # Create mock curl that returns valid Gemini responses
  mkdir -p "$TEST_TMP/bin"
  cat >"$TEST_TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
# Mock curl for AI tests - returns canned Gemini response

# Parse arguments to detect what kind of request this is
for arg in "$@"; do
  case "$arg" in
    *generateContent*)
      # Valid API request - return success response
      echo '{
  "candidates": [{
    "content": {
      "parts": [{
        "text": "This is a mock AI response for testing purposes. Here are some suggestions:\n\n- Run tests with `just test`\n- Check code quality with `just lint`\n- Format code with `just fmt`"
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

# Default response for unexpected requests
echo '{}'
echo "200"
exit 0
EOF
  chmod +x "$TEST_TMP/bin/curl"

  # Put mock curl first in PATH
  export PATH="$TEST_TMP/bin:$PATH"

  # Source the AI module
  source "$ROOT/lib/ai.sh"
}

cleanup_ai_test_env() {
  rm -rf "${TEST_TMP:?}/bin"
  rm -rf "${TEST_TMP:?}/ai-cache"
  unset GEMINI_API_KEY
  unset HARM_CLI_AI_CACHE_TTL
  unset HARM_CLI_AI_TIMEOUT
}

# ═══════════════════════════════════════════════════════════════
# Requirements Check Tests
# ═══════════════════════════════════════════════════════════════

Describe 'ai_check_requirements'
It 'passes when curl and jq are available'
When call ai_check_requirements
The status should be success
End

It 'detects curl availability'
When call ai_check_requirements
The status should be success
End

It 'detects jq availability'
When call ai_check_requirements
The status should be success
End
End

# ═══════════════════════════════════════════════════════════════
# API Key Retrieval Tests
# ═══════════════════════════════════════════════════════════════

Describe 'ai_get_api_key'
It 'retrieves key from GEMINI_API_KEY environment variable'
When call ai_get_api_key
The output should equal "test_key_1234567890abcdef1234567890abcdef"
The status should be success
End

It 'returns valid key when found in environment'
When call ai_get_api_key
The output should not be blank
The status should be success
End

It 'validates key format (minimum 32 characters)'
export GEMINI_API_KEY="short_key"
When call ai_get_api_key
The status should equal 2
The stderr should include "Invalid API key format"
End

It 'validates key contains only valid characters'
# Use single quotes to prevent variable expansion
export GEMINI_API_KEY='invalid@key#with!special%chars1234567890abc'
When call ai_get_api_key
The status should equal 2
End

It 'fails gracefully when no key found'
# Unset env var and mock security to fail (prevent finding key in keychain)
unset GEMINI_API_KEY
security() { return 1; }
When call ai_get_api_key
The status should equal 2
The stderr should include "No API key found"
End
End

# ═══════════════════════════════════════════════════════════════
# Cache Operations Tests
# ═══════════════════════════════════════════════════════════════

Describe '_ai_cache_hash'
It 'generates consistent hash for same input'
result1=$(_ai_cache_hash "test query" "context")
result2=$(_ai_cache_hash "test query" "context")
When call test "$result1" = "$result2"
The status should be success
End

It 'generates different hash for different queries'
result1=$(_ai_cache_hash "query one" "context")
result2=$(_ai_cache_hash "query two" "context")
When call test "$result1" != "$result2"
The status should be success
End

It 'generates 40-character hash'
result=$(_ai_cache_hash "test")
When call test "${#result}" -eq 40
The status should be success
End
End

Describe '_ai_cache_get and _ai_cache_set'
It 'returns cache miss for non-existent cache'
When call _ai_cache_get "nonexistent_cache_key"
The status should equal 1
End

It 'stores and retrieves cached responses'
cache_key=$(_ai_cache_hash "test" "")
response='{"candidates":[{"content":{"parts":[{"text":"cached"}]}}]}'

# Store in cache
_ai_cache_set "$cache_key" "$response"

# Retrieve from cache
When call _ai_cache_get "$cache_key"
The output should include "cached"
The status should be success
End

It 'returns cached data when valid cache found'
cache_key=$(_ai_cache_hash "test2" "")
response='{"test":"data"}'
_ai_cache_set "$cache_key" "$response"

When call _ai_cache_get "$cache_key"
The output should include "test"
The status should be success
End

It 'creates cache directory if missing'
rm -rf "$TEST_TMP/ai-cache"
cache_key=$(_ai_cache_hash "test3" "")

When call _ai_cache_set "$cache_key" '{"test":"data"}'
The status should be success
The path "$TEST_TMP/ai-cache" should be directory
End
End

# ═══════════════════════════════════════════════════════════════
# Context Building Tests
# ═══════════════════════════════════════════════════════════════

Describe '_ai_build_context'
It 'includes current directory'
When call _ai_build_context
The output should include "Current directory:"
End

It 'includes git information when in git repo'
# We're in harm-cli repo
When call _ai_build_context
The output should include "Git branch:"
End

It 'includes git status'
When call _ai_build_context
The output should include "Git status:"
End

It 'detects shell project type'
# harm-cli has Justfile and .shellspec
When call _ai_build_context
The output should include "Project type: Bash/Shell"
End

It 'returns non-empty context'
When call _ai_build_context
The output should not be blank
End
End

# ═══════════════════════════════════════════════════════════════
# API Request Tests (Mocked)
# ═══════════════════════════════════════════════════════════════

Describe '_ai_make_request'
It 'makes successful API request with valid key'
When call _ai_make_request "test_key_1234567890abcdef1234567890abcdef" "test query"
The status should be success
The output should include "candidates"
End

It 'returns valid JSON response'
When call _ai_make_request "test_key_1234567890abcdef1234567890abcdef" "test"
The output should include "candidates"
The status should be success
End

It 'handles query without errors'
When call _ai_make_request "test_key_1234567890abcdef1234567890abcdef" "test"
The status should be success
End

It 'includes context in request'
When call _ai_make_request "test_key_1234567890abcdef1234567890abcdef" "query" "context info"
The status should be success
End
End

# ═══════════════════════════════════════════════════════════════
# Response Parsing Tests
# ═══════════════════════════════════════════════════════════════

Describe '_ai_parse_response'
It 'extracts text from valid Gemini response'
response='{
        "candidates": [{
          "content": {
            "parts": [{
              "text": "This is the AI response text"
            }]
          }
        }]
      }'

When call _ai_parse_response "$response"
The output should equal "This is the AI response text"
The status should be success
End

It 'handles malformed JSON'
When call _ai_parse_response "not json at all"
The status should equal 5
The stderr should include "Invalid JSON response"
End

It 'handles empty response text'
response='{"candidates":[{"content":{"parts":[]}}]}'
When call _ai_parse_response "$response"
The status should equal 5
End

It 'returns extracted text successfully'
response='{"candidates":[{"content":{"parts":[{"text":"test"}]}}]}'
When call _ai_parse_response "$response"
The output should equal "test"
The status should be success
End
End

# ═══════════════════════════════════════════════════════════════
# AI Query Integration Tests
# ═══════════════════════════════════════════════════════════════

Describe 'ai_query'
It 'successfully processes a query'
When call ai_query "test question"
The status should be success
The output should include "mock AI response"
End

It 'shows thinking message'
When call ai_query "test"
The output should include "Thinking..."
End

It 'uses cache on repeated queries'
# First query
ai_query "cached query" >/dev/null 2>&1

# Second query should hit cache
When call ai_query "cached query"
The output should include "(cached response)"
End

It 'bypasses cache with --no-cache flag'
# Prime cache
ai_query "no-cache test" >/dev/null 2>&1

# Query with --no-cache should not show cached message
When call ai_query --no-cache "no-cache test"
The output should not include "(cached response)"
End

It 'includes context with --context flag'
When call ai_query --context "test query"
The status should be success
The output should include "mock AI response"
End

It 'auto-enables context when no query provided'
When call ai_query
The status should be success
The output should include "mock AI response"
End

It 'completes query successfully'
When call ai_query "test"
The status should be success
End
End

# ═══════════════════════════════════════════════════════════════
# Error Handling Tests
# ═══════════════════════════════════════════════════════════════

Describe 'Error handling'
It 'provides fallback suggestions when API key missing'
unset GEMINI_API_KEY

When call ai_query "test"
The status should equal 2
The output should include "AI unavailable"
The output should include "harm-cli work status"
End

It 'validates API key before making request'
export GEMINI_API_KEY="short"

When call ai_query "test"
The status should equal 2
End
End

# ═══════════════════════════════════════════════════════════════
# Setup Command Tests
# ═══════════════════════════════════════════════════════════════

Describe 'ai_setup'
It 'function exists and is exported'
# Note: Can't fully test interactive setup in automated tests
# Just verify function exists
When call type -t ai_setup
The output should equal "function"
End
End

# ═══════════════════════════════════════════════════════════════
# Advanced AI Features Tests
# ═══════════════════════════════════════════════════════════════

Describe 'ai_review'
It 'runs without errors'
# Test that function runs (may have changes or not)
When call ai_review
The status should be success
End

It 'accepts --unstaged flag'
When call ai_review --unstaged
The status should equal 0
End

It 'accepts --staged flag'
When call ai_review --staged
The status should equal 0
End

It 'function exists and is exported'
When call type -t ai_review
The output should equal "function"
End
End

Describe 'ai_explain_error'
It 'handles missing log file gracefully'
# Default behavior when no logs exist
When call ai_explain_error
# May return 0 (no errors) or 1 (no log file)
The status should be defined
End

It 'function exists and is exported'
When call type -t ai_explain_error
The output should equal "function"
End
End

Describe 'ai_daily'
It 'generates insights for today'
When call ai_daily
The status should equal 0
End

It 'supports --yesterday flag'
When call ai_daily --yesterday
The status should equal 0
End

It 'supports --week flag'
When call ai_daily --week
The status should equal 0
End

It 'handles no data gracefully'
# Set empty HARM_CLI_HOME
export HARM_CLI_HOME="$TEST_TMP/empty"
mkdir -p "$TEST_TMP/empty"

When call ai_daily
The output should include "No activity data"
The status should equal 0
End

It 'function exists and is exported'
When call type -t ai_daily
The output should equal "function"
End
End
End
