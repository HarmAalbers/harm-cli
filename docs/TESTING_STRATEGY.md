# harm-cli Testing Strategy

## 🎯 Overview

This document describes the **multi-layer defense strategy** that prevents bugs like the `install_completions` parameter bug from reaching production.

## 🛡️ Defense Layers

### Layer 1: Static Analysis (ShellCheck)

**Purpose**: Catch syntax errors, bad practices, and some logic errors before runtime.

**Configuration**:

- `.pre-commit-config.yaml` - Runs shellcheck on all shell files
- `justfile` - `just lint` includes `install.sh` and `uninstall.sh`
- Excludes: `2016,2034,2148,2155` (ShellSpec patterns)

**Run manually**:

```bash
just lint               # Lint all scripts including installer
shellcheck install.sh   # Lint installer specifically
```

**What it catches**:

- Undefined variables (if not in parent scope)
- Syntax errors
- Bad quoting
- Unused variables
- Many bash anti-patterns

**Example prevention**:

```bash
# ❌ Would catch if variable was truly undefined
function_name() {
  echo "$undefined_var"  # SC2154: variable is referenced but not assigned
}
```

### Layer 2: Integration Tests (ShellSpec)

**Purpose**: Verify architectural consistency and contract compliance.

**Test file**: `spec/install_spec.sh`

**Run tests**:

```bash
just test                          # Run full test suite
shellspec spec/install_spec.sh     # Run installer tests only
shellspec --watch                  # Watch mode for TDD
```

**What it verifies**:

- ✅ Bash syntax validity (`bash -n`)
- ✅ Strict error handling (`set -u` present)
- ✅ Function parameter consistency
- ✅ ShellCheck compliance
- ✅ Function existence
- ✅ Architectural contracts (functions accept parameters)
- ✅ Call site correctness (parameters passed)

**Example test that caught the bug**:

```bash
It "install_completions accepts aliases_file parameter"
  When run grep -A3 "^install_completions()" install.sh
  The output should include 'local aliases_file="$1"'
End
```

### Layer 3: Custom Pre-commit Hook

**Purpose**: Enforce architectural patterns and catch inconsistencies.

**Hook file**: `.pre-commit-hooks/check-function-parameters.sh`

**Configuration**: Registered in `.pre-commit-config.yaml`

**Run manually**:

```bash
pre-commit run check-function-parameters --all-files
.pre-commit-hooks/check-function-parameters.sh install.sh
```

**What it detects**:

- Functions using variables without accepting them as parameters
- Inconsistent parameter patterns
- Reliance on parent scope instead of explicit parameters

**Example output** (would have caught the bug):

```
❌ Potential parameter issue in install.sh:
   Function: install_completions()
   Issue: Uses $aliases_file without accepting it as parameter
   Suggestion: Add local aliases_file="$1" at start of function
```

### Layer 4: CI Pipeline

**Purpose**: Ensure all checks run before merge.

**Run locally**:

```bash
just ci              # Run full CI: fmt + lint + test
just pre-push        # Run before pushing
```

**CI workflow**:

1. Format code (`shfmt`)
2. Lint code (`shellcheck`)
3. Run tests (`shellspec`)
4. All must pass ✅

**Exit Code Handling**:
ShellSpec exit codes:

- `0` - All tests passed, no warnings ✅
- `101` - Tests passed, but has warnings ⚠️ (acceptable)
- Other - Actual test failures ❌

Our CI treats warnings as acceptable:

```yaml
set +e  # Don't exit on shellspec warnings
shellspec -s "$BASH_PATH"
EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]] || [[ $EXIT_CODE -eq 101 ]]; then
  exit 0  # Success
fi
```

This ensures CI passes when tests succeed, even with warnings.

## 🐛 Case Study: The install_completions Bug

### The Original Bug

**File**: `install.sh:834-849`

**Problem**:

```bash
# ❌ BEFORE (buggy)
install_completions() {
  # Missing: local aliases_file="$1"

  # This relied on parent scope, which failed with set -u
  echo "$aliases_file"  # Variable not defined in local scope!
}

# Call site
install_completions  # ❌ No parameter passed
```

**Error**:

```
./install.sh: line 834: /tmp/harm-cli-aliases-19579.sh: No such file or directory
```

**Root cause**: With `set -u`, referencing undefined variables exits immediately.

### The Fix

```bash
# ✅ AFTER (fixed)
install_completions() {
  local aliases_file="$1"  # ✅ Explicitly accept parameter

  echo "$aliases_file"
}

# Call site
install_completions "$aliases_file"  # ✅ Pass parameter
```

### Why It Wasn't Caught Initially

1. ❌ `install.sh` was NOT in lint targets
2. ❌ No unit tests for installer functions
3. ❌ No architectural consistency checks
4. ❌ Relied on implicit parent scope sharing

### What Catches It Now

1. ✅ **ShellCheck** (Layer 1): `install.sh` now linted
2. ✅ **ShellSpec** (Layer 2): Test verifies parameter acceptance
3. ✅ **Custom hook** (Layer 3): Detects scope reliance pattern
4. ✅ **CI** (Layer 4): Runs all checks before merge

## 📋 Testing Checklist

Before committing bash scripts:

- [ ] **Format**: `just fmt` or `shfmt -w file.sh`
- [ ] **Lint**: `just lint` or `shellcheck file.sh`
- [ ] **Test**: Add tests to `spec/` if adding new functions
- [ ] **Run tests**: `just test` or `shellspec`
- [ ] **Pre-commit**: Hooks auto-run or `pre-commit run --all-files`
- [ ] **CI**: `just ci` passes locally

## 🎓 Best Practices

### 1. Always Accept Parameters Explicitly

```bash
# ✅ GOOD - Explicit parameters
my_function() {
  local param1="$1"
  local param2="$2"
  # Use param1, param2
}

# ❌ BAD - Relies on parent scope
my_function() {
  # Uses $param1 without defining it
  echo "$param1"  # Fragile!
}
```

### 2. Use `set -Eeuo pipefail`

```bash
#!/usr/bin/env bash
set -Eeuo pipefail  # Strict error handling

# -e: Exit on error
# -E: Inherit ERR trap
# -u: Error on undefined variable
# -o pipefail: Pipeline fails if any command fails
```

### 3. Write Tests for Complex Functions

```bash
Describe "my_function()"
  It "accepts required parameters"
    When call my_function "arg1" "arg2"
    The status should be success
  End

  It "fails when parameters missing"
    When run my_function
    The status should be failure
  End
End
```

### 4. Keep Functions Small and Focused

```bash
# ✅ GOOD - Single responsibility
generate_aliases() {
  # Only generates aliases
}

install_completions() {
  # Only installs completions
}

# ❌ BAD - Multiple responsibilities
do_everything() {
  # Generates aliases
  # Installs completions
  # Updates shell RC
  # ... too much!
}
```

## 🔄 Continuous Improvement

### Adding New Tests

1. Create test file in `spec/`:

   ```bash
   touch spec/my_feature_spec.sh
   ```

2. Write tests:

   ```bash
   Describe "my_feature"
     It "does what it should"
       When call my_function
       The status should be success
     End
   End
   ```

3. Run tests:
   ```bash
   shellspec spec/my_feature_spec.sh
   ```

### Adding New Hooks

1. Create hook in `.pre-commit-hooks/`:

   ```bash
   touch .pre-commit-hooks/my-check.sh
   chmod +x .pre-commit-hooks/my-check.sh
   ```

2. Register in `.pre-commit-config.yaml`:

   ```yaml
   - id: my-check
     name: My custom check
     entry: .pre-commit-hooks/my-check.sh
     language: script
     types: [shell]
   ```

3. Test the hook:
   ```bash
   pre-commit run my-check --all-files
   ```

## 📚 References

- [ShellCheck Wiki](https://github.com/koalaman/shellcheck/wiki)
- [ShellSpec Documentation](https://shellspec.info/)
- [Pre-commit Framework](https://pre-commit.com/)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)

## 🎯 Summary

This multi-layer testing strategy ensures:

1. **Prevention**: Catches bugs before they're committed
2. **Detection**: Tests verify correctness continuously
3. **Documentation**: Tests serve as living documentation
4. **Confidence**: Refactor safely with comprehensive coverage

**Result**: Bugs like the `install_completions` issue are caught in development, not production! 🎉
