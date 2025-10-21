# Bash Coding Standards for harm-cli

This document establishes coding standards and patterns for bash development to prevent subtle bugs and ensure consistent, high-quality code.

---

## Critical Gotchas and Safeguards

### 🚨 CRITICAL: Arithmetic Post-Increment with `set -e`

**The Bug:**

```bash
set -e
i=0
((i++))  # ❌ EXITS SCRIPT! Evaluates to 0 (false) = exit code 1
```

**Why it happens:**

- Post-increment `((i++))` evaluates to the **OLD value** (0)
- In bash arithmetic: `0 = false = exit code 1`
- With `set -e`: any exit code 1 terminates the script
- Result: Silent failure with no error message

**Real-world impact:**

- **Issue #4:** `goal show` command completely broken
- Loop exited on first iteration
- No error message, just empty output
- Tests didn't catch it (called functions directly, not CLI)

**Safe Patterns:**

✅ **ALWAYS USE** one of these patterns:

```bash
# Option 1: Pre-increment (safest for set -e)
((++i))  # Evaluates to NEW value (1) = exit code 0 ✅

# Option 2: Arithmetic expansion (always safe)
i=$((i + 1))  # Never returns exit code 1 ✅

# Option 3: Explicit true (verbose but clear)
((i++)) || true  # Ignores exit code ✅
```

❌ **NEVER USE** post-increment/decrement as standalone command with `set -e`:

```bash
((i++))  # ❌ Dangerous with set -e when i=0
((i--))  # ❌ Dangerous with set -e when i=1
```

**Enforcement:**

- Pre-commit hook: `.pre-commit-hooks/check-bash-arithmetic.sh`
- Automatically scans all `.sh` files for dangerous patterns
- Prevents commits containing `((var++))` or `((var--))`

---

## Strict Mode Configuration

All harm-cli scripts use strict mode for maximum safety:

```bash
set -Eeuo pipefail
```

**What each flag does:**

| Flag          | Effect                   | Why We Use It                              |
| ------------- | ------------------------ | ------------------------------------------ |
| `-e`          | Exit on error            | Fail fast, don't continue with bad state   |
| `-E`          | ERR trap inheritance     | Error handlers work in functions/subshells |
| `-u`          | Error on unset variables | Catch typos and missing variable errors    |
| `-o pipefail` | Pipe failures propagate  | Detect errors in pipeline chains           |

**Implications:**

- ANY command returning non-zero exits the script
- Unset variables cause immediate failure
- Must explicitly handle expected failures with `|| true` or `|| return 0`
- Arithmetic expressions must be carefully designed

---

## Loop Patterns

### Incrementing Counters in Loops

✅ **RECOMMENDED:**

```bash
# Pre-increment (safe with set -e)
local i=0
while some_condition; do
  ((++i))  # ✅ Safe
  echo "Processing item $i"
done

# Or use arithmetic expansion
local i=0
while some_condition; do
  i=$((i + 1))  # ✅ Safe
  echo "Processing item $i"
done
```

❌ **AVOID:**

```bash
# Post-increment (dangerous with set -e)
local i=0
while some_condition; do
  ((i++))  # ❌ Will exit when i=0
  echo "Never reaches here on first iteration"
done
```

### Reading Files Line by Line

✅ **RECOMMENDED:**

```bash
local line_num=0
while IFS= read -r line; do
  ((++line_num))  # ✅ Pre-increment is safe
  echo "$line_num: $line"
done < file.txt
```

### Array Iteration with Index

✅ **RECOMMENDED:**

```bash
local items=("a" "b" "c")
local i
for ((i=0; i<${#items[@]}; i++)); do  # ✅ Safe in for (( )) loop
  echo "${items[$i]}"
done
```

**Note:** Post-increment is SAFE in `for (( ))` loops because the loop construct handles exit codes differently than `(( ))` standalone commands.

---

## Testing Standards

### Principle: Test the Actual Invocation, Not Just the Function

**Problem Pattern:**

```bash
# ❌ Insufficient - only tests function in isolation
It 'shows goals'
When call goal_show
The output should include "First goal"
End
```

**Why this fails:**

- Doesn't test through actual CLI entry point
- Doesn't verify `set -e` behavior
- Only checks content inclusion, not format correctness
- Can pass even if output is completely wrong

**Correct Pattern:**

```bash
# ✅ Comprehensive - tests actual CLI invocation
It 'shows goals with correct format'
goal_set "First goal" >/dev/null 2>&1
goal_set "Second goal" >/dev/null 2>&1
When run ./bin/harm-cli goal show
The status should be success
The line 1 should equal "Goals for $(date '+%Y-%m-%d'):"
The line 2 should equal ""
The line 3 should match pattern "  1. First goal (*% complete)"
The line 4 should match pattern "  2. Second goal (*% complete)"
End
```

**Benefits:**

- Tests actual user experience
- Verifies exit codes
- Checks exact output format
- Catches `set -e` issues
- Validates line-by-line output

### Testing Checklist

For each command, verify:

- [ ] Invokes actual CLI binary (not just function)
- [ ] Checks exit code explicitly
- [ ] Verifies exact output format (not just content)
- [ ] Tests edge cases (empty state, single item, multiple items)
- [ ] Tests error conditions
- [ ] Verifies both text and JSON output formats

---

## Error Handling Patterns

### Expected Failures

When a command is expected to fail, explicitly handle it:

```bash
# ✅ Explicit failure handling
if some_command_that_might_fail; then
  echo "Success"
else
  echo "Failed as expected"
fi

# ✅ Or use || for fallback
result=$(some_command || echo "default")

# ❌ Don't rely on set -e being disabled
some_command  # If this fails, script exits!
```

### Arithmetic Operations That Might Be Zero

```bash
# ❌ Dangerous
result=$((some_calculation))
[[ $result -gt 0 ]] && do_something  # Script exits if result=0!

# ✅ Safe
result=$((some_calculation))
if [[ $result -gt 0 ]]; then
  do_something
fi
```

---

## Code Review Checklist

Before approving bash code, verify:

- [ ] **No post-increment/decrement** as standalone `(( ))` commands
- [ ] **All arithmetic** operations safe with `set -e`
- [ ] **Tests invoke CLI** binary, not just functions
- [ ] **Output format** explicitly verified in tests
- [ ] **Error messages** tested and verified
- [ ] **Edge cases** covered (empty, single, multiple items)
- [ ] **Both formats** tested (text and JSON)

---

## Common Patterns Library

### Safe Counter Increment

```bash
# Pattern: Incrementing in loops
local count=0
while condition; do
  ((++count))  # Pre-increment
  # or
  count=$((count + 1))  # Arithmetic expansion
done
```

### Safe Array Index

```bash
# Pattern: Array iteration with index
for ((i=0; i<${#array[@]}; i++)); do  # Safe in for (( ))
  echo "${array[$i]}"
done
```

### Safe Conditional Arithmetic

```bash
# Pattern: Arithmetic with conditional logic
if ((value > 0)); then  # Safe - in conditional context
  do_something
fi

# Pattern: Arithmetic in test
[[ $((value + 1)) -gt 0 ]]  # Safe - in [[ ]] context
```

---

## Historical Bugs Prevented by These Standards

### Bug #1: Goal Show Silent Failure (2025-10-21)

**Pattern:** `((line_num++))` in while loop with `set -e`

**Impact:** Entire goal tracking feature unusable

**Root cause:** Post-increment evaluated to 0, causing exit code 1

**Fix:** Changed to `((++line_num))`

**Prevention:** Pre-commit hook now detects this pattern

### Bug #2: Error Handler Stack Trace (Potential)

**Pattern:** `((i++))` in error handlers (2 instances found and fixed)

**Impact:** Stack traces might fail to display in debug mode

**Fix:** Changed to `((++i))` in both locations

**Prevention:** Same pre-commit hook catches these

---

## References

- [Bash Arithmetic Evaluation](https://www.gnu.org/software/bash/manual/html_node/Shell-Arithmetic.html)
- [Bash set builtin](https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html)
- [ShellCheck](https://www.shellcheck.net/)

---

**Version:** 1.0
**Last Updated:** 2025-10-21
**Maintained by:** harm-cli project
