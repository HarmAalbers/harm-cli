# harm-cli Mega Improvement Plan

**Generated**: 2025-10-25
**Analysis**: 8 specialized agents (code quality, SOLID, performance, security, testing, architecture, UX, git workflow)

---

## Executive Summary

harm-cli is a **production-ready CLI toolkit** with excellent foundations (287 passing tests, modular architecture, comprehensive documentation). However, comprehensive analysis reveals **significant opportunities** for improvement across 8 dimensions:

- **Grade**: A- overall (89/100 code quality, A- SOLID compliance, GOOD security)
- **Critical Issues**: 1 (pattern override bug)
- **High-Priority Opportunities**: 14 (security, performance, integration)
- **Test Coverage Gaps**: 10 untested modules, critical safety operations
- **Architecture Potential**: Transform from "tools collection" to "cohesive platform"

---

## Critical Issues (Fix Immediately)

### 🔴 CRITICAL-1: Pattern Override Bug in CLI Dispatcher

**Severity**: CRITICAL
**Impact**: Commands are unreachable (break violations, reset-violations, set-mode)
**File**: `/Users/harm/harm-cli/bin/harm-cli` lines 377-381
**Effort**: 5 minutes

**Current Code**:

```bash
case "$subcmd" in
  *)
    die "Unknown break command: $subcmd. Try: start, stop, status" 2
    ;;
  violations) work_get_violations ;;  # UNREACHABLE!
  reset-violations) work_reset_violations ;;  # UNREACHABLE!
  set-mode) work_set_enforcement "$@" ;;  # UNREACHABLE!
esac
```

**Fix**:

```bash
case "$subcmd" in
  --help | help)
    # ... help text ...
    ;;
  start) break_start "$@" ;;
  stop) break_stop "$@" ;;
  status) break_status "$@" ;;
  violations) work_get_violations ;;
  reset-violations) work_reset_violations ;;
  set-mode) work_set_enforcement "$@" ;;
  *)  # MOVE TO END
    die "Unknown break command: $subcmd. Try: start, stop, status, violations, reset-violations, set-mode" 2
    ;;
esac
```

**Verification**:

```bash
just lint
just test
```

---

## High-Priority Security Fixes

### 🟠 MEDIUM-1: Notification Command Injection

**Severity**: MEDIUM
**File**: `/Users/harm/harm-cli/lib/work.sh` lines 109-114
**Effort**: 30 minutes

**Vulnerability**:

```bash
# Current - escapes only double quotes
local safe_title="${title//\"/\\\"}"
osascript -e "display notification \"$safe_message\" with title \"$safe_title\""
```

**Fix**:

```bash
# Use osascript stdin to avoid shell interpretation
osascript <<EOF
display notification "$message" with title "$title" sound name "Glass"
EOF
```

**Test**:

```bash
harm-cli work start "Test \$(whoami)"  # Should NOT execute whoami
```

---

### 🟠 MEDIUM-2: Remove eval from Logging

**Severity**: MEDIUM
**File**: `/Users/harm/harm-cli/lib/logging.sh` lines 577, 582, 589, 593
**Effort**: 1 hour

**Current**:

```bash
eval "stdbuf -o0 $tail_cmd '$log_file' | stdbuf -o0 $filter_cmd"
```

**Fix**:

```bash
# Use command arrays instead of eval
stdbuf -o0 "$tail_cmd" "$log_file" | stdbuf -o0 $filter_cmd
```

---

### 🟠 MEDIUM-3: Sanitize curl Error Output

**Severity**: MEDIUM
**File**: `/Users/harm/harm-cli/lib/ai.sh` line 544
**Effort**: 15 minutes

**Fix**:

```bash
response=$(curl -s -w "\n%{http_code}" \
  -m "$AI_TIMEOUT" \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: $api_key" \
  -d "$request_body" \
  "$api_url" 2>&1 | sed 's/x-goog-api-key:[^[:space:]]*/x-goog-api-key:***REDACTED***/g')
```

---

## High-Priority Performance Optimizations

### ⚡ PERF-1: Consolidate JSON Parsing

**Impact**: 60-90% faster for goal/work operations
**Files**: `lib/goals.sh` lines 241-253, `lib/work.sh` lines 428-433
**Effort**: 2 hours

**Current (3 jq processes per goal)**:

```bash
while IFS= read -r line; do
  goal="$(jq -r '.goal' <<<"$line")"
  progress="$(jq -r '.progress' <<<"$line")"
  completed="$(jq -r '.completed' <<<"$line")"
done <"$goal_file"
```

**Optimized (1 jq process total)**:

```bash
jq -r '.[] | [.goal, .progress, .completed] | @tsv' "$goal_file" | \
while IFS=$'\t' read -r goal progress completed; do
  # Process data
done
```

**Expected Improvement**: 450ms → 50ms for 10 goals

---

### ⚡ PERF-2: Optimize goal_show Loop

**Impact**: 90% faster
**File**: `/Users/harm/harm-cli/lib/goals.sh` lines 241-253
**Effort**: 1 hour

Apply same pattern as PERF-1 to `goal_show` function.

---

## Critical Test Coverage Gaps

### 🧪 TEST-1: Add Safety Operation Tests

**Priority**: P0 (prevents data loss)
**File**: Create `spec/safety_spec.sh` with 47+ tests
**Effort**: 1 day

**Missing Tests**:

- Confirmation timeout behavior
- Preview accuracy (files vs directories)
- Permission errors
- Dangerous flags detection
- Docker daemon failures
- Git reset backup verification

**Risk**: Destructive operations with minimal validation could cause data loss.

---

### 🧪 TEST-2: Add Background Process Tests

**Priority**: P0 (prevents zombie processes)
**File**: Update `spec/work_spec.sh` with timer tests
**Effort**: 4 hours

**Missing Tests**:

- Timer PID file creation/cleanup
- Background process lifecycle
- Orphaned process prevention
- Multiple timer instances

---

### 🧪 TEST-3: Test Untested Modules

**Priority**: P1
**Modules**: focus.sh, interactive.sh, github.sh, insights.sh, goal_ai.sh (10 total)
**Effort**: 2 weeks

Create test files for 3,977 untested lines across 10 modules.

---

## Architecture Improvements

### 🏗️ ARCH-1: Work ↔ Goals Integration

**Impact**: HIGH - Direct productivity boost
**Effort**: 1-2 days

**Implementation**:

```bash
# Add goal_id to work session state
work_start() {
  if goal_exists_today; then
    echo "Active goals:"
    goal_show
    read -p "Associate with goal #? " goal_num

    if [[ -n "$goal_num" ]]; then
      work_save_state "active" "$start_time" "$description" 0 "$goal_num"
    fi
  fi
}

# Auto-suggest progress updates
work_stop() {
  local goal_id=$(json_get "$state" ".goal_id")
  if [[ -n "$goal_id" ]]; then
    echo "Update progress for goal #$goal_id? (y/N)"
    read -p "> " -n 1 -r
    [[ $REPLY =~ ^[Yy]$ ]] && goal_update_progress "$goal_id"
  fi
}
```

**Files**: `lib/work.sh`, `lib/goals.sh`

---

### 🏗️ ARCH-2: AI Context Injection

**Impact**: HIGH - Better AI suggestions
**Effort**: 1 day

**Implementation**:

```bash
# Create lib/context.sh
declare -gA HARM_CONTEXT=(
  [work_session_id]=""
  [project_name]=""
  [active_goal_ids]=""
)

# Enhance ai_query
ai_query() {
  local context=""

  # Add work session context
  [[ -n "${HARM_CONTEXT[work_session_id]}" ]] && \
    context+="Currently working on: $(work_get_description)\n"

  # Add project context
  [[ -n "${HARM_CONTEXT[project_name]}" ]] && \
    context+="Current project: ${HARM_CONTEXT[project_name]}\n"

  # Inject into prompt
  _ai_query_internal "Context:\n$context\n\nQuery: $query"
}
```

**Files**: Create `lib/context.sh`, update `lib/ai.sh`

---

### 🏗️ ARCH-3: Refactor lib/common.sh (God Module)

**Impact**: MEDIUM - Removes technical debt
**Effort**: 1 day

**Current**: 235 lines mixing 5+ responsibilities
**Target**: Split into focused modules

```
lib/
├── error.sh         # Die, warn, require_command
├── file.sh          # File I/O operations
├── validation.sh    # Input validation
├── process.sh       # Process utilities
├── json.sh          # JSON helpers
└── common.sh        # Backward compatibility shim
```

**Migration**: Non-breaking (common.sh sources all sub-modules)

---

## UX Improvements

### 🎨 UX-1: Work Session Wizard

**Impact**: HIGH - Reduces friction
**File**: `lib/work.sh` line 301
**Effort**: 4 hours

**Current**:

```bash
$ harm-cli work start "Phase 3"
✓ Work session started
```

**Enhanced**:

```bash
$ harm-cli work start
🍅 Start Pomodoro Session

What are you working on?
  1. Complete Phase 3 (from goals)
  2. Fix authentication bug
  3. Custom goal...
> 1

Duration: 25m (standard) ◆ 15m (mini) ◆ 45m (deep)
> 25m

✅ Pomodoro started: Complete Phase 3
⏱  25:00 remaining
```

**Uses**: `interactive_choose` from existing `lib/interactive.sh`

---

### 🎨 UX-2: Goal Selection Menu

**Impact**: HIGH - Faster than remembering IDs
**File**: `lib/goals.sh` line 295
**Effort**: 2 hours

**Implementation**:

```bash
goal_update_progress() {
  if [[ $# -eq 0 ]]; then
    # Interactive mode
    local goal_num=$(goal_select_interactive)
    [[ -z "$goal_num" ]] && return 1

    read -p "New progress (0-100): " progress
    goal_update_progress "$goal_num" "$progress"
  else
    # CLI mode (backward compatible)
    # ... existing logic ...
  fi
}
```

---

### 🎨 UX-3: AI Progress Feedback

**Impact**: HIGH - Reduces anxiety
**File**: `lib/ai.sh` line 719
**Effort**: 1 hour

**Implementation**:

```bash
if has_gum; then
  gum spin --spinner dot --title "Thinking..." -- \
    _ai_make_request "$api_key" "$query"
else
  _show_spinner &
  spinner_pid=$!
  _ai_make_request "$api_key" "$query"
  kill $spinner_pid
fi
```

---

## Git Workflow Improvements

### 📝 GIT-1: Add Commit Message Validation Hook

**Impact**: HIGH - 100% conventional commits
**Effort**: 1 hour

**Create**: `.git/hooks/commit-msg`

```bash
#!/usr/bin/env bash
commit_msg=$(cat "$1")

if ! echo "$commit_msg" | grep -qE "^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?: .{10,72}"; then
  echo "❌ Commit message must follow conventional commits format"
  exit 1
fi
```

**Install**:

```bash
chmod +x .git/hooks/commit-msg
pre-commit install --hook-type commit-msg
```

---

### 📝 GIT-2: Create Release Automation

**Impact**: HIGH - 30min → 5min releases
**Effort**: 2 hours

**Create**: `scripts/release.sh`

Features:

- Auto-update VERSION file
- Generate CHANGELOG with git-cliff
- Create annotated tag
- Push to remote
- Create GitHub release

**Usage**:

```bash
./scripts/release.sh 1.2.0
```

---

## SOLID Compliance Fixes

### 🔧 SOLID-1: Fix Inconsistent Error Contracts

**File**: `lib/util.sh` lines 113-144
**Effort**: 2 hours

**Issue**: Mixed error handling patterns

```bash
file_sha256() { require_file "$file"; ... }  # Dies on error
file_exists() { [[ -f "$file" ]]; }          # Returns 0/1
```

**Fix**: Standardize all `file_*` functions to return exit codes

---

## Implementation Roadmap

### Week 1: Critical Fixes & Security

- [ ] Day 1: Fix pattern override bug (CRITICAL-1)
- [ ] Day 2: Fix notification injection (MEDIUM-1)
- [ ] Day 2: Remove eval from logging (MEDIUM-2)
- [ ] Day 3: Sanitize curl errors (MEDIUM-3)
- [ ] Day 4-5: Add safety operation tests (TEST-1)

### Week 2: Performance & Architecture

- [ ] Day 1-2: Consolidate JSON parsing (PERF-1, PERF-2)
- [ ] Day 3: Work ↔ Goals integration (ARCH-1)
- [ ] Day 4: AI context injection (ARCH-2)
- [ ] Day 5: Refactor lib/common.sh (ARCH-3)

### Week 3: UX & Testing

- [ ] Day 1-2: Work session wizard (UX-1)
- [ ] Day 2: Goal selection menu (UX-2)
- [ ] Day 3: AI progress feedback (UX-3)
- [ ] Day 4-5: Background process tests (TEST-2)

### Week 4: Git Workflow & Polish

- [ ] Day 1: Commit message validation (GIT-1)
- [ ] Day 2: Release automation (GIT-2)
- [ ] Day 3: SOLID fixes (SOLID-1)
- [ ] Day 4-5: Documentation updates, testing

---

## Success Metrics

### Code Quality

- [ ] Shellcheck violations: 2 → 0
- [ ] Code coverage: ~60% → 80%+
- [ ] SOLID compliance: B+ → A

### Performance

- [ ] Goal operations: 480ms → 50ms (90% faster)
- [ ] Work status: 45ms → 15ms (67% faster)
- [ ] AI queries: Add progress feedback

### Security

- [ ] Command injection vulnerabilities: 1 → 0
- [ ] Eval usage: Removed from logging
- [ ] Secret leakage: Sanitized in errors

### User Experience

- [ ] Interactive features: 2 → 8+
- [ ] Error message quality: Add examples
- [ ] Setup friction: Reduced by 30%

### Testing

- [ ] Test files: 18 → 28
- [ ] Test count: 287 → 500+
- [ ] Module coverage: 44% → 100%

### Git Workflow

- [ ] Conventional commits: 40% → 100%
- [ ] Release time: 30min → 5min
- [ ] Branch count: 60+ → 10-15 active

---

## Risk Assessment

### Low Risk (Safe to Implement)

- Pattern override bug fix
- JSON parsing consolidation
- UX enhancements (use existing interactive.sh)
- Test additions
- Git workflow improvements

### Medium Risk (Requires Testing)

- lib/common.sh refactoring (backward compatibility needed)
- Eval removal from logging (behavior verification)
- SOLID error contract changes (API changes)

### High Risk (Careful Planning)

- Work ↔ Goals integration (state schema changes)
- AI context injection (prompt engineering)

---

## Quick Wins (Implement Today)

1. **Fix pattern override bug** (5 min) - CRITICAL
2. **Add AI progress spinner** (1 hour) - High UX impact
3. **Add goal selection menu** (2 hours) - High UX impact
4. **Sanitize curl errors** (15 min) - Security fix
5. **Add commit-msg hook** (1 hour) - Enforces quality

**Total**: 4.5 hours for 5 high-impact improvements

---

## References

- Code Quality Report: Lines analyzed: ~10,000
- SOLID Analysis: 10 modules, ~5,757 lines
- Performance Analysis: 8 bottlenecks identified
- Security Audit: 4 MEDIUM, 3 LOW findings
- Test Coverage: 287 passing, 10 modules untested
- Architecture Analysis: 14 integration opportunities
- UX Analysis: 9 improvement opportunities
- Git Workflow: 7 recommendations

---

## Next Steps

1. **Review this plan** with team/stakeholders
2. **Prioritize** based on project goals
3. **Create GitHub issues** for each task
4. **Start with Quick Wins** for immediate impact
5. **Follow roadmap** for systematic improvement

---

**Generated by**: 8 specialized AI agents
**Total Analysis Time**: Comprehensive codebase review
**Estimated Total Effort**: 4-6 weeks (with testing)
**Expected ROI**: Transform from "good" to "exceptional"
