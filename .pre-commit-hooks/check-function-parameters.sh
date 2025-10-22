#!/usr/bin/env bash
# Pre-commit hook: Check for function parameter consistency
# Detects functions that use variables without accepting them as parameters
# This would have caught the install_completions bug

set -euo pipefail

EXIT_CODE=0
CHECKED_FILES=0

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "🔍 Checking function parameter consistency..."

for file in "$@"; do
  # Skip if not a shell script
  if [[ ! "$file" =~ \.(sh|bash)$ ]] && [[ ! -x "$file" ]]; then
    continue
  fi

  CHECKED_FILES=$((CHECKED_FILES + 1))

  # Extract functions and check for common anti-patterns
  while IFS= read -r line; do
    # Match function definitions: function_name() { or function function_name {
    if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)\(\)[[:space:]]*\{ ]]; then
      func_name="${BASH_REMATCH[1]}"

      # Get the function body (simplified - just check first 20 lines)
      # Use || true to prevent SIGPIPE (exit 141) when head closes pipe early
      func_body=$(sed -n "/^${func_name}()/,/^}/p" "$file" | head -20 || true)

      # Check if function uses variables that look like they should be parameters
      # Pattern: Uses $var but doesn't have 'local var=' or 'var="$1"'
      if echo "$func_body" | grep -qE '\$[a-z_]+_file' \
        && ! echo "$func_body" | grep -qE 'local [a-z_]+_file='; then

        # Extract which variable is problematic
        var_name=$(echo "$func_body" | grep -oE '\$[a-z_]+_file' | head -1 | tr -d '$')

        # Skip if it's clearly a global variable (all caps or specific patterns)
        if [[ "$var_name" =~ ^[A-Z] ]] || [[ "$var_name" =~ ^(BASH|HOME|PATH|PWD) ]]; then
          continue
        fi

        echo -e "${RED}❌ Potential parameter issue in $file:${NC}"
        echo -e "   Function: ${YELLOW}${func_name}()${NC}"
        echo -e "   Issue: Uses ${YELLOW}\$$var_name${NC} without accepting it as parameter"
        echo -e "   Suggestion: Add ${GREEN}local $var_name=\"\$1\"${NC} at start of function"
        echo ""
        EXIT_CODE=1
      fi
    fi
  done <"$file"
done

if [[ $CHECKED_FILES -eq 0 ]]; then
  echo "⚠️  No shell scripts to check"
  exit 0
fi

if [[ $EXIT_CODE -eq 0 ]]; then
  echo -e "${GREEN}✅ Function parameters look consistent ($CHECKED_FILES files checked)${NC}"
else
  echo -e "${RED}❌ Found parameter consistency issues${NC}"
  echo "   Review the suggestions above to ensure functions explicitly accept their parameters"
fi

exit $EXIT_CODE
