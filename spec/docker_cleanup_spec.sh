#!/usr/bin/env bash
# shellcheck disable=SC2317
# SC2317: Mock functions called indirectly via export -f (false positive)
# ShellSpec tests for Docker cleanup functionality

Describe 'lib/docker.sh - docker_cleanup'
Include spec/helpers/env.sh

BeforeAll 'export HARM_LOG_LEVEL=ERROR && source "$ROOT/lib/docker.sh"'

# ═══════════════════════════════════════════════════════════════
# Test Setup - Mock Docker Commands
# ═══════════════════════════════════════════════════════════════

setup_docker_mock_running() {
  # Mock: Docker daemon is running
  docker() {
    case "$1" in
      "info")
        return 0
        ;;
      "system")
        if [[ "$2" == "df" ]]; then
          cat <<'EOF'
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          5         2         1.5GB     500MB (33%)
Containers      3         1         50MB      25MB (50%)
Build Cache     10        0         2GB       2GB (100%)
EOF
          return 0
        fi
        ;;
      "container")
        if [[ "$2" == "prune" ]]; then
          echo "Deleted Containers:"
          echo "abc123"
          echo "Total reclaimed space: 25MB"
          return 0
        fi
        ;;
      "image")
        if [[ "$2" == "prune" ]]; then
          echo "deleted: sha256:abc123"
          echo "Total reclaimed space: 500MB"
          return 0
        fi
        ;;
      "network")
        if [[ "$2" == "prune" ]]; then
          echo "Deleted Networks:"
          echo "test-network"
          return 0
        fi
        ;;
      "builder")
        if [[ "$2" == "prune" ]]; then
          echo "Total: 2GB"
          return 0
        fi
        ;;
      *)
        return 1
        ;;
    esac
  }
  export -f docker
}

setup_docker_mock_not_running() {
  # Mock: Docker daemon not running
  docker() {
    case "$1" in
      "info")
        return 1
        ;;
      *)
        return 1
        ;;
    esac
  }
  export -f docker

  # Override docker_is_running for this test
  docker_is_running() {
    return 1
  }
  export -f docker_is_running
}

setup_docker_mock_no_resources() {
  # Mock: Docker running but no resources to clean
  docker() {
    case "$1" in
      "info")
        return 0
        ;;
      "system")
        if [[ "$2" == "df" ]]; then
          echo "TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE"
          echo "Images          0         0         0B        0B"
          return 0
        fi
        ;;
      "container" | "image" | "network" | "builder")
        # All prune commands return empty (nothing to clean)
        echo ""
        return 0
        ;;
      *)
        return 1
        ;;
    esac
  }
  export -f docker
}

setup_docker_mock_df_fails() {
  docker() {
    case "$1" in
      "info") return 0 ;;
      "system")
        if [[ "$2" == "df" ]]; then
          return 1 # Simulate df failure
        fi
        ;;
      "container")
        if [[ "$2" == "prune" ]]; then
          echo "Total reclaimed space: 25MB"
          return 0
        fi
        ;;
      "image")
        if [[ "$2" == "prune" ]]; then
          echo "Total reclaimed space: 500MB"
          return 0
        fi
        ;;
      "network")
        if [[ "$2" == "prune" ]]; then
          echo "Deleted Networks:"
          echo "test-network"
          return 0
        fi
        ;;
      "builder")
        if [[ "$2" == "prune" ]]; then
          echo "Total: 2GB"
          return 0
        fi
        ;;
      *) return 0 ;;
    esac
  }
  export -f docker
}

# ═══════════════════════════════════════════════════════════════
# Scenario 1: Precondition Validation
# ═══════════════════════════════════════════════════════════════

Describe 'docker_cleanup preconditions'
Context 'when Docker daemon is not running'
BeforeEach setup_docker_mock_not_running

It 'exits with EXIT_INVALID_STATE'
When call docker_cleanup
The status should equal "$EXIT_INVALID_STATE"
The output should include "Start Docker Desktop"
The error should include "Docker daemon is not running"
End

It 'prints error message to stderr'
When call docker_cleanup
The status should equal "$EXIT_INVALID_STATE"
The error should include "Docker daemon is not running"
The output should include "Start Docker Desktop"
End

It 'provides helpful suggestion'
When call docker_cleanup
The status should equal "$EXIT_INVALID_STATE"
The output should include "Start Docker Desktop"
The error should include "Docker daemon is not running"
End
End

Context 'when Docker daemon is running'
BeforeEach setup_docker_mock_running

It 'returns success exit code'
When call docker_cleanup
The status should equal 0
The output should include "Docker Cleanup"
The output should include "Cleanup complete"
End

It 'proceeds with cleanup'
When call docker_cleanup
The output should include "Docker Cleanup"
The output should include "Cleanup complete"
End
End
End

# ═══════════════════════════════════════════════════════════════
# Scenario 2: Cleanup Operations
# ═══════════════════════════════════════════════════════════════

Describe 'docker_cleanup operations'
BeforeEach setup_docker_mock_running

Context 'container cleanup'
It 'removes containers stopped for >24h'
When call docker_cleanup
The output should include "Removing stopped containers"
The output should include "Total reclaimed space: 25MB"
End
End

Context 'image cleanup'
It 'removes dangling images'
When call docker_cleanup
The output should include "Removing dangling images"
The output should include "Total reclaimed space: 500MB"
End

It 'removes old unused images (>30 days)'
When call docker_cleanup
The output should include "Removing unused images"
End
End

Context 'network cleanup'
It 'removes unused networks'
When call docker_cleanup
The output should include "Removing unused networks"
The output should include "test-network"
End
End

Context 'build cache cleanup'
It 'removes build cache'
When call docker_cleanup
The output should include "Removing build cache"
The output should include "Total: 2GB"
End
End
End

# ═══════════════════════════════════════════════════════════════
# Scenario 3: Output Verification
# ═══════════════════════════════════════════════════════════════

Describe 'docker_cleanup output'
BeforeEach setup_docker_mock_running

Context 'progress messages'
It 'displays cleanup header with emoji'
When call docker_cleanup
The output should include "🧹 Docker Cleanup"
End

It 'shows progress for each step'
When call docker_cleanup
The output should include "🗑️  Removing stopped containers"
The output should include "🗑️  Removing dangling images"
The output should include "🗑️  Removing unused networks"
The output should include "🗑️  Removing build cache"
End

It 'displays completion message'
When call docker_cleanup
The output should include "✅ Cleanup complete!"
End
End

Context 'disk usage reporting'
It 'shows disk usage before cleanup'
When call docker_cleanup
The output should include "Disk usage before cleanup"
End

It 'shows disk usage after cleanup'
When call docker_cleanup
The output should include "Disk usage after cleanup"
End
End

Context 'volume safety warning'
It 'displays volume preservation notice'
When call docker_cleanup
The output should include "Volumes were NOT touched"
End

It 'provides volume inspection commands'
When call docker_cleanup
The output should include "docker volume ls"
The output should include "docker volume inspect"
The output should include "docker volume prune"
End

It 'warns about data loss risk'
When call docker_cleanup
The output should include "CAUTION: Data loss risk"
End
End
End

# ═══════════════════════════════════════════════════════════════
# Scenario 4: Edge Cases
# ═══════════════════════════════════════════════════════════════

Describe 'docker_cleanup edge cases'
Context 'when no resources to clean'
BeforeEach setup_docker_mock_no_resources

It 'completes successfully'
When call docker_cleanup
The status should equal 0
The output should include "Docker Cleanup"
The output should include "Cleanup complete"
End

It 'shows appropriate messages for empty results'
When call docker_cleanup
The output should include "No old containers to remove"
The output should include "No dangling images to remove"
End
End

Context 'when disk usage command fails'
BeforeEach setup_docker_mock_df_fails

It 'continues cleanup despite df failure'
When call docker_cleanup
The status should equal 0
The output should include "Docker Cleanup"
The output should include "Cleanup complete"
End

It 'shows warning about df failure'
When call docker_cleanup
The output should include "Unable to fetch disk stats"
End
End
End

# ═══════════════════════════════════════════════════════════════
# Scenario 5: Integration Test
# ═══════════════════════════════════════════════════════════════

Describe 'docker_cleanup full workflow'
BeforeEach setup_docker_mock_running

Context 'complete cleanup execution'
It 'runs all cleanup steps in order'
When call docker_cleanup
The status should equal 0
The line 1 of output should include "Docker Cleanup"
The output should include "Disk usage before cleanup"
The output should include "Removing stopped containers"
The output should include "Removing dangling images"
The output should include "Removing unused networks"
The output should include "Removing unused images"
The output should include "Removing build cache"
The output should include "Disk usage after cleanup"
The output should include "Cleanup complete"
The output should include "Volumes were NOT touched"
End
End
End
End
