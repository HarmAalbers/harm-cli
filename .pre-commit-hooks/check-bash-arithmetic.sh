#!/usr/bin/env bash
# check-bash-arithmetic.sh - Detect dangerous bash arithmetic patterns
#
# Detects post-increment/decrement in arithmetic expressions that can fail with set -e
# This prevents the ((var++)) bug that caused goal_show to silently fail.

set -euo pipefail

EXIT_SUCCESS=0
EXIT_FAILURE=1

# ANSI colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_file() {
  local file="$1"
  local issues_found=0

  # Skip non-bash files
  [[ "$file" =~ \.(sh|bash)$ ]] || return 0

  # Skip this hook file itself (contains patterns in documentation)
  [[ "$(basename "$file")" == "check-bash-arithmetic.sh" ]] && return 0

  # Pattern 1: Post-increment in loops ((var++))
  # Dangerous because it evaluates to 0 on first iteration, causing exit code 1 with set -e
  if grep -n '(([a-z_][a-z0-9_]*++))' "$file" 2>/dev/null; then
    echo -e "${RED}ERROR${NC}: Dangerous post-increment pattern found in $file" >&2
    echo "  Post-increment ((var++)) evaluates to 0 when var=0, causing exit code 1 with set -e" >&2
    echo -e "  ${YELLOW}Fix${NC}: Use pre-increment ((++var)) or var=\$((var + 1))" >&2
    echo "" >&2
    issues_found=$((issues_found + 1)) # Safe: arithmetic expansion, not ((++))
  fi

  # Pattern 2: Post-decrement in loops ((var--))
  if grep -n '(([a-z_][a-z0-9_]*--))' "$file" 2>/dev/null; then
    echo -e "${RED}ERROR${NC}: Dangerous post-decrement pattern found in $file" >&2
    echo "  Post-decrement ((var--)) can cause exit code 1 with set -e" >&2
    echo -e "  ${YELLOW}Fix${NC}: Use pre-decrement ((--var)) or var=\$((var - 1))" >&2
    echo "" >&2
    issues_found=$((issues_found + 1)) # Safe: arithmetic expansion, not ((++))
  fi

  return $issues_found
}

main() {
  local total_issues=0

  if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <file>..." >&2
    return "$EXIT_FAILURE"
  fi

  for file in "$@"; do
    if ! check_file "$file"; then
      total_issues=$((total_issues + 1)) # Safe: arithmetic expansion
    fi
  done

  if [[ $total_issues -gt 0 ]]; then
    echo -e "${RED}Found $total_issues file(s) with dangerous bash arithmetic patterns${NC}" >&2
    echo "See: docs/BASH_STANDARDS.md for safe patterns" >&2
    return "$EXIT_FAILURE"
  fi

  return "$EXIT_SUCCESS"
}

main "$@"
