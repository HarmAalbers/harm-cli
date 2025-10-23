#!/usr/bin/env bash
# shellcheck shell=bash
# github.sh - GitHub integration for harm-cli
#
# Features:
# - GitHub CLI (gh) wrapper with authentication
# - Repository information and context
# - Issue and PR management
# - Branch tracking and status
# - Comment retrieval
# - Rate limit management
#
# Public API:
#   github_check_auth                    - Verify gh CLI authentication
#   github_get_repo_info                 - Get current repo details
#   github_get_current_branch_info       - Branch, tracking, PRs
#   github_list_issues [state]           - List issues (open/closed/all)
#   github_list_prs [state]              - List pull requests
#   github_get_issue <number>            - Get issue details
#   github_get_pr <number>               - Get PR details
#   github_get_comments <type> <number>  - Get issue/PR comments
#   github_create_context_summary        - Generate AI-ready context
#
# Dependencies: gh (GitHub CLI), jq

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_GITHUB_LOADED:-}" ]] && return 0

# Source dependencies
GITHUB_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly GITHUB_SCRIPT_DIR

# shellcheck source=lib/common.sh
source "$GITHUB_SCRIPT_DIR/common.sh"
# shellcheck source=lib/error.sh
source "$GITHUB_SCRIPT_DIR/error.sh"
# shellcheck source=lib/logging.sh
source "$GITHUB_SCRIPT_DIR/logging.sh"

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════

readonly GITHUB_CACHE_DIR="${HARM_CLI_HOME:-$HOME/.harm-cli}/github-cache"
readonly GITHUB_CACHE_TTL="${HARM_GITHUB_CACHE_TTL:-300}" # 5 minutes default

# Ensure cache directory exists
ensure_dir "$GITHUB_CACHE_DIR"

# ═══════════════════════════════════════════════════════════════
# Authentication & Requirements
# ═══════════════════════════════════════════════════════════════

# github_check_gh_installed: Check if gh CLI is installed
#
# Returns:
#   0 - gh CLI installed
#   1 - gh CLI not installed
github_check_gh_installed() {
  if ! command -v gh >/dev/null 2>&1; then
    log_error "github" "GitHub CLI not installed"
    error_msg "GitHub CLI (gh) is required"
    error_msg "Install: brew install gh (macOS) or https://cli.github.com"
    return 1
  fi

  log_debug "github" "GitHub CLI found" "$(gh --version | head -1)"
  return 0
}

# github_check_auth: Verify GitHub CLI authentication
#
# Returns:
#   0 - Authenticated
#   1 - Not authenticated
#
# Outputs:
#   stderr: Error messages if not authenticated
github_check_auth() {
  if ! github_check_gh_installed; then
    return 1
  fi

  if ! gh auth status >/dev/null 2>&1; then
    log_error "github" "Not authenticated"
    error_msg "GitHub authentication required"
    error_msg "Run: gh auth login"
    return 1
  fi

  log_debug "github" "GitHub authentication verified"
  return 0
}

# ═══════════════════════════════════════════════════════════════
# Repository Information
# ═══════════════════════════════════════════════════════════════

# github_in_repo: Check if current directory is in a git repo with GitHub remote
#
# Returns:
#   0 - In GitHub repository
#   1 - Not in repo or no GitHub remote
github_in_repo() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    log_debug "github" "Not in git repository"
    return 1
  fi

  # Check for GitHub remote
  if ! git remote get-url origin 2>/dev/null | grep -q "github.com"; then
    log_debug "github" "No GitHub remote found"
    return 1
  fi

  return 0
}

# github_get_repo_info: Get current repository information
#
# Returns:
#   0 - Success
#   1 - Not in GitHub repo or error
#
# Outputs:
#   stdout: JSON object with repo info (owner, name, description, etc.)
#
# Examples:
#   info=$(github_get_repo_info)
#   owner=$(echo "$info" | jq -r '.owner')
github_get_repo_info() {
  github_check_auth || return 1
  github_in_repo || {
    error_msg "Not in a GitHub repository"
    return 1
  }

  log_debug "github" "Fetching repository info"

  # Get repo info via gh CLI
  gh repo view --json owner,name,description,url,isPrivate,defaultBranchRef,updatedAt
}

# github_get_current_branch_info: Get current branch information
#
# Returns:
#   0 - Success
#   1 - Error
#
# Outputs:
#   stdout: JSON object with branch info, tracking, and related PRs
github_get_current_branch_info() {
  github_check_auth || return 1
  github_in_repo || return 1

  local current_branch
  current_branch=$(git branch --show-current)

  log_debug "github" "Getting branch info" "Branch: $current_branch"

  # Get tracking info
  local tracking
  tracking=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo "")

  # Check for PRs for this branch
  local prs
  prs=$(gh pr list --head "$current_branch" --json number,title,state,url 2>/dev/null || echo "[]")

  # Build JSON response
  jq -n \
    --arg branch "$current_branch" \
    --arg tracking "$tracking" \
    --argjson prs "$prs" \
    '{
      branch: $branch,
      tracking: $tracking,
      pull_requests: $prs
    }'
}

# ═══════════════════════════════════════════════════════════════
# Issues
# ═══════════════════════════════════════════════════════════════

# github_list_issues: List repository issues
#
# Arguments:
#   $1 - state (optional): open|closed|all (default: open)
#   $2 - limit (optional): max number to return (default: 30)
#
# Returns:
#   0 - Success
#   1 - Error
#
# Outputs:
#   stdout: JSON array of issues
github_list_issues() {
  github_check_auth || return 1
  github_in_repo || return 1

  local state="${1:-open}"
  local limit="${2:-30}"

  log_debug "github" "Listing issues" "State: $state, Limit: $limit"

  gh issue list \
    --state "$state" \
    --limit "$limit" \
    --json number,title,state,author,labels,createdAt,updatedAt,url
}

# github_get_issue: Get specific issue details
#
# Arguments:
#   $1 - number (required): Issue number
#
# Returns:
#   0 - Success
#   1 - Error
#
# Outputs:
#   stdout: JSON object with full issue details
github_get_issue() {
  local number="${1:?github_get_issue requires issue number}"

  github_check_auth || return 1
  github_in_repo || return 1

  log_debug "github" "Getting issue" "#$number"

  gh issue view "$number" \
    --json number,title,body,state,author,labels,assignees,comments,createdAt,updatedAt,url
}

# ═══════════════════════════════════════════════════════════════
# Pull Requests
# ═══════════════════════════════════════════════════════════════

# github_list_prs: List repository pull requests
#
# Arguments:
#   $1 - state (optional): open|closed|merged|all (default: open)
#   $2 - limit (optional): max number to return (default: 30)
#
# Returns:
#   0 - Success
#   1 - Error
#
# Outputs:
#   stdout: JSON array of PRs
github_list_prs() {
  github_check_auth || return 1
  github_in_repo || return 1

  local state="${1:-open}"
  local limit="${2:-30}"

  log_debug "github" "Listing PRs" "State: $state, Limit: $limit"

  gh pr list \
    --state "$state" \
    --limit "$limit" \
    --json number,title,state,author,labels,createdAt,updatedAt,url,headRefName
}

# github_get_pr: Get specific PR details
#
# Arguments:
#   $1 - number (required): PR number
#
# Returns:
#   0 - Success
#   1 - Error
#
# Outputs:
#   stdout: JSON object with full PR details
github_get_pr() {
  local number="${1:?github_get_pr requires PR number}"

  github_check_auth || return 1
  github_in_repo || return 1

  log_debug "github" "Getting PR" "#$number"

  gh pr view "$number" \
    --json number,title,body,state,author,labels,assignees,comments,createdAt,updatedAt,url,headRefName,baseRefName,mergeable
}

# ═══════════════════════════════════════════════════════════════
# Comments
# ═══════════════════════════════════════════════════════════════

# github_get_comments: Get comments for issue or PR
#
# Arguments:
#   $1 - type (required): issue|pr
#   $2 - number (required): Issue or PR number
#
# Returns:
#   0 - Success
#   1 - Error
#
# Outputs:
#   stdout: JSON array of comments
github_get_comments() {
  local type="${1:?github_get_comments requires type (issue|pr)}"
  local number="${2:?github_get_comments requires number}"

  github_check_auth || return 1
  github_in_repo || return 1

  log_debug "github" "Getting comments" "Type: $type, #$number"

  case "$type" in
    issue)
      github_get_issue "$number" | jq '.comments'
      ;;
    pr)
      github_get_pr "$number" | jq '.comments'
      ;;
    *)
      error_msg "Unknown type: $type. Use: issue|pr"
      return 1
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════════
# AI Context Generation
# ═══════════════════════════════════════════════════════════════

# github_create_context_summary: Create AI-ready context from GitHub data
#
# Description:
#   Generates a markdown-formatted summary of current GitHub context
#   for use with AI queries. Includes repo info, branch status,
#   open issues, PRs, and recent activity.
#
# Returns:
#   0 - Success
#   1 - Error
#
# Outputs:
#   stdout: Markdown-formatted context summary
github_create_context_summary() {
  github_check_auth || return 1
  github_in_repo || return 1

  log_debug "github" "Creating context summary"

  # Get all data
  local repo_info branch_info open_issues open_prs
  repo_info=$(github_get_repo_info) || return 1
  branch_info=$(github_get_current_branch_info) || return 1
  open_issues=$(github_list_issues "open" 5) || return 1
  open_prs=$(github_list_prs "open" 5) || return 1

  # Build markdown summary
  cat <<EOF
# GitHub Context

## Repository
- **Name:** $(echo "$repo_info" | jq -r '.owner.login + "/" + .name')
- **Description:** $(echo "$repo_info" | jq -r '.description // "N/A"')
- **Private:** $(echo "$repo_info" | jq -r '.isPrivate')
- **Default Branch:** $(echo "$repo_info" | jq -r '.defaultBranchRef.name')
- **URL:** $(echo "$repo_info" | jq -r '.url')

## Current Branch
- **Branch:** $(echo "$branch_info" | jq -r '.branch')
- **Tracking:** $(echo "$branch_info" | jq -r '.tracking // "none"')
- **Pull Requests:**
$(echo "$branch_info" | jq -r '.pull_requests[] | "  - #\(.number): \(.title) (\(.state))"' || echo "  None")

## Open Issues (Recent 5)
$(echo "$open_issues" | jq -r '.[] | "- #\(.number): \(.title)"' || echo "None")

## Open Pull Requests (Recent 5)
$(echo "$open_prs" | jq -r '.[] | "- #\(.number): \(.title) (by @\(.author.login))"' || echo "None")
EOF
}

# ═══════════════════════════════════════════════════════════════
# Exports
# ═══════════════════════════════════════════════════════════════

export -f github_check_gh_installed
export -f github_check_auth
export -f github_in_repo
export -f github_get_repo_info
export -f github_get_current_branch_info
export -f github_list_issues
export -f github_get_issue
export -f github_list_prs
export -f github_get_pr
export -f github_get_comments
export -f github_create_context_summary

# Mark module as loaded
readonly _HARM_GITHUB_LOADED=1
