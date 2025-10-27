#!/usr/bin/env bash
# qa-runner.sh - Interactive Manual QA Test Runner
# Guides testers through the QA checklist interactively

set -Eeuo pipefail
IFS=$'\n\t'

# ═══════════════════════════════════════════════════════════════
# Colors and Formatting
# ═══════════════════════════════════════════════════════════════

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly RESET='\033[0m'

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
QA_CHECKLIST="$PROJECT_ROOT/docs/QA_CHECKLIST.md"
QA_LOG_DIR="${QA_LOG_DIR:-$HOME/.harm-cli/qa-logs}"
QA_SESSION_LOG="$QA_LOG_DIR/qa-session-$(date '+%Y%m%d-%H%M%S').log"

mkdir -p "$QA_LOG_DIR"

# ═══════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════

log_result() {
  local category="$1"
  local test_name="$2"
  local result="$3" # PASS/FAIL/SKIP
  local notes="${4:-}"

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$result] $category :: $test_name :: $notes" >>"$QA_SESSION_LOG"
}

print_header() {
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════${RESET}"
  echo -e "${BOLD}$1${RESET}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════${RESET}"
  echo ""
}

print_test() {
  local number="$1"
  local description="$2"
  echo -e "${YELLOW}[$number]${RESET} $description"
}

print_command() {
  local cmd="$1"
  echo -e "  ${BLUE}Command:${RESET} ${BOLD}$cmd${RESET}"
}

print_expected() {
  local expected="$1"
  echo -e "  ${GREEN}Expected:${RESET} $expected"
}

prompt_result() {
  echo "" >&2
  echo -n "Result? [p=pass, f=fail, s=skip, q=quit]: " >&2
  read -r result
  case "$result" in
    p | P) echo "PASS" ;;
    f | F) echo "FAIL" ;;
    s | S) echo "SKIP" ;;
    q | Q) echo "QUIT" ;;
    *) echo "SKIP" ;;
  esac
}

prompt_notes() {
  echo -n "Notes (optional, Enter to skip): " >&2
  read -r notes
  echo "$notes"
}

# ═══════════════════════════════════════════════════════════════
# Test Categories
# ═══════════════════════════════════════════════════════════════

# Helper function to reduce repetition
run_test() {
  local test_num="$1"
  local description="$2"
  local command="$3"
  local expected="$4"
  local category="$5"
  local test_name="$6"

  print_test "$test_num" "$description" >&2
  print_command "$command" >&2
  print_expected "$expected" >&2

  # Copy command to clipboard (macOS)
  if command -v pbcopy >/dev/null 2>&1; then
    echo "$command" | pbcopy
    echo -e "  ${GREEN}✓ Copied to clipboard${RESET}" >&2
  fi

  result=$(prompt_result)
  notes=$(prompt_notes)
  log_result "$category" "$test_name" "$result" "$notes"
  echo "$result"
}

run_core_tests() {
  print_header "Category 1: Core Commands (12 tests)"

  local category="Core Commands"
  local tests_passed=0
  local tests_failed=0
  local tests_skipped=0

  # Test 1.1: Version command
  result=$(run_test "1.1" "harm-cli version - Shows version in text format" \
    "harm-cli version" "Version number, commit hash, build info" \
    "$category" "version text format")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 1.2: Version JSON
  result=$(run_test "1.2" "harm-cli version --format json - Shows version in JSON" \
    "harm-cli version --format json" "Valid JSON with version fields" \
    "$category" "version JSON format")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 1.3: Version short flag
  result=$(run_test "1.3" "harm-cli -v - Short flag works" \
    "harm-cli -v" "Same as 'harm-cli version'" \
    "$category" "version -v flag")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 1.4: Help command
  result=$(run_test "1.4" "harm-cli help - Shows general help" \
    "harm-cli help" "Command list, usage examples" \
    "$category" "help command")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 1.5: Help flag
  result=$(run_test "1.5" "harm-cli --help - Flag version works" \
    "harm-cli --help" "Same as 'harm-cli help'" \
    "$category" "help --help flag")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 1.6: Help short flag
  result=$(run_test "1.6" "harm-cli -h - Short flag works" \
    "harm-cli -h" "Same as 'harm-cli help'" \
    "$category" "help -h flag")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 1.7: Doctor command
  result=$(run_test "1.7" "harm-cli doctor - Checks system health" \
    "harm-cli doctor" "Dependency check results" \
    "$category" "doctor command")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 1.8: Doctor JSON
  result=$(run_test "1.8" "harm-cli doctor --format json - JSON output" \
    "harm-cli doctor --format json" "Valid JSON with health status" \
    "$category" "doctor JSON format")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 1.9: Init command
  result=$(run_test "1.9" "harm-cli init - Initialize in current shell" \
    "harm-cli init" "Source command for shell integration" \
    "$category" "init command")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 1.10: Quiet mode
  result=$(run_test "1.10" "harm-cli -q version - Quiet mode suppresses output" \
    "harm-cli -q version" "No non-error output" \
    "$category" "quiet mode")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 1.11: Debug mode
  result=$(run_test "1.11" "harm-cli -d doctor - Debug mode shows extra logging" \
    "harm-cli -d doctor" "Debug log entries visible" \
    "$category" "debug mode")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 1.12: Format env var
  result=$(run_test "1.12" "HARM_CLI_FORMAT=json harm-cli version - Env var format" \
    "HARM_CLI_FORMAT=json harm-cli version" "JSON output" \
    "$category" "format env var")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  echo ""
  echo -e "${GREEN}Passed: $tests_passed${RESET} | ${RED}Failed: $tests_failed${RESET} | ${YELLOW}Skipped: $tests_skipped${RESET}"

  return 0
}

run_work_tests() {
  print_header "Category 2: Work Session Management (6 tests)"

  local category="Work Sessions"
  local tests_passed=0
  local tests_failed=0
  local tests_skipped=0

  # Test 2.1: Start work session
  result=$(run_test "2.1" "harm-cli work start 'Phase 3 testing' - Start new session" \
    "harm-cli work start 'Phase 3 testing'" "Session started, confirmation message" \
    "$category" "work start")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 2.2: Show work status
  result=$(run_test "2.2" "harm-cli work status - Show current session" \
    "harm-cli work status" "Active session details or 'No active session'" \
    "$category" "work status")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 2.3: Work default command
  result=$(run_test "2.3" "harm-cli work - Default command is status" \
    "harm-cli work" "Same as 'work status'" \
    "$category" "work default")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 2.4: Stop work session
  result=$(run_test "2.4" "harm-cli work stop - Stop current session" \
    "harm-cli work stop" "Session stopped, duration shown" \
    "$category" "work stop")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 2.5: Work stats command
  result=$(run_test "2.5" "harm-cli work stats - Show work statistics" \
    "harm-cli work stats" "Work session statistics displayed" \
    "$category" "work stats")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 2.6: Work JSON output
  result=$(run_test "2.6" "harm-cli work status --format json - JSON format" \
    "harm-cli work status --format json" "Valid JSON with session data" \
    "$category" "work JSON")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  echo ""
  echo -e "${GREEN}Passed: $tests_passed${RESET} | ${RED}Failed: $tests_failed${RESET} | ${YELLOW}Skipped: $tests_skipped${RESET}"

  return 0
}

run_goal_tests() {
  print_header "Category 3: Goal Tracking (10 tests)"

  local category="Goal Tracking"
  local tests_passed=0
  local tests_failed=0
  local tests_skipped=0

  # Test 3.1: Set goal with time
  result=$(run_test "3.1" "harm-cli goal set 'Complete Phase 3' 4h - Set with time" \
    "harm-cli goal set 'Complete Phase 3' 4h" "Goal created, confirmation shown" \
    "$category" "goal set with time")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 3.2: Set goal minutes format
  result=$(run_test "3.2" "harm-cli goal set 'Quick task' 30m - Minutes format" \
    "harm-cli goal set 'Quick task' 30m" "Goal created with 30 minutes" \
    "$category" "goal set minutes")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 3.3: Set goal combined format
  result=$(run_test "3.3" "harm-cli goal set 'Complex task' 2h30m - Combined format" \
    "harm-cli goal set 'Complex task' 2h30m" "Goal created with 2.5 hours" \
    "$category" "goal set combined")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 3.4: Set goal plain integer
  result=$(run_test "3.4" "harm-cli goal set 'Test task' 90 - Plain integer (minutes)" \
    "harm-cli goal set 'Test task' 90" "Goal created with 90 minutes" \
    "$category" "goal set integer")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 3.5: Show goals
  result=$(run_test "3.5" "harm-cli goal show - List all goals" \
    "harm-cli goal show" "Numbered list with progress percentages" \
    "$category" "goal show")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 3.6: Goal default command
  result=$(run_test "3.6" "harm-cli goal - Default command is show" \
    "harm-cli goal" "Same as 'goal show'" \
    "$category" "goal default")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 3.7: Goal JSON output
  result=$(run_test "3.7" "harm-cli goal show --format json - JSON output" \
    "harm-cli goal show --format json" "Valid JSON array of goals" \
    "$category" "goal JSON")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 3.8: Update progress
  result=$(run_test "3.8" "harm-cli goal progress 1 50 - Set to 50%" \
    "harm-cli goal progress 1 50" "Goal #1 updated to 50%" \
    "$category" "goal progress")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 3.9: Complete goal
  result=$(run_test "3.9" "harm-cli goal complete 1 - Mark goal complete" \
    "harm-cli goal complete 1" "Goal #1 at 100%, marked completed" \
    "$category" "goal complete")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 3.10: Clear goals
  result=$(run_test "3.10" "harm-cli goal clear --force - Clear all goals" \
    "harm-cli goal clear --force" "All goals deleted" \
    "$category" "goal clear")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  echo ""
  echo -e "${GREEN}Passed: $tests_passed${RESET} | ${RED}Failed: $tests_failed${RESET} | ${YELLOW}Skipped: $tests_skipped${RESET}"

  return 0
}

run_ai_tests() {
  print_header "Category 4: AI Assistant (11 tests)"

  local category="AI Assistant"
  local tests_passed=0
  local tests_failed=0
  local tests_skipped=0

  # Test 4.1: Simple query
  result=$(run_test "4.1" "harm-cli ai 'What is the capital of France?' - Simple query" \
    "harm-cli ai 'What is the capital of France?'" "AI response" \
    "$category" "ai simple query")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 4.2: Technical query
  result=$(run_test "4.2" "harm-cli ai 'How do I use grep?' - Technical query" \
    "harm-cli ai 'How do I use grep?'" "Helpful AI response" \
    "$category" "ai technical query")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 4.3: Context-aware query
  result=$(run_test "4.3" "harm-cli ai --context 'Explain this codebase' - With context" \
    "harm-cli ai --context 'Explain this codebase'" "AI response with project context" \
    "$category" "ai context query")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 4.4: No cache
  result=$(run_test "4.4" "harm-cli ai --no-cache 'Current time?' - Bypass cache" \
    "harm-cli ai --no-cache 'Current time?'" "Fresh AI response" \
    "$category" "ai no cache")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 4.5: Code review staged
  result=$(run_test "4.5" "harm-cli ai review - Review staged changes" \
    "harm-cli ai review" "AI review of git staged files" \
    "$category" "ai review staged")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 4.6: Code review unstaged
  result=$(run_test "4.6" "harm-cli ai review --unstaged - Review unstaged" \
    "harm-cli ai review --unstaged" "AI review of working directory changes" \
    "$category" "ai review unstaged")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 4.7: Explain error
  result=$(run_test "4.7" "harm-cli ai explain-error - Explain last error" \
    "harm-cli ai explain-error" "AI explanation of most recent log error" \
    "$category" "ai explain error")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 4.8: Daily insights
  result=$(run_test "4.8" "harm-cli ai daily - Today's insights" \
    "harm-cli ai daily" "Productivity summary for today" \
    "$category" "ai daily")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 4.9: Yesterday's insights
  result=$(run_test "4.9" "harm-cli ai daily --yesterday - Yesterday's insights" \
    "harm-cli ai daily --yesterday" "Productivity summary for yesterday" \
    "$category" "ai daily yesterday")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 4.10: Weekly insights
  result=$(run_test "4.10" "harm-cli ai daily --week - Weekly insights" \
    "harm-cli ai daily --week" "Week summary" \
    "$category" "ai daily week")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 4.11: Setup
  result=$(run_test "4.11" "harm-cli ai --setup - Configure API key" \
    "harm-cli ai --setup" "Interactive API key setup" \
    "$category" "ai setup")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  echo ""
  echo -e "${GREEN}Passed: $tests_passed${RESET} | ${RED}Failed: $tests_failed${RESET} | ${YELLOW}Skipped: $tests_skipped${RESET}"

  return 0
}

run_git_tests() {
  print_header "Category 5: Git Workflows (3 tests)"

  local category="Git Workflows"
  local tests_passed=0
  local tests_failed=0
  local tests_skipped=0

  # Test 5.1: Git status
  result=$(run_test "5.1" "harm-cli git status - Git status with AI" \
    "harm-cli git status" "Git status with AI suggestions" \
    "$category" "git status")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 5.2: Commit message generation
  result=$(run_test "5.2" "harm-cli git commit-msg - Generate message" \
    "harm-cli git commit-msg" "AI-generated commit message" \
    "$category" "git commit-msg")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 5.3: Full workflow integration
  result=$(run_test "5.3" "Full workflow: msg=\$(harm-cli git commit-msg) && git commit -m \"\$msg\"" \
    "msg=\$(harm-cli git commit-msg) && git commit -m \"\$msg\"" "Commits with AI message" \
    "$category" "git workflow")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  echo ""
  echo -e "${GREEN}Passed: $tests_passed${RESET} | ${RED}Failed: $tests_failed${RESET} | ${YELLOW}Skipped: $tests_skipped${RESET}"

  return 0
}

run_proj_tests() {
  print_header "Category 6: Project Management (8 tests)"

  local category="Project Management"
  local tests_passed=0
  local tests_failed=0
  local tests_skipped=0

  # Test 6.1: List projects
  result=$(run_test "6.1" "harm-cli proj list - Show all projects" \
    "harm-cli proj list" "List of registered projects" \
    "$category" "proj list")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 6.2: List projects JSON
  result=$(run_test "6.2" "harm-cli proj list --format json - JSON output" \
    "harm-cli proj list --format json" "Valid JSON array" \
    "$category" "proj list JSON")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 6.3: Add current directory
  result=$(run_test "6.3" "harm-cli proj add . - Add current directory" \
    "harm-cli proj add ." "Current dir added to registry" \
    "$category" "proj add current")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 6.4: Add specific path
  result=$(run_test "6.4" "harm-cli proj add ~/myapp - Add specific path" \
    "harm-cli proj add ~/myapp" "Path added to registry" \
    "$category" "proj add path")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 6.5: Add with name
  result=$(run_test "6.5" "harm-cli proj add ~/myapp 'My App' - Add with name" \
    "harm-cli proj add ~/myapp 'My App'" "Project added with custom name" \
    "$category" "proj add named")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 6.6: Remove project
  result=$(run_test "6.6" "harm-cli proj remove myapp - Remove project" \
    "harm-cli proj remove myapp" "Project removed from registry" \
    "$category" "proj remove")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 6.7: Switch project
  result=$(run_test "6.7" "harm-cli proj switch myapp - Switch to project" \
    "harm-cli proj switch myapp" "CD command output" \
    "$category" "proj switch")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 6.8: Switch project eval
  result=$(run_test "6.8" "eval \"\$(harm-cli proj switch myapp)\" - Actually switch" \
    "eval \"\$(harm-cli proj switch myapp)\"" "Directory changed" \
    "$category" "proj switch eval")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  echo ""
  echo -e "${GREEN}Passed: $tests_passed${RESET} | ${RED}Failed: $tests_failed${RESET} | ${YELLOW}Skipped: $tests_skipped${RESET}"

  return 0
}

run_docker_tests() {
  print_header "Category 7: Docker Management (8 tests)"

  local category="Docker Management"
  local tests_passed=0
  local tests_failed=0
  local tests_skipped=0

  # Test 7.1: Docker status
  result=$(run_test "7.1" "harm-cli docker status - Show status" \
    "harm-cli docker status" "Running containers, service health" \
    "$category" "docker status")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 7.2: Docker default command
  result=$(run_test "7.2" "harm-cli docker - Default is status" \
    "harm-cli docker" "Same as 'docker status'" \
    "$category" "docker default")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 7.3: Docker up
  result=$(run_test "7.3" "harm-cli docker up - Start all services" \
    "harm-cli docker up" "Containers started in detached mode" \
    "$category" "docker up")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 7.4: Docker up specific services
  result=$(run_test "7.4" "harm-cli docker up backend database - Start specific" \
    "harm-cli docker up backend database" "Only specified services started" \
    "$category" "docker up specific")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 7.5: Docker down
  result=$(run_test "7.5" "harm-cli docker down - Stop all services" \
    "harm-cli docker down" "Containers stopped and removed" \
    "$category" "docker down")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 7.6: Docker logs
  result=$(run_test "7.6" "harm-cli docker logs backend - Follow service logs" \
    "harm-cli docker logs backend" "Streaming logs for backend service" \
    "$category" "docker logs")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 7.7: Docker shell
  result=$(run_test "7.7" "harm-cli docker shell backend - Open shell" \
    "harm-cli docker shell backend" "Interactive shell in container" \
    "$category" "docker shell")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 7.8: Docker health
  result=$(run_test "7.8" "harm-cli docker health - Docker environment health" \
    "harm-cli docker health" "Docker daemon status, resource usage" \
    "$category" "docker health")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  echo ""
  echo -e "${GREEN}Passed: $tests_passed${RESET} | ${RED}Failed: $tests_failed${RESET} | ${YELLOW}Skipped: $tests_skipped${RESET}"

  return 0
}

run_python_tests() {
  print_header "Category 8: Python Development (6 tests)"

  local category="Python Development"
  local tests_passed=0
  local tests_failed=0
  local tests_skipped=0

  # Test 8.1: Python status
  result=$(run_test "8.1" "harm-cli python status - Show Python env" \
    "harm-cli python status" "Python version, venv status, packages" \
    "$category" "python status")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 8.2: Python test
  result=$(run_test "8.2" "harm-cli python test - Run test suite" \
    "harm-cli python test" "Pytest/unittest runs" \
    "$category" "python test")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 8.3: Python test verbose
  result=$(run_test "8.3" "harm-cli python test -v - Verbose output" \
    "harm-cli python test -v" "Detailed test output" \
    "$category" "python test verbose")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 8.4: Python lint
  result=$(run_test "8.4" "harm-cli python lint - Run linters" \
    "harm-cli python lint" "Ruff/flake8 output" \
    "$category" "python lint")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 8.5: Python format
  result=$(run_test "8.5" "harm-cli python format - Format code" \
    "harm-cli python format" "Code formatted with ruff/black" \
    "$category" "python format")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 8.6: Python format check
  result=$(run_test "8.6" "harm-cli python format --check - Check only" \
    "harm-cli python format --check" "Report formatting issues without changes" \
    "$category" "python format check")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  echo ""
  echo -e "${GREEN}Passed: $tests_passed${RESET} | ${RED}Failed: $tests_failed${RESET} | ${YELLOW}Skipped: $tests_skipped${RESET}"

  return 0
}

run_gcloud_tests() {
  print_header "Category 9: Google Cloud SDK (2 tests)"

  local category="Google Cloud"
  local tests_passed=0
  local tests_failed=0
  local tests_skipped=0

  # Test 9.1: GCloud status
  result=$(run_test "9.1" "harm-cli gcloud status - Show gcloud config" \
    "harm-cli gcloud status" "Active project, account, config" \
    "$category" "gcloud status")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 9.2: GCloud JSON
  result=$(run_test "9.2" "harm-cli gcloud status --format json - JSON output" \
    "harm-cli gcloud status --format json" "Valid JSON with gcloud info" \
    "$category" "gcloud JSON")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  echo ""
  echo -e "${GREEN}Passed: $tests_passed${RESET} | ${RED}Failed: $tests_failed${RESET} | ${YELLOW}Skipped: $tests_skipped${RESET}"

  return 0
}

run_health_tests() {
  print_header "Category 10: Health Checks (3 tests)"

  local category="Health Checks"
  local tests_passed=0
  local tests_failed=0
  local tests_skipped=0

  # Test 10.1: Health check
  result=$(run_test "10.1" "harm-cli health - Run comprehensive health check" \
    "harm-cli health" "System dependencies, project health, warnings" \
    "$category" "health check")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 10.2: Health JSON
  result=$(run_test "10.2" "harm-cli health --format json - JSON health report" \
    "harm-cli health --format json" "Structured health data" \
    "$category" "health JSON")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 10.3: Health verbose
  result=$(run_test "10.3" "harm-cli health --verbose - Detailed health info" \
    "harm-cli health --verbose" "Extra diagnostic information" \
    "$category" "health verbose")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  echo ""
  echo -e "${GREEN}Passed: $tests_passed${RESET} | ${RED}Failed: $tests_failed${RESET} | ${YELLOW}Skipped: $tests_skipped${RESET}"

  return 0
}

run_safety_tests() {
  print_header "Category 11: Safety Wrappers (6 tests)"

  local category="Safety Wrappers"
  local tests_passed=0
  local tests_failed=0
  local tests_skipped=0

  # Test 11.1: Safe rm
  result=$(run_test "11.1" "harm-cli safe rm testfile.txt - Delete with confirmation" \
    "harm-cli safe rm testfile.txt" "Interactive confirmation, file deleted" \
    "$category" "safe rm")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 11.2: Safe docker-prune
  result=$(run_test "11.2" "harm-cli safe docker-prune - Clean Docker with confirmation" \
    "harm-cli safe docker-prune" "Interactive confirmation, cleanup summary" \
    "$category" "safe docker-prune")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 11.3: Safe git-reset
  result=$(run_test "11.3" "harm-cli safe git-reset - Reset with backup" \
    "harm-cli safe git-reset" "Automatic backup created, reset performed" \
    "$category" "safe git-reset")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 11.4: Safe git-reset to ref
  result=$(run_test "11.4" "harm-cli safe git-reset HEAD~1 - Reset to specific ref" \
    "harm-cli safe git-reset HEAD~1" "Backup created, reset to ref" \
    "$category" "safe git-reset ref")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 11.5: Safe git-reset hard
  result=$(run_test "11.5" "harm-cli safe git-reset --hard - Hard reset with backup" \
    "harm-cli safe git-reset --hard" "Backup created, hard reset performed" \
    "$category" "safe git-reset hard")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 11.6: Backup restore
  result=$(run_test "11.6" "Verify backup restore works - Restore from backup" \
    "Restore from git-reset backup" "Can restore from backup after reset" \
    "$category" "backup restore")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  echo ""
  echo -e "${GREEN}Passed: $tests_passed${RESET} | ${RED}Failed: $tests_failed${RESET} | ${YELLOW}Skipped: $tests_skipped${RESET}"

  return 0
}

run_markdown_tests() {
  print_header "Category 12: Markdown Rendering (4 tests)"

  local category="Markdown Rendering"
  local tests_passed=0
  local tests_failed=0
  local tests_skipped=0

  # Test 12.1: Render file
  result=$(run_test "12.1" "harm-cli md README.md - Render file" \
    "harm-cli md README.md" "Pretty-printed markdown (via glow/bat)" \
    "$category" "md render file")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 12.2: View command
  result=$(run_test "12.2" "harm-cli md view README.md - Explicit view command" \
    "harm-cli md view README.md" "Same as 'harm-cli md README.md'" \
    "$category" "md view")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 12.3: Pipe input
  result=$(run_test "12.3" "echo '# Test' | harm-cli md - Render from stdin" \
    "echo '# Test' | harm-cli md" "Rendered markdown from pipe" \
    "$category" "md pipe")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 12.4: Pipe file
  result=$(run_test "12.4" "cat README.md | harm-cli md - Pipe file contents" \
    "cat README.md | harm-cli md" "Rendered markdown" \
    "$category" "md pipe file")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  echo ""
  echo -e "${GREEN}Passed: $tests_passed${RESET} | ${RED}Failed: $tests_failed${RESET} | ${YELLOW}Skipped: $tests_skipped${RESET}"

  return 0
}

run_log_tests() {
  print_header "Category 13: Log Streaming (3 tests)"

  local category="Log Streaming"
  local tests_passed=0
  local tests_failed=0
  local tests_skipped=0

  # Test 13.1: View logs
  result=$(run_test "13.1" "harm-cli log view - Show recent logs" \
    "harm-cli log view" "Recent log entries displayed" \
    "$category" "log view")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 13.2: Tail logs
  result=$(run_test "13.2" "harm-cli log tail - Follow logs in real-time" \
    "harm-cli log tail" "Streaming log output" \
    "$category" "log tail")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 13.3: Filter logs
  result=$(run_test "13.3" "harm-cli log view --level ERROR - Filter by level" \
    "harm-cli log view --level ERROR" "Only ERROR logs shown" \
    "$category" "log filter")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  echo ""
  echo -e "${GREEN}Passed: $tests_passed${RESET} | ${RED}Failed: $tests_failed${RESET} | ${YELLOW}Skipped: $tests_skipped${RESET}"

  return 0
}

run_just_tests() {
  print_header "Category 14: Development Tools (just commands) (15 tests)"

  local category="Development Tools"
  local tests_passed=0
  local tests_failed=0
  local tests_skipped=0

  # Test 14.1: Just help
  result=$(run_test "14.1" "just help - Show all commands" \
    "just help" "List of all just recipes" \
    "$category" "just help")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 14.2: Just info
  result=$(run_test "14.2" "just info - Project information" \
    "just info" "Stats, dependencies, project info" \
    "$category" "just info")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 14.3: Just fmt
  result=$(run_test "14.3" "just fmt - Format all shell scripts" \
    "just fmt" "Scripts formatted with shfmt" \
    "$category" "just fmt")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 14.4: Just lint
  result=$(run_test "14.4" "just lint - Lint with shellcheck" \
    "just lint" "Shellcheck errors/warnings" \
    "$category" "just lint")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 14.5: Just spell
  result=$(run_test "14.5" "just spell - Check spelling" \
    "just spell" "Codespell output" \
    "$category" "just spell")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 14.6: Just test
  result=$(run_test "14.6" "just test - Run all tests (bash + zsh)" \
    "just test" "Full test suite passes" \
    "$category" "just test")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 14.7: Just test-bash
  result=$(run_test "14.7" "just test-bash - Bash-only tests" \
    "just test-bash" "Tests run with bash 5+" \
    "$category" "just test-bash")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 14.8: Just test-zsh
  result=$(run_test "14.8" "just test-zsh - Zsh-only tests" \
    "just test-zsh" "Tests run with zsh" \
    "$category" "just test-zsh")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 14.9: Just test-file
  result=$(run_test "14.9" "just test-file spec/goals_spec.sh - Run specific test" \
    "just test-file spec/goals_spec.sh" "Single test file runs" \
    "$category" "just test-file")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 14.10: Just test-watch
  result=$(run_test "14.10" "just test-watch - TDD watch mode" \
    "just test-watch" "Tests run continuously on file changes" \
    "$category" "just test-watch")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 14.11: Just coverage
  result=$(run_test "14.11" "just coverage - Coverage report" \
    "just coverage" "Test coverage statistics" \
    "$category" "just coverage")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 14.12: Just ci
  result=$(run_test "14.12" "just ci - Full CI pipeline" \
    "just ci" "format + lint + test all pass" \
    "$category" "just ci")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 14.13: Just pre-commit
  result=$(run_test "14.13" "just pre-commit - Run pre-commit hooks" \
    "just pre-commit" "All hooks pass" \
    "$category" "just pre-commit")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 14.14: Just pre-push
  result=$(run_test "14.14" "just pre-push - CI before push" \
    "just pre-push" "Full validation before push" \
    "$category" "just pre-push")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  # Test 14.15: Just clean
  result=$(run_test "14.15" "just clean - Clean artifacts" \
    "just clean" "Build artifacts removed" \
    "$category" "just clean")
  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;; FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;; QUIT) return 1 ;;
  esac

  echo ""
  echo -e "${GREEN}Passed: $tests_passed${RESET} | ${RED}Failed: $tests_failed${RESET} | ${YELLOW}Skipped: $tests_skipped${RESET}"

  return 0
}

# ═══════════════════════════════════════════════════════════════
# Main Menu
# ═══════════════════════════════════════════════════════════════

show_menu() {
  clear
  echo -e "${BOLD}╔═══════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}║              harm-cli QA Interactive Test Runner             ║${RESET}"
  echo -e "${BOLD}╚═══════════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo "Session log: $QA_SESSION_LOG"
  echo ""
  echo "Select test category to run:"
  echo ""
  echo "  1.  Core Commands (12 tests)"
  echo "  2.  Work Session Management (6 tests)"
  echo "  3.  Goal Tracking (10 tests)"
  echo "  4.  AI Assistant (11 tests)"
  echo "  5.  Git Workflows (3 tests)"
  echo "  6.  Project Management (8 tests)"
  echo "  7.  Docker Management (8 tests)"
  echo "  8.  Python Development (6 tests)"
  echo "  9.  Google Cloud SDK (2 tests)"
  echo "  10. Health Checks (3 tests)"
  echo "  11. Safety Wrappers (6 tests)"
  echo "  12. Markdown Rendering (4 tests)"
  echo "  13. Log Streaming (3 tests)"
  echo "  14. Development Tools/Just (15 tests)"
  echo ""
  echo "  a.  All Tests (95 tests)"
  echo ""
  echo "  r.  View test results"
  echo "  q.  Quit"
  echo ""
  echo -n "Choice: "
}

view_results() {
  if [[ ! -f "$QA_SESSION_LOG" ]]; then
    echo "No test results yet."
    return
  fi

  echo ""
  echo -e "${BOLD}Test Results Summary${RESET}"
  echo "═══════════════════════════════════════════════════════════════"

  local passed=$(grep -c "\[PASS\]" "$QA_SESSION_LOG" || echo "0")
  local failed=$(grep -c "\[FAIL\]" "$QA_SESSION_LOG" || echo "0")
  local skipped=$(grep -c "\[SKIP\]" "$QA_SESSION_LOG" || echo "0")
  local total=$((passed + failed + skipped))

  echo ""
  echo -e "${GREEN}Passed:${RESET}  $passed"
  echo -e "${RED}Failed:${RESET}  $failed"
  echo -e "${YELLOW}Skipped:${RESET} $skipped"
  echo -e "${BOLD}Total:${RESET}   $total"
  echo ""

  if [[ $failed -gt 0 ]]; then
    echo -e "${RED}Failed Tests:${RESET}"
    grep "\[FAIL\]" "$QA_SESSION_LOG" | sed 's/^/  /'
    echo ""
  fi

  echo "Full log: $QA_SESSION_LOG"
  echo ""
  echo "Press Enter to continue..."
  read -r
}

# ═══════════════════════════════════════════════════════════════
# Main Loop
# ═══════════════════════════════════════════════════════════════

main() {
  # Check if QA checklist exists
  if [[ ! -f "$QA_CHECKLIST" ]]; then
    echo -e "${RED}Error: QA checklist not found at $QA_CHECKLIST${RESET}"
    exit 1
  fi

  while true; do
    show_menu
    read -r choice

    case "$choice" in
      1) run_core_tests || continue ;;
      2) run_work_tests || continue ;;
      3) run_goal_tests || continue ;;
      4) run_ai_tests || continue ;;
      5) run_git_tests || continue ;;
      6) run_proj_tests || continue ;;
      7) run_docker_tests || continue ;;
      8) run_python_tests || continue ;;
      9) run_gcloud_tests || continue ;;
      10) run_health_tests || continue ;;
      11) run_safety_tests || continue ;;
      12) run_markdown_tests || continue ;;
      13) run_log_tests || continue ;;
      14) run_just_tests || continue ;;
      a | A)
        echo "Running all tests..."
        run_core_tests && run_work_tests && run_goal_tests && \
        run_ai_tests && run_git_tests && run_proj_tests && \
        run_docker_tests && run_python_tests && run_gcloud_tests && \
        run_health_tests && run_safety_tests && run_markdown_tests && \
        run_log_tests && run_just_tests
        ;;
      r | R) view_results ;;
      q | Q)
        echo ""
        echo "QA session complete. Results saved to:"
        echo "  $QA_SESSION_LOG"
        echo ""
        exit 0
        ;;
      *)
        echo "Invalid choice. Press Enter to continue..."
        read -r
        ;;
    esac

    echo ""
    echo "Press Enter to return to menu..."
    read -r
  done
}

# Run main function
main "$@"
