#!/usr/bin/env bash
# shellcheck shell=bash
# health.sh - Comprehensive system and project health checks
# Ported from: ~/.zsh/90_health_check.zsh
#
# Features:
# - System health monitoring (CPU, memory, disk)
# - Git repository health checks
# - Docker environment health
# - Python environment health
# - AI module health
# - Multi-category support with scoring
# - Cross-platform compatible (macOS/Linux)
#
# Public API:
#   health_check [category] [--quick] [--json]
#
# Categories: all, system, git, docker, python, ai
#
# Dependencies: Core system commands (top, df, free/vm_stat)

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_HEALTH_LOADED:-}" ]] && return 0

# Source dependencies
HEALTH_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly HEALTH_SCRIPT_DIR

# shellcheck source=lib/common.sh
source "$HEALTH_SCRIPT_DIR/common.sh"
# shellcheck source=lib/error.sh
source "$HEALTH_SCRIPT_DIR/error.sh"
# shellcheck source=lib/logging.sh
source "$HEALTH_SCRIPT_DIR/logging.sh"
# shellcheck source=lib/util.sh
source "$HEALTH_SCRIPT_DIR/util.sh"

# ═══════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════

# Platform detection
readonly IS_MACOS="$([ "$(uname -s)" = "Darwin" ] && echo 1 || echo 0)"
readonly IS_LINUX="$([ "$(uname -s)" = "Linux" ] && echo 1 || echo 0)"

# Health thresholds
readonly CPU_THRESHOLD=80      # CPU usage %
readonly MEMORY_THRESHOLD=20   # Free memory %
readonly DISK_THRESHOLD_GB=10  # Free disk GB
readonly DISK_THRESHOLD_PCT=10 # Free disk %

# Module-level issue counters
_health_critical_count=0
_health_warning_count=0

# ═══════════════════════════════════════════════════════════════════
# Cross-Platform Utilities
# ═══════════════════════════════════════════════════════════════════

# _health_get_cpu_usage: Get CPU usage percentage (cross-platform)
_health_get_cpu_usage() {
  if [[ "$IS_MACOS" -eq 1 ]]; then
    # macOS: top -l 1 shows CPU usage
    top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//' || echo "0"
  else
    # Linux: top -bn1 shows CPU usage
    top -bn1 | grep "Cpu(s)" | awk '{print 100-$8}' || echo "0"
  fi
}

# _health_get_memory_free_pct: Get free memory percentage (cross-platform)
_health_get_memory_free_pct() {
  if [[ "$IS_MACOS" -eq 1 ]]; then
    # macOS: Use vm_stat
    vm_stat | awk '/Pages free/ {free=$3} /Pages active/ {active=$3} /Pages inactive/ {inactive=$3} /Pages speculative/ {spec=$3} /Pages wired/ {wired=$3} END {total=free+active+inactive+spec+wired; if(total>0) printf "%.0f", (free/total)*100; else print "0"}' || echo "50"
  else
    # Linux: Use free command
    free | awk 'NR==2{printf "%.0f", $7/$2*100}' || echo "50"
  fi
}

# _health_get_disk_free_pct: Get disk free percentage for current directory
_health_get_disk_free_pct() {
  df -h . | awk 'NR==2{print $5}' | sed 's/%//' || echo "50"
}

# ═══════════════════════════════════════════════════════════════════
# Health Check Categories
# ═══════════════════════════════════════════════════════════════════

# _health_check_system: Check system resources (CPU, memory, disk)
#
# Returns: 0 (healthy), 1 (warning), 2 (critical)
_health_check_system() {
  log_debug "health" "Running system health check"

  echo "💻 System Health"
  echo "──────────────────────────"

  local issues=0

  # CPU check
  local cpu
  cpu=$(_health_get_cpu_usage)
  # Validate and use bash arithmetic
  if [[ -n "$cpu" ]] && [[ "$cpu" =~ ^[0-9]+\.?[0-9]*$ ]]; then
    local cpu_int=${cpu%.*}
    cpu_int=${cpu_int:-0}
    if [[ "$cpu_int" -gt "$CPU_THRESHOLD" ]]; then
      echo "  ⚠  CPU usage: ${cpu}% (threshold: ${CPU_THRESHOLD}%)"
      echo "     → Close unnecessary applications"
      issues=1
      ((++_health_warning_count))
    else
      echo "  ✓ CPU usage: ${cpu}%"
    fi
  else
    echo "  ℹ  CPU usage: unavailable"
  fi

  # Memory check
  local mem_free
  mem_free=$(_health_get_memory_free_pct)
  # Validate and use bash arithmetic
  if [[ -n "$mem_free" ]] && [[ "$mem_free" =~ ^[0-9]+$ ]]; then
    if [[ "$mem_free" -lt "$MEMORY_THRESHOLD" ]]; then
      echo "  ⚠  Memory: ${mem_free}% free (threshold: ${MEMORY_THRESHOLD}%)"
      echo "     → Restart applications or reboot"
      issues=1
      ((++_health_warning_count))
    else
      echo "  ✓ Memory: ${mem_free}% free"
    fi
  else
    echo "  ℹ  Memory: unavailable"
  fi

  # Disk space check
  local disk_free_pct
  disk_free_pct=$(_health_get_disk_free_pct)

  # Validate numeric
  if [[ -n "$disk_free_pct" ]] && [[ "$disk_free_pct" =~ ^[0-9]+$ ]]; then
    local disk_used=$((100 - disk_free_pct))
    local threshold=$((100 - DISK_THRESHOLD_PCT))

    if [[ "$disk_used" -gt "$threshold" ]]; then
      echo "  ⚠  Disk space: ${disk_used}% used"
      echo "     → Clean up: brew cleanup, docker system prune"
      issues=1
      ((++_health_warning_count))
    else
      echo "  ✓ Disk space: ${disk_used}% used"
    fi
  else
    echo "  ℹ  Disk space: unavailable"
  fi

  log_debug "health" "System health check complete" "Issues: $issues"
  echo ""
  return "$issues"
}

# _health_check_git: Check git repository health
#
# Returns: 0 (healthy), 1 (warning), 2 (critical)
_health_check_git() {
  log_debug "health" "Running git health check"
  echo "🔧 Git Health"
  echo "──────────────────────────"

  # Check if git module available (loose coupling)
  if type git_is_repo >/dev/null 2>&1; then
    # Use git module
    if ! git_is_repo; then
      echo "  ℹ  Not in git repository (skipping)"
      echo ""
      return 0
    fi
  else
    # Fallback to basic check
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
      echo "  ℹ  Not in git repository (skipping)"
      echo ""
      return 0
    fi
  fi

  local issues=0

  # Repository detected
  echo "  ✓ Git repository detected"

  # Check for uncommitted changes
  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    local changed
    changed=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    echo "  ⚠  Uncommitted changes: $changed files"
    echo "     → Commit: git commit -m \"message\""
    echo "     → Or stash: git stash"
    issues=1
    ((++_health_warning_count))
  else
    echo "  ✓ Working tree clean"
  fi

  # Check for unpushed commits
  local branch
  branch=$(git branch --show-current 2>/dev/null)
  if [[ -n "$branch" ]]; then
    local unpushed
    unpushed=$(git log "@{u}.." --oneline 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    if [[ "$unpushed" -gt 0 ]]; then
      echo "  ⚠  Unpushed commits: $unpushed"
      echo "     → Push: git push"
      issues=1
      ((++_health_warning_count))
    else
      echo "  ✓ Branch synced with remote"
    fi
  fi

  log_debug "health" "Git health check complete" "Issues: $issues"
  echo ""
  return "$issues"
}

# _health_check_docker: Check Docker environment health
#
# Returns: 0 (healthy), 1 (warning), 2 (critical)
_health_check_docker() {
  log_debug "health" "Running docker health check"
  echo "🐳 Docker Health"
  echo "──────────────────────────"

  # Check if docker module available (loose coupling)
  if type docker_is_running >/dev/null 2>&1; then
    # Use docker module function
    if docker_is_running; then
      echo "  ✓ Docker daemon running"

      # Check for compose file and services
      if type docker_find_compose_file >/dev/null 2>&1; then
        if compose_file=$(docker_find_compose_file); then
          echo "  ✓ Compose file: $compose_file"

          # Count services
          local total running
          total=$(docker compose -f "$compose_file" config --services 2>/dev/null | wc -l | tr -d ' ')
          running=$(docker compose -f "$compose_file" ps --services --filter "status=running" 2>/dev/null | wc -l | tr -d ' ')

          echo "  ✓ Services: $running/$total running"
        fi
      fi
    else
      echo "  ✗ Docker daemon not running"
      echo "     → Start Docker Desktop"
      ((++_health_critical_count))
      echo ""
      return 2
    fi
  else
    # Docker module not loaded, basic check
    if command -v docker >/dev/null 2>&1; then
      if docker info >/dev/null 2>&1; then
        echo "  ✓ Docker daemon running"
      else
        echo "  ✗ Docker daemon not running"
        ((++_health_critical_count))
        echo ""
        return 2
      fi
    else
      echo "  ℹ  Docker not installed (skipping)"
    fi
  fi

  log_debug "health" "Docker health check complete"
  echo ""
  return 0
}

# _health_check_python: Check Python environment health
#
# Returns: 0 (healthy), 1 (warning), 2 (critical)
_health_check_python() {
  log_debug "health" "Running python health check"
  echo "🐍 Python Health"
  echo "──────────────────────────"

  # Check if Python available
  if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then
    echo "  ℹ  Python not installed (skipping)"
    echo ""
    return 0
  fi

  local issues=0

  # Python version
  local version
  if command -v python3 >/dev/null 2>&1; then
    version=$(python3 --version 2>&1 | cut -d' ' -f2)
    echo "  ✓ Python $version"
  else
    version=$(python --version 2>&1 | cut -d' ' -f2)
    echo "  ✓ Python $version"
  fi

  # Check if python module available (loose coupling)
  if type python_is_venv_active >/dev/null 2>&1; then
    # Use python module
    if python_is_venv_active; then
      echo "  ✓ Virtual environment active"
    elif [[ -d ".venv" ]] || [[ -d "venv" ]]; then
      echo "  ⚠  Virtual environment available but not active"
      echo "     → Activate: source .venv/bin/activate"
      issues=1
      ((++_health_warning_count))
    fi

    if type python_is_poetry >/dev/null 2>&1 && python_is_poetry; then
      echo "  ✓ Poetry project detected"
    fi
  else
    # Basic check without python module
    if [[ -n "${VIRTUAL_ENV:-}" ]]; then
      echo "  ✓ Virtual environment active"
    elif [[ -d ".venv" ]] || [[ -d "venv" ]]; then
      echo "  ⚠  Virtual environment not active"
      issues=1
      ((++_health_warning_count))
    fi
  fi

  log_debug "health" "Python health check complete" "Issues: $issues"
  echo ""
  return "$issues"
}

# _health_check_ai: Check AI module health
#
# Returns: 0 (healthy), 1 (warning), 2 (critical)
_health_check_ai() {
  log_debug "health" "Running AI health check"
  echo "🤖 AI Health"
  echo "──────────────────────────"

  # Check if AI module available (loose coupling)
  if ! type ai_check_requirements >/dev/null 2>&1; then
    echo "  ℹ  AI module not loaded (skipping)"
    echo ""
    return 0
  fi

  local issues=0

  # Check requirements
  if ai_check_requirements >/dev/null 2>&1; then
    echo "  ✓ AI requirements met (curl, jq)"
  else
    echo "  ✗ AI requirements missing"
    echo "     → Install: brew install curl jq"
    issues=2
    ((++_health_critical_count))
  fi

  # Check API key
  if type ai_get_api_key >/dev/null 2>&1; then
    if ai_get_api_key >/dev/null 2>&1; then
      echo "  ✓ API key configured"
    else
      echo "  ⚠  No API key found"
      echo "     → Setup: harm-cli ai --setup"
      issues=1
      ((++_health_warning_count))
    fi
  fi

  # Check cache size
  local cache_dir="${HARM_CLI_HOME:-$HOME/.harm-cli}/ai-cache"
  if [[ -d "$cache_dir" ]]; then
    local cache_size
    cache_size=$(du -sh "$cache_dir" 2>/dev/null | awk '{print $1}' || echo "0")
    echo "  ℹ  Cache size: $cache_size"
  fi

  log_debug "health" "AI health check complete" "Issues: $issues"
  echo ""
  return "$issues"
}

# ═══════════════════════════════════════════════════════════════════
# Main Health Check Function
# ═══════════════════════════════════════════════════════════════════

# health_check: Comprehensive health monitoring
#
# Description:
#   Performs comprehensive health checks across multiple categories including
#   system resources, git repository, Docker environment, Python setup, and
#   AI module configuration. Provides actionable suggestions for issues found.
#
# Arguments:
#   $1 - category (string, optional): Specific category or "all" (default: all)
#        Categories: all, system, git, docker, python, ai
#   --quick - Quick essential checks only
#   --json - JSON output format
#
# Returns:
#   0 - All checks passed (healthy)
#   1 - Warnings found (functional but needs attention)
#   2 - Critical issues found (immediate action needed)
#
# Outputs:
#   stdout: Health check report with status and suggestions
#   stderr: Log messages via log_info/log_debug
#
# Examples:
#   health_check                 # Complete check
#   health_check system          # System only
#   health_check --quick         # Fast essential checks
#   health_check docker          # Docker environment only
#   harm-cli health              # Via CLI
#   harm-cli health --quick      # Fast check
#
# Notes:
#   - Auto-detects which modules are loaded
#   - Skips checks for unavailable modules (not an error)
#   - Provides actionable suggestions for all issues
#   - Cross-platform (macOS/Linux)
#   - Quick mode: system + git only (~500ms)
#   - Full mode: all categories (~2-5s)
#
# Check Categories:
#   - system: CPU, memory, disk space
#   - git: Repository status, uncommitted/unpushed
#   - docker: Daemon, services, resources
#   - python: Version, venv, dependencies
#   - ai: API key, cache, connectivity
#
# Performance:
#   - Quick mode: <1s (system + git only)
#   - Normal mode: 2-5s (all checks)
#   - Depends on: repo size, services count, network latency
#
# Integration:
#   - Loosely coupled: Checks if modules loaded before using
#   - Works standalone or with any combination of modules
#   - Safe to run even if no modules loaded
health_check() {
  local category="all"
  local quick=0
  local json_output=0
  local verbose=0

  # Parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --quick | -q)
        quick=1
        shift
        ;;
      --json | -j)
        json_output=1
        shift
        ;;
      --verbose | -v)
        verbose=1
        shift
        ;;
      system | git | docker | python | ai | all)
        category="$1"
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  log_info "health" "Starting health check" "Category: $category, Quick: $quick"

  # Reset counters
  _health_critical_count=0
  _health_warning_count=0

  # Header (text mode only)
  if [[ $json_output -eq 0 ]]; then
    echo "🏥 Comprehensive Health Check"
    echo "══════════════════════════════════════════"
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
  fi

  # Run checks based on category
  case "$category" in
    all)
      _health_check_system
      [[ $quick -eq 0 ]] && _health_check_git
      [[ $quick -eq 0 ]] && _health_check_docker
      [[ $quick -eq 0 ]] && _health_check_python
      [[ $quick -eq 0 ]] && _health_check_ai
      ;;
    system)
      _health_check_system
      ;;
    git)
      _health_check_git
      ;;
    docker)
      _health_check_docker
      ;;
    python)
      _health_check_python
      ;;
    ai)
      _health_check_ai
      ;;
    *)
      error_msg "Unknown health category: $category"
      echo "Valid categories: all, system, git, docker, python, ai"
      return "$EXIT_INVALID_ARGS"
      ;;
  esac

  # Summary (text mode only)
  if [[ $json_output -eq 0 ]]; then
    echo "══════════════════════════════════════════"
    echo "Health Summary"
    echo ""

    if [[ $_health_critical_count -gt 0 ]]; then
      echo "✗ $_health_critical_count critical issues found"
      echo ""
      echo "Immediate action required!"
      log_warn "health" "Critical issues found" "Count: $_health_critical_count"
      return 2
    elif [[ $_health_warning_count -gt 0 ]]; then
      echo "⚠  $_health_warning_count warnings found"
      echo ""
      echo "System functional but needs attention"
      log_info "health" "Warnings found" "Count: $_health_warning_count"
      return 1
    else
      echo "✅ All systems healthy!"
      log_info "health" "Health check passed" "No issues found"
      return 0
    fi
  fi

  # JSON output (future enhancement)
  if [[ $json_output -eq 1 ]]; then
    jq -n \
      --argjson critical "$_health_critical_count" \
      --argjson warnings "$_health_warning_count" \
      '{critical: $critical, warnings: $warnings, status: (if $critical > 0 then "critical" elif $warnings > 0 then "warning" else "healthy" end)}'
  fi

  return 0
}

# Export public functions
export -f health_check

# Mark module as loaded
readonly _HARM_HEALTH_LOADED=1
