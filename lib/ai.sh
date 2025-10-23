#!/usr/bin/env bash
# shellcheck shell=bash
# ai.sh - AI integration with Gemini API
# Ported from: ~/.zsh/86_ai_assistant.zsh
#
# Features:
# - Context-aware AI queries using Google Gemini
# - Secure API key management (keychain, env, secret-tool, pass)
# - Response caching with configurable TTL
# - Comprehensive error handling with fallbacks
# - JSON + text output formats
#
# Public API:
#   ai_query <query> [--no-cache]  - Query AI with optional cache bypass
#   ai_check_requirements          - Validate dependencies
#   ai_setup                       - Interactive API key setup
#
# Dependencies: curl, jq, logging.sh, error.sh, util.sh

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_AI_LOADED:-}" ]] && return 0

# Source dependencies
AI_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly AI_SCRIPT_DIR

# shellcheck source=lib/common.sh
source "$AI_SCRIPT_DIR/common.sh"
# shellcheck source=lib/error.sh
source "$AI_SCRIPT_DIR/error.sh"
# shellcheck source=lib/logging.sh
source "$AI_SCRIPT_DIR/logging.sh"
# shellcheck source=lib/util.sh
source "$AI_SCRIPT_DIR/util.sh"

# ═══════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════

readonly AI_API_ENDPOINT="https://generativelanguage.googleapis.com/v1beta/models"
readonly AI_DEFAULT_MODEL="${GEMINI_MODEL:-gemini-2.0-flash-exp}"
readonly AI_CACHE_DIR="${HARM_CLI_HOME:-$HOME/.harm-cli}/ai-cache"
readonly AI_CACHE_TTL="${HARM_CLI_AI_CACHE_TTL:-3600}" # Configurable: 1 hour default
readonly AI_TIMEOUT="${HARM_CLI_AI_TIMEOUT:-20}"       # Configurable: 20 seconds default
readonly AI_MAX_TOKENS="${HARM_CLI_AI_MAX_TOKENS:-2048}"

# AI Model Registry (name:description:tier:features)
declare -gA AI_MODELS=(
  ["gemini-2.0-flash-exp"]="Fast, latest experimental|Free tier|Multimodal (text+vision)"
  ["gemini-1.5-pro"]="Balanced, stable production|Paid tier|Text+Vision+Audio"
  ["gemini-1.5-flash"]="Ultra-fast, efficient|Free tier|Text only"
  ["gemini-1.5-flash-8b"]="Smallest, fastest|Free tier|Text only"
)

# Exit codes specific to AI module
readonly EXIT_AI_NO_KEY=2
readonly EXIT_AI_NETWORK=3
readonly EXIT_AI_RATE_LIMIT=4
readonly EXIT_AI_INVALID_RESPONSE=5

# ═══════════════════════════════════════════════════════════════════
# Requirements & Validation
# ═══════════════════════════════════════════════════════════════════

# ai_check_requirements: Validate AI module dependencies
#
# Description:
#   Checks for required external commands (curl, jq) needed for AI functionality.
#   Logs helpful installation instructions if dependencies are missing.
#
# Arguments:
#   None
#
# Returns:
#   0 - All requirements satisfied
#   EXIT_DEPENDENCY_MISSING - One or more dependencies missing
#
# Outputs:
#   stderr: Log messages via log_debug/log_error/log_warn, error messages via error_msg
#
# Examples:
#   ai_check_requirements || exit 1
#   if ai_check_requirements; then
#     echo "AI ready"
#   fi
#
# Notes:
#   - Checks for curl (HTTP requests) and jq (JSON parsing)
#   - Provides platform-specific installation instructions
#   - Safe to call multiple times (no side effects)
ai_check_requirements() {
  log_debug "ai" "Checking AI requirements"

  local missing=0

  # Check for curl
  if ! command -v curl >/dev/null 2>&1; then
    log_error "ai" "curl not found" "Required for API requests"
    error_msg "curl is required for AI features"
    error_msg "Install: brew install curl (macOS) or apt-get install curl (Linux)"
    missing=1
  else
    log_debug "ai" "curl found" "$(curl --version | head -n1)"
  fi

  # Check for jq
  if ! command -v jq >/dev/null 2>&1; then
    log_error "ai" "jq not found" "Required for JSON parsing"
    error_msg "jq is required for AI features"
    error_msg "Install: brew install jq (macOS) or apt-get install jq (Linux)"
    missing=1
  else
    log_debug "ai" "jq found" "$(jq --version)"
  fi

  if [[ $missing -eq 1 ]]; then
    log_warn "ai" "Missing required dependencies for AI features"
    return "$EXIT_DEPENDENCY_MISSING"
  fi

  log_debug "ai" "All AI requirements satisfied"
  return 0
}

# ═══════════════════════════════════════════════════════════════════
# API Key Management
# ═══════════════════════════════════════════════════════════════════

# ai_get_api_key: Retrieve Gemini API key from secure sources
#
# Description:
#   Attempts to retrieve API key from multiple sources in priority order:
#   1. GEMINI_API_KEY environment variable (highest priority)
#   2. macOS Keychain (via security command)
#   3. Linux secret-tool
#   4. pass (password store)
#   Validates key format before returning.
#
# Arguments:
#   None
#
# Returns:
#   0 - Key found and validated (key output to stdout)
#   EXIT_AI_NO_KEY - No key found or invalid format
#
# Outputs:
#   stdout: API key (if found)
#   stderr: Log messages via log_debug/log_error
#
# Examples:
#   api_key=$(ai_get_api_key) || die "No API key"
#   if key=$(ai_get_api_key); then
#     echo "Key length: ${#key}"
#   fi
#
# Notes:
#   - Keys must be 32+ characters, alphanumeric with dashes/underscores
#   - macOS: Uses `security find-generic-password -s harm-cli-gemini`
#   - Linux: Uses `secret-tool lookup service harm-cli-gemini`
#   - pass: Uses `pass show harm-cli/gemini-api-key`
#   - Never logs or exposes the actual key value
#
# Performance:
#   - Keychain lookup: ~50-100ms (first call), ~10ms (cached by OS)
#   - Environment variable: <1ms
ai_get_api_key() {
  log_debug "ai" "Attempting to retrieve API key"

  local key=""

  # Priority 1: Environment variable
  if [[ -n "${GEMINI_API_KEY:-}" ]]; then
    key="$GEMINI_API_KEY"
    log_debug "ai" "API key found in environment variable"

  # Priority 2: macOS Keychain
  elif command -v security >/dev/null 2>&1; then
    log_debug "ai" "Attempting to retrieve key from macOS Keychain"
    key=$(security find-generic-password -s "harm-cli-gemini" -w 2>/dev/null || true)
    if [[ -n "$key" ]]; then
      log_debug "ai" "API key retrieved from macOS Keychain"
    fi

  # Priority 3: Linux secret-tool
  elif command -v secret-tool >/dev/null 2>&1; then
    log_debug "ai" "Attempting to retrieve key from secret-tool"
    key=$(secret-tool lookup service harm-cli-gemini 2>/dev/null || true)
    if [[ -n "$key" ]]; then
      log_debug "ai" "API key retrieved from secret-tool"
    fi

  # Priority 4: pass (password store)
  elif command -v pass >/dev/null 2>&1; then
    log_debug "ai" "Attempting to retrieve key from pass"
    key=$(pass show harm-cli/gemini-api-key 2>/dev/null | head -n1 || true)
    if [[ -n "$key" ]]; then
      log_debug "ai" "API key retrieved from pass"
    fi
  fi

  # Validate key was found
  if [[ -z "$key" ]]; then
    log_error "ai" "No API key found" "Checked: env, keychain, secret-tool, pass"
    return "$EXIT_AI_NO_KEY"
  fi

  # Basic format validation (Gemini keys are alphanumeric with dashes/underscores, 32+ chars)
  if [[ ! "$key" =~ ^[A-Za-z0-9_-]{32,}$ ]]; then
    log_error "ai" "Invalid API key format" "Key length: ${#key}"
    return "$EXIT_AI_NO_KEY"
  fi

  log_debug "ai" "API key validated" "Length: ${#key} characters"
  echo "$key"
  return 0
}

# ai_setup: Interactive API key configuration
#
# Description:
#   Interactively prompts user for Gemini API key and stores it securely.
#   Attempts to store in system keychain (macOS/Linux) with fallback to
#   environment variable instructions if keychain unavailable.
#
# Arguments:
#   None (interactive prompts)
#
# Returns:
#   0 - API key configured successfully
#   EXIT_INVALID_ARGS - Invalid key format or user cancelled
#   EXIT_IO_ERROR - Failed to store in keychain
#
# Outputs:
#   stdout: Setup instructions and success messages
#   stderr: Log messages via log_info/log_debug/log_error
#
# Examples:
#   harm-cli ai --setup
#   ai_setup  # Direct function call
#
# Notes:
#   - Prompts for key with hidden input (read -s)
#   - Validates key format before storing
#   - macOS: Stores in Keychain via `security add-generic-password`
#   - Linux: Stores via `secret-tool store`
#   - Fallback: Displays environment variable export command
#   - Overwrites existing key if present
#
# Security:
#   - Key input is masked (not visible during typing)
#   - Validates format before accepting
#   - Uses secure OS keychains when available
ai_setup() {
  log_info "ai" "Starting API key setup"

  echo ""
  echo "🔐 AI Assistant Setup"
  echo ""
  echo "You'll need a Gemini API key from Google."
  echo "Get one here: https://aistudio.google.com/app/apikey"
  echo ""

  # Prompt for API key
  read -r -s -p "Enter your Gemini API key: " api_key
  echo ""

  if [[ -z "$api_key" ]]; then
    error_msg "No API key provided"
    return "$EXIT_INVALID_ARGS"
  fi

  # Validate format
  if [[ ! "$api_key" =~ ^[A-Za-z0-9_-]{32,}$ ]]; then
    error_msg "Invalid API key format"
    error_msg "Expected: 32+ alphanumeric characters with dashes/underscores"
    return "$EXIT_INVALID_ARGS"
  fi

  log_debug "ai" "API key validated" "Length: ${#api_key}"

  # Try to store in keychain (macOS)
  if command -v security >/dev/null 2>&1; then
    read -r -p "Store in macOS Keychain? (y/n): " store_keychain
    if [[ "$store_keychain" =~ ^[Yy]$ ]]; then
      # Delete existing key if present
      security delete-generic-password -s "harm-cli-gemini" 2>/dev/null || true

      # Add new key
      if security add-generic-password -a "$USER" -s "harm-cli-gemini" -w "$api_key" 2>/dev/null; then
        log_info "ai" "API key stored in macOS Keychain"
        success_msg "API key stored securely in Keychain"
      else
        log_error "ai" "Failed to store in Keychain"
        error_msg "Failed to store in Keychain"
        return "$EXIT_IO_ERROR"
      fi
    fi
  elif command -v secret-tool >/dev/null 2>&1; then
    read -r -p "Store with secret-tool? (y/n): " store_secret
    if [[ "$store_secret" =~ ^[Yy]$ ]]; then
      if echo "$api_key" | secret-tool store --label='harm-cli Gemini API' service harm-cli-gemini; then
        log_info "ai" "API key stored with secret-tool"
        success_msg "API key stored securely with secret-tool"
      else
        log_error "ai" "Failed to store with secret-tool"
        error_msg "Failed to store with secret-tool"
        return "$EXIT_IO_ERROR"
      fi
    fi
  else
    echo ""
    echo "⚠️  No secure storage available (keychain or secret-tool)"
    echo "Add this to your ~/.bashrc or ~/.zshrc:"
    echo ""
    echo "  export GEMINI_API_KEY=\"$api_key\""
    echo ""
  fi

  echo ""
  success_msg "AI assistant ready to use"
  echo "Try it: harm-cli ai \"Hello, what can you help with?\""
  echo ""

  log_info "ai" "API key setup completed"
  return 0
}

# ═══════════════════════════════════════════════════════════════════
# Cache Management
# ═══════════════════════════════════════════════════════════════════

# Generate consistent cache key from query and context
# Args: query string
# Returns: SHA1 hash on stdout
_ai_cache_hash() {
  local query="$1"
  local context="${2:-}"
  local input="$query|$context|$AI_DEFAULT_MODEL"

  log_debug "ai" "Generating cache key" "Input length: ${#input}"

  # Use sha1sum or shasum depending on platform
  local hash
  if command -v sha1sum >/dev/null 2>&1; then
    hash=$(echo -n "$input" | sha1sum | awk '{print $1}')
  elif command -v shasum >/dev/null 2>&1; then
    hash=$(echo -n "$input" | shasum -a 1 | awk '{print $1}')
  else
    # Fallback: use md5 (less ideal but better than nothing)
    hash=$(echo -n "$input" | md5sum 2>/dev/null | awk '{print $1}' || echo -n "$input" | md5 2>/dev/null || echo "no-cache")
  fi

  log_debug "ai" "Cache key generated" "Hash: $hash"
  echo "$hash"
}

# Retrieve cached response if valid (not expired)
# Args: cache_key
# Returns: 0 with response on stdout if valid cache hit, 1 otherwise
_ai_cache_get() {
  local cache_key="$1"
  local cache_file="$AI_CACHE_DIR/${cache_key}.json"

  log_debug "ai" "Checking cache" "Key: $cache_key"

  # Create cache directory if needed
  if [[ ! -d "$AI_CACHE_DIR" ]]; then
    log_debug "ai" "Creating cache directory" "$AI_CACHE_DIR"
    mkdir -p "$AI_CACHE_DIR" || {
      log_warn "ai" "Failed to create cache directory" "$AI_CACHE_DIR"
      return 1
    }
  fi

  # Check if cache file exists
  if [[ ! -f "$cache_file" ]]; then
    log_debug "ai" "Cache miss" "File not found"
    return 1
  fi

  # Check if cache is expired
  local now
  now=$(date +%s)
  local file_time
  file_time=$(stat -f%m "$cache_file" 2>/dev/null || stat -c%Y "$cache_file" 2>/dev/null || echo 0)
  local age=$((now - file_time))

  log_debug "ai" "Cache age check" "Age: ${age}s, TTL: ${AI_CACHE_TTL}s"

  if [[ $age -gt $AI_CACHE_TTL ]]; then
    log_debug "ai" "Cache expired" "Age ${age}s exceeds TTL ${AI_CACHE_TTL}s"
    return 1
  fi

  # Read and return cached response
  local cached_response
  cached_response=$(cat "$cache_file")

  log_info "ai" "Cache hit" "Age: ${age}s"
  echo "$cached_response"
  return 0
}

# Store response in cache
# Args: cache_key, response
_ai_cache_set() {
  local cache_key="$1"
  local response="$2"
  local cache_file="$AI_CACHE_DIR/${cache_key}.json"

  log_debug "ai" "Storing in cache" "Key: $cache_key"

  # Create cache directory if needed
  if [[ ! -d "$AI_CACHE_DIR" ]]; then
    mkdir -p "$AI_CACHE_DIR" || {
      log_warn "ai" "Failed to create cache directory" "$AI_CACHE_DIR"
      return 1
    }
  fi

  # Write response to cache file
  if echo "$response" >"$cache_file"; then
    log_debug "ai" "Cached response" "File: $cache_file"
    return 0
  else
    log_warn "ai" "Failed to cache response"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════════
# Context Building
# ═══════════════════════════════════════════════════════════════════

# Build context information for AI query
# Returns: context string on stdout
_ai_build_context() {
  log_debug "ai" "Building context"

  local context=""

  # Current directory
  context+="Current directory: $(pwd)\n"

  # Git information (if in a git repository)
  if git rev-parse --git-dir >/dev/null 2>&1; then
    local branch
    branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    context+="Git branch: $branch\n"

    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
      context+="Git status: uncommitted changes\n"
    else
      context+="Git status: clean\n"
    fi

    log_debug "ai" "Git context added" "Branch: $branch"
  fi

  # Project type detection
  if [[ -f "package.json" ]]; then
    context+="Project type: Node.js\n"
    log_debug "ai" "Detected Node.js project"
  elif [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]]; then
    context+="Project type: Python\n"
    log_debug "ai" "Detected Python project"
  elif [[ -f "Cargo.toml" ]]; then
    context+="Project type: Rust\n"
    log_debug "ai" "Detected Rust project"
  elif [[ -f "go.mod" ]]; then
    context+="Project type: Go\n"
    log_debug "ai" "Detected Go project"
  elif [[ -f "Justfile" ]] && [[ -f ".shellspec" ]]; then
    context+="Project type: Bash/Shell\n"
    log_debug "ai" "Detected Shell project"
  fi

  # Docker detection
  if [[ -f "docker-compose.yml" ]] || [[ -f "compose.yaml" ]] || [[ -f "Dockerfile" ]]; then
    context+="Docker: available\n"
    log_debug "ai" "Docker detected"
  fi

  log_debug "ai" "Context built" "Length: ${#context}"
  echo -e "$context"
}

# ═══════════════════════════════════════════════════════════════════
# API Communication
# ═══════════════════════════════════════════════════════════════════

# Make API request to Gemini
# Args: api_key, query, context
# Returns: 0 with JSON response on stdout, or error code
_ai_make_request() {
  local api_key="$1"
  local query="$2"
  local context="${3:-}"

  log_info "ai" "Making API request" "Model: $AI_DEFAULT_MODEL"

  # Combine context and query
  local full_prompt
  if [[ -n "$context" ]]; then
    full_prompt="$context\n\nQuestion: $query"
  else
    full_prompt="$query"
  fi

  # Build JSON request body using jq
  local request_body
  request_body=$(jq -n \
    --arg text "$full_prompt" \
    --argjson max_tokens "$AI_MAX_TOKENS" \
    '{
      contents: [{
        parts: [{
          text: $text
        }]
      }],
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: $max_tokens
      }
    }')

  log_debug "ai" "Request body generated" "Size: ${#request_body} bytes"

  # Make API request
  local api_url="${AI_API_ENDPOINT}/${AI_DEFAULT_MODEL}:generateContent"
  local response
  local http_code

  log_debug "ai" "Sending request" "Timeout: ${AI_TIMEOUT}s"

  # Execute curl with timeout and capture response + HTTP code
  response=$(curl -s -w "\n%{http_code}" \
    -m "$AI_TIMEOUT" \
    -H "Content-Type: application/json" \
    -H "x-goog-api-key: $api_key" \
    -d "$request_body" \
    "$api_url" 2>&1)

  local curl_status=$?

  # Extract HTTP code from last line
  http_code=$(echo "$response" | tail -n1)
  response=$(echo "$response" | sed '$d')

  # Check for curl errors (network, timeout, etc.)
  if [[ $curl_status -ne 0 ]]; then
    log_error "ai" "Network error" "curl exit code: $curl_status"

    if [[ $curl_status -eq 28 ]]; then
      error_msg "Request timeout after ${AI_TIMEOUT}s"
      return "$EXIT_AI_NETWORK"
    else
      error_msg "Network error (code: $curl_status)"
      return "$EXIT_AI_NETWORK"
    fi
  fi

  log_debug "ai" "API response received" "HTTP: $http_code, Size: ${#response} bytes"

  # Check HTTP status code
  case "$http_code" in
    200) # HTTP_OK
      log_info "ai" "API request successful"
      echo "$response"
      return 0
      ;;
    400) # HTTP_BAD_REQUEST
      log_error "ai" "Bad request" "HTTP $http_code"
      error_msg "Invalid request format"
      return "$EXIT_AI_INVALID_RESPONSE"
      ;;
    401 | 403) # HTTP_UNAUTHORIZED | HTTP_FORBIDDEN
      log_error "ai" "Authentication failed" "HTTP $http_code"
      error_msg "Invalid API key"
      return "$EXIT_AI_NO_KEY"
      ;;
    429) # HTTP_RATE_LIMIT
      log_error "ai" "Rate limit exceeded" "HTTP $http_code"
      error_msg "Rate limit exceeded - wait a moment and try again"
      return "$EXIT_AI_RATE_LIMIT"
      ;;
    500 | 502 | 503) # HTTP_INTERNAL_ERROR | HTTP_BAD_GATEWAY | HTTP_SERVICE_UNAVAILABLE
      log_error "ai" "Server error" "HTTP $http_code"
      error_msg "AI service temporarily unavailable"
      return "$EXIT_AI_NETWORK"
      ;;
    *)
      log_error "ai" "Unexpected HTTP status" "HTTP $http_code"
      error_msg "Unexpected API response (HTTP $http_code)"
      return "$EXIT_AI_INVALID_RESPONSE"
      ;;
  esac
}

# Parse Gemini API response and extract text
# Args: json_response
# Returns: 0 with text on stdout, or error code
_ai_parse_response() {
  local response="$1"

  log_debug "ai" "Parsing API response"

  # Validate JSON
  if ! echo "$response" | jq empty 2>/dev/null; then
    log_error "ai" "Invalid JSON response"
    return "$EXIT_AI_INVALID_RESPONSE"
  fi

  # Extract text from Gemini response structure
  local text
  text=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty')

  if [[ -z "$text" ]]; then
    log_error "ai" "Empty response text"

    # Check for error in response
    local api_error_msg
    api_error_msg=$(echo "$response" | jq -r '.error.message // "Unknown error"')
    if [[ "$api_error_msg" != "Unknown error" ]]; then
      log_error "ai" "API error" "$api_error_msg"
      error_msg "API error: $api_error_msg"
    fi

    return "$EXIT_AI_INVALID_RESPONSE"
  fi

  log_debug "ai" "Response parsed" "Text length: ${#text}"
  echo "$text"
  return 0
}

# ═══════════════════════════════════════════════════════════════════
# Fallback & Helpers
# ═══════════════════════════════════════════════════════════════════

# Provide offline suggestions when AI is unavailable
_ai_fallback() {
  log_info "ai" "Providing fallback suggestions"

  echo ""
  echo "⚠️  AI unavailable - here are some general suggestions:"
  echo ""
  echo "Work & Goals:"
  echo "  - harm-cli work status     Check current work session"
  echo "  - harm-cli goal show       View today's goals"
  echo ""
  echo "System:"
  echo "  - harm-cli doctor          Check system health"
  echo "  - just test                Run test suite"
  echo "  - just ci                  Run full CI pipeline"
  echo ""
  echo "Git:"
  echo "  - git status               Check repository status"
  echo "  - git log --oneline -10    View recent commits"
  echo ""
}

# ═══════════════════════════════════════════════════════════════════
# Public API
# ═══════════════════════════════════════════════════════════════════

# ai_query: Query AI assistant with optional context and caching
#
# Description:
#   Main entry point for AI queries. Supports context-aware responses by
#   including current directory, git status, and project type information.
#   Uses response caching (1-hour TTL) to reduce API calls and improve speed.
#
# Arguments:
#   $@ - query (string) and options:
#        --no-cache: Skip cache, always make fresh API request
#        --context|-c: Include full environment context in query
#        (All other arguments combined as the query text)
#
# Returns:
#   0 - Query successful, response displayed
#   EXIT_DEPENDENCY_MISSING - curl or jq not available
#   EXIT_AI_NO_KEY - No API key found or invalid format
#   EXIT_AI_NETWORK - Network error or timeout
#   EXIT_AI_RATE_LIMIT - API rate limit exceeded
#   EXIT_AI_INVALID_RESPONSE - Invalid or empty response
#
# Outputs:
#   stdout: AI response text or cached response indicator
#   stderr: Log messages via log_info/log_debug/log_error
#
# Examples:
#   ai_query "How do I list files recursively?"
#   ai_query --context "What should I focus on next?"
#   ai_query --no-cache "Give me a fresh suggestion"
#   ai_query  # No args = auto-context mode with default query
#
# Notes:
#   - Auto-enables context mode if no query provided
#   - Cache key based on query + context + model (SHA1 hash)
#   - Cache TTL configurable via HARM_CLI_AI_CACHE_TTL (default: 3600s)
#   - Displays "(cached response)" indicator for cache hits
#   - Falls back to offline suggestions if API unavailable
#
# Performance:
#   - Cache hit: <100ms (file read + JSON parse)
#   - Cache miss: 2-5s (API latency dependent)
#   - Context building: ~10-50ms (depends on git repo size)
#
# Environment Variables:
#   GEMINI_API_KEY - API key (optional if stored in keychain)
#   HARM_CLI_AI_CACHE_TTL - Cache TTL in seconds (default: 3600)
#   HARM_CLI_AI_TIMEOUT - API timeout in seconds (default: 20)
#   HARM_CLI_AI_MAX_TOKENS - Max response tokens (default: 2048)
ai_query() {
  local query=""
  local use_cache=1
  local include_context=0

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-cache)
        use_cache=0
        log_debug "ai" "Cache disabled by flag"
        shift
        ;;
      --context | -c)
        include_context=1
        log_debug "ai" "Full context requested"
        shift
        ;;
      *)
        query+="$1 "
        shift
        ;;
    esac
  done

  # Trim query
  query=$(echo "$query" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  # Auto-detect context if no query
  if [[ -z "$query" ]]; then
    include_context=1
    query="Based on my current context, what should I focus on? Provide specific, actionable suggestions."
    log_debug "ai" "Auto-enabled context mode with default query"
  fi

  log_info "ai" "AI query requested" "Query length: ${#query}"

  # Check requirements
  ai_check_requirements || {
    local exit_code=$?
    return "$exit_code"
  }

  # Get API key
  local api_key
  api_key=$(ai_get_api_key) || {
    error_msg "No API key found"
    echo ""
    error_msg "To set up:"
    error_msg "1. Get API key from: https://aistudio.google.com/app/apikey"
    error_msg "2. Run: harm-cli ai --setup"
    error_msg "3. Or: export GEMINI_API_KEY=\"your-key\""
    _ai_fallback
    return "$EXIT_AI_NO_KEY"
  }

  # Build context if requested
  local context=""
  if [[ $include_context -eq 1 ]]; then
    context=$(_ai_build_context)
    log_debug "ai" "Context included" "Length: ${#context}"
  fi

  # Generate cache key
  local cache_key
  cache_key=$(_ai_cache_hash "$query" "$context")

  # Check cache
  if [[ $use_cache -eq 1 ]]; then
    local cached
    if cached=$(_ai_cache_get "$cache_key"); then
      # Parse and display cached response
      local text
      if text=$(_ai_parse_response "$cached"); then
        echo "${DIM}(cached response)${RESET}"

        # Log cached response to audit if available
        if type ai_audit_log >/dev/null 2>&1; then
          ai_audit_log "$query" "$text" "${AI_DEFAULT_MODEL}" "0" "null" "true" 2>/dev/null || true
        fi

        # Use markdown rendering if available
        if [[ "${HARM_CLI_FORMAT:-text}" == "text" ]] && type render_markdown_pipe >/dev/null 2>&1; then
          echo "$text" | render_markdown_pipe "" 2>/dev/null || echo "$text"
        else
          echo "$text"
        fi

        return 0
      fi
    fi
  fi

  # Make API request
  echo "🤖 Thinking..."
  log_info "ai" "Sending API request"

  # Track start time for audit
  local start_time
  start_time=$(date +%s%3N 2>/dev/null || echo "0")

  local response
  if ! response=$(_ai_make_request "$api_key" "$query" "$context"); then
    local exit_code=$?
    log_error "ai" "API request failed"
    _ai_fallback
    return "$exit_code"
  fi

  # Calculate duration
  local end_time duration_ms
  end_time=$(date +%s%3N 2>/dev/null || echo "0")
  duration_ms=$((end_time - start_time))

  # Parse response
  local text
  if ! text=$(_ai_parse_response "$response"); then
    log_error "ai" "Failed to parse response"
    _ai_fallback
    return "$EXIT_AI_INVALID_RESPONSE"
  fi

  # Cache response
  if [[ $use_cache -eq 1 ]]; then
    _ai_cache_set "$cache_key" "$response"
  fi

  # Log to audit trail if module available
  if type ai_audit_log >/dev/null 2>&1; then
    ai_audit_log "$query" "$text" "${AI_DEFAULT_MODEL}" "$duration_ms" "null" "false" 2>/dev/null || true
  fi

  # Display response with markdown rendering if available
  echo ""

  # Try to render with markdown if markdown.sh is available and format is text
  if [[ "${HARM_CLI_FORMAT:-text}" == "text" ]] && [[ -f "$AI_SCRIPT_DIR/markdown.sh" ]]; then
    # Source markdown module
    # shellcheck source=lib/markdown.sh
    source "$AI_SCRIPT_DIR/markdown.sh" 2>/dev/null || true

    # If markdown rendering available, use it
    if type render_markdown_pipe >/dev/null 2>&1; then
      echo "$text" | render_markdown_pipe "" 2>/dev/null || echo "$text"
    else
      echo "$text"
    fi
  else
    # JSON format or markdown not available - output as-is
    echo "$text"
  fi

  echo ""

  log_info "ai" "Query completed successfully"
  return 0
}

# ═══════════════════════════════════════════════════════════════════
# Advanced AI Features
# ═══════════════════════════════════════════════════════════════════

# ai_review: AI-powered code review of git changes
#
# Description:
#   Reviews staged or unstaged git changes using AI to detect bugs,
#   best practice violations, security issues, and suggest improvements.
#   Automatically truncates large diffs to stay within token limits.
#
# Arguments:
#   --unstaged|-u - Review unstaged changes (default: staged)
#   --staged|-s - Review staged changes (explicit)
#
# Returns:
#   0 - Review completed successfully
#   EXIT_INVALID_ARGS - Unknown option provided
#   EXIT_INVALID_STATE - Not in a git repository
#   EXIT_AI_NO_KEY - No API key available
#   EXIT_AI_NETWORK - Network error during API request
#   EXIT_AI_INVALID_RESPONSE - Failed to parse AI response
#
# Outputs:
#   stdout: AI code review with specific suggestions
#   stderr: Log messages via log_info/log_debug/log_error/log_warn
#
# Examples:
#   ai_review                    # Review staged changes
#   ai_review --unstaged         # Review unstaged changes
#   git add lib/ai.sh && ai_review
#
# Notes:
#   - Requires git repository
#   - Returns early if no changes found (exit 0)
#   - Truncates diffs > 200 lines (displays warning)
#   - Always bypasses cache (reviews should be fresh)
#   - Includes git branch and line count in context
#
# Performance:
#   - Small diffs (<100 lines): 2-5s
#   - Large diffs (200 lines): 3-7s
#   - No changes: <50ms (early return)
#
# Security:
#   - ⚠️  Sends code diff to Gemini API (external service)
#   - Only use with code comfortable sharing externally
ai_review() {
  local use_staged=1

  # Parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --unstaged | -u)
        use_staged=0
        shift
        ;;
      --staged | -s)
        use_staged=1
        shift
        ;;
      *)
        error_msg "Unknown option: $1"
        return "$EXIT_INVALID_ARGS"
        ;;
    esac
  done

  log_info "ai" "Starting code review" "Type: $([ $use_staged -eq 1 ] && echo 'staged' || echo 'unstaged')"

  # Check if in git repository
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    error_msg "Not in a git repository"
    log_error "ai" "Code review failed" "Not in git repository"
    return "$EXIT_INVALID_STATE"
  fi

  # Get diff
  local diff
  if [[ $use_staged -eq 1 ]]; then
    diff=$(git diff --cached 2>/dev/null)
  else
    diff=$(git diff 2>/dev/null)
  fi

  # Check if empty
  if [[ -z "$diff" ]]; then
    echo "No changes to review"
    log_info "ai" "Code review skipped" "No changes found"
    return 0
  fi

  # Count lines and truncate if needed
  local line_count
  line_count=$(echo "$diff" | wc -l | tr -d ' ')
  log_debug "ai" "Diff retrieved" "Lines: $line_count"

  if [[ $line_count -gt 200 ]]; then
    diff=$(echo "$diff" | head -200)
    echo "⚠️  Diff truncated to 200 lines for analysis (total: $line_count lines)"
    log_warn "ai" "Diff truncated" "Original: $line_count, Truncated: 200"
  fi

  # Get git context
  local branch
  branch=$(git branch --show-current 2>/dev/null || echo "unknown")

  # Build context
  local context
  context="Code Review Request\n"
  context+="Branch: $branch\n"
  context+="Lines changed: $line_count\n"
  context+="Type: $([ $use_staged -eq 1 ] && echo 'staged' || echo 'unstaged')\n\n"
  context+="Diff:\n\`\`\`diff\n$diff\n\`\`\`"

  # Build prompt
  local prompt
  prompt="Review these code changes and provide:\n\n"
  prompt+="1. **Summary:** What changed\n"
  prompt+="2. **Issues:** Potential bugs or problems\n"
  prompt+="3. **Best Practices:** Any violations\n"
  prompt+="4. **Security:** Any concerns\n"
  prompt+="5. **Suggestions:** Specific improvements\n\n"
  prompt+="Be specific and actionable. Format as markdown."

  echo "📝 Reviewing code changes with AI..."
  log_info "ai" "Sending code review request" "Lines: $line_count"

  # Build full query
  local full_query="$context\n\n$prompt"

  # Query AI (always bypass cache for reviews)
  local response
  if ! response=$(_ai_make_request "$(ai_get_api_key)" "$full_query" ""); then
    local exit_code=$?
    log_error "ai" "Code review failed" "API request error"
    return "$exit_code"
  fi

  # Parse and display
  local review_text
  if review_text=$(_ai_parse_response "$response"); then
    echo ""
    echo "$review_text"
    echo ""
    log_info "ai" "Code review completed" "Lines reviewed: $line_count"
    return 0
  else
    log_error "ai" "Failed to parse review response"
    return "$EXIT_AI_INVALID_RESPONSE"
  fi
}

# ai_explain_error: Explain last error from logs using AI
#
# Description:
#   Analyzes the most recent ERROR entry from harm-cli logs and provides
#   AI-powered explanation including what it means, common causes, specific
#   fix commands, and prevention strategies.
#
# Arguments:
#   None
#
# Returns:
#   0 - Error explained successfully OR no errors found
#   1 - Log file not found
#   EXIT_AI_NO_KEY - No API key available
#   EXIT_AI_NETWORK - Network error during API request
#   EXIT_AI_INVALID_RESPONSE - Failed to parse AI response
#
# Outputs:
#   stdout: Error analysis and solutions, or success message if no errors
#   stderr: Log messages via log_info/log_debug/log_warn/log_error
#
# Examples:
#   ai_explain_error           # Explain last error
#   harm-cli ai explain-error  # Via CLI
#   harm-cli ai explain        # Alias
#
# Notes:
#   - Reads from: ${HARM_CLI_HOME}/logs/harm-cli.log
#   - Parses last line containing [ERROR]
#   - Extracts: timestamp, component, error message
#   - Returns 0 (success) if no errors found (celebratory message)
#   - Always bypasses cache (explanations should be fresh)
#
# Performance:
#   - Log file search: <50ms (grep + tail)
#   - AI explanation: 2-5s (API latency)
#   - No errors: <50ms (early return)
#
# Integration:
#   - Depends on lib/logging.sh log format
#   - Expected format: [timestamp] [ERROR] [component] message
ai_explain_error() {
  log_info "ai" "Explaining last error from logs"

  # Find log file
  local log_file="${HARM_CLI_HOME:-$HOME/.harm-cli}/logs/harm-cli.log"

  if [[ ! -f "$log_file" ]]; then
    error_msg "Log file not found"
    log_warn "ai" "Cannot explain error" "Log file not found: $log_file"
    return 1
  fi

  # Extract last ERROR entry
  local last_error
  last_error=$(grep '\[ERROR\]' "$log_file" | tail -1)

  if [[ -z "$last_error" ]]; then
    success_msg "No recent errors found! 🎉"
    log_info "ai" "No errors to explain"
    return 0
  fi

  log_debug "ai" "Found error in logs" "Entry: $last_error"

  # Parse error components
  local error_time
  error_time=$(echo "$last_error" | grep -o '^\[[-0-9: ]*\]' | head -1 | tr -d '[]')
  local error_component
  error_component=$(echo "$last_error" | grep -o '\[[a-z_-]*\]' | head -1 | tr -d '[]')
  local error_msg
  error_msg=$(echo "$last_error" | sed 's/.*\] \[ERROR\] \[[^]]*\] //' | sed 's/ |.*//')

  # Build context
  local context
  context="Error Analysis Request\n\n"
  context+="Time: $error_time\n"
  context+="Component: $error_component\n"
  context+="Error: $error_msg\n"

  # Build prompt
  local prompt
  prompt="Explain this error and provide solutions:\n\n"
  prompt+="1. **What it means:** Explain the error in simple terms\n"
  prompt+="2. **Common causes:** Why this happens\n"
  prompt+="3. **How to fix:** Specific commands to run\n"
  prompt+="4. **Prevention:** How to avoid this in future\n\n"
  prompt+="Be specific and actionable."

  echo "🔍 Analyzing last error..."
  echo "Error: $error_msg"
  echo ""
  log_info "ai" "Sending error explanation request"

  # Build full query
  local full_query="$context\n\n$prompt"

  # Query AI (bypass cache)
  local response
  if ! response=$(_ai_make_request "$(ai_get_api_key)" "$full_query" ""); then
    local exit_code=$?
    log_error "ai" "Error explanation failed" "API request error"
    return "$exit_code"
  fi

  # Parse and display
  local explanation
  if explanation=$(_ai_parse_response "$response"); then
    echo "$explanation"
    echo ""
    log_info "ai" "Error explanation completed"
    return 0
  else
    log_error "ai" "Failed to parse explanation response"
    return "$EXIT_AI_INVALID_RESPONSE"
  fi
}

# ai_daily: Daily productivity insights powered by AI
#
# Description:
#   Generates AI-powered productivity report by analyzing work sessions,
#   completed goals, and git commit activity for the specified time period.
#   Provides encouraging summary, insights, and actionable next steps.
#
# Arguments:
#   --yesterday|-y - Analyze yesterday's activity
#   --week|-w - Analyze last 7 days of activity
#   (default: today's activity)
#
# Returns:
#   0 - Insights generated successfully OR no data available
#   EXIT_AI_NO_KEY - No API key available
#   EXIT_AI_NETWORK - Network error during API request
#   EXIT_AI_INVALID_RESPONSE - Failed to parse AI response
#
# Outputs:
#   stdout: Productivity insights and suggestions, or "no data" message
#   stderr: Log messages via log_info/log_debug/log_error
#
# Examples:
#   ai_daily                   # Today's insights
#   ai_daily --yesterday       # Yesterday's insights
#   ai_daily --week            # Weekly report
#   harm-cli ai daily          # Via CLI
#
# Notes:
#   - Integrates with lib/work.sh (work session data)
#   - Integrates with lib/goals.sh (goal completion data)
#   - Integrates with git (commit history)
#   - Returns early (exit 0) if no data available for period
#   - Always bypasses cache (insights should be personalized and fresh)
#
# Data Sources:
#   - Work sessions: ${HARM_CLI_HOME}/work/archive.jsonl
#   - Goals: ${HARM_CLI_HOME}/goals/YYYY-MM-DD.jsonl
#   - Git: `git log --since="period"` (requires git repo)
#
# Performance:
#   - Data gathering: 50-200ms (depends on file sizes)
#   - AI analysis: 3-7s (API latency, varies with data amount)
#   - No data: <50ms (early return)
#
# Integration:
#   - Requires work.sh and goals.sh data formats
#   - Git integration optional (works without git repo)
#   - Date calculations cross-platform (macOS/Linux compatible)
ai_daily() {
  local period="today"
  local period_days=0

  # Parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yesterday | -y)
        period="yesterday"
        period_days=1
        shift
        ;;
      --week | -w)
        period="week"
        period_days=7
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  log_info "ai" "Generating daily insights" "Period: $period"

  echo "🤖 Analyzing your productivity for $period..."
  echo ""

  # Build context from multiple sources
  local context=""
  local has_data=0

  # 1. Work sessions
  local work_archive="${HARM_CLI_HOME:-$HOME/.harm-cli}/work/archive.jsonl"
  if [[ -f "$work_archive" ]]; then
    local cutoff_date
    if [[ $period_days -gt 0 ]]; then
      cutoff_date=$(date -v-${period_days}d +%Y-%m-%d 2>/dev/null || date -d "${period_days} days ago" +%Y-%m-%d 2>/dev/null)
    else
      cutoff_date=$(date +%Y-%m-%d)
    fi

    local work_summary
    work_summary=$(grep "\"started_at\":\"$cutoff_date" "$work_archive" 2>/dev/null \
      | jq -r '.goal + " (" + (.duration_seconds/60|floor|tostring) + "m)"' 2>/dev/null || echo "")

    if [[ -n "$work_summary" ]]; then
      context+="Work sessions:\n$work_summary\n\n"
      has_data=1
      log_debug "ai" "Added work session data to context"
    fi
  fi

  # 2. Goals
  local goal_date
  if [[ $period_days -eq 1 ]]; then
    goal_date=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d 2>/dev/null)
  else
    goal_date=$(date +%Y-%m-%d)
  fi

  local goal_file="${HARM_CLI_HOME:-$HOME/.harm-cli}/goals/$goal_date.jsonl"
  if [[ -f "$goal_file" ]]; then
    local completed_goals
    completed_goals=$(jq -r 'select(.completed==true) | "✓ " + .goal' "$goal_file" 2>/dev/null || echo "")

    if [[ -n "$completed_goals" ]]; then
      context+="Completed goals:\n$completed_goals\n\n"
      has_data=1
      log_debug "ai" "Added goal data to context"
    fi
  fi

  # 3. Git activity
  if git rev-parse --git-dir >/dev/null 2>&1; then
    local since_date
    if [[ $period_days -gt 0 ]]; then
      since_date="${period_days} days ago"
    else
      since_date="today"
    fi

    local commits_count
    commits_count=$(git log --since="$since_date" --oneline 2>/dev/null | wc -l | tr -d ' ')

    if [[ $commits_count -gt 0 ]]; then
      context+="Git commits: $commits_count\n"
      local commit_msgs
      commit_msgs=$(git log --since="$since_date" --pretty=format:"- %s" 2>/dev/null | head -20)
      context+="Commits:\n$commit_msgs\n\n"
      has_data=1
      log_debug "ai" "Added git activity to context"
    fi
  fi

  # Check if we have any data
  if [[ $has_data -eq 0 ]]; then
    echo "No activity data available for $period"
    log_info "ai" "Daily insights skipped" "No data for period: $period"
    return 0
  fi

  # Build prompt
  local prompt
  prompt="Based on my development activity for $period, provide:\n\n"
  prompt+="1. **Productivity Summary:** What I accomplished\n"
  prompt+="2. **Insights:** Patterns or observations\n"
  prompt+="3. **Next Steps:** What to focus on next\n"
  prompt+="4. **Learning:** Skills to develop\n\n"
  prompt+="Be encouraging, specific, and actionable. Format as markdown."

  log_info "ai" "Sending daily insights request" "Period: $period"

  # Build full query
  local full_query="$context\n\n$prompt"

  # Query AI (bypass cache for personalized insights)
  local response
  if ! response=$(_ai_make_request "$(ai_get_api_key)" "$full_query" ""); then
    local exit_code=$?
    log_error "ai" "Daily insights failed" "API request error"
    return "$exit_code"
  fi

  # Parse and display
  local insights
  if insights=$(_ai_parse_response "$response"); then
    echo "$insights"
    echo ""
    log_info "ai" "Daily insights completed" "Period: $period"
    return 0
  else
    log_error "ai" "Failed to parse insights response"
    return "$EXIT_AI_INVALID_RESPONSE"
  fi
}

# Export public functions
export -f ai_query
export -f ai_check_requirements
export -f ai_setup
export -f ai_review
export -f ai_explain_error
export -f ai_daily

# Mark module as loaded
readonly _HARM_AI_LOADED=1

# ═══════════════════════════════════════════════════════════════
# Model Management
# ═══════════════════════════════════════════════════════════════

# ai_list_models: List available AI models
#
# Returns:
#   0 - Success
#
# Outputs:
#   stdout: List of models with descriptions (text or JSON)
ai_list_models() {
  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    # JSON output
    local json_array="["
    local first=true
    for model in "${!AI_MODELS[@]}"; do
      [[ "$first" == false ]] && json_array+=","
      first=false
      IFS='|' read -r desc tier features <<<"${AI_MODELS[$model]}"
      json_array+="{\"name\":\"$model\",\"description\":\"$desc\",\"tier\":\"$tier\",\"features\":\"$features\"}"
    done
    json_array+="]"
    echo "$json_array" | jq '.'
  else
    # Text output
    echo "Available AI Models:"
    echo ""
    for model in "${!AI_MODELS[@]}"; do
      IFS='|' read -r desc tier features <<<"${AI_MODELS[$model]}"
      local current=""
      [[ "$model" == "$AI_DEFAULT_MODEL" ]] && current=" ${SUCCESS_GREEN}(current)${RESET}"
      echo "  • $model$current"
      echo "    $desc"
      echo "    Tier: $tier | Features: $features"
      echo ""
    done
  fi
}

# ai_model_info: Show information about a specific model
#
# Arguments:
#   $1 - model (optional): Model name (default: current)
#
# Returns:
#   0 - Success
#   1 - Model not found
ai_model_info() {
  local model="${1:-$AI_DEFAULT_MODEL}"

  if [[ -z "${AI_MODELS[$model]:-}" ]]; then
    error_msg "Unknown model: $model"
    echo "Available models:"
    ai_list_models
    return 1
  fi

  IFS='|' read -r desc tier features <<<"${AI_MODELS[$model]}"

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --arg name "$model" \
      --arg desc "$desc" \
      --arg tier "$tier" \
      --arg features "$features" \
      '{name: $name, description: $desc, tier: $tier, features: $features}'
  else
    echo "Model: $model"
    echo "Description: $desc"
    echo "Tier: $tier"
    echo "Features: $features"
  fi
}

# ai_select_model: Interactively select AI model
#
# Returns:
#   0 - Model selected (prints model name)
#   1 - Selection cancelled or error
#
# Outputs:
#   stdout: Selected model name
ai_select_model() {
  # Load interactive module if available
  if [[ -f "$AI_SCRIPT_DIR/interactive.sh" ]]; then
    # shellcheck source=lib/interactive.sh
    source "$AI_SCRIPT_DIR/interactive.sh"
  fi

  if ! type interactive_choose >/dev/null 2>&1; then
    error_msg "Interactive module not available"
    echo "Available models:"
    ai_list_models
    return 1
  fi

  # Build options with descriptions
  local -a model_options=()
  for model in "${!AI_MODELS[@]}"; do
    IFS='|' read -r desc tier features <<<"${AI_MODELS[$model]}"
    model_options+=("$model - $desc ($tier)")
  done

  # Let user choose
  local selection
  if selection=$(interactive_choose "Select AI model" "${model_options[@]}"); then
    # Extract model name (before " - ")
    local model_name="${selection%% -*}"
    echo "$model_name"
    return 0
  else
    return 1
  fi
}

# ai_set_model: Set the default AI model
#
# Arguments:
#   $1 - model (required): Model name
#
# Returns:
#   0 - Success
#   1 - Invalid model
ai_set_model() {
  local model="${1:?ai_set_model requires model name}"

  # Validate model exists
  if [[ -z "${AI_MODELS[$model]:-}" ]]; then
    error_msg "Unknown model: $model"
    echo "Available models:"
    for m in "${!AI_MODELS[@]}"; do
      echo "  - $m"
    done
    return 1
  fi

  # Update config file (requires options module)
  if type options_set >/dev/null 2>&1; then
    options_set "ai_model" "$model"
  else
    # Fallback: set environment variable suggestion
    echo "To persist this setting, add to ~/.bashrc:"
    echo "  export GEMINI_MODEL=$model"
  fi

  success_msg "AI model set to: $model"
  IFS='|' read -r desc tier features <<<"${AI_MODELS[$model]}"
  echo "  Description: $desc"
  echo "  Tier: $tier"

  return 0
}

# Export model management functions
export -f ai_list_models ai_model_info ai_select_model ai_set_model
