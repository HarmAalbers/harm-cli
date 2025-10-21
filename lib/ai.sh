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

# Exit codes specific to AI module
readonly EXIT_AI_NO_KEY=2
readonly EXIT_AI_NETWORK=3
readonly EXIT_AI_RATE_LIMIT=4
readonly EXIT_AI_INVALID_RESPONSE=5

# ═══════════════════════════════════════════════════════════════════
# Requirements & Validation
# ═══════════════════════════════════════════════════════════════════

# Check if all required dependencies are available
# Returns: 0 if all requirements met, 1 otherwise
ai_check_requirements() {
  log_debug "ai" "Checking AI requirements"

  local missing=0

  # Check for curl
  if ! command -v curl >/dev/null 2>&1; then
    log_error "ai" "curl not found" "Required for API requests"
    error_message "curl is required for AI features"
    error_message "Install: brew install curl (macOS) or apt-get install curl (Linux)"
    missing=1
  else
    log_debug "ai" "curl found" "$(curl --version | head -n1)"
  fi

  # Check for jq
  if ! command -v jq >/dev/null 2>&1; then
    log_error "ai" "jq not found" "Required for JSON parsing"
    error_message "jq is required for AI features"
    error_message "Install: brew install jq (macOS) or apt-get install jq (Linux)"
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

# Retrieve API key from secure sources
# Priority: env var -> macOS keychain -> Linux secret-tool -> pass
# Returns: 0 with key on stdout, or EXIT_AI_NO_KEY
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

# Interactive API key setup
# Stores key securely in keychain (macOS) or prompts for alternative
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
    error_message "No API key provided"
    return "$EXIT_INVALID_ARGS"
  fi

  # Validate format
  if [[ ! "$api_key" =~ ^[A-Za-z0-9_-]{32,}$ ]]; then
    error_message "Invalid API key format"
    error_message "Expected: 32+ alphanumeric characters with dashes/underscores"
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
        success_message "API key stored securely in Keychain"
      else
        log_error "ai" "Failed to store in Keychain"
        error_message "Failed to store in Keychain"
        return "$EXIT_IO_ERROR"
      fi
    fi
  elif command -v secret-tool >/dev/null 2>&1; then
    read -r -p "Store with secret-tool? (y/n): " store_secret
    if [[ "$store_secret" =~ ^[Yy]$ ]]; then
      if echo "$api_key" | secret-tool store --label='harm-cli Gemini API' service harm-cli-gemini; then
        log_info "ai" "API key stored with secret-tool"
        success_message "API key stored securely with secret-tool"
      else
        log_error "ai" "Failed to store with secret-tool"
        error_message "Failed to store with secret-tool"
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
  success_message "AI assistant ready to use"
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
      error_message "Request timeout after ${AI_TIMEOUT}s"
      return "$EXIT_AI_NETWORK"
    else
      error_message "Network error (code: $curl_status)"
      return "$EXIT_AI_NETWORK"
    fi
  fi

  log_debug "ai" "API response received" "HTTP: $http_code, Size: ${#response} bytes"

  # Check HTTP status code
  case "$http_code" in
    200)
      log_info "ai" "API request successful"
      echo "$response"
      return 0
      ;;
    400)
      log_error "ai" "Bad request" "HTTP 400"
      error_message "Invalid request format"
      return "$EXIT_AI_INVALID_RESPONSE"
      ;;
    401 | 403)
      log_error "ai" "Authentication failed" "HTTP $http_code"
      error_message "Invalid API key"
      return "$EXIT_AI_NO_KEY"
      ;;
    429)
      log_error "ai" "Rate limit exceeded" "HTTP 429"
      error_message "Rate limit exceeded - wait a moment and try again"
      return "$EXIT_AI_RATE_LIMIT"
      ;;
    500 | 502 | 503)
      log_error "ai" "Server error" "HTTP $http_code"
      error_message "AI service temporarily unavailable"
      return "$EXIT_AI_NETWORK"
      ;;
    *)
      log_error "ai" "Unexpected HTTP status" "HTTP $http_code"
      error_message "Unexpected API response (HTTP $http_code)"
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
    local error_msg
    error_msg=$(echo "$response" | jq -r '.error.message // "Unknown error"')
    if [[ "$error_msg" != "Unknown error" ]]; then
      log_error "ai" "API error" "$error_msg"
      error_message "API error: $error_msg"
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

# Query AI with context-aware prompt
# Args: query, [--no-cache]
# Returns: 0 on success, error code on failure
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
  ai_check_requirements || return $?

  # Get API key
  local api_key
  api_key=$(ai_get_api_key) || {
    error_message "No API key found"
    error_message ""
    error_message "To set up:"
    error_message "1. Get API key from: https://aistudio.google.com/app/apikey"
    error_message "2. Run: harm-cli ai --setup"
    error_message "3. Or: export GEMINI_API_KEY=\"your-key\""
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
        echo "$text"
        return 0
      fi
    fi
  fi

  # Make API request
  echo "🤖 Thinking..."
  log_info "ai" "Sending API request"

  local response
  if ! response=$(_ai_make_request "$api_key" "$query" "$context"); then
    log_error "ai" "API request failed"
    _ai_fallback
    return $?
  fi

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

  # Display response
  echo ""
  echo "$text"
  echo ""

  log_info "ai" "Query completed successfully"
  return 0
}

# Export public functions
export -f ai_query
export -f ai_check_requirements
export -f ai_setup

# Mark module as loaded
readonly _HARM_AI_LOADED=1
