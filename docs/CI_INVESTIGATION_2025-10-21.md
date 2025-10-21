# CI Investigation - Bash/Zsh Portability Issues

**Date:** 2025-10-21
**Status:** Investigation paused - issues documented for future reference

---

## Original Problem

GitHub Actions CI failing with 4 jobs:

- ❌ Pre-commit Hooks
- ❌ Lint & Format Check
- ❌ Test with Bash
- ❌ Test with Zsh

---

## What We Fixed Successfully

### 1. Pre-commit Hook Issues ✅

**Issues found:**

- Missing shebangs in `spec/helpers/env.sh` and `spec/helpers/matchers.sh`
- Files with shebangs not marked executable
- Codespell flagging "AfterAll" (ShellSpec keyword) as typo
- Prettier formatting issues
- Shellcheck SC2016 warnings on ShellSpec syntax

**Fixes applied:**

- Added shellcheck directives (`# shellcheck shell=bash`) to helper files
- Updated `.pre-commit-config.yaml`:
  - Excluded SC2016 (ShellSpec single-quote pattern is intentional)
  - Added "afterall" to codespell ignore list
  - Excluded `lib/` and `spec/helpers/` from shebang-executable check
- Made spec test files executable (not lib files - they're sourced)
- Added `node_modules/` to `.gitignore`
- Ran prettier on markdown/YAML files

**Result:** Pre-commit hooks pass locally ✅

### 2. Created Shell Portability Prevention System ✅

**New file:** `.pre-commit-hooks/check-shell-portability.sh`

**Purpose:** Catches non-portable `BASH_SOURCE[0]` usage in lib files

**Detection logic:**

```bash
# Checks that lib files using BASH_SOURCE have:
# 1. Conditional check: if [[ -n "${BASH_SOURCE[0]:-}" ]]
# 2. Zsh fallback in else clause
```

**Configuration:** Added to `.pre-commit-config.yaml` as `check-shell-portability` hook

---

## The Core Problem: Bash/Zsh Script Directory Detection

### Why This Is Hard

**Context:** The project supports both bash and zsh (per README line 14: "ShellSpec with bash + zsh coverage")

**Challenge:** Lib files need to determine their own directory to source dependencies:

```bash
# lib/goals.sh needs to:
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/error.sh"
```

### Bash vs Zsh Detection Methods

| Shell    | Method              | Notes                                              |
| -------- | ------------------- | -------------------------------------------------- |
| **Bash** | `${BASH_SOURCE[0]}` | ✅ Works reliably for sourced files                |
| **Zsh**  | `${(%):-%x}`        | ✅ Works for sourced files, ❌ Complex scope rules |
| **Zsh**  | `${0:A:h}`          | ❌ Returns shell name when sourced, not file path  |
| **Zsh**  | `$0`                | ❌ Returns function name in sourced context        |

### Approaches We Tried

#### Attempt 1: Simple if/else with BASH_SOURCE check

```bash
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  # Zsh
  SCRIPT_DIR="${0:A:h}"
fi
readonly SCRIPT_DIR
```

**Result:** ❌ `${0:A:h}` doesn't work for sourced files

---

#### Attempt 2: Use zsh prompt expansion

```bash
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  # Zsh
  SCRIPT_DIR="${${(%):-%x}:A:h}"
fi
readonly SCRIPT_DIR
```

**Result:** ❌ Nested parameter expansion `${${...}}` syntax issues

---

#### Attempt 3: Two-step expansion

```bash
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  # Zsh
  _FILE="${(%):-%x}"
  SCRIPT_DIR="${_FILE:A:h}"
fi
readonly SCRIPT_DIR
```

**Result:** ❌ Variable became local-scoped in zsh, disappeared after if-block

---

#### Attempt 4: Use typeset -g for global scope

```bash
typeset -g SCRIPT_DIR
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  typeset _FILE="${(%):-%x}"
  SCRIPT_DIR="${_FILE:A:h}"
fi
readonly SCRIPT_DIR
```

**Result:** ❌ Broke bash tests (ShellSpec-specific issue)

---

#### Attempt 5: Pre-initialize variable

```bash
SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
fi
readonly SCRIPT_DIR
```

**Result:** ⚠️ Partially works

- ✅ Zsh: Files load, only real test failures remain
- ❌ Bash: ShellSpec aborts with exit code 1/2

---

### The Zsh Local Scope Issue

**Key Discovery:** In zsh, variables assigned inside if-statements become local-scoped:

```bash
if true; then
  MYVAR="value"
fi
readonly MYVAR
echo "$MYVAR"  # EMPTY in zsh! Variable was local to if-block
```

**Type output:** `scalar-local-readonly` (not global)

**Debug Evidence:**

```
[DEBUG] Using Zsh: GOALS_SCRIPT_DIR=/Users/harm/harm-cli/lib
[DEBUG] After readonly: GOALS_SCRIPT_DIR=''  ← Lost!
[DEBUG] Type: scalar-local-readonly
```

---

## Why CI Still Fails

### Pre-commit Hooks

- ✅ Pass locally
- ❌ Pass on CI but exit code 1 (mysterious - all individual hooks pass)

### Bash Tests

- ❌ Were already failing BEFORE our changes (tested on commit `f2ed373`)
- Issue is pre-existing, not caused by our portability attempts

### Zsh Tests

- ❌ Fail due to script directory detection issues
- The `elif` pattern works better but ShellSpec environment adds complexity

---

## Lessons Learned

### 1. Shell Portability Is Complex

Supporting both bash and zsh requires:

- Understanding shell-specific variable scoping rules
- Testing in actual environments (not just direct sourcing)
- Considering test harness quirks (ShellSpec adds layer of complexity)

### 2. Zsh Scoping Rules Are Different

- Variables in if-blocks are local unless declared with `typeset -g`
- But `typeset -g` breaks bash compatibility in some contexts
- Pre-initialization helps but doesn't solve all cases

### 3. File Organization Matters

Library files that source each other create circular dependency challenges:

- `goals.sh` → sources → `common.sh`, `error.sh`, `logging.sh`, `util.sh`
- Each needs to know its own directory
- Cascading failures if one fails to load

---

## Recommended Path Forward

### Option A: Bash-Only (Simplest) ⭐

**Pros:**

- Eliminates all portability complexity
- `BASH_SOURCE[0]` works reliably
- Can focus on fixing actual bash test issues

**Cons:**

- Breaks promise in README (line 14: "bash + zsh coverage")
- Reduces user base (some use zsh)

**Implementation:**

1. Remove zsh from CI (`.github/workflows/test.yml`)
2. Update README to document bash-only
3. Keep shebangs as `#!/usr/bin/env bash`
4. Fix pre-existing bash test failures

---

### Option B: Use ROOT Variable from Caller

**Pros:**

- Avoids auto-detection entirely
- Caller (bin/harm-cli or tests) sets `ROOT`
- Simple and explicit

**Cons:**

- Requires lib files to have `ROOT` set before sourcing
- Changes API contract

**Implementation:**

```bash
# In lib files:
SCRIPT_DIR="${ROOT:?ROOT must be set}/lib"
source "$SCRIPT_DIR/common.sh"

# In bin/harm-cli:
export ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/goals.sh"
```

---

### Option C: Single Lib File

**Pros:**

- No interdependencies
- No directory detection needed
- One source, one load

**Cons:**

- Large file (harder to maintain)
- Violates SRP if all utilities in one file

---

### Option D: Continue Investigation

**Estimated time:** 2-4 more hours
**Success probability:** 60%
**Blockers identified:**

- ShellSpec environment differences vs direct sourcing
- Pre-existing bash test failures unrelated to portability

---

## Files Modified During Investigation

**Created:**

- `.pre-commit-hooks/check-shell-portability.sh` - Prevention hook

**Modified:**

- `.pre-commit-config.yaml` - Hook configuration updates
- `.gitignore` - Added `node_modules/`
- `lib/goals.sh`, `lib/work.sh`, `lib/util.sh`, `lib/logging.sh` - Portability attempts
- `spec/helpers/env.sh`, `spec/helpers/matchers.sh` - Added shellcheck directives
- Various spec files - Made executable, added shellcheck disables
- Markdown/YAML files - Prettier formatting

**To revert:** `git reset --hard f2ed373` (commit before CI investigation)

---

## Next Steps (When Resuming)

1. **Decide on shell support strategy** (bash-only vs bash+zsh)
2. **If bash-only:**
   - Remove zsh CI job
   - Keep the pre-commit fixes (they're valuable)
   - Fix pre-existing bash test failures
3. **If bash+zsh:**
   - Consider Option B (ROOT variable) or Option C (single lib file)
   - Or investigate ShellSpec-specific configuration options

---

## Testing Commands Used

```bash
# Local testing
shellspec -s /bin/bash          # Test with bash
shellspec -s /bin/zsh           # Test with zsh
pre-commit run --all-files      # Run all hooks

# Debug zsh sourcing
zsh -c 'source file.sh'
bash -c 'set -x; source file.sh'  # Trace execution

# Check variable scope
zsh -c 'if true; then VAR="x"; fi; readonly VAR; echo "${VAR:-EMPTY}"'

# CI debugging
gh pr checks --watch                    # Watch CI status
gh run view <run_id> --log-failed      # Get failed logs
```

---

## References

- ShellSpec docs: https://github.com/shellspec/shellspec
- Zsh parameter expansion: `man zshexpn`
- Bash BASH_SOURCE: `man bash` (search for BASH_SOURCE)
- Zsh prompt escapes: `man zshmisc` (SIMPLE PROMPT ESCAPES)

---

**Conclusion:** The investigation revealed deep portability challenges. Pre-commit issues are fixed locally. Test failures require strategic decision on shell support scope before continuing.
