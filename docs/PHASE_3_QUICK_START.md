# Phase 3 Quick Start Guide

**Use this as a checklist while implementing Phase 3**

---

## 🚀 Implementation Order

### Step 1: Create Branch

```bash
cd ~/harm-cli
git checkout main
git pull
git checkout -b phase-3/ai-integration
```

### Step 2: Create `lib/ai.sh` Skeleton

```bash
#!/usr/bin/env bash
# shellcheck shell=bash
# ai.sh - AI integration with Gemini API
# Ported from: ~/.zsh/86_ai_assistant.zsh

set -Eeuo pipefail
IFS=$'\n\t'

# Load guard
[[ -n "${_HARM_AI_LOADED:-}" ]] && return 0

# Dependencies
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/error.sh"
source "$SCRIPT_DIR/logging.sh"
source "$SCRIPT_DIR/util.sh"

# Configuration
readonly GEMINI_API_ENDPOINT="https://generativelanguage.googleapis.com/v1beta/models"
readonly GEMINI_DEFAULT_MODEL="gemini-2.0-flash-exp"
readonly AI_CACHE_TTL=3600  # 1 hour
readonly AI_TIMEOUT=20      # 20 seconds

# Mark as loaded
readonly _HARM_AI_LOADED=1
```

### Step 3: Implement Functions (Order Matters!)

**3A. Requirements Check (15 min)**

```bash
ai_check_requirements() {
    # Check curl
    # Check jq
    # Return appropriate exit codes
}
```

**3B. API Key Retrieval (30 min)**

```bash
ai_get_api_key() {
    # Try GEMINI_API_KEY env
    # Try keychain (macOS security)
    # Try secret-tool (Linux)
    # Try pass (password store)
    # Validate format
}
```

**3C. Context Building (20 min)**

```bash
ai_build_context() {
    # Current directory
    # Git status (if in repo)
    # Project type detection
    # Format as markdown
}
```

**3D. Cache Operations (30 min)**

```bash
ai_cache_hash() {
    # Generate consistent hash from query
}

ai_cache_get() {
    # Check if cached response exists
    # Check if expired (TTL)
    # Return cached content or exit 1
}

ai_cache_set() {
    # Store response with timestamp
    # Ensure cache directory exists
}
```

**3E. API Request (45 min)**

```bash
ai_make_request() {
    local api_key="$1"
    local query="$2"
    local context="$3"

    # Build JSON request body with jq
    # Make curl request
    # Handle errors (network, timeout, rate limit)
    # Return response
}
```

**3F. Response Parsing (20 min)**

```bash
ai_parse_response() {
    local response="$1"

    # Extract text from Gemini JSON structure
    # Handle malformed JSON
    # Return plain text
}
```

**3G. Main Query Function (30 min)**

```bash
ai_query() {
    local query="$1"
    local use_cache="${2:-true}"

    # Check requirements
    # Get API key
    # Build context
    # Check cache
    # Make request
    # Parse response
    # Store in cache
    # Output result
}
```

**3H. Fallback Suggestions (10 min)**

```bash
ai_fallback() {
    # Provide offline suggestions
    echo "⚠️  AI unavailable - here are some suggestions:"
    echo "- harm-cli work status"
    echo "- harm-cli goal show"
    # etc.
}
```

**3I. Export Functions**

```bash
export -f ai_query
export -f ai_check_requirements
# Don't export private functions (_ai_*)
```

---

## 🧪 Step 4: Create Tests

### Create `spec/ai_spec.sh`

```bash
#!/usr/bin/env bash
# ShellSpec tests for AI module

Describe 'lib/ai.sh'
  Include spec/helpers/env.sh

  BeforeAll 'setup_ai_test_env'
  AfterAll 'cleanup_ai_test_env'

  setup_ai_test_env() {
    # Create mock curl
    cat > "$TEST_TMP/curl" <<'EOF'
#!/usr/bin/env bash
# Mock curl for AI tests
jq -nc '{
  "candidates": [{
    "content": {
      "parts": [{
        "text": "Mock AI response"
      }]
    }
  }]
}'
EOF
    chmod +x "$TEST_TMP/curl"
    export PATH="$TEST_TMP:$PATH"

    # Set test API key
    export GEMINI_API_KEY="test_key_for_testing_only"

    # Source the module
    source "$ROOT/lib/ai.sh"
  }

  cleanup_ai_test_env() {
    rm -f "$TEST_TMP/curl"
    unset GEMINI_API_KEY
  }

  Describe 'ai_check_requirements'
    It 'passes when curl and jq available'
      When call ai_check_requirements
      The status should be success
    End
  End

  Describe 'ai_get_api_key'
    It 'retrieves key from environment'
      When call ai_get_api_key
      The output should equal "test_key_for_testing_only"
      The status should be success
    End
  End

  # Add 23 more tests...
End
```

---

## 🔧 Step 5: Integrate with CLI

### Edit `bin/harm-cli`

```bash
# Around line 250 (after goal command)

"ai")
  shift
  case "${1:-query}" in
    --help|-h)
      cmd_ai_help
      ;;
    --setup)
      cmd_ai_setup
      ;;
    *)
      # Load AI module
      source "$LIB_DIR/ai.sh"
      ai_query "$*"
      ;;
  esac
  ;;
```

### Add help function

```bash
cmd_ai_help() {
  cat <<'EOF'
harm-cli ai - AI-powered development assistant

Usage:
  harm-cli ai [OPTIONS] [QUERY]

Options:
  -h, --help        Show this help
  --setup           Configure API key
  --no-cache        Skip cache
  -c, --context     Include full context

Examples:
  harm-cli ai "How do I list files?"
  harm-cli ai -c "What should I work on?"
  harm-cli ai --setup

API Key:
  Get your Gemini API key from:
  https://aistudio.google.com/app/apikey

  Store it securely:
  - Run: harm-cli ai --setup
  - Or: export GEMINI_API_KEY="your-key"
EOF
}
```

---

## ✅ Step 6: Testing Checklist

```bash
# Run ShellSpec tests
shellspec spec/ai_spec.sh
# Should show: 25 examples, 0 failures

# Run full test suite
just test
# Should show: 183 examples (158 + 25), 0 failures

# Lint check
just lint
# Should show: 0 errors

# Format check
just fmt
```

---

## 🧪 Step 7: Manual Testing

### With Real API Key

```bash
# Export test key
export GEMINI_API_KEY="your-real-key-here"

# Test basic query
./bin/harm-cli ai "Hello, what can you do?"
# Should return AI response

# Test caching
time ./bin/harm-cli ai "test query"  # ~2-3 seconds
time ./bin/harm-cli ai "test query"  # <0.1 seconds (cached)

# Test context
cd /tmp && ./bin/harm-cli ai -c "analyze this directory"

# Test JSON output
./bin/harm-cli --format json ai "test"
# Should return valid JSON

# Test error handling
unset GEMINI_API_KEY
./bin/harm-cli ai "test"
# Should show helpful error message

# Test fallback
# (Disconnect network or use invalid key)
./bin/harm-cli ai "test"
# Should show offline suggestions
```

---

## 📝 Step 8: Documentation

### Update Files

1. **README.md** - Add AI features
2. **docs/PROGRESS.md** - Mark Phase 3 complete
3. **CHANGELOG.md** - Add Phase 3 entry

### Create AI Usage Guide

Create `docs/AI_USAGE.md`:

```markdown
# AI Assistant Usage Guide

## Quick Start

...

## API Key Setup

...

## Examples

...
```

---

## 🎯 Step 9: Commit & Push

```bash
# Stage all files
git add -A

# Commit with conventional commit format
git commit -m "feat(phase-3): add AI integration with Gemini API

- Pure bash implementation with curl + jq
- Secure API key management (keychain support)
- Response caching (1 hour TTL)
- Context-aware queries (directory, git, project type)
- Comprehensive error handling with fallbacks
- 25 ShellSpec tests (all mocked, no real API calls)
- JSON + text output formats

API key sources (priority order):
1. GEMINI_API_KEY environment variable
2. macOS Keychain (security command)
3. Linux secret-tool
4. pass (password store)

Commands:
- harm-cli ai \"query\" - Ask AI a question
- harm-cli ai --setup - Configure API key
- harm-cli ai --help - Show help

Closes #3 (AI Integration)"

# Push to GitHub
git push -u origin phase-3/ai-integration
```

---

## 📊 Step 10: Create PR

```bash
# Open PR creation URL
open "https://github.com/HarmAalbers/harm-cli/compare/main...phase-3/ai-integration?expand=1"
```

**PR Title:**

```
Phase 3: AI Integration with Gemini API (Elite Quality ✨)
```

**PR Description:**

````markdown
## Summary

Implements AI-powered development assistant using Google's Gemini API.

## Features

- ✅ Pure bash implementation (no Python dependencies)
- ✅ Secure API key management (keychain, env, secret-tool, pass)
- ✅ Response caching (1 hour TTL)
- ✅ Context-aware queries (directory, git status, project type)
- ✅ Comprehensive error handling with offline fallbacks
- ✅ JSON + text output formats
- ✅ 25 comprehensive tests (100% mocked - no real API calls)

## Commands

```bash
harm-cli ai "question"           # Ask AI
harm-cli ai --setup              # Configure API key
harm-cli ai -c "specific query"  # Include full context
harm-cli --format json ai "q"    # JSON output
```
````

## Testing

```bash
just test  # 183/183 tests passing ✅
just lint  # shellcheck clean ✅
just ci    # Full pipeline passing ✅
```

## Metrics

- **Code:** ~300 LOC (lib/ai.sh)
- **Tests:** 25 tests (spec/ai_spec.sh)
- **Coverage:** 100% of public API
- **Code Reduction:** ~80% (from 72,812 LOC ZSH)

## Breaking Changes

None - backward compatible

## Documentation

- `docs/PHASE_3_PLAN.md` - Architecture & design
- `docs/AI_USAGE.md` - User guide
- Updated README.md

```

---

## 🎉 Success Criteria

- [x] All 25 AI tests passing
- [x] All 158 existing tests still passing
- [x] Shellcheck clean (0 warnings)
- [x] Manual testing with real API works
- [x] Caching works (fast repeated queries)
- [x] Error messages are helpful
- [x] Fallback mode works when offline
- [x] Documentation complete

---

## 💡 Tips

### While Implementing

1. **Test as you go** - Don't wait until the end
2. **Use TDD** - Write test first, then implementation
3. **Keep functions small** - < 20 lines average
4. **Quote everything** - "$var", not $var
5. **Check exit codes** - Every command that can fail
6. **Log liberally** - Use log_debug for troubleshooting

### Common Pitfalls

❌ Forgetting load guard
❌ Using $(( var++ )) instead of $(( ++var ))
❌ Not quoting variables
❌ Not checking command exit codes
❌ Hardcoding paths
❌ Missing input validation
❌ Real API calls in tests

### When Stuck

1. Look at existing Phase 1-2 code for patterns
2. Check `docs/BASH_STANDARDS.md`
3. Run shellcheck on your code
4. Read ShellSpec docs for mocking
5. Test with `set -x` for debugging

---

## 📞 Need Help?

- **Bash Standards:** `docs/BASH_STANDARDS.md`
- **DoD Checklist:** `docs/check-list.md`
- **Phase 1-2 Examples:** `lib/error.sh`, `lib/work.sh`, `lib/goals.sh`
- **Test Examples:** `spec/error_spec.sh`, `spec/goals_spec.sh`

---

**Estimated Time:** 6-8 hours
**Difficulty:** Medium (API integration, caching, mocking)
**Reward:** Elite-tier AI integration! 🚀
```
