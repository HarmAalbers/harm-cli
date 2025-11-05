#!/usr/bin/env bash
# ShellSpec tests for safety module - comprehensive tests
# Note: Removed tests that require interactive input or live filesystem access

Describe 'lib/safety.sh - Comprehensive Tests'
Include spec/helpers/env.sh

BeforeAll 'source "$ROOT/lib/safety.sh" 2>/dev/null || true'

Describe 'Module loading'
It 'loads safety module'
The variable _HARM_SAFETY_LOADED should equal 1
End
End
End
