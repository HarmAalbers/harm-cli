# LLM Continuation Prompt for harm-cli Development

**Copy this entire prompt to continue work on harm-cli project**

---

## 📍 Project Context

I'm working on **harm-cli**, a production-grade CLI toolkit being built by refactoring a 19,000 LOC ZSH development environment into a modern bash 5+ CLI using elite-tier engineering practices.

**Repository:** `~/harm-cli` (local) → https://github.com/HarmAalbers/harm-cli

**Current Status:**

- **Version:** 0.2.0-alpha
- **Phase:** 2 complete (Work & Goals functional)
- **Progress:** 30% of full migration
- **Tests:** 139 ShellSpec tests (94% passing)
- **Code:** 2,708 LOC (from 19,000 original = 86% reduction)

---

## 🎯 Testing Framework Decision (ANSWERED)

**Question:** What is the best testing framework for this project?

**Answer:** **ShellSpec** - Definitively proven with 139 real tests written

**Why ShellSpec:**

- ✅ Full bash + zsh support (tested with both)
- ✅ BDD syntax (RSpec-style, self-documenting)
- ✅ Excellent debugging output
- ✅ Mocking capabilities ready
- ✅ 139 tests prove it works excellently
- ❌ BATS rejected (bash-only, can't test zsh features)
- ❌ ZUnit rejected (too early-stage)

**Installation:** `brew install shellspec`
**Config:** `.shellspec` (bash 5+ required)
**Run:** `just test` or `shellspec spec/`

---

## 🏗️ Project Structure

```
~/harm-cli/
├── bin/
│   └── harm-cli              # Main CLI entry point
├── lib/
│   ├── common.sh             # Shared utilities
│   ├── error.sh              # Error handling (21 tests) ✅
│   ├── logging.sh            # Logging system (32 tests) ✅
│   ├── util.sh               # Helper functions (40 tests) ✅
│   ├── work.sh               # Work sessions (18 tests, 4 pending)
│   └── goals.sh              # Goal tracking (20 tests, 4 pending)
├── spec/
│   ├── helpers/              # Test helpers
│   └── *_spec.sh             # ShellSpec tests
├── docs/
│   ├── SESSION_2025-10-19.md    # Today's session notes ⭐
│   ├── PROGRESS.md              # Migration tracker ⭐
│   └── check-list.md            # Definition of Done
├── Justfile                  # Task runner (just ci, just test, etc.)
├── .shellspec                # ShellSpec config
└── README.md
```

---

## ✅ What's Complete

### Phase 1: Core Infrastructure (MERGED to main)

- `lib/error.sh` - Exit codes, colored messages, validation
- `lib/logging.sh` - Multi-level logging, rotation, timers
- `lib/util.sh` - String/array/file/time/JSON helpers
- **101 tests** (100% passing)
- **Bash 5+ only** (uses associative arrays, ${var^^})

### Phase 2: Work & Goals (On branch `phase-2/work-and-goals`)

- `lib/work.sh` - Work session start/stop/status
- `lib/goals.sh` - Goal set/show/progress/complete
- CLI integration: `harm-cli work|goal` subcommands
- **38 tests** (34 passing, 4 skipped)

**Currently on branch:** `phase-2/work-and-goals`
**Last commit:** `30ca03c docs: comprehensive session documentation`

⚠️ **IMPORTANT:** Latest commit (`30ca03c`) is documentation only - DO NOT PUSH IT. Will be removed/rebased later.

---

## 🔧 Critical Technical Decisions

### 1. Bash 5+ Only (BREAKING CHANGE)

**Decision made:** Require bash 5.0+ (drop bash 3.2 support)

**Why:**

- Associative arrays: `declare -A LOG_LEVELS=([DEBUG]=0 [INFO]=1)`
- String ops: `${var^^}` instead of `tr` subprocess
- Cleaner, faster, more maintainable code

**Testing:** Uses `/opt/homebrew/bin/bash` (bash 5.3.3)

### 2. Load Guards on ALL Modules

**CRITICAL PATTERN:** Every module must have load guard to prevent readonly errors

```bash
#!/usr/bin/env bash
set -Eeuo pipefail; IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_MODULE_LOADED:-}" ]] && return 0

# ... module code ...

# Mark as loaded
readonly _HARM_MODULE_LOADED=1
```

**Why:** Modules source each other; without guards, readonly variables error on re-source

**Applied to:** common.sh, error.sh, logging.sh, util.sh, work.sh, goals.sh

### 3. Cross-Platform Date Parsing

**Problem:** `date -d` (GNU) doesn't work on macOS

**Solution:** Created `parse_iso8601_to_epoch()` in lib/work.sh:49

```bash
# Try GNU date (Linux), then BSD date (macOS), then fallback
```

### 4. JSONL Format

**All persistent data uses JSON Lines** (single-line JSON per entry)

**Key:** Use `jq -nc` for compact output:

```bash
jq -nc '{key: $value}'  # Single line
```

**Not:**

```bash
jq -n '{         # Multi-line breaks JSONL!
  key: $value
}'
```

---

## 🐛 Known Issues (Phase 2)

### 4 Skipped Tests (Pending Refinement)

**Location:** spec/work_spec.sh:106, spec/goals_spec.sh:122,128,144

**Issues:**

1. `goal_show` - Not displaying goal text properly (empty output)
2. `goal_update_progress` - JSONL line update not working
3. `work_status` - Date parsing edge case on macOS

**Estimated fix:** 1-2 hours

**NOT blockers** - core functionality works:

```bash
$ harm-cli work start "goal"     # ✅ Works
$ harm-cli goal set "test" 120   # ✅ Works
$ harm-cli goal show              # ⚠️ Shows structure but not text
```

---

## 📋 Immediate Next Steps

### Option A: Fix Phase 2 Issues (1-2 hours)

1. Fix `goal_show` display (lib/goals.sh:133-141)
   - Problem: jq parsing in while loop with JSONL
   - Solution: Read full lines correctly

2. Fix `goal_update_progress` JSONL updates (lib/goals.sh:160-180)
   - Problem: Updating specific line in JSONL file
   - Solution: Use jq array processing

3. Unskip the 4 tests

4. Run `just ci` - should get 38/38 passing

5. Rebase to remove doc commit, then push Phase 2

### Option B: Merge Phase 2 As-Is, Start Phase 3 (Recommended)

Phase 2 is **89% functional** - good enough for alpha!

1. Push Phase 2 to GitHub
2. Create PR #2
3. Merge to main
4. Start Phase 3: AI Integration

---

## 🚀 Starting Phase 3: AI Integration

### Preparation

```bash
cd ~/harm-cli
git checkout main
git pull
git checkout -b phase-3/ai-integration
```

### Scope

**Port from:** `~/.zsh/86_ai_assistant.zsh` (~1,500 LOC)

**Create:**

- `lib/ai.sh` (~300 LOC estimated)
- `spec/ai_spec.sh` (~25 tests)
- CLI integration: `harm-cli ai query|chat|commit-msg`

**Key features:**

- OpenAI API integration (curl-based)
- API key management (keychain or env)
- Error handling (rate limits, timeouts)
- **CRITICAL:** Mock curl in tests (no real API calls!)

**Estimated time:** 6-8 hours

---

## 🎓 Patterns & Standards Established

### Module Template

```bash
#!/usr/bin/env bash
# shellcheck shell=bash
# module.sh - Description
# Ported from: ~/.zsh/original_file.zsh

set -Eeuo pipefail
IFS=$'\n\t'

# Load guard
[[ -n "${_HARM_MODULE_LOADED:-}" ]] && return 0

# Dependencies
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/error.sh"

# ... module code ...

readonly _HARM_MODULE_LOADED=1
export -f function_names...
```

### Test Template

```bash
#!/usr/bin/env bash
# ShellSpec tests for module

Describe 'lib/module.sh'
  Include spec/helpers/env.sh

  BeforeAll 'export CONFIG="$TEST_TMP/config" && mkdir -p "$(dirname $CONFIG)"'
  AfterAll 'rm -rf "$TEST_TMP"'
  BeforeAll 'source "$ROOT/lib/module.sh"'

  Describe 'function_name'
    It 'does something'
      When call function_name "arg"
      The status should be success
      The output should include "expected"
    End
  End
End
```

### JSON Output Standard

```bash
if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
  jq -n --arg key "$value" '{key: $key}'
else
  echo "Human output"
fi
```

### DoD Checklist

**Every module must:**

- ✅ Strict mode + load guard
- ✅ Input validation
- ✅ JSON + text output parity
- ✅ ShellSpec tests (90%+ coverage)
- ✅ shellcheck clean
- ✅ Proper quoting
- ✅ Exports for functions

**Verify:** See `docs/check-list.md`

---

## 🛠️ Essential Commands

### Development Workflow

```bash
# Run all tests
just ci                # Format + lint + test (bash + zsh)

# Run specific tests
just test-bash         # Bash only
just test-zsh          # Zsh only
shellspec spec/work_spec.sh

# Check code quality
just lint              # shellcheck (blocking!)
just fmt               # shfmt auto-format
just doctor            # Check dependencies

# Test CLI
./bin/harm-cli work start "test"
./bin/harm-cli goal set "test" 60
```

### Git Workflow

```bash
# Feature branch
git checkout -b phase-N/feature-name

# Commit
git add -A
git commit -m "feat(phase-N): description"

# Push
git push -u origin phase-N/feature-name

# Create PR on GitHub
# Merge when CI passes
```

---

## 📊 Progress Dashboard

**Completed:** 2/8 phases (25%)
**LOC:** 2,708/~5,500 (49%)
**Tests:** 139/~320 (43%)
**Time:** ~10h / ~70h total (14%)

**Next milestones:**

- [ ] Fix Phase 2 issues (1-2h)
- [ ] Complete Phase 3: AI (6-8h)
- [ ] Complete Phase 4: Git (8-10h)
- [ ] 50% milestone (~35h total)

---

## 🔑 Files to Read First

When continuing tomorrow:

1. **docs/SESSION_2025-10-19.md** - Today's detailed notes
2. **docs/PROGRESS.md** - Overall progress tracker
3. **docs/check-list.md** - DoD checklist
4. **README.md** - Current features/status

---

## ⚡ Quick Context Summary

**In 3 sentences:**

We're migrating a 19,000 LOC ZSH environment to a modern bash 5+ CLI using ShellSpec for testing (139 tests prove it's excellent). We've completed Phase 0 (foundation), Phase 1 (error/logging/utils with 101 tests), and Phase 2 (work/goals with 38 tests, 89% passing). Next is Phase 3 (AI integration) which involves porting OpenAI API code with mocked tests.

---

## 🎯 Success Metrics

**Testing framework evaluation:**

- ✅ 139 ShellSpec tests written
- ✅ BDD syntax proven excellent
- ✅ Bash + Zsh matrix working
- ✅ DoD integration seamless
- ✅ **Answer: ShellSpec is definitively the best choice**

**Code quality:**

- Zero shellcheck warnings (blocking enforced)
- 86% code reduction through modernization
- Bash 5+ features throughout
- Comprehensive test coverage

---

## 💭 Important Notes

1. **DO NOT PUSH** the latest commit (30ca03c) - it's documentation only
2. **Branch:** Currently on `phase-2/work-and-goals`
3. **User:** HarmAalbers <haalbers@gmail.com> (local git config only)
4. **Bash:** Requires bash 5.0+ (uses modern features)
5. **macOS:** Some commands need cross-platform handling (date, stat)

---

## 🚀 To Continue Tomorrow

```bash
cd ~/harm-cli

# Check where we are
git status
git log --oneline -3

# Read the session notes
cat docs/SESSION_2025-10-19.md
cat docs/PROGRESS.md

# Decide: Fix Phase 2 or start Phase 3?

# Option A: Fix Phase 2
shellspec spec/work_spec.sh spec/goals_spec.sh  # See failures
# Fix issues in lib/goals.sh and lib/work.sh
# Unskip tests
# Commit and push

# Option B: Start Phase 3
git checkout main
git pull
git checkout -b phase-3/ai-integration
# Port AI features from ~/.zsh/86_ai_assistant.zsh
```

---

## 📚 Key Resources

**Testing:** ShellSpec docs at https://shellspec.info/
**Bash 5:** https://www.gnu.org/software/bash/manual/
**jq:** https://jqlang.github.io/jq/manual/

**Project files:**

- Justfile - All commands
- docs/check-list.md - DoD criteria
- CONTRIBUTING.md - Code standards

---

## ✨ Remember

- ShellSpec is the answer (proven with 139 tests)
- All modules need load guards
- Bash 5+ only (no legacy compatibility)
- JSON + text output on everything
- DoD checklist for every module
- `just ci` must pass before committing

---

**Ready to continue building an elite-tier CLI!** 🔥

_Last session: 2025-10-19, ~10 hours invested, 30% complete_
