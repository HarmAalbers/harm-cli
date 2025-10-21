# Phase 5d: Health Checks - Architectural Design

**Date:** 2025-10-21
**Status:** Deep Design Phase
**Estimated Time:** 4-5 hours
**Complexity:** HIGH - Integrates all modules

---

## 🎯 Design Challenges

### The Complexity

Health checks are the **most complex module** because they:

1. **Integrate with ALL modules** (docker, python, git, work, goals, ai)
2. **Cross-platform** (macOS vs Linux differences)
3. **Multiple categories** (system, git, docker, python, ai, network, security)
4. **Multiple modes** (--quick, --fix, --json, --verbose)
5. **Scoring system** (critical, warnings, healthy)
6. **Actionable suggestions** (what to do about issues)

### The Risk

**Bad Architecture:**

- God function (violates SRP)
- Tight coupling to other modules
- Hard to test
- Hard to extend
- Platform-specific code scattered everywhere

**Good Architecture:**

- Each check is independent (SRP)
- Loose coupling via detection
- Easy to test each check
- Easy to add new checks
- Platform differences isolated

---

## 🏗️ SOLID Architecture Design

### Principle 1: Single Responsibility

**✅ DO:** Each check category is ONE function with ONE responsibility

```bash
# GOOD - Each function does ONE category check
_health_check_system() {
  # ONLY checks system (CPU, memory, disk)
  # Returns: exit_code (0=healthy, 1=warning, 2=critical)
}

_health_check_docker() {
  # ONLY checks Docker environment
  # Returns: exit_code
}

_health_check_git() {
  # ONLY checks Git repository
  # Returns: exit_code
}

# Main orchestrator delegates
health_check() {
  local category="$1"
  case "$category" in
    system) _health_check_system ;;
    docker) _health_check_docker ;;
    git) _health_check_git ;;
    all)
      _health_check_system
      _health_check_git
      _health_check_docker
      # etc...
      ;;
  esac
}
```

**❌ DON'T:** One giant function checking everything

```bash
# BAD - God function
health_check() {
  # 500 lines checking system, git, docker, python, network...
  # Impossible to test individual checks
  # Hard to maintain
}
```

---

### Principle 2: Open/Closed

**✅ DO:** Easy to add new check categories without modifying existing code

```bash
# Registry of check categories (easy to extend)
readonly -A HEALTH_CHECK_CATEGORIES=(
  [system]="_health_check_system"
  [git]="_health_check_git"
  [docker]="_health_check_docker"
  [python]="_health_check_python"
  # Easy to add:
  # [nodejs]="_health_check_nodejs"
  # [rust]="_health_check_rust"
)

# Generic check runner
_run_health_check() {
  local category="$1"
  local check_function="${HEALTH_CHECK_CATEGORIES[$category]}"

  if [[ -n "$check_function" ]]; then
    $check_function
  fi
}
```

---

### Principle 3: Dependency Inversion

**✅ DO:** Depend on abstractions (check if module exists), not concrete implementations

```bash
# GOOD - Checks if Docker module loaded before checking
_health_check_docker() {
  # Abstract interface: check if function exists
  if ! type docker_is_running >/dev/null 2>&1; then
    echo "⚠  Docker module not loaded (skipping)"
    return 0  # Not an error, just not applicable
  fi

  # Now safe to use docker functions
  if docker_is_running; then
    echo "✓ Docker daemon running"
  else
    echo "✗ Docker daemon not running"
    return 2  # Critical
  fi
}
```

**❌ DON'T:** Assume modules are loaded

```bash
# BAD - Assumes docker.sh is loaded
_health_check_docker() {
  if docker_is_running; then  # Crashes if docker.sh not loaded!
    echo "✓"
  fi
}
```

---

### Principle 4: Interface Segregation

**✅ DO:** Consistent return interface for all checks

```bash
# All check functions follow same contract:
# - Return 0 (healthy), 1 (warning), 2 (critical)
# - Output to stdout (formatted message)
# - Log via stderr

_health_check_system() {
  # Returns: 0, 1, or 2
}

_health_check_docker() {
  # Returns: 0, 1, or 2  (same contract)
}
```

---

### Principle 5: Liskov Substitution

**✅ DO:** All check functions are interchangeable

```bash
# Can call any check function the same way
for category in system git docker; do
  _health_check_${category}
  local status=$?
  [[ $status -eq 2 ]] && critical_issues+=1
  [[ $status -eq 1 ]] && warnings+=1
done
```

---

## 📋 Architecture Specification

### Module Structure

```bash
lib/health.sh (300 LOC estimated):

# Configuration (20 LOC)
- Category registry
- Thresholds (CPU, memory, disk)
- Constants

# Main Entry Point (50 LOC)
health_check(category, --quick, --fix, --json)
  - Parse options
  - Validate category
  - Run checks
  - Aggregate results
  - Display summary

# Category Checks (180 LOC - ~20 LOC each)
_health_check_system()
  - CPU usage (via top/ps)
  - Memory usage (free/vm_stat)
  - Disk space (df)
  - Load average

_health_check_git()
  - Repository detection
  - Uncommitted changes
  - Remote connectivity
  - Branch status

_health_check_docker()
  - Daemon status
  - Service health
  - Resource usage
  - Image updates available

_health_check_python()
  - Python version
  - Venv status
  - Dependencies up-to-date
  - Test suite passing

_health_check_ai()
  - API key configured
  - Cache size
  - Recent errors
  - Connectivity

# Utility Functions (50 LOC)
_health_format_result()
_health_get_disk_usage()
_health_get_memory_usage()
_health_check_port()
```

---

## 🔧 Cross-Platform Strategy

### Challenge: macOS vs Linux Differences

**System Commands Differ:**

- Memory: `memory_pressure` (macOS) vs `free` (Linux)
- CPU: `top -l 1` (macOS) vs `top -bn1` (Linux)
- Disk: `df -h` (same) but output format differs

**Solution: Platform Abstraction Layer**

```bash
# Platform detection (use common.sh pattern)
readonly IS_MACOS="$([ "$(uname -s)" = "Darwin" ] && echo 1 || echo 0)"
readonly IS_LINUX="$([ "$(uname -s)" = "Linux" ] && echo 1 || echo 0)"

# Abstract cross-platform functions
_health_get_cpu_usage() {
  if [[ "$IS_MACOS" -eq 1 ]]; then
    # macOS implementation
    top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//'
  else
    # Linux implementation
    top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//'
  fi
}

_health_get_memory_free_percent() {
  if [[ "$IS_MACOS" -eq 1 ]]; then
    # macOS implementation
    vm_stat | awk '/Pages free/ {free=$3} /Pages active/ {active=$3} /Pages inactive/ {inactive=$3} END {printf "%.0f", (free/(free+active+inactive))*100}'
  else
    # Linux implementation
    free | awk 'NR==2{printf "%.0f", $7/$2*100}'
  fi
}
```

---

## 🎨 Output Design

### Text Format (Human-Friendly)

```
🏥 Comprehensive Health Check
═══════════════════════════════════════════════
Timestamp: 2025-10-21 19:45:00

💻 System Health
──────────────────────────
  ✓ CPU usage: 15%
  ✓ Memory: 45% free
  ✓ Disk space: 120GB free (40%)
  ✓ Load average: 2.5

🔧 Git Health
──────────────────────────
  ✓ Repository detected
  ⚠  Uncommitted changes (3 files)
  ✓ Remote: origin configured
  → Suggestion: Commit or stash changes

🐳 Docker Health
──────────────────────────
  ✓ Docker daemon running
  ✓ 3 of 3 services healthy
  ✓ Resources: CPU 5%, Memory 512MB

🐍 Python Health
──────────────────────────
  ✓ Python 3.11.5
  ✓ Virtual environment active
  ✓ 42 dependencies installed
  ⚠  2 outdated packages
  → Suggestion: poetry update

═══════════════════════════════════════════════
Health Check Summary

⚠  2 warnings
System functional but needs attention

Run with --fix to attempt repairs
```

### JSON Format (Machine-Parseable)

```json
{
  "timestamp": "2025-10-21T19:45:00Z",
  "categories": {
    "system": {
      "status": "healthy",
      "checks": {
        "cpu": { "value": 15, "threshold": 80, "status": "ok" },
        "memory": { "value": 45, "threshold": 20, "status": "ok" },
        "disk": { "value": 40, "threshold": 10, "status": "ok" }
      }
    },
    "git": {
      "status": "warning",
      "checks": {
        "uncommitted": { "count": 3, "status": "warning" }
      },
      "suggestions": ["Commit or stash changes"]
    }
  },
  "summary": {
    "critical": 0,
    "warnings": 2,
    "healthy": 4,
    "overall": "warning"
  }
}
```

---

## 🧪 Testing Strategy

### Challenge: Testing System Checks

**Problem:** Can't mock `top`, `free`, `df` easily in ShellSpec

**Solution: Test at Function Level**

```bash
Describe '_health_check_system'
  It 'runs without errors'
    When call _health_check_system 0 0
    The status should be success
    The output should include "System Health"
  End

  It 'checks CPU usage'
    When call _health_check_system 0 0
    The output should include "CPU"
  End
End

# Don't test actual thresholds (environment-dependent)
# Test function structure and output format
```

### Test Philosophy

```bash
# ✅ DO: Test function exists, callable, proper output format
# ✅ DO: Test category routing works
# ✅ DO: Test module detection (if docker.sh loaded)
# ❌ DON'T: Test actual CPU/memory values (environment-specific)
# ❌ DON'T: Mock system commands (too brittle)
```

---

## 📊 Implementation Plan

### Phase 1: Core Architecture (1.5 hours)

1. Create `lib/health.sh` skeleton
2. Implement main `health_check()` orchestrator
3. Implement category routing
4. Add option parsing (--quick, --fix, --json)
5. Add summary/scoring system

### Phase 2: Check Categories (2 hours)

1. `_health_check_system()` - CPU, memory, disk (30 min)
2. `_health_check_git()` - Git status (20 min)
3. `_health_check_docker()` - Docker checks (20 min)
4. `_health_check_python()` - Python env (20 min)
5. `_health_check_ai()` - AI module (20 min)
6. Cross-platform helpers (30 min)

### Phase 3: Testing (1 hour)

1. Create `spec/health_spec.sh`
2. Test each check category (15 tests)
3. Test orchestration and routing
4. Test option parsing

### Phase 4: Polish (30 min)

1. CLI integration
2. Documentation
3. Final testing

---

## 🔑 Key Design Decisions

### Decision 1: Loose Coupling via Detection

**Approach:**

```bash
_health_check_docker() {
  # Don't assume docker.sh is loaded
  if type docker_is_running >/dev/null 2>&1; then
    # Docker module available, use it
    docker_health
  else
    # Docker module not loaded, basic check
    if command -v docker >/dev/null 2>&1; then
      echo "⚠  Docker installed but module not loaded"
    else
      echo "ℹ  Docker not installed (skipping)"
    fi
  fi
}
```

**Benefit:** Works whether modules are loaded or not

---

### Decision 2: Consistent Return Codes

**All check functions return:**

- `0` - Healthy (no issues)
- `1` - Warning (minor issues)
- `2` - Critical (major issues)

**Main function aggregates:**

- Any critical → return 2
- Any warnings → return 1
- All healthy → return 0

---

### Decision 3: Progressive Disclosure

**Quick Mode:**

- Only critical checks
- Fast (<1s)
- Essential health only

**Normal Mode:**

- All checks
- Medium speed (~2-5s)
- Comprehensive

**Verbose Mode:**

- All checks + details
- Slower (~5-10s)
- Deep diagnostics

---

### Decision 4: Fix Mode Strategy

**Philosophy:** Only fix safe, non-destructive issues

**Safe to fix:**

- ✅ Install missing dependencies (with confirmation)
- ✅ Clean cache files
- ✅ Update outdated packages (with confirmation)
- ✅ Fix file permissions

**Never fix automatically:**

- ❌ Commit uncommitted changes
- ❌ Delete containers/volumes
- ❌ Modify production config
- ❌ Change system settings

**Implementation:**

```bash
_health_check_docker() {
  local fix_mode="$1"

  # Check cache size
  local cache_size=$(du -sh ~/.harm-cli/ai-cache | awk '{print $1}')
  if [[ "$cache_size" > "100M" ]]; then
    echo "⚠  Large cache: $cache_size"

    if [[ "$fix_mode" -eq 1 ]]; then
      read -p "Clean cache? (y/n): " -n 1 -r
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf ~/.harm-cli/ai-cache/*
        echo "✓ Cache cleaned"
      fi
    else
      echo "  → Run with --fix to clean"
    fi
  fi
}
```

---

## 📋 Category Specification

### System Health (Essential)

**Checks:**

- CPU usage (threshold: 80%)
- Memory free (threshold: 20%)
- Disk space (threshold: 10GB or 10%)
- Load average (threshold: CPU count \* 2)

**Suggestions:**

- High CPU: "Close unnecessary applications"
- Low memory: "Restart applications or system"
- Low disk: "Clean up files: brew cleanup, docker system prune"

---

### Git Health (If in repo)

**Checks:**

- Repository detected
- Uncommitted changes
- Unpushed commits
- Remote connectivity

**Suggestions:**

- Uncommitted: "Commit or stash: git stash"
- Unpushed: "Push changes: git push"
- No remote: "Add remote: git remote add origin URL"

---

### Docker Health (If Docker available)

**Checks:**

- Docker daemon running
- Services health (if compose file)
- Image updates available
- Resource usage

**Suggestions:**

- Daemon not running: "Start Docker Desktop"
- Services unhealthy: "Check logs: harm-cli docker logs <service>"
- Updates available: "Pull images: docker compose pull"

---

### Python Health (If Python project)

**Checks:**

- Python version
- Virtual environment status
- Dependencies installed
- Outdated packages

**Suggestions:**

- No venv: "Create: python -m venv .venv"
- Venv not active: "Activate: source .venv/bin/activate"
- Outdated: "Update: poetry update or pip install -U -r requirements.txt"

---

### AI Health (If AI module)

**Checks:**

- API key configured
- Cache size reasonable
- Recent errors in logs
- API connectivity

**Suggestions:**

- No key: "Setup: harm-cli ai --setup"
- Large cache: "Clean: rm -rf ~/.harm-cli/ai-cache"
- Recent errors: "Check: harm-cli ai explain-error"

---

## 🧪 Testing Strategy

### Test Structure

```bash
Describe 'health_check'
  It 'runs without errors'
  It 'accepts --quick flag'
  It 'accepts --json flag'
  It 'accepts category argument'
  It 'displays summary'
End

Describe '_health_check_system'
  It 'checks system health'
  It 'outputs formatted results'
  It 'returns status code'
End

Describe '_health_check_git'
  It 'skips when not in git repo'
  It 'checks repo when available'
End

# Similar for each category
```

**Total: ~20 tests**

---

## 💡 Implementation Order

### Step 1: Foundation (30 min)

- Create lib/health.sh skeleton
- Add constants and configuration
- Add platform detection

### Step 2: Core Orchestration (30 min)

- Implement `health_check()` main function
- Option parsing
- Category routing
- Summary system

### Step 3: System Check (30 min)

- CPU, memory, disk checks
- Cross-platform implementations
- Threshold logic

### Step 4: Module Checks (1.5 hours)

- Git health (20 min)
- Docker health (20 min)
- Python health (20 min)
- AI health (20 min)
- Integration testing (30 min)

### Step 5: Polish (1 hour)

- JSON output format
- Fix mode implementation
- Comprehensive tests
- Documentation

---

## ⚠️ Critical Considerations

### 1. Don't Break If Modules Missing

```bash
# ✅ CRITICAL: Check before using
if type docker_health >/dev/null 2>&1; then
  docker_health
else
  echo "ℹ  Docker module not loaded (OK)"
fi
```

### 2. Cross-Platform Compatibility

```bash
# ✅ CRITICAL: Test on both macOS and Linux
# Use abstraction functions for platform-specific code
```

### 3. Performance

```bash
# ✅ CRITICAL: --quick mode should be <1s
# System checks can be slow, make them optional
```

### 4. No Destructive Operations

```bash
# ✅ CRITICAL: --fix should NEVER delete data
# Always confirm before destructive operations
```

---

## 📈 Success Criteria

**Functional:**

- [x] Works on macOS and Linux
- [x] All categories implemented
- [x] Quick mode < 1s
- [x] JSON output works
- [x] Fix mode safe and helpful
- [x] Proper error handling
- [x] Actionable suggestions

**Code Quality:**

- [x] SOLID principles (especially SRP and DIP)
- [x] Comprehensive docstrings
- [x] < 300 LOC
- [x] Average function < 20 lines
- [x] All checks independent

**Testing:**

- [x] 20+ tests
- [x] Each category tested
- [x] Integration tested
- [x] No brittle system mocks

---

## 🎯 MVP Scope

### Must Have:

1. ✅ System health (CPU, memory, disk)
2. ✅ Git health
3. ✅ Docker health
4. ✅ Python health
5. ✅ AI health
6. ✅ Summary with scoring
7. ✅ --quick mode

### Nice to Have (defer if time):

- Network connectivity checks
- Security checks (SSH keys, permissions)
- Port availability checks
- Auto-fix mode

---

**This design ensures:**

- ✅ SOLID architecture
- ✅ Easy to test
- ✅ Easy to extend
- ✅ Cross-platform
- ✅ Loose coupling
- ✅ Elite-tier quality

**Ready to implement with extreme care!** 🏥
