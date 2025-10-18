# ShellSpec custom matchers
# Loaded by: Include spec/helpers/matchers.sh

# Example custom matcher for JSON validation
# Usage: The output should be valid_json
be_valid_json() {
  if command -v jq >/dev/null 2>&1; then
    jq -e . >/dev/null 2>&1 <<<"$1"
  else
    # Fallback: basic check
    [[ "$1" =~ ^\{.*\}$ ]] || [[ "$1" =~ ^\[.*\]$ ]]
  fi
}

# Match JSON field value
# Usage: The output should have_json_field "version" "0.1.0-alpha"
have_json_field() {
  local field="$1"
  local expected="$2"
  local json="$3" # Actual value from shellspec

  if command -v jq >/dev/null 2>&1; then
    local actual
    actual="$(jq -r ".$field" <<<"$json" 2>/dev/null)"
    [[ "$actual" == "$expected" ]]
  else
    grep -q "\"$field\".*\"$expected\"" <<<"$json"
  fi
}
