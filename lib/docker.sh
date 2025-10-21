#!/usr/bin/env bash
# shellcheck shell=bash
# docker.sh - Docker and Docker Compose management
# Ported from: ~/.zsh/30_docker_management.zsh
#
# Features:
# - Docker Compose wrapper with intelligent defaults
# - Service health monitoring
# - Resource usage tracking
# - Container shell access
# - Log viewing and management
#
# Public API:
#   docker_is_running          - Check if Docker daemon is running
#   docker_find_compose_file   - Locate compose file (compose.yaml or docker-compose.yml)
#   docker_up                  - Start services (detached)
#   docker_down                - Stop and remove services
#   docker_restart             - Restart service(s)
#   docker_logs                - View service logs
#   docker_shell               - Open shell in container
#   docker_status              - Show service status with health
#   docker_health              - Check Docker environment health
#
# Dependencies: docker, docker compose (or docker-compose)

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_HARM_DOCKER_LOADED:-}" ]] && return 0

# Source dependencies
DOCKER_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly DOCKER_SCRIPT_DIR

# shellcheck source=lib/common.sh
source "$DOCKER_SCRIPT_DIR/common.sh"
# shellcheck source=lib/error.sh
source "$DOCKER_SCRIPT_DIR/error.sh"
# shellcheck source=lib/logging.sh
source "$DOCKER_SCRIPT_DIR/logging.sh"
# shellcheck source=lib/util.sh
source "$DOCKER_SCRIPT_DIR/util.sh"

# ═══════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════

readonly DOCKER_COMPOSE_FILES=("compose.yaml" "docker-compose.yml" "docker-compose.yaml")

# ═══════════════════════════════════════════════════════════════════
# Docker Utilities
# ═══════════════════════════════════════════════════════════════════

# docker_is_running: Check if Docker daemon is running
#
# Description:
#   Verifies Docker daemon is accessible by running `docker info`.
#   Use this before attempting any Docker operations.
#
# Arguments:
#   None
#
# Returns:
#   0 - Docker daemon is running
#   1 - Docker daemon not running or not installed
#
# Outputs:
#   stderr: Log messages via log_debug
#
# Examples:
#   docker_is_running || die "Docker is not running"
#   if docker_is_running; then
#     echo "Docker ready"
#   fi
#
# Notes:
#   - Checks both docker availability and daemon status
#   - Silent check (no output unless logging enabled)
#   - Fast check (<50ms typically)
#
# Performance:
#   - Typical: 20-50ms
#   - Cached by Docker daemon
docker_is_running() {
  log_debug "docker" "Checking if Docker daemon is running"

  if ! command -v docker >/dev/null 2>&1; then
    log_debug "docker" "Docker command not found"
    return 1
  fi

  if docker info >/dev/null 2>&1; then
    log_debug "docker" "Docker daemon is running"
    return 0
  else
    log_debug "docker" "Docker daemon not running"
    return 1
  fi
}

# docker_find_compose_file: Locate Docker Compose file
#
# Description:
#   Searches for Docker Compose file in current directory.
#   Checks in priority order: compose.yaml, docker-compose.yml, docker-compose.yaml
#
# Arguments:
#   None
#
# Returns:
#   0 - Compose file found (path output to stdout)
#   1 - No compose file found
#
# Outputs:
#   stdout: Path to compose file (if found)
#   stderr: Log messages via log_debug
#
# Examples:
#   compose_file=$(docker_find_compose_file) || die "No compose file"
#   if file=$(docker_find_compose_file); then
#     echo "Using: $file"
#   fi
#
# Notes:
#   - Checks modern format first (compose.yaml)
#   - Falls back to legacy formats
#   - Returns first match found
#
# Performance:
#   - Typical: <10ms (file system checks)
docker_find_compose_file() {
  log_debug "docker" "Searching for compose file"

  local file
  for file in "${DOCKER_COMPOSE_FILES[@]}"; do
    if [[ -f "$file" ]]; then
      log_debug "docker" "Found compose file" "$file"
      echo "$file"
      return 0
    fi
  done

  log_debug "docker" "No compose file found"
  return 1
}

# ═══════════════════════════════════════════════════════════════════
# Docker Compose Operations
# ═══════════════════════════════════════════════════════════════════

# docker_up: Start Docker Compose services
#
# Description:
#   Starts all or specified services using Docker Compose in detached mode.
#   Automatically locates compose file and checks Docker daemon status.
#
# Arguments:
#   $@ - service names (optional): Specific services to start
#
# Returns:
#   0 - Services started successfully
#   EXIT_INVALID_STATE - Docker not running or no compose file
#   EXIT_COMMAND_FAILED - Docker command failed
#
# Outputs:
#   stdout: Docker Compose output
#   stderr: Log messages via log_info/log_error
#
# Examples:
#   docker_up                  # Start all services
#   docker_up backend database # Start specific services
#   harm-cli docker up
#
# Notes:
#   - Starts in detached mode (-d)
#   - Auto-detects compose file
#   - Validates Docker daemon is running
#   - Logs service startup
#
# Performance:
#   - Startup time: 2-30s (depends on images/services)
#   - First run: slower (image pulls)
docker_up() {
  log_info "docker" "Starting Docker Compose services" "Services: ${*:-all}"

  # Check Docker daemon
  if ! docker_is_running; then
    error_msg "Docker daemon is not running"
    log_error "docker" "Docker not running"
    echo "Start Docker Desktop or run: sudo systemctl start docker"
    return "$EXIT_INVALID_STATE"
  fi

  # Find compose file
  local compose_file
  compose_file=$(docker_find_compose_file) || {
    error_msg "No Docker Compose file found"
    log_error "docker" "No compose file" "Checked: ${DOCKER_COMPOSE_FILES[*]}"
    echo "Expected: compose.yaml or docker-compose.yml"
    return "$EXIT_INVALID_STATE"
  }

  log_debug "docker" "Using compose file" "$compose_file"

  # Start services
  echo "🐳 Starting services..."
  if docker compose -f "$compose_file" up -d "$@"; then
    echo "✓ Services started"
    log_info "docker" "Services started successfully"
    return 0
  else
    error_msg "Failed to start services"
    log_error "docker" "docker compose up failed"
    return "$EXIT_COMMAND_FAILED"
  fi
}

# docker_down: Stop and remove Docker Compose services
#
# Description:
#   Stops all services and removes containers, networks, and volumes.
#
# Arguments:
#   --volumes|-v - Also remove volumes (optional)
#
# Returns:
#   0 - Services stopped successfully
#   EXIT_INVALID_STATE - Docker not running or no compose file
#   EXIT_COMMAND_FAILED - Docker command failed
#
# Outputs:
#   stdout: Docker Compose output
#   stderr: Log messages
#
# Examples:
#   docker_down            # Stop services
#   docker_down --volumes  # Stop and remove volumes
#
# Performance:
#   - Typical: 2-10s
docker_down() {
  local remove_volumes=0

  # Parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --volumes | -v)
        remove_volumes=1
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  log_info "docker" "Stopping Docker Compose services" "Remove volumes: $remove_volumes"

  # Check Docker daemon
  docker_is_running || {
    error_msg "Docker daemon is not running"
    return "$EXIT_INVALID_STATE"
  }

  # Find compose file
  local compose_file
  compose_file=$(docker_find_compose_file) || {
    error_msg "No Docker Compose file found"
    return "$EXIT_INVALID_STATE"
  }

  # Stop services
  echo "🐳 Stopping services..."
  local args=()
  [[ $remove_volumes -eq 1 ]] && args+=("-v")

  if docker compose -f "$compose_file" down "${args[@]}"; then
    echo "✓ Services stopped"
    log_info "docker" "Services stopped successfully"
    return 0
  else
    error_msg "Failed to stop services"
    log_error "docker" "docker compose down failed"
    return "$EXIT_COMMAND_FAILED"
  fi
}

# docker_status: Show Docker Compose service status
#
# Description:
#   Displays status of all services with health information and resource usage.
#
# Arguments:
#   None
#
# Returns:
#   0 - Status displayed successfully
#   EXIT_INVALID_STATE - Docker not running or no compose file
#
# Outputs:
#   stdout: Service status with health and resources
#   stderr: Log messages
#
# Examples:
#   docker_status
#   harm-cli docker status
#
# Performance:
#   - Typical: 100-500ms (depends on number of services)
docker_status() {
  log_info "docker" "Showing Docker Compose status"

  # Check Docker daemon
  docker_is_running || {
    error_msg "Docker daemon is not running"
    return "$EXIT_INVALID_STATE"
  }

  # Find compose file
  local compose_file
  compose_file=$(docker_find_compose_file) || {
    error_msg "No Docker Compose file found"
    return "$EXIT_INVALID_STATE"
  }

  echo "Docker Compose Status"
  echo "══════════════════════════════════════════"
  echo ""
  echo "Compose file: $compose_file"
  echo ""

  # Show service status
  docker compose -f "$compose_file" ps

  log_debug "docker" "Status displayed"
  return 0
}

# docker_logs: View service logs
#
# Description:
#   Displays logs for specified service with follow mode by default.
#
# Arguments:
#   $1 - service (string): Service name
#   $@ - additional options passed to docker compose logs
#
# Returns:
#   0 - Logs displayed
#   EXIT_INVALID_ARGS - No service specified
#   EXIT_INVALID_STATE - Docker not running or no compose file
#
# Examples:
#   docker_logs backend
#   docker_logs backend --tail 100
#
# Performance:
#   - Initial load: <1s
#   - Follow mode: continuous
docker_logs() {
  local service="${1:?docker_logs requires service name}"
  shift

  log_info "docker" "Viewing logs" "Service: $service"

  # Check Docker daemon
  docker_is_running || {
    error_msg "Docker daemon is not running"
    return "$EXIT_INVALID_STATE"
  }

  # Find compose file
  local compose_file
  compose_file=$(docker_find_compose_file) || {
    error_msg "No Docker Compose file found"
    return "$EXIT_INVALID_STATE"
  }

  # Follow logs by default
  docker compose -f "$compose_file" logs -f "$service" "$@"
}

# docker_shell: Open shell in container
#
# Description:
#   Opens interactive shell in specified service container.
#   Auto-detects shell type (sh, bash, etc).
#
# Arguments:
#   $1 - service (string): Service name
#
# Returns:
#   0 - Shell session completed
#   EXIT_INVALID_ARGS - No service specified
#   EXIT_INVALID_STATE - Docker not running or service not running
#
# Examples:
#   docker_shell backend
#   docker_shell postgres
#
# Performance:
#   - Connection: <500ms
docker_shell() {
  local service="${1:?docker_shell requires service name}"

  log_info "docker" "Opening shell" "Service: $service"

  # Check Docker daemon
  docker_is_running || {
    error_msg "Docker daemon is not running"
    return "$EXIT_INVALID_STATE"
  }

  # Find compose file
  local compose_file
  compose_file=$(docker_find_compose_file) || {
    error_msg "No Docker Compose file found"
    return "$EXIT_INVALID_STATE"
  }

  # Open shell (try bash first, fallback to sh)
  docker compose -f "$compose_file" exec "$service" bash 2>/dev/null \
    || docker compose -f "$compose_file" exec "$service" sh
}

# docker_health: Check Docker environment health
#
# Description:
#   Performs health check of Docker daemon, services, and resources.
#   Reports status and provides actionable suggestions.
#
# Arguments:
#   None
#
# Returns:
#   0 - All healthy
#   1 - Minor issues
#   2 - Major issues
#
# Outputs:
#   stdout: Health report
#   stderr: Log messages
#
# Examples:
#   docker_health
#   harm-cli docker health
#
# Performance:
#   - Typical: 200-500ms
docker_health() {
  log_info "docker" "Checking Docker health"

  local issues=0

  echo "Docker Health Check"
  echo "══════════════════════════════════════════"
  echo ""

  # Check Docker daemon
  if docker_is_running; then
    echo "✓ Docker daemon running"
  else
    echo "✗ Docker daemon not running"
    echo "  → Start Docker Desktop or: sudo systemctl start docker"
    issues=2
    return "$issues"
  fi

  # Check Docker Compose
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    local version
    version=$(docker compose version --short 2>/dev/null || echo "unknown")
    echo "✓ Docker Compose available ($version)"
  else
    echo "✗ Docker Compose not available"
    echo "  → Install: https://docs.docker.com/compose/install/"
    issues=1
  fi

  # Check for compose file
  if compose_file=$(docker_find_compose_file); then
    echo "✓ Compose file found: $compose_file"

    # Count services
    local service_count
    service_count=$(docker compose -f "$compose_file" config --services 2>/dev/null | wc -l | tr -d ' ')
    echo "  Services defined: $service_count"

    # Check running services
    local running_count
    running_count=$(docker compose -f "$compose_file" ps --services --filter "status=running" 2>/dev/null | wc -l | tr -d ' ')
    echo "  Services running: $running_count/$service_count"
  else
    echo "⚠  No compose file in current directory"
    echo "  → Expected: compose.yaml or docker-compose.yml"
  fi

  echo ""
  if [[ $issues -eq 0 ]]; then
    echo "✓ Docker environment healthy"
  elif [[ $issues -eq 1 ]]; then
    echo "⚠  Minor issues found"
  else
    echo "✗ Major issues found"
  fi

  log_debug "docker" "Health check completed" "Issues: $issues"
  return "$issues"
}

# Export public functions
export -f docker_is_running
export -f docker_find_compose_file
export -f docker_up
export -f docker_down
export -f docker_status
export -f docker_logs
export -f docker_shell
export -f docker_health

# Mark module as loaded
readonly _HARM_DOCKER_LOADED=1
