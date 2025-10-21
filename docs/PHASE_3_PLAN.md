# Phase 3: AI Integration - Implementation Plan

**Date:** 2025-10-21
**Status:** Planning
**Estimated Time:** 6-8 hours
**Priority:** High - Next phase after Phase 2 completion

---

## 📊 Analysis Summary

### Original Implementation (86_ai_assistant.zsh)

- **Size:** 72,812 LOC (largest file in ZSH project)
- **API Provider:** Google Gemini (not OpenAI)
- **Architecture:** Hybrid Bash/Python approach
- **Python Scripts:** 6 helper scripts for robustness
- **Key Features:** Context-aware AI, caching, secure key storage, error handling

### Source File Analysis

**Main Functions Identified:**

- `ai()` - Primary CLI command with options parsing
- `ask_gemini()` - Core API integration
- `_assistant_get_python()` - Python venv management
- `_assistant_try_load_api_key()` - Secure keychain integration
- `_ai_build_context()` - Context gathering (git, project, history)
- `analyze_history()` - Command history analysis
- `learn()` - Interactive learning mode
- `aidaily()` - Daily AI summaries

**Python Helper Scripts:**

- `assistant_core.py` - Main API caller (5,348 bytes)
- `parse_gemini_response.py` - JSON parsing (1,719 bytes)
- `behavioral_analyzer.py` - Pattern analysis (9,767 bytes)
- `goal_validator.py` - Goal validation (9,091 bytes)
- `encode_gemini_payload.py` - Request encoding (384 bytes)
- `sha1.py` - Portable hashing (242 bytes)

---

## 🎯 Phase 3 Goals

### MVP (Minimum Viable Product)

**Core functionality that MUST work:**

1. ✅ Basic AI query command: `harm-cli ai "question"`
2. ✅ API key management (environment + keychain)
3. ✅ Response caching (1 hour TTL)
4. ✅ Error handling with fallback suggestions
5. ✅ Context-aware responses (current directory, git status)
6. ✅ JSON + text output formats

### Nice-to-Have (Defer to Phase 3.5 or later if needed)

- History analysis
- Daily summaries
- Learning mode
- Code review features
- Multi-turn conversations

---

## 🔧 Technical Architecture

### Decision: Pure Bash vs Bash+Python

**RECOMMENDATION: Pure Bash (for now)**

**Rationale:**

1. **Consistency:** Entire harm-cli codebase is pure bash
2. **Dependencies:** Avoid Python dependency and venv management complexity
3. **Testability:** Easier to mock with ShellSpec
4. **Code Quality:** Maintain strict bash standards we've established
5. **Simplicity:** curl + jq is sufficient for API calls

**Trade-offs Accepted:**

- Slightly more verbose JSON handling (mitigated with jq)
- Manual JSON escaping (acceptable with proper quoting)
- No Python's `google-generativeai` library (we use REST API directly)

**Future:** Can add Python helpers later if complexity demands it

---

### API Provider Decision

**RECOMMENDATION: Start with Gemini, Design for Extensibility**

**Why Gemini:**

1. ✅ Original implementation uses it (port accuracy)
2. ✅ Free tier is generous (more forgiving during development)
3. ✅ REST API is simple and well-documented
4. ✅ No rate limits for basic usage

**Architecture for Future OpenAI Support:**

- Abstract API interface in separate functions
- Provider-agnostic error codes
- Configuration-driven provider selection
- Future: `HARM_CLI_AI_PROVIDER=openai|gemini|anthropic`

**API Endpoint:**

```
https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent
```

---

## 📁 File Structure

### New Files

**lib/ai.sh** (~300 LOC)

```bash
#!/usr/bin/env bash
# AI integration module
# API: Gemini (Google)
# Features: Query, context, caching, key management

# Core functions:
ai_query()              # Main query function
ai_check_requirements() # Validate dependencies
ai_get_api_key()        # Secure key retrieval
ai_build_context()      # Gather environment context
ai_cache_get()          # Cache retrieval
ai_cache_set()          # Cache storage
ai_make_request()       # HTTP request with curl
ai_parse_response()     # Extract text from JSON
ai_fallback()           # Offline suggestions
```

**spec/ai_spec.sh** (~25 tests)

```bash
# Test categories:
# - Requirements check (curl, jq, API key)
# - API key retrieval (env, keychain)
# - Context building (git, directory)
# - Cache operations (get/set/expiry)
# - API request (MOCKED with curl)
# - Response parsing
# - Error handling
# - Fallback mode
```

---

## 🏗️ Module Design (SOLID Principles)

### Single Responsibility Principle (SRP)

**✅ DO:** Separate concerns into focused functions

```bash
# GOOD - Each function has ONE responsibility
ai_query() {
    # Orchestrates the flow
    local query="$1"
    ai_check_requirements || return 1
    local key=$(ai_get_api_key) || return 2
    local context=$(ai_build_context)
    local cached=$(ai_cache_get "$query")
    [[ -n "$cached" ]] && echo "$cached" && return 0
    local response=$(ai_make_request "$key" "$query" "$context")
    ai_cache_set "$query" "$response"
    ai_parse_response "$response"
}

# Each helper does ONE thing:
ai_get_api_key() { ... }       # ONLY retrieves API key
ai_build_context() { ... }     # ONLY builds context
ai_cache_get() { ... }         # ONLY reads cache
ai_make_request() { ... }      # ONLY calls API
```

**❌ DON'T:** Mix multiple responsibilities

```bash
# BAD - God function doing everything
ai_query() {
    # Check requirements
    command -v curl || die "curl required"
    command -v jq || die "jq required"
    # Get API key
    local key="${GEMINI_API_KEY:-}"
    [[ -z "$key" ]] && key=$(security find-generic-password...)
    # Build context
    local context="Dir: $PWD\n"
    [[ -d .git ]] && context+="Git: $(git status)\n"
    # Check cache
    local cache_file="..."
    # Make request
    # Parse response
    # ... 200+ lines of mixed concerns
}
```

### Open/Closed Principle (OCP)

**✅ DO:** Design for extension without modification

```bash
# Abstract API provider interface
ai_provider_request() {
    local provider="${HARM_CLI_AI_PROVIDER:-gemini}"
    case "$provider" in
        gemini)
            _ai_gemini_request "$@"
            ;;
        openai)
            _ai_openai_request "$@"  # Future extension
            ;;
        *)
            die "Unknown AI provider: $provider"
            ;;
    esac
}

# Provider-specific implementations
_ai_gemini_request() { ... }
_ai_openai_request() { ... }  # Can add later
```

### Liskov Substitution Principle (LSP)

**✅ DO:** Consistent error codes across all functions

```bash
# All AI functions follow same error contract
ai_query()         # Returns: 0=success, 1=requirements, 2=no_key, 3=network, 4=rate_limit
ai_make_request()  # Returns: 0=success, 3=network, 4=rate_limit
ai_cache_get()     # Returns: 0=found, 1=not_found/expired

# Callers can rely on consistent exit codes
```

### Interface Segregation Principle (ISP)

**✅ DO:** Small, focused interfaces

```bash
# Public API (exported functions)
export -f ai_query
export -f ai_check_requirements

# Private helpers (not exported, prefixed with _ai_)
_ai_make_request() { ... }
_ai_parse_json() { ... }
_ai_cache_hash() { ... }

# Users only see what they need
```

### Dependency Inversion Principle (DIP)

**✅ DO:** Depend on abstractions (environment, standard tools)

```bash
# Depend on interface (env var), not specific storage
ai_get_api_key() {
    # Try environment first (abstraction)
    local key="${GEMINI_API_KEY:-}"

    # Fallback to keychain if available
    if [[ -z "$key" ]] && command -v security >/dev/null; then
        key=$(security find-generic-password -s harm-cli-gemini -w 2>/dev/null)
    fi

    # Not hardcoded to specific storage mechanism
    echo "$key"
}
```

---

## 🔐 Security Considerations

### API Key Storage

**Priority Order (highest to lowest security):**

1. **Keychain (macOS)**

   ```bash
   # Store (one-time setup)
   security add-generic-password -a "$USER" -s "harm-cli-gemini" -w "API_KEY"

   # Retrieve
   security find-generic-password -s "harm-cli-gemini" -w
   ```

2. **secret-tool (Linux)**

   ```bash
   # Store
   secret-tool store --label='harm-cli Gemini API' service harm-cli-gemini

   # Retrieve
   secret-tool lookup service harm-cli-gemini
   ```

3. **Pass (Password Store)**

   ```bash
   # Store
   pass insert harm-cli/gemini-api-key

   # Retrieve
   pass show harm-cli/gemini-api-key | head -n1
   ```

4. **Environment Variable** (convenient but less secure)

   ```bash
   export GEMINI_API_KEY="your-key-here"
   ```

5. **Config File** (~/.harm-cli/config - permissions 600)
   ```bash
   # ONLY if no other option available
   # File must have 0600 permissions
   GEMINI_API_KEY="your-key-here"
   ```

### Validation

```bash
ai_get_api_key() {
    local key=""

    # Try environment
    key="${GEMINI_API_KEY:-}"

    # Try keychain (macOS)
    if [[ -z "$key" ]] && command -v security >/dev/null 2>&1; then
        key=$(security find-generic-password -s harm-cli-gemini -w 2>/dev/null || true)
    fi

    # Try secret-tool (Linux)
    if [[ -z "$key" ]] && command -v secret-tool >/dev/null 2>&1; then
        key=$(secret-tool lookup service harm-cli-gemini 2>/dev/null || true)
    fi

    # Try pass
    if [[ -z "$key" ]] && command -v pass >/dev/null 2>&1; then
        key=$(pass show harm-cli/gemini-api-key 2>/dev/null | head -n1 || true)
    fi

    # Validate key format (basic check)
    if [[ -z "$key" ]]; then
        return 1
    fi

    if [[ ! "$key" =~ ^[A-Za-z0-9_-]{32,}$ ]]; then
        log_error "ai" "Invalid API key format"
        return 1
    fi

    echo "$key"
    return 0
}
```

### Secure Transmission

- ✅ Always use HTTPS (Gemini API enforces this)
- ✅ API key in headers, not URL query params
- ✅ Use `-s` (silent) flag with curl to avoid leaking in logs
- ✅ Timeout requests to prevent hanging

---

## 🧪 Testing Strategy

### Mocking Approach

**CRITICAL:** All API tests must be MOCKED (no real API calls)

**Strategy: Mock curl command**

```bash
# In spec/ai_spec.sh

Describe 'lib/ai.sh'
  Include spec/helpers/env.sh

  # Mock curl for all AI tests
  BeforeAll 'setup_ai_mocks'
  AfterAll 'cleanup_ai_mocks'

  # Create fake curl that returns canned responses
  setup_ai_mocks() {
    # Create mock curl executable
    cat > "$TEST_TMP/curl" <<'EOF'
#!/usr/bin/env bash
# Mock curl for AI tests
# Return canned Gemini response
jq -nc '{
  "candidates": [{
    "content": {
      "parts": [{
        "text": "This is a mocked AI response for testing"
      }]
    }
  }]
}'
EOF
    chmod +x "$TEST_TMP/curl"
    export PATH="$TEST_TMP:$PATH"  # Mock curl takes precedence
  }

  cleanup_ai_mocks() {
    rm -f "$TEST_TMP/curl"
  }
End
```

### Test Coverage Plan

**spec/ai_spec.sh** (~25 tests)

```bash
Describe 'AI Requirements Check'
  It 'detects missing curl'
  It 'detects missing jq'
  It 'detects missing API key'
  It 'passes when all requirements met'
End

Describe 'API Key Retrieval'
  It 'reads from GEMINI_API_KEY environment variable'
  It 'reads from keychain when env not set'
  It 'fails gracefully when no key found'
  It 'validates key format (basic check)'
End

Describe 'Context Building'
  It 'includes current directory'
  It 'includes git status when in repo'
  It 'excludes git when not in repo'
  It 'includes project type detection'
End

Describe 'Cache Operations'
  It 'generates consistent cache keys'
  It 'retrieves cached responses'
  It 'respects cache TTL (1 hour)'
  It 'skips expired cache entries'
  It 'stores new responses in cache'
End

Describe 'API Request (MOCKED)'
  It 'makes successful request with valid key'
  It 'handles network errors gracefully'
  It 'handles API errors (400, 401, 429, 500)'
  It 'respects timeout settings'
  It 'includes context in request'
End

Describe 'Response Parsing'
  It 'extracts text from valid Gemini response'
  It 'handles malformed JSON'
  It 'handles empty responses'
End

Describe 'CLI Integration'
  It 'harm-cli ai "question" works'
  It 'harm-cli ai --help shows help'
  It 'harm-cli --format json ai "question" returns JSON'
End

Describe 'Fallback Mode'
  It 'provides offline suggestions when API unavailable'
End
```

---

## 🔄 Implementation Phases

### Phase 3A: Core API Integration (3-4 hours)

**Tasks:**

1. ✅ Create `lib/ai.sh` skeleton with load guard
2. ✅ Implement `ai_check_requirements()`
3. ✅ Implement `ai_get_api_key()` with keychain support
4. ✅ Implement `ai_make_request()` with curl
5. ✅ Implement `ai_parse_response()` with jq
6. ✅ Implement `ai_query()` orchestration
7. ✅ Add to `bin/harm-cli` (new `ai` subcommand)

**Validation:**

```bash
# Manual test (with real API key)
export GEMINI_API_KEY="your-test-key"
./bin/harm-cli ai "Hello, what can you do?"

# Should return AI response
```

### Phase 3B: Caching & Context (2 hours)

**Tasks:**

1. ✅ Implement `ai_cache_hash()` (consistent key generation)
2. ✅ Implement `ai_cache_get()`
3. ✅ Implement `ai_cache_set()`
4. ✅ Implement `ai_build_context()` (dir, git, project type)
5. ✅ Integrate caching into `ai_query()`

**Validation:**

```bash
# First call - should hit API
time harm-cli ai "test query"  # ~2-3 seconds

# Second call - should use cache
time harm-cli ai "test query"  # <0.1 seconds, shows "(cached)"
```

### Phase 3C: Testing (1-2 hours)

**Tasks:**

1. ✅ Create `spec/ai_spec.sh`
2. ✅ Implement curl mock helper
3. ✅ Write 25 comprehensive tests
4. ✅ Run `just test` - all pass
5. ✅ Update README with AI features

**Validation:**

```bash
shellspec spec/ai_spec.sh
# 25 examples, 0 failures

just ci
# All checks pass
```

### Phase 3D: Polish & Documentation (1 hour)

**Tasks:**

1. ✅ Add error messages for all failure modes
2. ✅ Create help text for `harm-cli ai --help`
3. ✅ Update `docs/PROGRESS.md`
4. ✅ Create `docs/AI_USAGE.md`
5. ✅ Git commit with conventional commit message

**Validation:**

```bash
harm-cli ai --help  # Shows comprehensive help
just doctor         # Passes (curl, jq detected)
just lint           # Passes (shellcheck clean)
```

---

## 📋 CLI Interface Design

### Command Structure

```bash
harm-cli ai [OPTIONS] [QUERY]
```

### Options

| Option            | Description          | Example                                |
| ----------------- | -------------------- | -------------------------------------- |
| `--help`, `-h`    | Show help            | `harm-cli ai --help`                   |
| `--setup`         | Configure API key    | `harm-cli ai --setup`                  |
| `--no-cache`      | Skip cache           | `harm-cli ai --no-cache "question"`    |
| `--context`, `-c` | Include full context | `harm-cli ai -c "explain this error"`  |
| `--format json`   | JSON output          | `harm-cli --format json ai "question"` |

### Examples

```bash
# Basic query
harm-cli ai "How do I list files recursively?"

# With context
harm-cli ai -c "What should I work on next?"

# Without cache
harm-cli ai --no-cache "Give me a random suggestion"

# JSON output
harm-cli --format json ai "Suggest improvements"
{
  "response": "Here are some suggestions...",
  "cached": false,
  "timestamp": "2025-10-21T10:30:00Z"
}

# Setup API key
harm-cli ai --setup
> Enter your Gemini API key: ***
> Store in keychain? (y/n): y
✓ API key stored securely
```

### Context Auto-Detection

When no query provided, auto-includes context:

```bash
harm-cli ai
# Equivalent to:
harm-cli ai -c "Based on my current context, what should I focus on?"
```

---

## 🎨 Output Format

### Text Format (Default)

```
🤖 Thinking...

Here are some suggestions for your Python project:

- `pytest tests/` - Run your test suite with verbose output
- `ruff check --fix` - Auto-fix linting issues
- `git commit -m "feat: add new feature"` - Commit your staged changes

💡 Tip: Use `harm-cli work start` to track this session
```

### JSON Format

```json
{
  "response": "Here are some suggestions...",
  "context": {
    "directory": "/Users/harm/harm-cli",
    "git_branch": "phase-3/ai-integration",
    "project_type": "bash"
  },
  "cached": false,
  "timestamp": "2025-10-21T10:30:00Z",
  "model": "gemini-2.0-flash-exp",
  "tokens": {
    "prompt": 234,
    "completion": 156
  }
}
```

---

## 🚨 Error Handling

### Exit Codes

| Code | Meaning              | User Action               |
| ---- | -------------------- | ------------------------- |
| 0    | Success              | -                         |
| 1    | Requirements missing | Install curl/jq           |
| 2    | No API key           | Run `harm-cli ai --setup` |
| 3    | Network error        | Check connection          |
| 4    | Rate limit           | Wait and retry            |
| 5    | Invalid response     | Report bug                |

### Error Messages

**Requirements Missing:**

```
❌ Required dependency missing: curl
Install with: brew install curl (macOS)
```

**No API Key:**

```
❌ Gemini API key not set

To set up:
1. Get API key from: https://aistudio.google.com/app/apikey
2. Run: harm-cli ai --setup
3. Or export GEMINI_API_KEY="your-key"
```

**Network Error:**

```
❌ Network error (timeout after 20s)
Check your connection and try again.
```

**Rate Limit:**

```
❌ API rate limit reached
Wait a few minutes and try again.
Free tier limit: 15 requests/minute
```

### Fallback Mode

When API unavailable, provide offline suggestions:

```
⚠️  AI unavailable - here are some general suggestions:

- `harm-cli work status` - Check your current work session
- `harm-cli goal show` - View today's goals
- `harm-cli doctor` - Check system health
- `just test` - Run test suite
```

---

## 📝 Code Quality Checklist

### Before Starting Implementation

- [x] Read all Phase 1-2 code to understand patterns
- [x] Review `docs/BASH_STANDARDS.md`
- [x] Review `docs/check-list.md` (Definition of Done)
- [x] Understand existing error handling patterns
- [x] Understand existing logging patterns

### During Implementation

- [ ] Every function has clear, single responsibility
- [ ] Input validation on all user-provided data
- [ ] Proper error handling with specific exit codes
- [ ] Quote ALL variables ("$var", not $var)
- [ ] Use `readonly` for constants
- [ ] Use `local` for function-local variables
- [ ] Export public functions with `export -f`
- [ ] Prefix private functions with `_ai_`
- [ ] Comprehensive inline comments
- [ ] Docstrings for all public functions

### Before Committing

- [ ] All tests pass: `just test` (158 + 25 = 183 tests)
- [ ] Shellcheck clean: `just lint` (zero warnings)
- [ ] Formatted: `just fmt`
- [ ] Load guard present in `lib/ai.sh`
- [ ] No bash arithmetic gotchas (pre-increment only)
- [ ] No hardcoded API keys or secrets
- [ ] Documentation updated (README, PROGRESS.md)
- [ ] Conventional commit message

---

## 🔗 Dependencies

### Required

- **bash 5.0+** (already required)
- **curl** - HTTP requests
- **jq** - JSON parsing

### Optional

- **security** (macOS) - Keychain integration
- **secret-tool** (Linux) - Keychain integration
- **pass** - Password store integration

### Validation

```bash
# Check in harm-cli doctor
harm-cli doctor

Required Dependencies:
  ✅ bash 5.3.3
  ✅ jq 1.6
  ✅ curl 8.1.2

Optional Dependencies (AI Features):
  ✅ security (keychain)
  ❌ secret-tool (not installed)
  ❌ pass (not installed)

✅ All required dependencies installed
⚠️  Some optional features unavailable
```

---

## 📊 Success Criteria

### Functional Requirements

- [x] User can run `harm-cli ai "question"` and get response
- [x] Responses are cached (1 hour TTL)
- [x] API key can be stored securely (keychain)
- [x] Works in JSON output mode
- [x] Context includes current directory, git status
- [x] Error messages are clear and actionable
- [x] Offline fallback suggestions work
- [x] Help text is comprehensive

### Non-Functional Requirements

- [x] No API calls in tests (all mocked)
- [x] 25+ comprehensive tests
- [x] 100% shellcheck clean
- [x] Response time < 5 seconds (API dependent)
- [x] Cache lookup time < 0.1 seconds
- [x] No hardcoded secrets
- [x] SOLID principles followed

### Code Quality

- [x] < 300 LOC in `lib/ai.sh`
- [x] Average function length < 20 lines
- [x] Cyclomatic complexity < 10 per function
- [x] All exported functions documented
- [x] All error paths tested

---

## 🎯 Next Steps

### After Phase 3 Complete

**Phase 3.5 (Optional Enhancement):**

- Command history analysis
- Daily AI summaries
- Interactive learning mode
- Code review integration

**Phase 4 (Git & Projects):**

- Smart commits with AI-generated messages
- PR description generation
- Branch naming suggestions

---

## 📚 References

### Gemini API Documentation

- **API Reference:** https://ai.google.dev/api/rest
- **Generate Content:** https://ai.google.dev/api/rest/v1beta/models/generateContent
- **API Key:** https://aistudio.google.com/app/apikey

### Internal Documentation

- `docs/BASH_STANDARDS.md` - Bash best practices
- `docs/check-list.md` - Definition of Done
- `docs/PROGRESS.md` - Migration tracker
- `CONTRIBUTING.md` - Code standards

### Testing Resources

- **ShellSpec:** https://shellspec.info/
- **Mocking Guide:** https://github.com/shellspec/shellspec#mocking

---

## 💡 Design Decisions Log

### Decision 1: Pure Bash (No Python)

**Rationale:** Consistency with entire codebase, easier testing, fewer dependencies
**Trade-off:** More verbose JSON handling (acceptable with jq)

### Decision 2: Gemini over OpenAI

**Rationale:** Port accuracy, generous free tier, simpler API
**Future:** Design allows adding OpenAI later

### Decision 3: 1-Hour Cache TTL

**Rationale:** Balance freshness vs API usage
**Configurable:** `HARM_CLI_AI_CACHE_TTL` (seconds)

### Decision 4: Mock curl in Tests

**Rationale:** No external dependencies, fast tests, no API costs
**Implementation:** PATH manipulation with fake curl script

### Decision 5: Keychain-First Security

**Rationale:** Best practice for API key storage
**Fallback:** Environment variable for CI/automation

---

**Last Updated:** 2025-10-21
**Author:** Harm Aalbers
**Status:** Ready for Implementation ✅
