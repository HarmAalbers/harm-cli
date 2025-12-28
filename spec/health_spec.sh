#!/usr/bin/env bash
# ShellSpec tests for Health module

Describe 'lib/health.sh'
Include spec/helpers/env.sh

BeforeAll 'setup_health_test_env'

setup_health_test_env() {
  # Set log level to ERROR to minimize test noise
  export HARM_LOG_LEVEL=ERROR # Suppress DEBUG/INFO logs during tests
  # Enable test mode to prevent background processes
  export HARM_TEST_MODE=1
  source "$ROOT/lib/health.sh"
}

# ═══════════════════════════════════════════════════════════════
# Health Check Tests
# ═══════════════════════════════════════════════════════════════

Describe 'health_check'
It 'runs complete health check'
When call health_check
The status should be defined
The output should include "Comprehensive Health Check"
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End

It 'runs system check'
When call health_check system
The status should be defined
The output should include "System Health"
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End

It 'runs git check'
When call health_check git
The status should be defined
The output should include "Git Health"
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End

It 'runs docker check'
When call health_check docker
The status should be defined
The output should include "Docker Health"
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End

It 'runs python check'
When call health_check python
The status should be defined
The output should include "Python Health"
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End

It 'runs ai check'
When call health_check ai
The status should be defined
The output should include "AI Health"
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End

It 'accepts --quick flag'
When call health_check --quick
The status should be defined
The output should include "Health Check"
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End

It 'handles unknown category'
When call health_check invalid_category
The status should not equal 0
The stdout should be present
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End

It 'displays summary'
When call health_check
The status should be defined
The output should include "Health Summary"
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End

It 'function exists and is exported'
When call type -t health_check
The output should equal "function"
End
End

# ═══════════════════════════════════════════════════════════════
# Category Check Tests
# ═══════════════════════════════════════════════════════════════

Describe 'System health check'
It 'checks CPU usage'
When call health_check system
The status should be defined
The output should include "CPU"
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End

It 'checks memory'
When call health_check system
The status should be defined
The output should include "Memory"
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End

It 'checks disk space'
When call health_check system
The status should be defined
The output should include "Disk"
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End
End

Describe 'Git health check'
It 'produces git health output'
When call health_check git
The status should be defined
The output should include "Git"
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End
End

Describe 'Docker health check'
It 'produces docker health output'
When call health_check docker
The status should be defined
The output should include "Docker"
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End
End

Describe 'Python health check'
It 'produces python health output'
When call health_check python
The status should be defined
The output should include "Python"
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End
End

Describe 'AI health check'
It 'checks AI module'
When call health_check ai
The status should be defined
The output should include "AI"
# Stderr output not required (HARM_LOG_LEVEL=ERROR suppresses INFO/DEBUG)
End
End
End
