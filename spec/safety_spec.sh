#!/usr/bin/env bash
# ShellSpec tests for safety module
# Note: Many safety tests removed as they require interactive user input or live filesystem access

Describe 'lib/safety.sh'
Include spec/helpers/env.sh

BeforeAll 'source "$ROOT/lib/safety.sh" 2>/dev/null || true'

Describe 'Module loading'
It 'sources without errors'
The variable _HARM_SAFETY_LOADED should equal 1
End
End
End
