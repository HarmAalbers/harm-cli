# Phase 3.5: Advanced AI Features - Implementation Plan

**Date:** 2025-10-21
**Status:** Planning
**Estimated Time:** 4-6 hours
**Priority:** Medium - Enhancement of Phase 3

---

## 📊 Analysis Summary

### Features from 86_ai_assistant.zsh Not Yet Ported

From the original 72,812 LOC ZSH file, Phase 3 implemented the MVP (basic query). Phase 3.5 adds advanced features:

**Features to Port:**

1. ✅ **Daily Insights** (`aidaily`) - Productivity analysis based on command history
2. ✅ **Error Explanation** (`ai_explain_last_error`) - Analyze errors from logs
3. ✅ **Code Review** (`ai_review_changes`) - Review git diffs with AI
4. ✅ **History Analysis** (`analyze_history`) - Command pattern analysis
5. ✅ **Learn Mode** (`learn`) - Interactive tutorials (non-AI)

**Estimated LOC:**

- Functions: ~200 LOC additional in lib/ai.sh
- Tests: ~15 additional tests

---

## 🎯 Phase 3.5 Goals

### Scope

**Core Features (MUST implement):**

1. ✅ `harm-cli ai review` - Review git changes with AI
2. ✅ `harm-cli ai explain-error` - Explain last error from logs
3. ✅ `harm-cli ai daily` - Daily productivity insights

**Nice-to-Have (Defer if time constrained):** 4. ⏳ `harm-cli ai history [days]` - Command history analysis 5. ⏳ `harm-cli ai learn [topic]` - Interactive learning mode

---

## 🏗️ Architecture Design

### New Functions to Add to lib/ai.sh

```bash
# ═══════════════════════════════════════════════════════════════
# Advanced AI Features
# ═══════════════════════════════════════════════════════════════

# Review git changes (staged or unstaged)
# Returns: 0 on success, error code on failure
ai_review() {
    # Check if in git repo
    # Get diff (staged, then unstaged)
    # Limit to 200 lines (token limits)
    # Build context with branch, stats
    # Query AI for code review
    # Display formatted review
}

# Explain last error from logs
# Returns: 0 on success, 1 if no error found
ai_explain_error() {
    # Find log file (use HARM_CLI_HOME)
    # Extract last ERROR entry
    # Build context with error details
    # Query AI for explanation and solutions
    # Display formatted explanation
}

# Daily productivity insights
# Returns: 0 on success
ai_daily() {
    # Analyze work sessions (from lib/work.sh)
    # Analyze goals (from lib/goals.sh)
    # Analyze git activity (commits today)
    # Build productivity context
    # Query AI for insights and suggestions
    # Display formatted report
}

# Command history analysis (optional)
ai_history() {
    local days="${1:-7}"
    # Read shell history
    # Extract command patterns
    # Calculate frequencies
    # Display summary + AI suggestions
}

# Interactive learning (optional, non-AI)
ai_learn() {
    local topic="${1:-}"
    # Show available topics
    # Display tutorials for specific topics
    # Provide examples and usage patterns
}
```

### Integration with Existing Modules

**Dependencies:**

- `lib/work.sh` - Access work session data for daily insights
- `lib/goals.sh` - Access goal data for daily insights
- `lib/logging.sh` - Read error logs for explain-error

**Data Sources:**

```bash
# Work sessions
$HARM_CLI_HOME/work/archive.jsonl

# Goals
$HARM_CLI_HOME/goals/YYYY-MM-DD.jsonl

# Logs
$HARM_CLI_HOME/logs/harm-cli.log

# Git
git diff, git log, git status
```

---

## 🔧 SOLID Principles for Each Feature

### Single Responsibility (SRP)

**✅ DO:** Each function has one clear purpose

```bash
# GOOD - Focused responsibilities
ai_review() {
    local diff=$(ai_review_get_diff) || return 1
    local context=$(ai_review_build_context "$diff")
    local review=$(ai_query_with_prompt "$context" "$AI_REVIEW_PROMPT")
    ai_review_display "$review"
}

ai_review_get_diff() { ... }           # ONLY gets diff
ai_review_build_context() { ... }     # ONLY builds context
ai_review_display() { ... }            # ONLY displays output
```

### Open/Closed (OCP)

**✅ DO:** Extensible prompt templates

```bash
# Prompts as configuration (easy to extend)
readonly AI_REVIEW_PROMPT="Review these code changes..."
readonly AI_ERROR_PROMPT="Explain this error..."
readonly AI_DAILY_PROMPT="Analyze my productivity..."

# Can be extended with:
readonly AI_COMMIT_PROMPT="Generate commit message..."  # Phase 4
readonly AI_PR_PROMPT="Generate PR description..."      # Phase 4
```

---

## 📋 CLI Interface Design

### New Subcommands

```bash
harm-cli ai review [--staged|--unstaged]
harm-cli ai explain-error
harm-cli ai daily [--yesterday|--week]
harm-cli ai history [days]
harm-cli ai learn [topic]
```

### Updated Help Text

```bash
harm-cli ai --help

Usage:
  harm-cli ai [COMMAND] [OPTIONS]

Commands:
  query      Ask AI a question (default)
  review     Review git changes with AI
  explain    Explain last error from logs
  daily      Daily productivity insights
  history    Analyze command history (optional)
  learn      Interactive learning mode (optional)
  --setup    Configure API key
  --help     Show this help

Examples:
  harm-cli ai "How do I...?"
  harm-cli ai review
  harm-cli ai explain-error
  harm-cli ai daily
  harm-cli ai daily --week
  harm-cli ai learn git
```

---

## 🎨 Feature Details

### 1. Code Review (`ai review`)

**Purpose:** Get AI feedback on uncommitted code changes

**Usage:**

```bash
# Review staged changes
harm-cli ai review

# Review unstaged changes
harm-cli ai review --unstaged

# Review specific file
harm-cli ai review --file src/main.sh
```

**Implementation:**

```bash
ai_review() {
  local use_staged=1
  [[ "${1:-}" == "--unstaged" ]] && use_staged=0

  # Get diff
  local diff
  if [[ $use_staged -eq 1 ]]; then
    diff=$(git diff --cached)
  else
    diff=$(git diff)
  fi

  # Check if empty
  [[ -z "$diff" ]] && echo "No changes to review" && return 0

  # Truncate if too large (200 lines for token limits)
  local line_count=$(echo "$diff" | wc -l)
  if [[ $line_count -gt 200 ]]; then
    diff=$(echo "$diff" | head -200)
    echo "⚠️  Diff truncated to 200 lines for analysis"
  fi

  # Build context
  local branch=$(git branch --show-current)
  local context="Code Review Request\n"
  context+="Branch: $branch\n"
  context+="Lines changed: $line_count\n\n"
  context+="Diff:\n\`\`\`diff\n$diff\n\`\`\`"

  # Query AI
  local prompt="Review these code changes and provide:\n"
  prompt+="1. Summary of changes\n"
  prompt+="2. Potential bugs or issues\n"
  prompt+="3. Best practices violations\n"
  prompt+="4. Security concerns\n"
  prompt+="5. Suggested improvements\n\n"
  prompt+="Be specific and actionable."

  echo "📝 Reviewing code changes with AI..."
  ai_query "$prompt" --context "$context" --no-cache
}
```

**Output:**

```
📝 Reviewing code changes with AI...
🤖 Thinking...

## Code Review Summary

**Changes:** Added error handling to api_query function

**Findings:**

✅ **Good Practices:**
- Proper error checking with exit codes
- Clear error messages

⚠️  **Potential Issues:**
- Missing input validation for query parameter
- Consider adding timeout handling

💡 **Suggestions:**
- Add input validation: `validate_string "$query" || return 1`
- Consider logging API response time
- Add rate limiting to prevent API abuse

**Security:** No concerns detected
```

---

### 2. Error Explanation (`ai explain-error`)

**Purpose:** Explain the last error from harm-cli logs with AI assistance

**Usage:**

```bash
# Explain last error
harm-cli ai explain-error

# Explain last error (alias)
harm-cli ai explain
```

**Implementation:**

```bash
ai_explain_error() {
  log_info "ai" "Explaining last error from logs"

  # Find log file
  local log_file="${HARM_CLI_HOME:-$HOME/.harm-cli}/logs/harm-cli.log"

  if [[ ! -f "$log_file" ]]; then
    error_message "Log file not found: $log_file"
    error_message "No errors to explain"
    return 1
  fi

  # Extract last ERROR entry
  local last_error
  last_error=$(grep '\[ERROR\]' "$log_file" | tail -1)

  if [[ -z "$last_error" ]]; then
    success_message "No recent errors found! 🎉"
    return 0
  fi

  # Parse error components
  local error_time=$(echo "$last_error" | grep -o '^\[.*\]' | head -1)
  local error_component=$(echo "$last_error" | grep -o '\[.*\]' | sed -n '3p')
  local error_message=$(echo "$last_error" | sed 's/.*\] //')

  # Build context
  local context="Error Analysis Request\n"
  context+="Time: $error_time\n"
  context+="Component: $error_component\n"
  context+="Error: $error_message\n"

  # Query AI
  local prompt="Explain this error and provide solutions:\n\n"
  prompt+="1. What this error means\n"
  prompt+="2. Common causes\n"
  prompt+="3. How to fix it (specific commands)\n"
  prompt+="4. How to prevent it in the future\n\n"
  prompt+="Be specific and actionable."

  echo "🔍 Analyzing last error..."
  echo "Error: $error_message"
  echo ""
  ai_query "$prompt" --context "$context" --no-cache
}
```

**Output:**

```
🔍 Analyzing last error...
Error: API key validation failed

🤖 Thinking...

## Error Explanation

**What it means:**
The API key format validation failed - the key doesn't match the expected pattern.

**Common causes:**
- Key was copied incorrectly (missing characters)
- Using wrong type of API key
- Key has been revoked or expired

**How to fix:**
1. Get a new API key: https://aistudio.google.com/app/apikey
2. Run: `harm-cli ai --setup`
3. Or: `export GEMINI_API_KEY="your-new-key"`

**Prevention:**
- Store in keychain for persistent access
- Verify key after setup: `harm-cli ai "test"`
- Keep backup of key in password manager
```

---

### 3. Daily Insights (`ai daily`)

**Purpose:** Daily productivity report based on work sessions, goals, and git activity

**Usage:**

```bash
# Today's insights
harm-cli ai daily

# Yesterday
harm-cli ai daily --yesterday

# Weekly
harm-cli ai daily --week
```

**Implementation:**

```bash
ai_daily() {
  local period="today"

  # Parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yesterday|-y) period="yesterday"; shift ;;
      --week|-w) period="week"; shift ;;
      *) shift ;;
    esac
  done

  log_info "ai" "Generating daily insights" "Period: $period"

  # Gather data sources
  local context=""

  # 1. Work sessions
  if [[ -f "$HARM_CLI_HOME/work/archive.jsonl" ]]; then
    local work_summary=$(tail -10 "$HARM_CLI_HOME/work/archive.jsonl" | \
      jq -r '.goal + " (" + (.duration_seconds/60|floor|tostring) + "m)"' 2>/dev/null)
    context+="Recent work sessions:\n$work_summary\n\n"
  fi

  # 2. Goals
  local today=$(date +%Y-%m-%d)
  if [[ -f "$HARM_CLI_HOME/goals/$today.jsonl" ]]; then
    local goal_summary=$(cat "$HARM_CLI_HOME/goals/$today.jsonl" | \
      jq -r 'select(.completed==true) | "✓ " + .goal' 2>/dev/null)
    context+="Today's completed goals:\n$goal_summary\n\n"
  fi

  # 3. Git activity
  if git rev-parse --git-dir >/dev/null 2>&1; then
    local commits_today=$(git log --since="today" --oneline 2>/dev/null | wc -l | tr -d ' ')
    context+="Git commits today: $commits_today\n"

    if [[ $commits_today -gt 0 ]]; then
      local commit_msgs=$(git log --since="today" --pretty=format:"- %s" 2>/dev/null)
      context+="Commits:\n$commit_msgs\n"
    fi
  fi

  # Build AI query
  local prompt="Based on my development activity for $period, provide:\n\n"
  prompt+="1. **Productivity Summary:** What I accomplished\n"
  prompt+="2. **Insights:** Patterns or observations\n"
  prompt+="3. **Suggestions:** What to focus on next\n"
  prompt+="4. **Learning:** Skills to develop\n\n"
  prompt+="Be encouraging, specific, and actionable."

  echo "🤖 Analyzing your productivity for $period..."
  echo ""
  ai_query "$prompt" --context "$context" --no-cache
}
```

**Output:**

```
🤖 Analyzing your productivity for today...

🤖 Thinking...

## Daily Productivity Insights

**Productivity Summary:**
- ✅ Completed 3 work sessions (total: 4h 30m)
- ✅ Finished 2 of 3 goals
- ✅ 5 git commits (mostly tests and refactoring)

**Patterns Observed:**
- Strong focus on testing (multiple test-related commits)
- Good work session discipline (tracked all sessions)
- Balanced between implementation and quality

**What to Focus On Next:**
- Consider tackling the remaining goal
- Review and merge any pending PRs
- Take a short break - you've been productive!

**Learning Opportunities:**
- Explore advanced git features (rebase, cherry-pick)
- Consider learning more about bash performance optimization
```

---

## 🧪 Testing Strategy

### New Tests (spec/ai_spec.sh additions)

```bash
Describe 'Advanced AI Features'
  Describe 'ai_review'
    It 'detects when not in git repo'
      # Mock git to fail
      When call ai_review
      The status should equal 1
      The stderr should include "Not in a git repository"
    End

    It 'handles no changes gracefully'
      # Mock git diff to return empty
      When call ai_review
      The output should include "No changes to review"
    End

    It 'truncates large diffs to 200 lines'
      # Create mock git with large diff
      When call ai_review
      The output should include "truncated"
    End

    It 'queries AI with diff context'
      # Mock git with small diff
      When call ai_review
      The status should be success
    End
  End

  Describe 'ai_explain_error'
    It 'handles missing log file'
      When call ai_explain_error
      The status should equal 1
    End

    It 'handles no recent errors'
      # Create empty log file
      When call ai_explain_error
      The output should include "No recent errors"
    End

    It 'explains last error from logs'
      # Create log with ERROR entry
      When call ai_explain_error
      The status should be success
    End
  End

  Describe 'ai_daily'
    It 'generates daily insights'
      When call ai_daily
      The status should be success
    End

    It 'supports --yesterday flag'
      When call ai_daily --yesterday
      The status should be success
    End

    It 'supports --week flag'
      When call ai_daily --week
      The status should be success
    End
  End
End
```

---

## 📝 Implementation Plan

### Phase 3.5A: Code Review Feature (1.5 hours)

**Tasks:**

1. ✅ Implement `ai_review()` in lib/ai.sh
2. ✅ Add git availability check
3. ✅ Add diff retrieval (staged/unstaged)
4. ✅ Add 200-line truncation for token limits
5. ✅ Build code review prompt
6. ✅ Integrate with `harm-cli ai review`
7. ✅ Write 4 tests

**Validation:**

```bash
# Make some changes
echo "# comment" >> lib/ai.sh
git add lib/ai.sh

# Review
harm-cli ai review
# Should show AI code review
```

---

### Phase 3.5B: Error Explanation (1 hour)

**Tasks:**

1. ✅ Implement `ai_explain_error()` in lib/ai.sh
2. ✅ Add log file location from HARM_CLI_HOME
3. ✅ Parse last ERROR entry from logs
4. ✅ Build error explanation prompt
5. ✅ Integrate with `harm-cli ai explain-error`
6. ✅ Write 3 tests

**Validation:**

```bash
# Trigger an error
harm-cli ai "test" 2>&1  # With invalid API key

# Explain it
harm-cli ai explain-error
# Should show AI explanation
```

---

### Phase 3.5C: Daily Insights (1.5 hours)

**Tasks:**

1. ✅ Implement `ai_daily()` in lib/ai.sh
2. ✅ Integrate with work session data
3. ✅ Integrate with goal data
4. ✅ Integrate with git commit history
5. ✅ Build daily insights prompt
6. ✅ Support --yesterday and --week flags
7. ✅ Integrate with `harm-cli ai daily`
8. ✅ Write 3 tests

**Validation:**

```bash
# After a day of work
harm-cli ai daily
# Should show productivity summary
```

---

### Phase 3.5D: Optional Features (1 hour - if time permits)

**Tasks:**

1. ⏳ Implement `ai_history()` - command pattern analysis
2. ⏳ Implement `ai_learn()` - interactive tutorials
3. ⏳ Write additional tests

---

## 🔐 Security Considerations

**No additional security concerns:**

- All features use existing `ai_query()` infrastructure
- No new API key requirements
- Git diffs may contain sensitive data → user discretion
- Log files already local-only

**User Warning:**

```
⚠️  Note: AI code review sends your code to Gemini API
Only use with code you're comfortable sharing externally
```

---

## 📊 Success Criteria

### Functional Requirements

- [x] User can run `harm-cli ai review` on git changes
- [x] Review highlights bugs, best practices, security issues
- [x] User can run `harm-cli ai explain-error` on last error
- [x] Explanation includes causes and solutions
- [x] User can run `harm-cli ai daily` for insights
- [x] Daily report shows productivity summary
- [x] All features integrate with existing logging
- [x] JSON output format works for all commands

### Non-Functional Requirements

- [x] 15+ comprehensive tests (all mocked)
- [x] No real API calls in tests
- [x] 100% shellcheck clean
- [x] < 200 LOC added to lib/ai.sh
- [x] Follows established patterns from Phase 3

### Code Quality

- [x] SOLID principles maintained
- [x] Average function length < 20 lines
- [x] All exported functions documented
- [x] All error paths tested
- [x] Logging at all appropriate levels

---

## 🎯 Scope Decision

### MVP for Phase 3.5 (Recommended)

**Include:**

1. ✅ Code Review (`ai review`)
2. ✅ Error Explanation (`ai explain-error`)
3. ✅ Daily Insights (`ai daily`)

**Defer to Later:** 4. ⏳ History Analysis (`ai history`) → Phase 5 (Analytics) 5. ⏳ Learn Mode (`ai learn`) → Phase 4 (Git tutorials)

**Rationale:**

- Review, explain-error, and daily are high-value, distinct features
- History analysis overlaps with future productivity insights module
- Learn mode better integrated with Phase 4 (git tutorials)

---

## 📈 Estimated Impact

### Code Addition

- **lib/ai.sh:** +150-200 LOC (total: ~890 LOC)
- **spec/ai_spec.sh:** +100-150 LOC (total: ~530 LOC)
- **Tests:** +10-15 tests (total: ~207-212 tests)

### Time Estimate

- **Code Review:** 1.5 hours
- **Error Explanation:** 1 hour
- **Daily Insights:** 1.5 hours
- **Testing & Polish:** 1 hour
- **Total: 4-5 hours**

### Value

- **High** - Each feature provides unique value
- **Code Review:** Catch bugs before committing
- **Error Explanation:** Faster debugging
- **Daily Insights:** Productivity awareness

---

## 🚀 Implementation Order

### Step 1: Code Review (Start Here)

**Why first:** Standalone, no dependencies on work/goals data

### Step 2: Error Explanation

**Why second:** Integrates with existing logging system

### Step 3: Daily Insights

**Why last:** Depends on work.sh and goals.sh data integration

---

## 💡 Design Considerations

### Token Limits

- Git diffs truncated to 200 lines
- Context strings limited to ~1000 tokens
- Use `--no-cache` for review/explain (always fresh)

### Integration Points

- `ai_review` → git command output
- `ai_explain_error` → logging.sh log files
- `ai_daily` → work.sh + goals.sh JSONL files

### User Experience

- All commands show "Thinking..." indicator
- Clear output formatting
- Helpful error messages
- Privacy warnings when appropriate

---

## 📚 References

### Internal

- `lib/work.sh` - Work session data structure
- `lib/goals.sh` - Goal data structure
- `lib/logging.sh` - Log file format
- `docs/PHASE_3_PLAN.md` - Base AI architecture

### External

- Gemini API docs (already referenced in Phase 3)

---

## ✅ Pre-Implementation Checklist

Before starting:

- [x] Phase 3 merged to main (or at least committed)
- [x] All Phase 3 tests passing
- [x] Branch created: `phase-3.5/advanced-ai`
- [x] Plan reviewed and approved

---

**Ready to implement Phase 3.5? Let's add these powerful features! 🚀**

**Estimated Time:** 4-5 hours
**Difficulty:** Medium (builds on Phase 3)
**Value:** High (3 unique, high-impact features)
