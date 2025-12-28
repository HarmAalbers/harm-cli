#!/usr/bin/env bash
# shellcheck shell=bash
# git.sh - Enhanced git workflows with AI integration
# Ported from: ~/.zsh/20_git_advanced.zsh
#
# Features:
# - AI-powered commit message generation
# - Enhanced git status with suggestions
# - Git utilities (default branch detection, repo checks)
# - Integration with lib/ai.sh for intelligent workflows
#
# Public API:
#   git_commit_msg             - Generate AI commit message from staged changes
#   git_status_enhanced        - Enhanced git status with actionable suggestions
#   git_fuzzy_checkout         - Interactive branch checkout with fzf (sorted by recency)
#   git_default_branch         - Detect repository's default branch (main/master)
#   git_is_repo                - Check if current directory is a git repository
#
# Dependencies: git, lib/ai.sh (for commit messages)

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_GIT_LOADED:-}" ]] && return 0

# Source dependencies
GIT_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly GIT_SCRIPT_DIR

# shellcheck source=lib/common.sh
source "$GIT_SCRIPT_DIR/common.sh"
# shellcheck source=lib/error.sh
source "$GIT_SCRIPT_DIR/error.sh"
# shellcheck source=lib/logging.sh
source "$GIT_SCRIPT_DIR/logging.sh"
# shellcheck source=lib/util.sh
source "$GIT_SCRIPT_DIR/util.sh"
# shellcheck source=lib/ai.sh
source "$GIT_SCRIPT_DIR/ai.sh"

# ═══════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════

# Conventional commit types
readonly GIT_COMMIT_TYPES=(feat fix docs style refactor perf test build ci chore revert)

# ═══════════════════════════════════════════════════════════════════
# Git Utilities
# ═══════════════════════════════════════════════════════════════════

# git_is_repo: Check if current directory is a git repository
#
# Description:
#   Verifies if the current working directory is inside a git repository
#   by checking for the .git directory.
#
# Arguments:
#   None
#
# Returns:
#   0 - Inside a git repository
#   1 - Not in a git repository
#
# Outputs:
#   stderr: Log messages via log_debug
#
# Examples:
#   git_is_repo && echo "In git repo"
#   if git_is_repo; then
#     git status
#   fi
#
# Notes:
#   - Uses `git rev-parse --git-dir` for detection
#   - Works in subdirectories of git repos
#   - Logs debug message when checking
#
# Performance:
#   - Typical: <10ms
#   - Uses git's built-in detection (very fast)
git_is_repo() {
  log_debug "git" "Checking if in git repository"

  if git rev-parse --git-dir >/dev/null 2>&1; then
    log_debug "git" "Inside git repository"
    return 0
  else
    log_debug "git" "Not in git repository"
    return 1
  fi
}

# git_default_branch: Detect repository's default branch
#
# Description:
#   Determines the default branch name for the current repository.
#   Checks in priority order: main, master, then falls back to main.
#
# Arguments:
#   None
#
# Returns:
#   0 - Always succeeds
#
# Outputs:
#   stdout: Branch name (main, master, or "main" as fallback)
#   stderr: Log messages via log_debug
#
# Examples:
#   default=$(git_default_branch)
#   git checkout "$(git_default_branch)"
#
# Notes:
#   - Checks if branches exist using git rev-parse
#   - Order: main (modern) → master (legacy) → main (fallback)
#   - Requires being in a git repository
#
# Performance:
#   - Typical: <20ms (2 git commands)
git_default_branch() {
  log_debug "git" "Detecting default branch"

  if git rev-parse --verify main >/dev/null 2>&1; then
    echo "main"
    log_debug "git" "Default branch: main"
  elif git rev-parse --verify master >/dev/null 2>&1; then
    echo "master"
    log_debug "git" "Default branch: master"
  else
    echo "main"
    log_debug "git" "Default branch: main (fallback)"
  fi
}

# ═══════════════════════════════════════════════════════════════════
# Git Operations
# ═══════════════════════════════════════════════════════════════════

# git_commit_msg: Generate AI-powered commit message from staged changes
#
# Description:
#   Analyzes staged git changes and uses AI to generate a well-formatted
#   conventional commit message. Detects commit type (feat/fix/docs/etc),
#   scope, and provides detailed description based on the actual code changes.
#
# Arguments:
#   None
#
# Returns:
#   0 - Commit message generated successfully
#   EXIT_INVALID_STATE - Not in git repository or no staged changes
#   EXIT_AI_NO_KEY - No AI API key available
#   EXIT_AI_NETWORK - AI API request failed
#
# Outputs:
#   stdout: Generated commit message (conventional commit format)
#   stderr: Log messages via log_info/log_debug/log_error
#
# Examples:
#   git add lib/git.sh
#   git_commit_msg
#   # Output: feat(git): add AI commit message generation
#
#   msg=$(git_commit_msg) && git commit -m "$msg"
#
# Notes:
#   - Requires staged changes (git diff --cached)
#   - Uses AI to analyze diff and generate message
#   - Follows conventional commit format: type(scope): description
#   - Truncates large diffs to 300 lines for AI processing
#   - Message includes summary + bullet points for details
#
# Format:
#   type(scope): short description
#
#   - Detailed change 1
#   - Detailed change 2
#   - Detailed change 3
#
# Performance:
#   - Small diffs (<100 lines): 2-5s (AI latency)
#   - Large diffs (300 lines): 3-7s
#   - No staged changes: <50ms (early return)
#
# Integration:
#   - Requires lib/ai.sh for AI query
#   - Uses ai_query() with custom prompt
#   - Bypasses cache (always fresh)
git_commit_msg() {
  log_info "git" "Generating AI commit message"

  # Check API key first before doing any work
  local api_key
  api_key=$(ai_get_api_key 2>/dev/null) || {
    error_msg "No Gemini API key configured. Run: harm-cli ai --setup"
    log_error "git" "Commit message generation failed" "No API key configured"
    return "$EXIT_AI_NO_KEY"
  }
  log_debug "git" "API key validated"

  # Check if in git repository
  if ! git_is_repo; then
    error_msg "Not in a git repository"
    log_error "git" "Commit message generation failed" "Not in git repo"
    return "$EXIT_INVALID_STATE"
  fi

  # Get staged changes
  local diff
  log_debug "git" "Getting staged changes"
  diff=$(git diff --cached 2>/dev/null)

  if [[ -z "$diff" ]]; then
    error_msg "No staged changes to commit"
    log_info "git" "No staged changes found"
    echo ""
    echo "Tip: Stage changes with: git add <files>"
    return "$EXIT_INVALID_STATE"
  fi
  log_debug "git" "Staged changes retrieved"

  # Count lines
  local line_count
  line_count=$(echo "$diff" | wc -l | tr -d ' ')
  log_debug "git" "Staged diff retrieved" "Lines: $line_count"

  # Truncate if too large
  if [[ $line_count -gt 300 ]]; then
    diff=$(echo "$diff" | head -300)
    echo "⚠️  Diff truncated to 300 lines for AI analysis (total: $line_count lines)"
    log_warn "git" "Diff truncated" "Original: $line_count, Using: 300"
  fi

  # Get current branch for context
  local branch
  branch=$(git branch --show-current 2>/dev/null || echo "unknown")

  # Get list of changed files
  local changed_files
  changed_files=$(git diff --cached --name-only | head -10)

  # Build context for AI
  local context
  context="Generate a conventional commit message for these staged changes.\n\n"
  context+="Branch: $branch\n"
  context+="Lines changed: $line_count\n"
  context+="Files changed:\n$changed_files\n\n"
  context+="Staged diff:\n\`\`\`diff\n$diff\n\`\`\`"

  # Build AI prompt
  local prompt
  prompt="Based on these git changes, generate a conventional commit message.\n\n"
  prompt+="Format:\n"
  prompt+="type(scope): short description (max 72 chars)\n\n"
  prompt+="- Detailed point 1\n"
  prompt+="- Detailed point 2\n"
  prompt+="- Detailed point 3\n\n"
  prompt+="Requirements:\n"
  prompt+="1. **Type**: Use appropriate type (feat/fix/docs/refactor/test/chore/style/perf)\n"
  prompt+="2. **Scope**: Module/component affected (e.g., ai, git, work, goals)\n"
  prompt+="3. **Description**: Clear, concise summary in imperative mood\n"
  prompt+="4. **Details**: 2-5 bullet points explaining what changed\n\n"
  prompt+="Be specific and follow conventional commit standards."

  # Note: _ai_make_request shows its own "🤖 Thinking..." message
  local file_count
  file_count=$(echo "$changed_files" | wc -l | tr -d ' ')
  log_info "git" "Requesting AI commit message" "Lines: $line_count, Files: $file_count"

  # Query AI (bypass cache)
  local full_query="$context\n\n$prompt"
  local response
  log_debug "git" "Sending request to AI" "Length: ${#full_query} chars"
  if ! response=$(_ai_make_request "$api_key" "$full_query" ""); then
    local exit_code=$?
    log_error "git" "Commit message generation failed" "AI API error"
    echo ""
    echo "Fallback: Generate commit message manually or try again"
    return "$exit_code"
  fi
  log_debug "git" "AI response received"

  # Parse response
  local commit_msg
  if commit_msg=$(_ai_parse_response "$response"); then
    echo ""
    echo "$commit_msg"
    echo ""
    log_info "git" "Commit message generated successfully"
    return 0
  else
    log_error "git" "Failed to parse commit message response"
    return "$EXIT_AI_INVALID_RESPONSE"
  fi
}

# git_status_enhanced: Enhanced git status with actionable suggestions
#
# Description:
#   Displays git status with additional context and actionable suggestions
#   based on current repository state. Helps guide next steps in workflow.
#
# Arguments:
#   None
#
# Returns:
#   0 - Status displayed successfully
#   EXIT_INVALID_STATE - Not in a git repository
#
# Outputs:
#   stdout: Enhanced status information with suggestions
#   stderr: Log messages via log_info/log_debug/log_error
#
# Examples:
#   git_status_enhanced
#   harm-cli git status
#
# Notes:
#   - Shows current branch, uncommitted changes, untracked files
#   - Provides actionable suggestions based on state
#   - Works with standard git commands (portable)
#
# Performance:
#   - Typical: 50-100ms (depends on repo size)
#   - Uses git status --porcelain for parsing
git_status_enhanced() {
  log_info "git" "Showing enhanced git status"

  # Check if in git repository
  if ! git_is_repo; then
    error_msg "Not in a git repository"
    log_error "git" "Enhanced status failed" "Not in git repo"
    return "$EXIT_INVALID_STATE"
  fi

  # Get current branch
  local branch
  branch=$(git branch --show-current 2>/dev/null || echo "detached HEAD")

  # Get status summary
  local status
  status=$(git status --porcelain 2>/dev/null)

  # Count changes (grep -c returns 0 on no match, which is what we want)
  local modified staged untracked
  modified=$(echo "$status" | grep -c "^ M\|^M " 2>/dev/null | tr -d ' \n' || echo "0")
  staged=$(echo "$status" | grep -c "^M\|^A\|^D" 2>/dev/null | tr -d ' \n' || echo "0")
  untracked=$(echo "$status" | grep -c "^??" 2>/dev/null | tr -d ' \n' || echo "0")

  # Ensure counts are numeric (grep -c outputs 0 on no match)
  modified=${modified:-0}
  staged=${staged:-0}
  untracked=${untracked:-0}

  # Display enhanced status
  echo "Git Status"
  echo "══════════════════════════════════════════"
  echo ""
  echo "Branch: $branch"
  echo ""

  if [[ -n "$status" ]]; then
    echo "Changes:"
    [[ $staged -gt 0 ]] && echo "  ✓ Staged: $staged files"
    [[ $modified -gt 0 ]] && echo "  ⚡ Modified: $modified files"
    [[ $untracked -gt 0 ]] && echo "  ✨ Untracked: $untracked files"
    echo ""

    # Show actual status
    git status --short
    echo ""

    # Provide suggestions
    echo "Suggestions:"
    if [[ $modified -gt 0 || $untracked -gt 0 ]]; then
      echo "  → Stage changes: git add <file>"
    fi
    if [[ $staged -gt 0 ]]; then
      echo "  → Generate commit: harm-cli git commit-msg"
      echo "  → Or commit: git commit -m \"message\""
    fi
    if [[ $modified -eq 0 && $staged -eq 0 && $untracked -eq 0 ]]; then
      echo "  → Working tree clean!"
    fi
  else
    echo "✅ Working tree clean"
    echo ""
    echo "Suggestions:"
    echo "  → Pull latest: git pull"
    echo "  → Create branch: git checkout -b feature/name"
  fi

  log_debug "git" "Status displayed" "Staged: $staged, Modified: $modified, Untracked: $untracked"
  return 0
}

# git_fuzzy_checkout: Interactive branch checkout with fzf
#
# Description:
#   Provides an interactive fuzzy-searchable menu for checking out git branches.
#   Branches are sorted by most recently checked out (from reflog) for quick access.
#   Shows preview of recent commits for each branch using fzf preview window.
#
# Arguments:
#   None
#
# Returns:
#   0 - Branch checked out successfully or user cancelled
#   EXIT_INVALID_STATE - Not in a git repository
#   EXIT_MISSING_DEPS - fzf not installed
#
# Outputs:
#   stdout: Git checkout output
#   stderr: Log messages via log_info/log_debug/log_error
#
# Examples:
#   git_fuzzy_checkout
#   harm-cli git fco
#   harm-cli git fuzzy-checkout
#
# Notes:
#   - Requires fzf (brew install fzf)
#   - Branches sorted by last checkout time (reflog analysis)
#   - Shows last 10 commits for each branch in preview
#   - Excludes commit hashes from branch list (detached HEAD states)
#   - Uses fzf for interactive selection with preview
#
# Performance:
#   - Small repos (<50 branches): <100ms
#   - Large repos (>100 branches): 100-500ms
#   - Preview generation: on-demand per branch
#
# Interactive:
#   - Arrow keys: Navigate branches
#   - Enter: Checkout selected branch
#   - Esc/Ctrl+C: Cancel without checkout
git_fuzzy_checkout() {
  log_info "git" "Starting fuzzy checkout"

  # Check for fzf
  if ! command -v fzf >/dev/null 2>&1; then
    error_msg "fzf not installed. Install with: brew install fzf"
    log_error "git" "Fuzzy checkout failed" "fzf not found"
    return "$EXIT_MISSING_DEPS"
  fi
  log_debug "git" "fzf found"

  # Check if in git repository
  if ! git_is_repo; then
    error_msg "Not in a git repository"
    log_error "git" "Fuzzy checkout failed" "Not in git repo"
    return "$EXIT_INVALID_STATE"
  fi

  # Get branches sorted by last checkout from reflog
  log_debug "git" "Retrieving reflog branch history"
  local reflog_branches
  if reflog_branches=$(git reflog 2>&1); then
    # Parse reflog output with error handling
    local parse_result
    if parse_result=$(echo "$reflog_branches" \
      | grep -o "checkout: moving from .* to .*" \
      | sed -E 's/checkout: moving from .* to (.*)/\1/' \
      | grep -v "^[0-9a-f]\{7,\}$" \
      | awk '!seen[$0]++' 2>&1); then
      reflog_branches="$parse_result"
      log_debug "git" "Reflog branches retrieved" "count=$(echo "$reflog_branches" | grep -c . || echo 0)"
    else
      log_error "git" "Failed to parse reflog" "error=$parse_result"
      reflog_branches=""
    fi
  else
    log_warn "git" "Failed to retrieve reflog" "error=$reflog_branches"
    reflog_branches=""
  fi

  # Validate we got some branches from reflog (empty is normal for new repos)
  if [[ -z "$reflog_branches" ]]; then
    log_info "git" "No reflog history available" "This is normal for new repositories"
  fi

  # Get all local branches
  log_debug "git" "Retrieving all local branches"
  local all_branches
  if ! all_branches=$(git branch --format='%(refname:short)' 2>&1 | sed 's/^[* ] *//'); then
    log_error "git" "Failed to retrieve local branches" "error=$all_branches"
    error_msg "Failed to retrieve branch list"
    return "$EXIT_ERROR"
  fi
  log_debug "git" "Local branches retrieved" "count=$(echo "$all_branches" | grep -c . || echo 0)"

  # Combine: reflog branches first, then remaining branches
  log_debug "git" "Combining and deduplicating branch lists"
  local sorted_branches
  if ! sorted_branches=$(
    {
      echo "$reflog_branches"
      echo "$all_branches"
    } | awk '!seen[$0]++' | grep -v '^$' 2>&1
  ); then
    log_error "git" "Failed to deduplicate branches" "error=$sorted_branches"
    error_msg "Failed to process branch list"
    return "$EXIT_ERROR"
  fi

  # Validate we have branches
  if [[ -z "$sorted_branches" ]]; then
    error_msg "No branches found in repository"
    log_error "git" "Fuzzy checkout failed" "No branches available"
    echo ""
    echo "This might be a new repository. Create a branch with:"
    echo "  git checkout -b main"
    return "$EXIT_INVALID_STATE"
  fi

  # Count branches
  local branch_count
  branch_count=$(echo "$sorted_branches" | wc -l | tr -d ' ')
  log_info "git" "Branch selection menu" "Branches: $branch_count"

  # Use fzf to select branch
  log_debug "git" "Launching fzf for branch selection"
  local selected
  selected=$(echo "$sorted_branches" \
    | fzf --height 50% --reverse \
      --header 'Select branch (sorted by last checkout)' \
      --preview 'git log --oneline --color=always -10 {}' \
      --preview-window 'right:50%:wrap')

  # Checkout selected branch
  if [[ -n "$selected" ]]; then
    log_info "git" "Checking out branch" "Branch: $selected"
    git checkout "$selected"
    log_info "git" "Branch checkout complete" "Branch: $selected"
  else
    log_info "git" "Fuzzy checkout cancelled" "No branch selected"
  fi

  return 0
}

# Export public functions
export -f git_is_repo
export -f git_default_branch
export -f git_commit_msg
export -f git_status_enhanced
export -f git_fuzzy_checkout

# Mark module as loaded
readonly _HARM_GIT_LOADED=1
