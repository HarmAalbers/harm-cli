#!/usr/bin/env bash
# ShellSpec tests for GCloud module

Describe 'lib/gcloud.sh'
Include spec/helpers/env.sh

BeforeAll 'setup_gcloud_test_env'

setup_gcloud_test_env() {
  export HARM_LOG_LEVEL=ERROR # Suppress DEBUG/INFO logs during tests
  source "$ROOT/lib/gcloud.sh"
}

# ═══════════════════════════════════════════════════════════════
# GCloud Utilities Tests
# ═══════════════════════════════════════════════════════════════

Describe 'gcloud_is_installed'
It 'function exists and is exported'
When call type -t gcloud_is_installed
The output should equal "function"
End

It 'is callable'
When call gcloud_is_installed
The status should be defined
End
End

Describe 'gcloud_status'
It 'shows GCloud SDK status'
When call gcloud_status
The status should be defined
The output should include "Google Cloud SDK Status"
End

It 'provides helpful information'
# Shows either installation or configuration info
When call gcloud_status
The status should be defined
The output should not be blank
The output should include "GCloud SDK"
End

It 'function exists and is exported'
When call type -t gcloud_status
The output should equal "function"
End
End
End
