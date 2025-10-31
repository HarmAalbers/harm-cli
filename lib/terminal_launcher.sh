#!/usr/bin/env bash
# shellcheck shell=bash
# lib/terminal_launcher.sh - Terminal window launcher for harm-cli
#
# Provides functions to open new terminal windows with commands
# across different operating systems and terminal emulators.
#
# Functions:
#   terminal_detect           - Detect OS and available terminal emulators
#   terminal_open_macos       - Open new Terminal.app/iTerm2 window on macOS
#   terminal_open_linux       - Open new terminal window on Linux
#   terminal_launch_script    - Launch a script in a new terminal window
#   terminal_is_remote        - Check if running in remote/SSH session
#
# Supported Terminals:
#   macOS:   Terminal.app, iTerm2
#   Linux:   gnome-terminal, konsole, xterm, xfce4-terminal

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading
[[ -n "${_LIB_TERMINAL_LAUNCHER_LOADED:-}" ]] && return 0
declare -g _LIB_TERMINAL_LAUNCHER_LOADED=1

# Source dependencies
TERMINAL_LAUNCHER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${TERMINAL_LAUNCHER_DIR}/common.sh"
# shellcheck source=lib/error.sh
source "${TERMINAL_LAUNCHER_DIR}/error.sh"
# shellcheck source=lib/logging.sh
source "${TERMINAL_LAUNCHER_DIR}/logging.sh"

# Global variables for detected terminal
declare -g TERMINAL_OS=""
declare -g TERMINAL_EMULATOR=""

# terminal_detect: Detect OS and available terminal emulators
#
# Description:
#   Detects the operating system and sets TERMINAL_OS and TERMINAL_EMULATOR
#   global variables for later use.
#
# Returns:
#   0 - Detection successful
#   1 - Unsupported OS or no terminal found
#
# Outputs:
#   Sets: TERMINAL_OS (macos|linux)
#         TERMINAL_EMULATOR (terminal|iterm2|gnome-terminal|konsole|xterm|xfce4-terminal)
terminal_detect() {
  # Detect OS
  case "$(uname -s)" in
    Darwin)
      TERMINAL_OS="macos"

      # Check for iTerm2 first (preferred on macOS)
      if [[ -d "/Applications/iTerm.app" ]]; then
        TERMINAL_EMULATOR="iterm2"
      elif [[ -d "/Applications/Utilities/Terminal.app" ]]; then
        TERMINAL_EMULATOR="terminal"
      else
        log_error "terminal" "No terminal emulator found on macOS"
        return 1
      fi
      ;;

    Linux)
      TERMINAL_OS="linux"

      # Detect available terminal emulator (in order of preference)
      if command -v gnome-terminal >/dev/null 2>&1; then
        TERMINAL_EMULATOR="gnome-terminal"
      elif command -v konsole >/dev/null 2>&1; then
        TERMINAL_EMULATOR="konsole"
      elif command -v xfce4-terminal >/dev/null 2>&1; then
        TERMINAL_EMULATOR="xfce4-terminal"
      elif command -v xterm >/dev/null 2>&1; then
        TERMINAL_EMULATOR="xterm"
      else
        log_error "terminal" "No terminal emulator found on Linux"
        return 1
      fi
      ;;

    *)
      log_error "terminal" "Unsupported OS: $(uname -s)"
      return 1
      ;;
  esac

  log_debug "terminal" "Detected terminal" "OS=$TERMINAL_OS, Emulator=$TERMINAL_EMULATOR"
  return 0
}

# terminal_is_remote: Check if running in remote/SSH session
#
# Description:
#   Detects if the current shell is running over SSH or other remote connection.
#   Used to disable GUI terminal features when not appropriate.
#
# Returns:
#   0 - Running remotely (SSH session)
#   1 - Running locally
terminal_is_remote() {
  # Check SSH environment variables
  if [[ -n "${SSH_CLIENT:-}" ]] || [[ -n "${SSH_TTY:-}" ]] || [[ -n "${SSH_CONNECTION:-}" ]]; then
    log_debug "terminal" "Remote session detected" "SSH"
    return 0
  fi

  # Check if parent process is sshd
  if ps -o comm= -p $PPID 2>/dev/null | grep -q sshd; then
    log_debug "terminal" "Remote session detected" "sshd parent"
    return 0
  fi

  return 1
}

# terminal_open_macos: Open new Terminal.app or iTerm2 window on macOS
#
# Description:
#   Opens a new macOS terminal window and executes the given command.
#   Uses osascript to launch Terminal.app or iTerm2.
#
# Arguments:
#   $@ - Command and arguments to execute in new window
#
# Returns:
#   0 - Terminal opened successfully
#   1 - Failed to open terminal
#
# Examples:
#   terminal_open_macos bash -c "echo Hello; read"
#   terminal_open_macos "$HOME/script.sh" --arg1 --arg2
terminal_open_macos() {
  [[ $# -eq 0 ]] && {
    log_error "terminal" "No command provided"
    return 1
  }

  # Create a temporary wrapper script to avoid osascript quoting issues
  local temp_script
  temp_script=$(mktemp /tmp/harm-cli-launch.XXXXXX.sh)

  # Write the command to temp script with proper shebang
  cat > "$temp_script" <<'SCRIPT_HEADER'
#!/usr/bin/env bash
set -Eeuo pipefail
exec
SCRIPT_HEADER

  # Add each argument properly quoted
  for arg in "$@"; do
    printf ' %q' "$arg" >> "$temp_script"
  done

  # Make executable
  chmod +x "$temp_script"

  case "$TERMINAL_EMULATOR" in
    iterm2)
      # iTerm2 - execute the wrapper script
      osascript >/dev/null 2>&1 <<EOF
tell application "iTerm"
  activate
  create window with default profile
  tell current session of current window
    write text "${temp_script}; rm ${temp_script}"
  end tell
end tell
EOF
      ;;

    terminal)
      # Terminal.app - execute the wrapper script
      osascript >/dev/null 2>&1 <<EOF
tell application "Terminal"
  activate
  do script "${temp_script}; rm ${temp_script}"
end tell
EOF
      ;;

    *)
      log_error "terminal" "Unknown macOS terminal emulator: $TERMINAL_EMULATOR"
      rm -f "$temp_script"
      return 1
      ;;
  esac

  local status=$?
  if [[ $status -eq 0 ]]; then
    log_info "terminal" "Opened new terminal window" "emulator=$TERMINAL_EMULATOR, wrapper=$temp_script"
  else
    log_error "terminal" "Failed to open terminal" "status=$status"
    rm -f "$temp_script"
  fi

  return $status
}

# terminal_open_linux: Open new terminal window on Linux
#
# Description:
#   Opens a new Linux terminal window and executes the given command.
#   Supports multiple terminal emulators.
#
# Arguments:
#   $@ - Command and arguments to execute in new window
#
# Returns:
#   0 - Terminal opened successfully
#   1 - Failed to open terminal
#
# Examples:
#   terminal_open_linux bash -c "echo Hello; read"
#   terminal_open_linux "$HOME/script.sh" --arg1 --arg2
terminal_open_linux() {
  [[ $# -eq 0 ]] && {
    log_error "terminal" "No command provided"
    return 1
  }

  local command="$*"

  case "$TERMINAL_EMULATOR" in
    gnome-terminal)
      # GNOME Terminal - open new window
      gnome-terminal -- bash -c "$command" >/dev/null 2>&1 &
      ;;

    konsole)
      # KDE Konsole - open new window
      konsole -e bash -c "$command" >/dev/null 2>&1 &
      ;;

    xfce4-terminal)
      # XFCE Terminal - open new window
      xfce4-terminal -e "bash -c '$command'" >/dev/null 2>&1 &
      ;;

    xterm)
      # XTerm - open new window
      xterm -e bash -c "$command" >/dev/null 2>&1 &
      ;;

    *)
      log_error "terminal" "Unknown Linux terminal emulator: $TERMINAL_EMULATOR"
      return 1
      ;;
  esac

  local status=$?
  if [[ $status -eq 0 ]]; then
    log_info "terminal" "Opened new terminal window" "emulator=$TERMINAL_EMULATOR"
  else
    log_error "terminal" "Failed to open terminal" "status=$status"
  fi

  return $status
}

# terminal_launch_script: Launch a script in a new terminal window
#
# Description:
#   Main entry point for launching scripts in new terminal windows.
#   Automatically detects OS/terminal and handles remote sessions.
#
# Arguments:
#   $1 - Script path (must exist and be executable)
#   $@ - Additional arguments to pass to script
#
# Returns:
#   0 - Script launched successfully
#   1 - Failed to launch (remote session, no terminal, or error)
#
# Examples:
#   terminal_launch_script /path/to/script.sh --arg1 --arg2
#   terminal_launch_script "$ROOT_DIR/libexec/break-timer-ui.sh" --duration 300
terminal_launch_script() {
  local script_path="${1:?terminal_launch_script requires script path}"
  shift

  # Check if script exists
  if [[ ! -f "$script_path" ]]; then
    log_error "terminal" "Script not found" "path=$script_path"
    error_msg "Script not found: $script_path"
    return 1
  fi

  # Make script executable if not already
  if [[ ! -x "$script_path" ]]; then
    log_warn "terminal" "Script not executable, fixing" "path=$script_path"
    chmod +x "$script_path" 2>/dev/null || {
      log_error "terminal" "Cannot make script executable" "path=$script_path"
      return 1
    }
  fi

  # Check for remote session
  if terminal_is_remote; then
    log_warn "terminal" "Remote session detected, cannot open GUI terminal"
    warn_msg "Cannot open new terminal window in SSH session"
    warn_msg "Run the script manually: $script_path $*"
    return 1
  fi

  # Detect terminal if not already done
  if [[ -z "$TERMINAL_OS" ]] || [[ -z "$TERMINAL_EMULATOR" ]]; then
    terminal_detect || {
      log_error "terminal" "Terminal detection failed"
      error_msg "No suitable terminal emulator found"
      return 1
    }
  fi

  # Launch based on OS (pass script and arguments separately)
  case "$TERMINAL_OS" in
    macos)
      terminal_open_macos "$script_path" "$@"
      ;;
    linux)
      terminal_open_linux "$script_path" "$@"
      ;;
    *)
      log_error "terminal" "Unsupported OS: $TERMINAL_OS"
      return 1
      ;;
  esac
}

# Export functions
export -f terminal_detect terminal_is_remote terminal_open_macos terminal_open_linux terminal_launch_script
