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
  echo ""
  echo -n "Result? [p=pass, f=fail, s=skip, q=quit]: "
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
  echo -n "Notes (optional, Enter to skip): "
  read -r notes
  echo "$notes"
}

# ═══════════════════════════════════════════════════════════════
# Test Categories
# ═══════════════════════════════════════════════════════════════

run_core_tests() {
  print_header "Category 1: Core Commands (12 tests)"

  local category="Core Commands"
  local tests_passed=0
  local tests_failed=0
  local tests_skipped=0

  # Test 1.1: Version command
  print_test "1.1" "harm-cli version - Shows version in text format"
  print_command "harm-cli version"
  print_expected "Version number, commit hash, build info"
  result=$(prompt_result)
  notes=$(prompt_notes)
  log_result "$category" "version text format" "$result" "$notes"

  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;;
    FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;;
    QUIT) return 1 ;;
  esac

  # Test 1.2: Version JSON
  print_test "1.2" "harm-cli version --format json - Shows version in JSON"
  print_command "harm-cli version --format json"
  print_expected "Valid JSON with version fields"
  result=$(prompt_result)
  notes=$(prompt_notes)
  log_result "$category" "version JSON format" "$result" "$notes"

  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;;
    FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;;
    QUIT) return 1 ;;
  esac

  # Test 1.3: Version short flag
  print_test "1.3" "harm-cli -v - Short flag works"
  print_command "harm-cli -v"
  print_expected "Same as 'harm-cli version'"
  result=$(prompt_result)
  notes=$(prompt_notes)
  log_result "$category" "version -v flag" "$result" "$notes"

  case "$result" in
    PASS) tests_passed=$((tests_passed + 1)) ;;
    FAIL) tests_failed=$((tests_failed + 1)) ;;
    SKIP) tests_skipped=$((tests_skipped + 1)) ;;
    QUIT) return 1 ;;
  esac

  # Additional core tests...
  # (Shortened for brevity - full implementation would include all 12)

  echo ""
  echo -e "${GREEN}Passed: $tests_passed${RESET} | ${RED}Failed: $tests_failed${RESET} | ${YELLOW}Skipped: $tests_skipped${RESET}"

  return 0
}

run_work_tests() {
  print_header "Category 2: Work Session Management (6 tests)"

  local category="Work Sessions"

  print_test "2.1" "harm-cli work start 'Phase 3 testing' - Start new session"
  print_command "harm-cli work start 'Phase 3 testing'"
  print_expected "Session started, confirmation message"
  result=$(prompt_result)
  notes=$(prompt_notes)
  log_result "$category" "work start" "$result" "$notes"

  if [[ "$result" == "QUIT" ]]; then return 1; fi

  # More work tests...
  return 0
}

run_goal_tests() {
  print_header "Category 3: Goal Tracking (10 tests)"

  local category="Goal Tracking"

  print_test "3.1" "harm-cli goal set 'Complete Phase 3' 4h - Set with time"
  print_command "harm-cli goal set 'Complete Phase 3' 4h"
  print_expected "Goal created, confirmation shown"
  result=$(prompt_result)
  notes=$(prompt_notes)
  log_result "$category" "goal set with time" "$result" "$notes"

  if [[ "$result" == "QUIT" ]]; then return 1; fi

  # More goal tests...
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
  echo "  1. Core Commands (12 tests)"
  echo "  2. Work Session Management (6 tests)"
  echo "  3. Goal Tracking (10 tests)"
  echo "  4. AI Assistant (11 tests)"
  echo "  5. Git Workflows (3 tests)"
  echo "  6. Project Management (8 tests)"
  echo "  7. Docker Management (8 tests)"
  echo "  8. Python Development (6 tests)"
  echo "  9. All Tests (108 tests)"
  echo ""
  echo "  r. View test results"
  echo "  q. Quit"
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
      4) echo "AI Assistant tests not yet implemented" ;;
      5) echo "Git Workflows tests not yet implemented" ;;
      6) echo "Project Management tests not yet implemented" ;;
      7) echo "Docker Management tests not yet implemented" ;;
      8) echo "Python Development tests not yet implemented" ;;
      9)
        echo "Running all tests..."
        run_core_tests && run_work_tests && run_goal_tests
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
