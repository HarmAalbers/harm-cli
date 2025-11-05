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
readonly DOCKER_COMPOSE_OVERRIDES=(
  "compose.override.yaml"
  "compose.override.yml"
  "docker-compose.override.yml"
  "docker-compose.override.yaml"
)

# Cleanup configuration (configurable via environment)
readonly DOCKER_CLEANUP_CONTAINER_AGE="${HARM_DOCKER_CLEANUP_CONTAINERS:-24h}"
readonly DOCKER_CLEANUP_IMAGE_AGE="${HARM_DOCKER_CLEANUP_IMAGES:-720h}" # 30 days

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

# docker_find_all_compose_files: Find base compose file and all override files
#
# Description:
#   Locates the base Docker Compose file and any override files that exist.
#   Supports standard override files and environment-specific overrides.
#
# Arguments:
#   None
#
# Returns:
#   0 - At least base compose file found
#   1 - No base compose file found
#
# Outputs:
#   stdout: Space-separated list of compose files (base + overrides)
#   stderr: Log messages via log_debug
#
# Examples:
#   files=$(docker_find_all_compose_files)
#   # Returns: "compose.yaml compose.override.yaml compose.dev.yaml"
#
# Notes:
#   - Always returns base file first
#   - Checks for standard overrides (*.override.*)
#   - Checks for environment-specific files based on $HARM_DOCKER_ENV
#   - Environment files: compose.dev.yaml, compose.prod.yaml, compose.test.yaml
#
# Environment Variables:
#   HARM_DOCKER_ENV - Environment name (dev, prod, test) for environment-specific overrides
docker_find_all_compose_files() {
  log_debug "docker" "Searching for all compose files"

  # Find base compose file
  local base_file
  base_file=$(docker_find_compose_file) || return 1

  local files=("$base_file")

  # Check for ALL standard override files (Docker Compose accepts mixing conventions)
  # Docker Compose will use any override file it finds, regardless of naming convention
  local override_file
  for override_file in "${DOCKER_COMPOSE_OVERRIDES[@]}"; do
    if [[ -f "$override_file" ]]; then
      log_debug "docker" "Found override file" "$override_file"
      files+=("$override_file")
    fi
  done

  # Check for environment-specific override (e.g., compose.dev.yaml)
  if [[ -n "${HARM_DOCKER_ENV:-}" ]]; then
    local env_file
    # Try modern naming (compose.ENV.yaml)
    env_file="compose.${HARM_DOCKER_ENV}.yaml"
    if [[ -f "$env_file" ]]; then
      log_debug "docker" "Found environment override" "$env_file"
      files+=("$env_file")
    else
      # Try legacy naming (docker-compose.ENV.yml)
      env_file="docker-compose.${HARM_DOCKER_ENV}.yml"
      if [[ -f "$env_file" ]]; then
        log_debug "docker" "Found environment override" "$env_file"
        files+=("$env_file")
      fi
    fi
  fi

  # Output all files
  echo "${files[@]}"
  log_debug "docker" "Found ${#files[@]} compose file(s)" "${files[*]}"
  return 0
}

# docker_build_compose_flags: Build -f flags for docker compose command
#
# Description:
#   Finds all compose files (base + overrides) and builds -f flags array.
#   This eliminates code duplication between docker_up and docker_down.
#
# Arguments:
#   None
#
# Returns:
#   0 - Success
#   1 - No compose file found
#
# Outputs:
#   stdout: One flag per line (-f flag, then filename)
#   stderr: Log messages
#
# Example:
#   local compose_flags=()
#   while IFS= read -r flag; do
#     compose_flags+=("$flag")
#   done < <(docker_build_compose_flags) || return "$EXIT_INVALID_STATE"
docker_build_compose_flags() {
  local compose_files
  compose_files=$(docker_find_all_compose_files) || return 1

  local files_array
  read -ra files_array <<<"$compose_files"

  # Validate that all files actually exist before passing to docker
  local file
  for file in "${files_array[@]}"; do
    if [[ ! -f "$file" ]]; then
      log_error "docker" "Compose file not found" "File: $file"
      error_msg "Compose file not found: $file"
      return 1
    fi
  done

  # Output -f flags (one per line for easy array building)
  for file in "${files_array[@]}"; do
    printf '%s\n' "-f"
    printf '%s\n' "$file"
  done

  return 0
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
#   EXIT_ERROR - Docker command failed
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

# _docker_validate_service_names: Validate Docker Compose service names
#
# SECURITY FIX (HIGH-2): Prevent command injection via malicious service names
#
# Description:
#   Validates that service names contain only safe characters.
#   Prevents command injection attacks via crafted service names.
#
# Arguments:
#   $@ - Service names to validate
#
# Returns:
#   0 - All service names valid
#   EXIT_INVALID_ARGS - Invalid service name detected
#
# Security:
#   - Service names must match: ^[a-zA-Z0-9_-]+$
#   - Blocks: semicolons, pipes, quotes, spaces, special chars
#   - Prevents attacks like: harm-cli docker up "; rm -rf /"
#
# Examples:
#   _docker_validate_service_names backend database  # OK
#   _docker_validate_service_names "app; malicious"  # BLOCKED
_docker_validate_service_names() {
  local service
  for service in "$@"; do
    if [[ ! "$service" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      log_error "docker" "Invalid service name rejected" "Service: $service"
      die "Invalid service name: $service (only alphanumeric, dash, underscore allowed)" "$EXIT_INVALID_ARGS"
    fi
  done
  log_debug "docker" "Service names validated" "Count: $#"
}

docker_up() {
  log_info "docker" "Starting Docker Compose services" "Services: ${*:-all}"

  # Check Docker daemon
  if ! docker_is_running; then
    error_msg "Docker daemon is not running"
    log_error "docker" "Docker not running"
    echo "Start Docker Desktop or run: sudo systemctl start docker"
    return "$EXIT_INVALID_STATE"
  fi

  # Build compose flags using helper function
  local compose_flags=()
  while IFS= read -r flag; do
    compose_flags+=("$flag")
  done < <(docker_build_compose_flags) || {
    error_msg "No Docker Compose file found"
    log_error "docker" "No compose file" "Checked: ${DOCKER_COMPOSE_FILES[*]}"
    echo "Expected: compose.yaml or docker-compose.yml"
    return "$EXIT_INVALID_STATE"
  }

  # Get file list for logging/display
  local compose_files
  compose_files=$(docker_find_all_compose_files)
  local files_array
  read -ra files_array <<<"$compose_files"

  log_debug "docker" "Using compose files" "${files_array[*]}"

  # Show which files are being used if more than just base
  if ((${#files_array[@]} > 1)); then
    echo "📋 Using compose files: ${files_array[*]}"
  fi

  # Start services
  echo "🐳 Starting services..."

  # SECURITY: Validate service names before passing to docker compose
  if [[ $# -gt 0 ]]; then
    _docker_validate_service_names "$@"
  fi

  if docker compose "${compose_flags[@]}" up -d "$@"; then
    echo "✓ Services started"
    log_info "docker" "Services started successfully"
    return 0
  else
    error_msg "Failed to start services"
    log_error "docker" "docker compose up failed"
    return "$EXIT_ERROR"
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
#   EXIT_ERROR - Docker command failed
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

  # Build compose flags using helper function
  local compose_flags=()
  while IFS= read -r flag; do
    compose_flags+=("$flag")
  done < <(docker_build_compose_flags) || {
    error_msg "No Docker Compose file found"
    return "$EXIT_INVALID_STATE"
  }

  # Stop services
  echo "🐳 Stopping services..."
  local args=()
  [[ $remove_volumes -eq 1 ]] && args+=("-v")

  if docker compose "${compose_flags[@]}" down "${args[@]}"; then
    echo "✓ Services stopped"
    log_info "docker" "Services stopped successfully"
    return 0
  else
    error_msg "Failed to stop services"
    log_error "docker" "docker compose down failed"
    return "$EXIT_ERROR"
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

  # Find all compose files (base + overrides)
  local compose_files
  compose_files=$(docker_find_all_compose_files) || {
    error_msg "No Docker Compose file found"
    return "$EXIT_INVALID_STATE"
  }

  local files_array
  read -ra files_array <<<"$compose_files"

  # Build compose flags
  local compose_flags=()
  while IFS= read -r flag; do
    compose_flags+=("$flag")
  done < <(docker_build_compose_flags)

  echo "Docker Compose Status"
  echo "══════════════════════════════════════════"
  echo ""
  if ((${#files_array[@]} > 1)); then
    echo "Compose files: ${files_array[*]}"
  else
    echo "Compose file: ${files_array[0]}"
  fi
  echo ""

  # Show service status
  docker compose "${compose_flags[@]}" ps

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

# ═══════════════════════════════════════════════════════════════════
# Docker Cleanup Operations (Internal Helpers)
# ═══════════════════════════════════════════════════════════════════

# docker_cleanup_containers: Remove stopped containers
docker_cleanup_containers() {
  echo "🗑️  Removing stopped containers (>${DOCKER_CLEANUP_CONTAINER_AGE} old)..."
  if output=$(docker container prune --filter "until=${DOCKER_CLEANUP_CONTAINER_AGE}" -f 2>&1); then
    if [[ "$output" == *"Total reclaimed space"* ]]; then
      echo "$output" | grep -E "(Deleted|Total reclaimed)"
    else
      echo "✓ No old containers to remove"
    fi
  fi
}

# docker_cleanup_dangling_images: Remove dangling images
docker_cleanup_dangling_images() {
  echo "🗑️  Removing dangling images..."
  if output=$(docker image prune -f 2>&1); then
    if [[ "$output" == *"Total reclaimed space"* ]]; then
      echo "$output" | grep -E "(deleted:|Total reclaimed)"
    else
      echo "✓ No dangling images to remove"
    fi
  fi
}

# docker_cleanup_networks: Remove unused networks
docker_cleanup_networks() {
  echo "🗑️  Removing unused networks..."
  if output=$(docker network prune -f 2>&1); then
    if [[ "$output" == *"Deleted Networks"* ]]; then
      echo "$output"
    else
      echo "✓ No unused networks to remove"
    fi
  fi
}

# docker_cleanup_old_images: Remove old unused images
docker_cleanup_old_images() {
  echo "🗑️  Removing unused images (>${DOCKER_CLEANUP_IMAGE_AGE} old)..."
  if output=$(docker image prune -a --filter "until=${DOCKER_CLEANUP_IMAGE_AGE}" -f 2>&1); then
    if [[ "$output" == *"Total reclaimed space"* ]]; then
      echo "$output" | grep -E "(untagged:|deleted:|Total reclaimed)"
    else
      echo "✓ No old images to remove"
    fi
  fi
}

# docker_cleanup_build_cache: Remove build cache
docker_cleanup_build_cache() {
  echo "🗑️  Removing build cache..."
  if output=$(docker builder prune -f 2>&1); then
    if [[ "$output" == *"Total:"* ]]; then
      echo "$output" | tail -1
    else
      echo "✓ No build cache to remove"
    fi
  fi
}

# docker_show_disk_usage: Show Docker disk usage
docker_show_disk_usage() {
  local label="$1"
  echo "📊 Disk usage $label:"
  if ! docker system df 2>/dev/null; then
    local msg="Unable to fetch disk stats"
    [[ "$label" == "before cleanup" ]] && msg="$msg (continuing anyway...)"
    echo "⚠️  $msg"
  fi
  echo ""
}

# ═══════════════════════════════════════════════════════════════════
# Docker Cleanup (Public API)
# ═══════════════════════════════════════════════════════════════════

# docker_cleanup: Safe Docker resource cleanup
#
# Description:
#   Performs comprehensive Docker cleanup in a safe, stepwise manner.
#   Removes stopped containers, dangling images, unused networks, old images, and build cache.
#   Never touches volumes automatically to prevent data loss.
#
# Arguments:
#   None
#
# Returns:
#   0 - Cleanup completed successfully
#   EXIT_INVALID_STATE - Docker not running
#
# Outputs:
#   stdout: Progress messages and space reclaimed summary
#   stderr: Log messages
#
# Examples:
#   docker_cleanup
#   harm-cli docker cleanup
#
# Notes:
#   - Shows disk usage before and after cleanup
#   - Removes containers stopped for >24h
#   - Removes images older than 30 days (unused)
#   - Cleans all build cache (safe to rebuild)
#   - NEVER removes volumes (manual review required)
#   - Safe for automated/scheduled execution
#
# Performance:
#   - Typical: 5-30s (depends on resources to clean)
docker_cleanup() {
  log_info "docker" "Starting Docker cleanup"

  # Check Docker daemon
  if ! docker_is_running; then
    error_msg "Docker daemon is not running"
    log_error "docker" "Docker not running"
    echo "Start Docker Desktop or run: sudo systemctl start docker"
    return "$EXIT_INVALID_STATE"
  fi

  echo "🧹 Docker Cleanup"
  echo "══════════════════════════════════════════"
  echo ""

  # Show disk usage before cleanup
  docker_show_disk_usage "before cleanup"

  # Run cleanup operations
  docker_cleanup_containers
  echo ""

  docker_cleanup_dangling_images
  echo ""

  docker_cleanup_networks
  echo ""

  docker_cleanup_old_images
  echo ""

  docker_cleanup_build_cache
  echo ""

  # Show disk usage after cleanup
  docker_show_disk_usage "after cleanup"

  echo "✅ Cleanup complete!"
  echo ""
  echo "💡 Note: Volumes were NOT touched. To review unused volumes, run:"
  echo "   docker volume ls -f 'dangling=true'"
  echo "   docker volume inspect <volume_name>"
  echo "   docker volume prune  # CAUTION: Data loss risk!"

  log_info "docker" "Cleanup completed successfully"
  return 0
}

# Export public functions
export -f docker_is_running
export -f docker_find_compose_file
export -f docker_find_all_compose_files
export -f docker_build_compose_flags
export -f _docker_validate_service_names
export -f docker_up
export -f docker_down
export -f docker_status
export -f docker_logs
export -f docker_shell
export -f docker_health
export -f docker_cleanup
export -f docker_cleanup_containers
export -f docker_cleanup_dangling_images
export -f docker_cleanup_networks
export -f docker_cleanup_old_images
export -f docker_cleanup_build_cache

# Mark module as loaded
readonly _HARM_DOCKER_LOADED=1
