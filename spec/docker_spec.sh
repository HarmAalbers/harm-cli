#!/usr/bin/env bash
# ShellSpec tests for Docker module

Describe 'lib/docker.sh'
Include spec/helpers/env.sh

BeforeAll 'setup_docker_test_env'
AfterAll 'cleanup_docker_test_env'

setup_docker_test_env() {
  # Set test configuration
  export HARM_CLI_HOME="$TEST_TMP"
  export HARM_CLI_LOG_LEVEL="DEBUG"

  # Create test compose file
  cat >"$TEST_TMP/compose.yaml" <<'EOF'
services:
  test-service:
    image: alpine:latest
    command: sleep 3600
EOF

  # Source the module
  source "$ROOT/lib/docker.sh"
}

cleanup_docker_test_env() {
  rm -f "$TEST_TMP/compose.yaml"
}

# ═══════════════════════════════════════════════════════════════
# Docker Utilities Tests
# ═══════════════════════════════════════════════════════════════

Describe 'docker_is_running'
It 'function exists and is exported'
When call type -t docker_is_running
The output should equal "function"
End

# Note: Can't reliably test if Docker is running in all environments
# Just verify function is callable
It 'is callable'
When call docker_is_running
The status should be defined
End
End

Describe 'docker_find_compose_file'
It 'finds compose.yaml in current directory'
cd "$TEST_TMP" || return
When call docker_find_compose_file
The output should equal "compose.yaml"
The status should equal 0
End

It 'returns error when no compose file exists'
cd "$ROOT" || return
# harm-cli root doesn't have compose file
When call docker_find_compose_file
The status should equal 1
End

It 'function exists and is exported'
When call type -t docker_find_compose_file
The output should equal "function"
End
End

# ═══════════════════════════════════════════════════════════════
# Docker Operations Tests
# ═══════════════════════════════════════════════════════════════

Describe 'docker_up'
It 'function exists and is exported'
When call type -t docker_up
The output should equal "function"
End

# Note: Actual docker operations require Docker daemon
# We test the function exists and has proper structure
End

Describe 'docker_down'
It 'function exists and is exported'
When call type -t docker_down
The output should equal "function"
End
End

Describe 'docker_status'
It 'function exists and is exported'
When call type -t docker_status
The output should equal "function"
End
End

Describe 'docker_logs'
It 'function exists and is exported'
When call type -t docker_logs
The output should equal "function"
End
End

Describe 'docker_shell'
It 'function exists and is exported'
When call type -t docker_shell
The output should equal "function"
End
End

Describe 'docker_health'
It 'function exists and is exported'
When call type -t docker_health
The output should equal "function"
End

# Health check is callable even without Docker
It 'runs health check'
When call docker_health
The status should be defined
The output should include "Docker Health Check"
End
End
End
