#!/usr/bin/env bash
# shellcheck shell=bash
# ai_audit.sh - AI audit trail and usage tracking
#
# Features:
# - Log all AI requests and responses in JSONL format
# - Track token usage and costs
# - Query audit history
# - Export audit data
# - Privacy controls and retention policies
#
# Privacy Notice:
# - Audit logs contain prompts and responses which may include sensitive data
# - Disable with: HARM_AI_AUDIT_ENABLED=0
# - Clean old entries with: harm-cli ai audit clean
# - Default retention: 30 days (configurable via HARM_AI_AUDIT_RETENTION_DAYS)
# - Audit logs stored locally only (not shared)
#
# Public API:
#   ai_audit_log <request> <response> <metadata>  - Log AI interaction
#   ai_audit_list [limit]                          - List recent queries
#   ai_audit_show <id>                             - Show specific audit entry
#   ai_audit_stats [period]                        - Usage statistics
#   ai_audit_export [format]                       - Export audit data
#   ai_audit_clean [days]                          - Clean old entries
#
# Dependencies: jq, lib/common.sh, lib/logging.sh

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_AI_AUDIT_LOADED:-}" ]] && return 0

# Source dependencies
AI_AUDIT_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly AI_AUDIT_SCRIPT_DIR

# shellcheck source=lib/common.sh
source "$AI_AUDIT_SCRIPT_DIR/common.sh"
# shellcheck source=lib/error.sh
source "$AI_AUDIT_SCRIPT_DIR/error.sh"
# shellcheck source=lib/logging.sh
source "$AI_AUDIT_SCRIPT_DIR/logging.sh"
# shellcheck source=lib/util.sh
source "$AI_AUDIT_SCRIPT_DIR/util.sh"

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════

readonly AI_AUDIT_DIR="${HARM_CLI_HOME:-$HOME/.harm-cli}/ai-audit"
readonly AI_AUDIT_FILE="$AI_AUDIT_DIR/audit.jsonl"
readonly AI_AUDIT_ENABLED="${HARM_AI_AUDIT_ENABLED:-1}"
readonly AI_AUDIT_RETENTION_DAYS="${HARM_AI_AUDIT_RETENTION_DAYS:-30}"

# Ensure audit directory exists
ensure_dir "$AI_AUDIT_DIR"

# ═══════════════════════════════════════════════════════════════
# Audit Logging
# ═══════════════════════════════════════════════════════════════

# ai_audit_log: Log an AI interaction
#
# Arguments:
#   $1 - prompt (string): The user's query/prompt
#   $2 - response (string): The AI's response
#   $3 - model (string): Model used
#   $4 - duration_ms (int): Request duration in milliseconds
#   $5 - tokens_used (int, optional): Tokens consumed
#   $6 - cache_hit (bool, optional): Whether response was cached
#
# Returns:
#   0 - Success
#   1 - Audit disabled or error
#
# Outputs:
#   Appends JSON line to audit file
#
# Examples:
#   ai_audit_log "$prompt" "$response" "gemini-2.0-flash" 1234 150 false
ai_audit_log() {
  # Skip if audit disabled
  if [[ "${AI_AUDIT_ENABLED}" != "1" ]]; then
    log_debug "ai_audit" "Audit logging disabled"
    return 0
  fi

  local prompt="${1:?ai_audit_log requires prompt}"
  local response="${2:?ai_audit_log requires response}"
  local model="${3:?ai_audit_log requires model}"
  local duration_ms="${4:?ai_audit_log requires duration_ms}"
  local tokens_used="${5:-null}"
  local cache_hit="${6:-false}"

  local timestamp
  timestamp="$(get_utc_timestamp)"

  # Generate unique ID
  local audit_id
  audit_id="$(echo "${timestamp}-${RANDOM}" | sha256sum | cut -d' ' -f1 | cut -c1-12)"

  # Create audit entry (JSONL format)
  jq -nc \
    --arg id "$audit_id" \
    --arg timestamp "$timestamp" \
    --arg model "$model" \
    --arg prompt "$prompt" \
    --arg response "$response" \
    --argjson duration_ms "$duration_ms" \
    --argjson tokens_used "$tokens_used" \
    --argjson cache_hit "$cache_hit" \
    '{
      id: $id,
      timestamp: $timestamp,
      model: $model,
      prompt: $prompt,
      response: $response,
      duration_ms: $duration_ms,
      tokens_used: $tokens_used,
      cache_hit: $cache_hit
    }' >>"$AI_AUDIT_FILE"

  log_debug "ai_audit" "Logged AI interaction" "ID: $audit_id"
  return 0
}

# ═══════════════════════════════════════════════════════════════
# Audit Queries
# ═══════════════════════════════════════════════════════════════

# ai_audit_list: List recent AI queries
#
# Arguments:
#   $1 - limit (int, optional): Number of entries to show (default: 10)
#
# Returns:
#   0 - Success
#
# Outputs:
#   stdout: List of recent queries (text or JSON based on HARM_CLI_FORMAT)
#
# Examples:
#   ai_audit_list
#   ai_audit_list 20
#   HARM_CLI_FORMAT=json ai_audit_list 5
ai_audit_list() {
  local limit="${1:-10}"

  if [[ ! -f "$AI_AUDIT_FILE" ]]; then
    echo "No audit entries found"
    return 0
  fi

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    # Output last N entries as JSON array
    tail -n "$limit" "$AI_AUDIT_FILE" | jq -s '.'
  else
    echo "Recent AI queries (last $limit):"
    echo ""

    tail -n "$limit" "$AI_AUDIT_FILE" | while IFS= read -r line; do
      local id timestamp prompt cache_hit
      id=$(jq -r '.id' <<<"$line")
      timestamp=$(jq -r '.timestamp' <<<"$line")
      prompt=$(jq -r '.prompt' <<<"$line" | cut -c1-60)
      cache_hit=$(jq -r '.cache_hit' <<<"$line")

      local cache_indicator=""
      [[ "$cache_hit" == "true" ]] && cache_indicator=" ${DIM}(cached)${RESET}"

      echo "  ${id} - ${timestamp} - ${prompt}...${cache_indicator}"
    done
  fi
}

# ai_audit_show: Show full details of specific audit entry
#
# Arguments:
#   $1 - id (string): Audit entry ID
#
# Returns:
#   0 - Entry found
#   1 - Entry not found
#
# Outputs:
#   stdout: Full audit entry details
ai_audit_show() {
  local id="${1:?ai_audit_show requires audit ID}"

  if [[ ! -f "$AI_AUDIT_FILE" ]]; then
    echo "No audit entries found"
    return 1
  fi

  local entry
  entry=$(jq -r --arg id "$id" 'select(.id == $id)' "$AI_AUDIT_FILE")

  if [[ -z "$entry" ]]; then
    echo "Audit entry not found: $id"
    return 1
  fi

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    echo "$entry" | jq '.'
  else
    echo "AI Audit Entry: $id"
    echo ""
    echo "Timestamp: $(echo "$entry" | jq -r '.timestamp')"
    echo "Model: $(echo "$entry" | jq -r '.model')"
    echo "Duration: $(echo "$entry" | jq -r '.duration_ms')ms"
    echo "Tokens: $(echo "$entry" | jq -r '.tokens_used')"
    echo "Cached: $(echo "$entry" | jq -r '.cache_hit')"
    echo ""
    echo "Prompt:"
    echo "$entry" | jq -r '.prompt'
    echo ""
    echo "Response:"
    echo "$entry" | jq -r '.response'
  fi
}

# ai_audit_stats: Show usage statistics
#
# Arguments:
#   $1 - period (optional): today|week|month|all (default: all)
#
# Returns:
#   0 - Success
#
# Outputs:
#   stdout: Usage statistics
ai_audit_stats() {
  local period="${1:-all}"

  if [[ ! -f "$AI_AUDIT_FILE" ]]; then
    echo "No audit data available"
    return 0
  fi

  # Calculate date filter
  local since_date=""
  case "$period" in
    today)
      since_date=$(date -u '+%Y-%m-%d')
      ;;
    week)
      since_date=$(date -u -v-7d '+%Y-%m-%d' 2>/dev/null || date -u -d '7 days ago' '+%Y-%m-%d')
      ;;
    month)
      since_date=$(date -u -v-30d '+%Y-%m-%d' 2>/dev/null || date -u -d '30 days ago' '+%Y-%m-%d')
      ;;
    all)
      since_date=""
      ;;
    *)
      echo "Unknown period: $period. Use: today, week, month, all"
      return 1
      ;;
  esac

  # Calculate stats
  local total_queries cache_hits total_tokens total_duration
  if [[ -n "$since_date" ]]; then
    total_queries=$(jq -r --arg since "$since_date" 'select(.timestamp >= $since) | 1' "$AI_AUDIT_FILE" | wc -l | tr -d ' ')
    cache_hits=$(jq -r --arg since "$since_date" 'select(.timestamp >= $since and .cache_hit == true) | 1' "$AI_AUDIT_FILE" | wc -l | tr -d ' ')
    total_tokens=$(jq -r --arg since "$since_date" 'select(.timestamp >= $since) | .tokens_used // 0' "$AI_AUDIT_FILE" | awk '{sum+=$1} END {print sum}')
    total_duration=$(jq -r --arg since "$since_date" 'select(.timestamp >= $since) | .duration_ms // 0' "$AI_AUDIT_FILE" | awk '{sum+=$1} END {print sum}')
  else
    total_queries=$(wc -l <"$AI_AUDIT_FILE" | tr -d ' ')
    cache_hits=$(jq -r 'select(.cache_hit == true) | 1' "$AI_AUDIT_FILE" | wc -l | tr -d ' ')
    total_tokens=$(jq -r '.tokens_used // 0' "$AI_AUDIT_FILE" | awk '{sum+=$1} END {print sum}')
    total_duration=$(jq -r '.duration_ms // 0' "$AI_AUDIT_FILE" | awk '{sum+=$1} END {print sum}')
  fi

  # Display stats
  echo "AI Usage Statistics ($period):"
  echo ""
  echo "  Total queries: $total_queries"
  echo "  Cache hits: $cache_hits ($(awk "BEGIN {printf \"%.1f\", ($cache_hits / ($total_queries > 0 ? $total_queries : 1)) * 100}")%)"
  echo "  Total tokens: $total_tokens"
  echo "  Total duration: ${total_duration}ms ($(awk "BEGIN {printf \"%.2f\", $total_duration / 1000}")s)"
  echo "  Avg duration: $(awk "BEGIN {printf \"%.0f\", $total_duration / ($total_queries > 0 ? $total_queries : 1)}")ms per query"
}

# ai_audit_export: Export audit data
#
# Arguments:
#   $1 - format (optional): json|csv (default: json)
#
# Returns:
#   0 - Success
#
# Outputs:
#   stdout: Exported audit data
ai_audit_export() {
  local format="${1:-json}"

  if [[ ! -f "$AI_AUDIT_FILE" ]]; then
    echo "No audit data to export"
    return 0
  fi

  case "$format" in
    json)
      jq -s '.' "$AI_AUDIT_FILE"
      ;;
    csv)
      echo "id,timestamp,model,prompt_length,response_length,duration_ms,tokens_used,cache_hit"
      jq -r '[.id, .timestamp, .model, (.prompt | length), (.response | length), .duration_ms, .tokens_used, .cache_hit] | @csv' "$AI_AUDIT_FILE"
      ;;
    *)
      echo "Unknown format: $format. Use: json, csv"
      return 1
      ;;
  esac
}

# ai_audit_clean: Remove old audit entries
#
# Arguments:
#   $1 - days (optional): Remove entries older than N days (default: AI_AUDIT_RETENTION_DAYS)
#
# Returns:
#   0 - Success
ai_audit_clean() {
  local days="${1:-$AI_AUDIT_RETENTION_DAYS}"

  if [[ ! -f "$AI_AUDIT_FILE" ]]; then
    echo "No audit file to clean"
    return 0
  fi

  # Calculate cutoff date
  local cutoff_date
  cutoff_date=$(date -u -v-"${days}"d '+%Y-%m-%d' 2>/dev/null || date -u -d "${days} days ago" '+%Y-%m-%d')

  # Count entries before cleanup
  local before_count
  before_count=$(wc -l <"$AI_AUDIT_FILE" | tr -d ' ')

  # Filter entries newer than cutoff
  local temp_file="${AI_AUDIT_FILE}.tmp"
  jq -r --arg cutoff "$cutoff_date" 'select(.timestamp >= $cutoff)' "$AI_AUDIT_FILE" >"$temp_file"

  # Replace original file
  mv "$temp_file" "$AI_AUDIT_FILE"

  # Count entries after cleanup
  local after_count
  after_count=$(wc -l <"$AI_AUDIT_FILE" | tr -d ' ')
  local removed=$((before_count - after_count))

  echo "✓ Cleaned audit trail"
  echo "  Removed: $removed entries (older than $days days)"
  echo "  Remaining: $after_count entries"
}

# ═══════════════════════════════════════════════════════════════
# Exports
# ═══════════════════════════════════════════════════════════════

export -f ai_audit_log
export -f ai_audit_list
export -f ai_audit_show
export -f ai_audit_stats
export -f ai_audit_export
export -f ai_audit_clean

# Mark module as loaded
readonly _HARM_AI_AUDIT_LOADED=1
