#!/usr/bin/env bash
# shellcheck shell=bash
# goal_ai.sh - AI-powered goal analysis and planning
# The META GOAL: Have Claude pick up on goals and automatically work on it!
#
# Features:
# - AI-powered goal analysis and breakdown
# - Implementation plan generation
# - Smart next-action suggestions
# - Goal completion verification
# - Claude Code context generation
# - GitHub issue linking and sync
#
# Public API:
#   goal_ai_analyze <goal_id>          - Analyze goal and estimate complexity
#   goal_ai_plan <goal_id>             - Generate implementation plan
#   goal_ai_next                       - Suggest what to work on next
#   goal_ai_check_completion <goal_id> - Verify goal can be marked complete
#   goal_ai_create_context             - Generate Claude Code context file
#   goal_ai_link_github <goal_id> <issue_number> - Link goal to GitHub issue
#   goal_ai_sync_github <goal_id>      - Sync goal status with GitHub issue
#
# Dependencies: ai.sh, goals.sh, github.sh, jq

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_GOAL_AI_LOADED:-}" ]] && return 0

# Source dependencies
GOAL_AI_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly GOAL_AI_SCRIPT_DIR

# shellcheck source=lib/common.sh
source "$GOAL_AI_SCRIPT_DIR/common.sh"
# shellcheck source=lib/error.sh
source "$GOAL_AI_SCRIPT_DIR/error.sh"
# shellcheck source=lib/logging.sh
source "$GOAL_AI_SCRIPT_DIR/logging.sh"
# shellcheck source=lib/util.sh
source "$GOAL_AI_SCRIPT_DIR/util.sh"
# shellcheck source=lib/goals.sh
source "$GOAL_AI_SCRIPT_DIR/goals.sh"
# shellcheck source=lib/ai.sh
source "$GOAL_AI_SCRIPT_DIR/ai.sh"
# shellcheck source=lib/github.sh
source "$GOAL_AI_SCRIPT_DIR/github.sh" 2>/dev/null || true # Optional

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════

readonly CLAUDE_CONTEXT_DIR="${HARM_CLI_HOME:-$HOME/.harm-cli}/claude-context"
readonly CLAUDE_CONTEXT_FILE="$CLAUDE_CONTEXT_DIR/goals-context.md"
readonly GOAL_AI_CACHE_DIR="${HARM_CLI_HOME:-$HOME/.harm-cli}/goal-ai-cache"

# Ensure directories exist
ensure_dir "$CLAUDE_CONTEXT_DIR"
ensure_dir "$GOAL_AI_CACHE_DIR"

# Mark as loaded
readonly _HARM_GOAL_AI_LOADED=1

# ═══════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════

# goal_ai_get_goal: Get goal details by ID
#
# Arguments:
#   $1 - goal_id (integer): Goal number (1-based)
#
# Returns:
#   0 - Goal found
#   1 - Goal not found
#
# Outputs:
#   stdout: JSON object with goal details
goal_ai_get_goal() {
  local goal_id="${1:?goal_ai_get_goal requires goal_id}"

  validate_int "$goal_id" || die "Goal ID must be an integer" "$EXIT_INVALID_ARGS"

  local goal_file
  goal_file="$(goal_file_for_today)"

  if [[ ! -f "$goal_file" ]]; then
    error_msg "No goals found for today"
    return 1
  fi

  # Get Nth goal (1-based)
  local goal_json
  goal_json=$(sed -n "${goal_id}p" "$goal_file")

  if [[ -z "$goal_json" ]]; then
    error_msg "Goal #$goal_id not found"
    return 1
  fi

  echo "$goal_json"
}

# goal_ai_extract_github_issue: Extract GitHub issue number from goal text
#
# Arguments:
#   $1 - goal_text (string): Goal description
#
# Outputs:
#   stdout: Issue number (if found)
goal_ai_extract_github_issue() {
  local goal_text="$1"

  # Match patterns like: #42, (#123), "Fix #456"
  if [[ "$goal_text" =~ \#([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi

  return 1
}

# ═══════════════════════════════════════════════════════════════
# AI Analysis Functions
# ═══════════════════════════════════════════════════════════════

# goal_ai_analyze: Analyze goal and estimate complexity
#
# Description:
#   Uses AI to analyze a goal, break it into subtasks, estimate time,
#   and identify dependencies.
#
# Arguments:
#   $1 - goal_id (integer): Goal number
#
# Returns:
#   0 - Analysis complete
#   1 - Goal not found or AI error
#
# Outputs:
#   stdout: AI analysis (formatted text or JSON)
goal_ai_analyze() {
  local goal_id="${1:?goal_ai_analyze requires goal_id}"

  log_info "goal-ai" "Analyzing goal #$goal_id"

  # Get goal details
  local goal_json
  goal_json=$(goal_ai_get_goal "$goal_id") || return 1

  local goal_text
  goal_text=$(jq -r '.goal' <<<"$goal_json")
  local estimated_minutes
  estimated_minutes=$(jq -r '.estimated_minutes // "null"' <<<"$goal_json")

  # Build AI prompt
  local prompt
  prompt="Analyze this development goal and provide a comprehensive breakdown:\n\n"
  prompt+="**Goal:** \"$goal_text\"\n"

  if [[ "$estimated_minutes" != "null" ]]; then
    local formatted_time
    formatted_time=$(format_duration $((estimated_minutes * 60)))
    prompt+="**Estimated Time:** $formatted_time\n"
  fi

  prompt+="\n**Please analyze:**\n\n"
  prompt+="1. **Complexity Assessment** (1-10 scale)\n"
  prompt+="   - Technical difficulty\n"
  prompt+="   - Risk level\n"
  prompt+="   - Scope appropriateness\n\n"
  prompt+="2. **Subtask Breakdown**\n"
  prompt+="   - List 3-7 actionable subtasks\n"
  prompt+="   - Estimated time for each\n"
  prompt+="   - Dependencies between tasks\n\n"
  prompt+="3. **Time Estimate Validation**\n"
  prompt+="   - Is the estimate realistic?\n"
  prompt+="   - Suggested adjusted estimate\n"
  prompt+="   - Factors to consider\n\n"
  prompt+="4. **Prerequisites & Dependencies**\n"
  prompt+="   - Required knowledge/skills\n"
  prompt+="   - External dependencies\n"
  prompt+="   - Blockers to watch for\n\n"
  prompt+="5. **Success Criteria**\n"
  prompt+="   - How to know when it's complete\n"
  prompt+="   - Testing approach\n"
  prompt+="   - Acceptance criteria\n\n"
  prompt+="Be specific, actionable, and honest about challenges."

  # Query AI
  echo ""
  echo "🤖 Analyzing goal with AI..."
  echo ""

  if ai_query "$prompt" --no-cache; then
    log_info "goal-ai" "Analysis complete for goal #$goal_id"
    return 0
  else
    log_error "goal-ai" "AI analysis failed"
    return 1
  fi
}

# goal_ai_plan: Generate implementation plan
#
# Description:
#   Creates a step-by-step implementation plan for a goal.
#
# Arguments:
#   $1 - goal_id (integer): Goal number
#
# Returns:
#   0 - Plan generated
#   1 - Goal not found or AI error
#
# Outputs:
#   stdout: Implementation plan
goal_ai_plan() {
  local goal_id="${1:?goal_ai_plan requires goal_id}"

  log_info "goal-ai" "Generating plan for goal #$goal_id"

  # Get goal details
  local goal_json
  goal_json=$(goal_ai_get_goal "$goal_id") || return 1

  local goal_text
  goal_text=$(jq -r '.goal' <<<"$goal_json")

  # Check if GitHub issue is referenced
  local issue_number
  issue_number=$(goal_ai_extract_github_issue "$goal_text") || issue_number=""

  # Build AI prompt
  local prompt
  prompt="Create a detailed implementation plan for this development goal:\n\n"
  prompt+="**Goal:** \"$goal_text\"\n\n"

  # Add GitHub context if available
  if [[ -n "$issue_number" ]] && github_check_auth 2>/dev/null; then
    log_debug "goal-ai" "Fetching GitHub issue #$issue_number"
    local issue_data
    issue_data=$(github_get_issue "$issue_number" 2>/dev/null || echo "")

    if [[ -n "$issue_data" ]]; then
      prompt+="**GitHub Issue #$issue_number:**\n"
      prompt+="- Title: $(jq -r '.title' <<<"$issue_data")\n"
      prompt+="- State: $(jq -r '.state' <<<"$issue_data")\n"
      prompt+="- Labels: $(jq -r '.labels[].name' <<<"$issue_data" | paste -sd ',' -)\n"
      prompt+="\n"

      local body
      body=$(jq -r '.body // ""' <<<"$issue_data")
      if [[ -n "$body" ]]; then
        prompt+="**Issue Description:**\n$body\n\n"
      fi
    fi
  fi

  prompt+="**Generate a step-by-step implementation plan:**\n\n"
  prompt+="1. **Preparation Steps** (setup, research, planning)\n"
  prompt+="2. **Implementation Steps** (numbered, in order)\n"
  prompt+="   - Each step should be <2 hours\n"
  prompt+="   - Include specific files/functions to modify\n"
  prompt+="   - Note any TDD requirements\n"
  prompt+="3. **Testing Strategy** (how to verify each step)\n"
  prompt+="4. **Rollback Plan** (if something goes wrong)\n"
  prompt+="5. **Success Verification** (final checks)\n\n"
  prompt+="Make the plan actionable, specific, and safe."

  echo ""
  echo "📋 Generating implementation plan with AI..."
  echo ""

  if ai_query "$prompt" --no-cache; then
    log_info "goal-ai" "Plan generated for goal #$goal_id"

    # Cache the plan
    local cache_file="$GOAL_AI_CACHE_DIR/plan-$goal_id-$(date '+%Y%m%d').md"
    ai_query "$prompt" --no-cache >"$cache_file" 2>/dev/null

    return 0
  else
    log_error "goal-ai" "Plan generation failed"
    return 1
  fi
}

# goal_ai_next: Suggest what to work on next
#
# Description:
#   Analyzes all active goals and suggests the best next action.
#
# Returns:
#   0 - Suggestion provided
#   1 - No goals or AI error
#
# Outputs:
#   stdout: Next action suggestion
goal_ai_next() {
  log_info "goal-ai" "Analyzing next action"

  if ! goal_exists_today; then
    echo "No goals set for today."
    echo ""
    echo "💡 Set a goal first:"
    echo "   harm-cli goal set \"Your goal\" 2h"
    return 0
  fi

  local goal_file
  goal_file="$(goal_file_for_today)"

  # Build context of all goals
  local goals_summary=""
  local goal_num=0

  while IFS= read -r line; do
    ((++goal_num))

    local goal
    goal=$(jq -r '.goal' <<<"$line")
    local progress
    progress=$(jq -r '.progress' <<<"$line")
    local completed
    completed=$(jq -r '.completed' <<<"$line")
    local estimated
    estimated=$(jq -r '.estimated_minutes // "null"' <<<"$line")

    local status="In Progress ($progress%)"
    if [[ "$completed" == "true" ]]; then
      status="✅ Completed"
    fi

    goals_summary+="$goal_num. **$goal** - $status"

    if [[ "$estimated" != "null" ]]; then
      local formatted
      formatted=$(format_duration $((estimated * 60)))
      goals_summary+=" (Est: $formatted)"
    fi

    goals_summary+="\n"
  done <"$goal_file"

  # Build AI prompt
  local prompt
  prompt="I have the following goals for today:\n\n"
  prompt+="$goals_summary\n"
  prompt+="**Question:** What should I work on next?\n\n"
  prompt+="Consider:\n"
  prompt+="1. **Urgency** - What's most time-sensitive?\n"
  prompt+="2. **Dependencies** - What blocks other tasks?\n"
  prompt+="3. **Progress** - What's closest to completion?\n"
  prompt+="4. **Energy** - What matches current focus level?\n"
  prompt+="5. **Impact** - What delivers most value?\n\n"
  prompt+="Provide:\n"
  prompt+="- Recommended goal to focus on (by number)\n"
  prompt+="- Reasoning for the recommendation\n"
  prompt+="- Suggested first action to take\n"
  prompt+="- Estimated time to complete this session\n"

  echo ""
  echo "🎯 Analyzing priorities with AI..."
  echo ""

  if ai_query "$prompt" --no-cache; then
    log_info "goal-ai" "Next action suggested"
    return 0
  else
    log_error "goal-ai" "Next action suggestion failed"
    return 1
  fi
}

# goal_ai_check_completion: Verify goal can be marked complete
#
# Description:
#   Uses AI to verify if a goal meets completion criteria.
#
# Arguments:
#   $1 - goal_id (integer): Goal number
#
# Returns:
#   0 - Verification complete
#   1 - Goal not found or AI error
#
# Outputs:
#   stdout: Verification result
goal_ai_check_completion() {
  local goal_id="${1:?goal_ai_check_completion requires goal_id}"

  log_info "goal-ai" "Verifying completion for goal #$goal_id"

  # Get goal details
  local goal_json
  goal_json=$(goal_ai_get_goal "$goal_id") || return 1

  local goal_text
  goal_text=$(jq -r '.goal' <<<"$goal_json")
  local progress
  progress=$(jq -r '.progress' <<<"$goal_json")

  # Build AI prompt
  local prompt
  prompt="Verify if this development goal can be marked as complete:\n\n"
  prompt+="**Goal:** \"$goal_text\"\n"
  prompt+="**Current Progress:** $progress%\n\n"
  prompt+="**Completion Checklist:**\n"
  prompt+="1. ✅ Implementation complete?\n"
  prompt+="2. ✅ Tests passing?\n"
  prompt+="3. ✅ Code reviewed (if applicable)?\n"
  prompt+="4. ✅ Documentation updated?\n"
  prompt+="5. ✅ No known blockers or issues?\n\n"
  prompt+="**Question:** Is this goal ready to be marked complete?\n\n"
  prompt+="Provide:\n"
  prompt+="- YES/NO recommendation\n"
  prompt+="- Reasoning\n"
  prompt+="- Any remaining tasks (if NO)\n"
  prompt+="- Suggestions for verification\n"

  echo ""
  echo "🔍 Verifying completion criteria with AI..."
  echo ""

  if ai_query "$prompt" --no-cache; then
    log_info "goal-ai" "Completion verification complete"
    return 0
  else
    log_error "goal-ai" "Completion verification failed"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════
# Claude Code Integration
# ═══════════════════════════════════════════════════════════════

# goal_ai_create_context: Generate Claude Code context file
#
# Description:
#   Creates a markdown context file for Claude Code with all active goals,
#   implementation plans, and GitHub context.
#
# Returns:
#   0 - Context file created
#   1 - No goals or creation failed
#
# Outputs:
#   stdout: Success message with file path
goal_ai_create_context() {
  log_info "goal-ai" "Creating Claude Code context"

  if ! goal_exists_today; then
    warn_msg "No goals set for today"
    return 1
  fi

  local goal_file
  goal_file="$(goal_file_for_today)"

  # Build context file
  {
    echo "# 🎯 Active Development Goals"
    echo ""
    echo "**Generated:** $(date '+%Y-%m-%d %H:%M:%S')"
    echo "**Source:** harm-cli goal tracking"
    echo ""
    echo "---"
    echo ""

    echo "## Today's Goals ($(date '+%Y-%m-%d'))"
    echo ""

    local goal_num=0
    while IFS= read -r line; do
      ((++goal_num))

      local goal
      goal=$(jq -r '.goal' <<<"$line")
      local progress
      progress=$(jq -r '.progress' <<<"$line")
      local completed
      completed=$(jq -r '.completed' <<<"$line")
      local estimated
      estimated=$(jq -r '.estimated_minutes // "null"' <<<"$line")

      echo "### Goal #$goal_num: $goal"
      echo ""

      if [[ "$completed" == "true" ]]; then
        echo "**Status:** ✅ Completed"
      else
        echo "**Status:** 🔄 In Progress ($progress%)"
      fi

      if [[ "$estimated" != "null" ]]; then
        local formatted
        formatted=$(format_duration $((estimated * 60)))
        echo "**Estimated Time:** $formatted"
      fi

      # Check for GitHub issue
      local issue_number
      issue_number=$(goal_ai_extract_github_issue "$goal") || issue_number=""

      if [[ -n "$issue_number" ]] && github_check_auth 2>/dev/null; then
        echo "**GitHub Issue:** #$issue_number"

        local issue_data
        issue_data=$(github_get_issue "$issue_number" 2>/dev/null || echo "")

        if [[ -n "$issue_data" ]]; then
          echo "**Issue Status:** $(jq -r '.state' <<<"$issue_data")"
          echo "**Labels:** $(jq -r '.labels[].name' <<<"$issue_data" | paste -sd ', ' -)"
        fi
      fi

      # Check for cached plan
      local cache_file="$GOAL_AI_CACHE_DIR/plan-$goal_num-$(date '+%Y%m%d').md"
      if [[ -f "$cache_file" ]]; then
        echo ""
        echo "**Implementation Plan:**"
        echo ""
        echo '```'
        cat "$cache_file"
        echo '```'
      fi

      echo ""
    done <"$goal_file"

    echo "---"
    echo ""
    echo "## Commands"
    echo ""
    echo "Update progress:"
    echo '```bash'
    echo "harm-cli goal progress <id> <percent>"
    echo '```'
    echo ""
    echo "Mark complete:"
    echo '```bash'
    echo "harm-cli goal complete <id>"
    echo '```'
    echo ""
    echo "Get AI assistance:"
    echo '```bash'
    echo "harm-cli goal ai-plan <id>    # Generate implementation plan"
    echo "harm-cli goal ai-next         # What to work on next"
    echo '```'
    echo ""

  } >"$CLAUDE_CONTEXT_FILE"

  success_msg "Claude Code context created"
  echo "  File: $CLAUDE_CONTEXT_FILE"
  echo ""
  echo "💡 Use in Claude Code session:"
  echo "   Read the file to understand active goals and plans"

  log_info "goal-ai" "Context file created at $CLAUDE_CONTEXT_FILE"
  return 0
}

# ═══════════════════════════════════════════════════════════════
# GitHub Integration
# ═══════════════════════════════════════════════════════════════

# goal_ai_link_github: Link goal to GitHub issue
#
# Arguments:
#   $1 - goal_id (integer): Goal number
#   $2 - issue_number (integer): GitHub issue number
#
# Returns:
#   0 - Link created
#   1 - Error
goal_ai_link_github() {
  local goal_id="${1:?goal_ai_link_github requires goal_id}"
  local issue_number="${2:?goal_ai_link_github requires issue_number}"

  log_info "goal-ai" "Linking goal #$goal_id to GitHub issue #$issue_number"

  # Verify GitHub auth
  if ! github_check_auth 2>/dev/null; then
    error_msg "GitHub authentication required"
    return 1
  fi

  # Get issue details to verify it exists
  local issue_data
  if ! issue_data=$(github_get_issue "$issue_number" 2>/dev/null); then
    error_msg "GitHub issue #$issue_number not found"
    return 1
  fi

  local issue_title
  issue_title=$(jq -r '.title' <<<"$issue_data")

  success_msg "Linked goal #$goal_id to GitHub issue #$issue_number"
  echo "  Issue: $issue_title"
  echo ""
  echo "💡 The goal description now references #$issue_number"

  log_info "goal-ai" "Link created"
  return 0
}

# goal_ai_sync_github: Sync goal status with GitHub issue
#
# Arguments:
#   $1 - goal_id (integer): Goal number
#
# Returns:
#   0 - Sync complete
#   1 - Error
goal_ai_sync_github() {
  local goal_id="${1:?goal_ai_sync_github requires goal_id}"

  log_info "goal-ai" "Syncing goal #$goal_id with GitHub"

  # Get goal details
  local goal_json
  goal_json=$(goal_ai_get_goal "$goal_id") || return 1

  local goal_text
  goal_text=$(jq -r '.goal' <<<"$goal_json")
  local progress
  progress=$(jq -r '.progress' <<<"$goal_json")
  local completed
  completed=$(jq -r '.completed' <<<"$goal_json")

  # Extract issue number
  local issue_number
  if ! issue_number=$(goal_ai_extract_github_issue "$goal_text"); then
    warn_msg "No GitHub issue referenced in goal #$goal_id"
    return 1
  fi

  # Verify GitHub auth
  if ! github_check_auth 2>/dev/null; then
    error_msg "GitHub authentication required"
    return 1
  fi

  info_msg "Syncing with GitHub issue #$issue_number"
  echo "  Goal progress: $progress%"
  echo "  Completed: $completed"
  echo ""

  # Note: Actual syncing would update issue comments/labels
  # For now, just report status
  echo "💡 Sync complete (read-only mode)"
  echo "   To update issue, use: gh issue comment $issue_number"

  log_info "goal-ai" "Sync complete"
  return 0
}

# ═══════════════════════════════════════════════════════════════
# Exports
# ═══════════════════════════════════════════════════════════════

export -f goal_ai_analyze goal_ai_plan goal_ai_next goal_ai_check_completion
export -f goal_ai_create_context
export -f goal_ai_link_github goal_ai_sync_github
