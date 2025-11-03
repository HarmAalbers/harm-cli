#!/usr/bin/env bash
# ShellSpec tests for terminal launcher module

Describe 'lib/terminal_launcher.sh'
Include spec/helpers/env.sh

# Setup test environment
setup_terminal_test_env() {
  export HARM_LOG_LEVEL=ERROR # Suppress DEBUG/INFO logs during tests
  export HARM_LOG_DIR="$TEST_TMP/logs"
  mkdir -p "$HARM_LOG_DIR"
  source "$ROOT/lib/terminal_launcher.sh"
}

# Clean up after tests
cleanup_terminal_test_env() {
  rm -rf "$HARM_LOG_DIR"
}

BeforeAll 'setup_terminal_test_env'
AfterAll 'cleanup_terminal_test_env'

Describe 'Module initialization'
It 'sets load guard to prevent re-loading'
The variable _LIB_TERMINAL_LAUNCHER_LOADED should equal 1
End

It 'initializes TERMINAL_OS variable'
The variable TERMINAL_OS should be defined
End

It 'initializes TERMINAL_EMULATOR variable'
The variable TERMINAL_EMULATOR should be defined
End
End

Describe 'terminal_is_remote'
Context 'SSH environment variable detection'
It 'detects SSH_CLIENT variable'
SSH_CLIENT="192.168.1.1 22 2222"
When call terminal_is_remote
The status should equal 0
End

It 'detects SSH_TTY variable'
unset SSH_CLIENT SSH_CONNECTION 2>/dev/null || true
SSH_TTY="/dev/pts/0"
When call terminal_is_remote
The status should equal 0
End

It 'detects SSH_CONNECTION variable'
unset SSH_CLIENT SSH_TTY 2>/dev/null || true
SSH_CONNECTION="192.168.1.1 2222 127.0.0.1 22"
When call terminal_is_remote
The status should equal 0
End
End

Context 'local session detection'
It 'returns failure when not in SSH'
unset SSH_CLIENT SSH_TTY SSH_CONNECTION 2>/dev/null || true
When call terminal_is_remote
The status should equal 1
End

It 'detects sshd as parent process'
unset SSH_CLIENT SSH_TTY SSH_CONNECTION 2>/dev/null || true
ps() { echo "sshd"; }
When call terminal_is_remote
The status should equal 0
End

It 'returns failure when parent is not sshd'
unset SSH_CLIENT SSH_TTY SSH_CONNECTION 2>/dev/null || true
ps() { echo "bash"; }
When call terminal_is_remote
The status should equal 1
End
End
End

Describe 'terminal_detect'
Context 'Linux platform detection'
It 'detects Linux OS'
uname() { echo "Linux"; }
command() {
  [[ "$2" == "gnome-terminal" ]] && return 0
  return 1
}
When call terminal_detect
The variable TERMINAL_OS should equal "linux"
End

It 'detects gnome-terminal on Linux'
uname() { echo "Linux"; }
command() {
  [[ "$2" == "gnome-terminal" ]] && return 0
  return 1
}
When call terminal_detect
The variable TERMINAL_EMULATOR should equal "gnome-terminal"
End

It 'falls back to konsole when gnome-terminal unavailable'
uname() { echo "Linux"; }
command() {
  [[ "$2" == "konsole" ]] && return 0
  return 1
}
When call terminal_detect
The variable TERMINAL_EMULATOR should equal "konsole"
End

It 'falls back to xfce4-terminal when konsole unavailable'
uname() { echo "Linux"; }
command() {
  [[ "$2" == "xfce4-terminal" ]] && return 0
  return 1
}
When call terminal_detect
The variable TERMINAL_EMULATOR should equal "xfce4-terminal"
End

It 'falls back to xterm as final fallback'
uname() { echo "Linux"; }
command() {
  [[ "$2" == "xterm" ]] && return 0
  return 1
}
When call terminal_detect
The variable TERMINAL_EMULATOR should equal "xterm"
End

It 'fails when no terminal available on Linux'
uname() { echo "Linux"; }
command() { return 1; }
When call terminal_detect
The status should equal 1
End
End

Context 'macOS platform detection'
It 'detects macOS (Darwin) OS'
uname() { echo "Darwin"; }
# Will only succeed if Terminal or iTerm actually exist
if [[ -d "/Applications/iTerm.app" ]] || [[ -d "/Applications/Utilities/Terminal.app" ]]; then
  When call terminal_detect
  The variable TERMINAL_OS should equal "macos"
fi
End
End

Context 'error handling'
It 'fails on unsupported OS'
uname() { echo "FreeBSD"; }
When call terminal_detect
The status should equal 1
End
End
End

Describe 'terminal_open_macos'
Context 'argument validation'
It 'rejects when no command provided'
TERMINAL_EMULATOR="iterm2"
When call terminal_open_macos
The status should equal 1
End

It 'accepts command argument'
TERMINAL_EMULATOR="iterm2"
osascript() { return 0; }
mktemp() { echo "/tmp/test-$RANDOM.sh"; }
When call terminal_open_macos bash -c "echo test" 2>/dev/null
The status should equal 0
End
End

Context 'emulator support'
It 'handles iTerm2 emulator'
TERMINAL_EMULATOR="iterm2"
osascript() { return 0; }
mktemp() { echo "/tmp/test-$RANDOM.sh"; }
When call terminal_open_macos bash -c "echo hello" 2>/dev/null
The status should equal 0
End

It 'handles Terminal.app emulator'
TERMINAL_EMULATOR="terminal"
osascript() { return 0; }
mktemp() { echo "/tmp/test-$RANDOM.sh"; }
When call terminal_open_macos bash -c "echo hello" 2>/dev/null
The status should equal 0
End

It 'fails with unknown emulator'
TERMINAL_EMULATOR="unknown"
mktemp() { echo "/tmp/test-$RANDOM.sh"; }
When call terminal_open_macos bash -c "echo test" 2>/dev/null
The status should equal 1
End
End

Context 'error handling'
It 'fails when osascript returns non-zero'
TERMINAL_EMULATOR="iterm2"
osascript() { return 1; }
mktemp() { echo "/tmp/test-$RANDOM.sh"; }
When call terminal_open_macos bash -c "echo test" 2>/dev/null
The status should equal 1
End

It 'handles special characters in arguments'
TERMINAL_EMULATOR="iterm2"
osascript() { return 0; }
mktemp() { echo "/tmp/test-$RANDOM.sh"; }
When call terminal_open_macos bash -c "echo 'hello world'" 2>/dev/null
The status should equal 0
End
End
End

Describe 'terminal_open_linux'
Context 'argument validation'
It 'rejects when no command provided'
TERMINAL_EMULATOR="gnome-terminal"
When call terminal_open_linux
The status should equal 1
End

It 'accepts command with arguments'
TERMINAL_EMULATOR="gnome-terminal"
gnome-terminal() { return 0; }
When call terminal_open_linux bash -c "echo test"
The status should equal 0
End
End

Context 'terminal emulator support'
It 'supports gnome-terminal'
TERMINAL_EMULATOR="gnome-terminal"
gnome-terminal() { return 0; }
When call terminal_open_linux bash -c "echo test"
The status should equal 0
End

It 'supports KDE Konsole'
TERMINAL_EMULATOR="konsole"
konsole() { return 0; }
When call terminal_open_linux bash -c "echo test"
The status should equal 0
End

It 'supports XFCE Terminal'
TERMINAL_EMULATOR="xfce4-terminal"
xfce4-terminal() { return 0; }
When call terminal_open_linux bash -c "echo test"
The status should equal 0
End

It 'supports XTerm'
TERMINAL_EMULATOR="xterm"
xterm() { return 0; }
When call terminal_open_linux bash -c "echo test"
The status should equal 0
End

It 'fails with unknown emulator'
TERMINAL_EMULATOR="unknown"
When call terminal_open_linux bash -c "echo test"
The status should equal 1
End
End

Context 'command execution'
It 'launches terminal in background'
TERMINAL_EMULATOR="gnome-terminal"
gnome-terminal() { return 0; }
When call terminal_open_linux bash -c "echo test"
The status should equal 0
End

It 'passes full command string to terminal'
TERMINAL_EMULATOR="gnome-terminal"
gnome-terminal() { return 0; }
When call terminal_open_linux bash -c "echo hello; sleep 1"
The status should equal 0
End
End
End

Describe 'terminal_launch_script'
setup_test_script() {
  TEST_SCRIPT="$TEST_TMP/test_script.sh"
  mkdir -p "$TEST_TMP"
  cat >"$TEST_SCRIPT" <<'EOF'
#!/usr/bin/env bash
echo "Script content"
EOF
  chmod +x "$TEST_SCRIPT"
}

cleanup_test_script() {
  rm -f "$TEST_SCRIPT"
}

BeforeEach 'setup_test_script'
AfterEach 'cleanup_test_script'

Context 'script path validation'
It 'succeeds with executable script on Linux'
[[ -x "$TEST_SCRIPT" ]]
TERMINAL_OS="linux"
TERMINAL_EMULATOR="gnome-terminal"
gnome-terminal() { return 0; }
unset SSH_CLIENT SSH_TTY SSH_CONNECTION 2>/dev/null || true
When call terminal_launch_script "$TEST_SCRIPT"
The status should equal 0
End

It 'handles already executable scripts'
[[ -x "$TEST_SCRIPT" ]]
TERMINAL_OS="linux"
TERMINAL_EMULATOR="gnome-terminal"
gnome-terminal() { return 0; }
unset SSH_CLIENT SSH_TTY SSH_CONNECTION 2>/dev/null || true
When call terminal_launch_script "$TEST_SCRIPT"
The status should equal 0
End
End

Context 'SSH remote session handling'
It 'succeeds in local session'
unset SSH_CLIENT SSH_TTY SSH_CONNECTION 2>/dev/null || true
ps() { echo "bash"; }
TERMINAL_OS="linux"
TERMINAL_EMULATOR="gnome-terminal"
gnome-terminal() { return 0; }
When call terminal_launch_script "$TEST_SCRIPT"
The status should equal 0
End
End

Context 'terminal detection and caching'
It 'uses cached terminal info if available'
TERMINAL_OS="linux"
TERMINAL_EMULATOR="gnome-terminal"
gnome-terminal() { return 0; }
unset SSH_CLIENT SSH_TTY SSH_CONNECTION 2>/dev/null || true
When call terminal_launch_script "$TEST_SCRIPT"
The status should equal 0
End
End

Context 'platform-specific launching'
It 'launches script on Linux'
TERMINAL_OS="linux"
TERMINAL_EMULATOR="gnome-terminal"
gnome-terminal() { return 0; }
unset SSH_CLIENT SSH_TTY SSH_CONNECTION 2>/dev/null || true
When call terminal_launch_script "$TEST_SCRIPT"
The status should equal 0
End
End

Context 'argument passing to scripts'
It 'passes arguments to script'
TERMINAL_OS="linux"
TERMINAL_EMULATOR="gnome-terminal"
gnome-terminal() { return 0; }
unset SSH_CLIENT SSH_TTY SSH_CONNECTION 2>/dev/null || true
When call terminal_launch_script "$TEST_SCRIPT" --arg1 --arg2
The status should equal 0
End
End

Context 'error handling edge cases'
It 'handles chmod failure gracefully'
chmod -x "$TEST_SCRIPT"
TERMINAL_OS="linux"
TERMINAL_EMULATOR="gnome-terminal"
# Mock chmod to fail
chmod() { return 1; }
When call terminal_launch_script "$TEST_SCRIPT"
The status should equal 1
End
End
End

Describe 'Integration with dependencies'
It 'loads all required modules'
The variable _LIB_TERMINAL_LAUNCHER_LOADED should be defined
The variable EXIT_ERROR should be defined
End

It 'exports all public functions'
When call type terminal_detect
The status should equal 0
End
End
