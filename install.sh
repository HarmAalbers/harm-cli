#!/usr/bin/env bash
# harm-cli Smart Installer
# Installs harm-cli with customizable shortcuts and shell integration

set -Eeuo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Script configuration
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
VERSION="$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "unknown")"
readonly VERSION

# Installation paths
HARM_CLI_BIN="$SCRIPT_DIR/bin/harm-cli"
COMPLETIONS_DIR="$SCRIPT_DIR/completions"

# Detect user's shell
USER_SHELL="${SHELL##*/}"
if [[ "$USER_SHELL" == "zsh" ]]; then
  SHELL_RC="$HOME/.zshrc"
elif [[ "$USER_SHELL" == "bash" ]]; then
  SHELL_RC="$HOME/.bashrc"
else
  SHELL_RC="$HOME/.${USER_SHELL}rc"
fi

# ═══════════════════════════════════════════════════════════════
# Configuration Variables (set by prompts or defaults)
# ═══════════════════════════════════════════════════════════════

# Installation mode
INSTALL_MODE="quick" # quick or custom

# Path configuration
LOCAL_BIN="$HOME/.local/bin"
HARM_CLI_HOME="$HOME/.harm-cli"
HARM_LOG_DIR="" # Will be set based on HARM_CLI_HOME if not specified

# Logging configuration
HARM_LOG_LEVEL="INFO"
HARM_LOG_TO_FILE="1"
HARM_LOG_MAX_SIZE_MB="10"
HARM_LOG_MAX_FILES="5"

# AI configuration
HARM_CLI_AI_CACHE_TTL="3600"
HARM_CLI_AI_TIMEOUT="20"
HARM_CLI_AI_MAX_TOKENS="2048"

# Feature flags
HARM_CLI_FORMAT="text"
INSTALL_COMPLETIONS="yes"
ADD_TO_PATH="yes"

# Shortcut style (set by existing prompt)
SHORTCUT_STYLE="4"

# ═══════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════

print_header() {
  echo -e "\n${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${CYAN}║                                                            ║${NC}"
  echo -e "${BOLD}${CYAN}║${NC}  ${BOLD}harm-cli Installer${NC} ${MAGENTA}v${VERSION}${NC}                             ${BOLD}${CYAN}║${NC}"
  echo -e "${BOLD}${CYAN}║                                                            ║${NC}"
  echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}\n"
}

print_step() {
  echo -e "${BOLD}${BLUE}▶${NC} $*"
}

print_success() {
  echo -e "${GREEN}✓${NC} $*"
}

print_warning() {
  echo -e "${YELLOW}⚠${NC} $*"
}

print_error() {
  echo -e "${RED}✗${NC} $*" >&2
}

print_info() {
  echo -e "${CYAN}ℹ${NC} $*"
}

die() {
  print_error "$1"
  exit "${2:-1}"
}

# ═══════════════════════════════════════════════════════════════
# Dependency Checks
# ═══════════════════════════════════════════════════════════════

check_dependencies() {
  print_step "Checking dependencies..."

  local missing=()

  # Required dependencies
  for dep in bash jq git; do
    if command -v "$dep" >/dev/null 2>&1; then
      print_success "$dep installed"
    else
      missing+=("$dep")
      print_error "$dep not found"
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo ""
    print_error "Missing required dependencies: ${missing[*]}"
    echo ""
    echo "Install with:"
    echo "  brew install ${missing[*]}"
    exit 1
  fi

  # Optional dependencies
  echo ""
  print_info "Optional dependencies:"
  for dep in just shellcheck shfmt shellspec; do
    if command -v "$dep" >/dev/null 2>&1; then
      print_success "$dep installed (optional)"
    else
      print_warning "$dep not installed (optional for development)"
    fi
  done
}

# ═══════════════════════════════════════════════════════════════
# Validation Functions
# ═══════════════════════════════════════════════════════════════

validate_log_level() {
  local level="$1"
  case "$level" in
    DEBUG | INFO | WARN | ERROR) return 0 ;;
    *) return 1 ;;
  esac
}

validate_yes_no() {
  local value="$1"
  case "$value" in
    [Yy] | [Yy][Ee][Ss] | "") return 0 ;; # Empty = yes (default)
    [Nn] | [Nn][Oo]) return 0 ;;
    *) return 1 ;;
  esac
}

validate_number() {
  local value="$1"
  [[ "$value" =~ ^[0-9]+$ ]]
}

validate_format() {
  local format="$1"
  case "$format" in
    text | json) return 0 ;;
    *) return 1 ;;
  esac
}

expand_path() {
  local path="$1"
  # Expand ~ to $HOME
  path="${path/#\~/$HOME}"
  echo "$path"
}

# ═══════════════════════════════════════════════════════════════
# Installation Mode Selection
# ═══════════════════════════════════════════════════════════════

prompt_install_mode() {
  echo ""
  print_step "Installation Mode"
  echo ""
  echo -e "  ${BOLD}1) Quick Install${NC} - Use recommended defaults"
  echo -e "     ${CYAN}•${NC} Installs to ~/.local/bin"
  echo -e "     ${CYAN}•${NC} Data in ~/.harm-cli"
  echo -e "     ${CYAN}•${NC} INFO logging level"
  echo -e "     ${CYAN}•${NC} All features enabled"
  echo ""
  echo -e "  ${BOLD}2) Custom Install${NC} - Configure everything"
  echo -e "     ${CYAN}•${NC} Choose your paths"
  echo -e "     ${CYAN}•${NC} Customize logging behavior"
  echo -e "     ${CYAN}•${NC} Configure AI settings"
  echo -e "     ${CYAN}•${NC} Select features"
  echo ""

  while true; do
    read -rp "Enter your choice [1-2] (default: 1): " choice
    choice="${choice:-1}"

    case "$choice" in
      1)
        INSTALL_MODE="quick"
        print_success "Quick Install selected"
        show_quick_install_summary
        break
        ;;
      2)
        INSTALL_MODE="custom"
        print_success "Custom Install selected"
        break
        ;;
      *)
        print_error "Invalid choice. Please enter 1 or 2."
        ;;
    esac
  done
}

show_quick_install_summary() {
  echo ""
  print_info "Quick Install will use these defaults:"
  echo ""
  echo -e "  ${CYAN}Installation:${NC}    $LOCAL_BIN"
  echo -e "  ${CYAN}Data directory:${NC}  $HARM_CLI_HOME"
  echo -e "  ${CYAN}Log directory:${NC}   $HARM_CLI_HOME/logs"
  echo -e "  ${CYAN}Log level:${NC}       $HARM_LOG_LEVEL"
  echo -e "  ${CYAN}Log max size:${NC}    ${HARM_LOG_MAX_SIZE_MB}MB"
  echo -e "  ${CYAN}AI cache TTL:${NC}    ${HARM_CLI_AI_CACHE_TTL}s (1 hour)"
  echo -e "  ${CYAN}Output format:${NC}   $HARM_CLI_FORMAT"
  echo -e "  ${CYAN}Completions:${NC}     Enabled"
  echo ""
}

# ═══════════════════════════════════════════════════════════════
# Configuration Prompts
# ═══════════════════════════════════════════════════════════════

prompt_path_config() {
  echo ""
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  Path Configuration${NC}"
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  echo ""

  # Installation directory
  read -rp "Installation directory (where symlink is created) [$LOCAL_BIN]: " input
  if [[ -n "$input" ]]; then
    LOCAL_BIN="$(expand_path "$input")"
  fi

  # Data directory
  read -rp "Data directory (goals, projects, sessions, cache) [$HARM_CLI_HOME]: " input
  if [[ -n "$input" ]]; then
    HARM_CLI_HOME="$(expand_path "$input")"
  fi

  # Log directory (default to data_dir/logs)
  local default_log_dir="$HARM_CLI_HOME/logs"
  read -rp "Log directory (log files) [$default_log_dir]: " input
  if [[ -n "$input" ]]; then
    HARM_LOG_DIR="$(expand_path "$input")"
  else
    HARM_LOG_DIR="$default_log_dir"
  fi

  print_success "Path configuration complete"
}

prompt_logging_config() {
  echo ""
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  Logging Configuration${NC}"
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  echo ""

  # Log level
  while true; do
    read -rp "Log level (DEBUG=verbose, INFO=normal, WARN=quiet, ERROR=critical) [$HARM_LOG_LEVEL]: " input
    input="${input:-$HARM_LOG_LEVEL}"
    input="${input^^}" # Convert to uppercase

    if validate_log_level "$input"; then
      HARM_LOG_LEVEL="$input"
      break
    else
      print_error "Invalid log level. Must be DEBUG, INFO, WARN, or ERROR."
    fi
  done

  # File logging
  while true; do
    read -rp "Enable file logging? [Y/n]: " input
    input="${input:-Y}"

    if validate_yes_no "$input"; then
      case "$input" in
        [Nn] | [Nn][Oo])
          HARM_LOG_TO_FILE="0"
          print_warning "File logging disabled"
          ;;
        *)
          HARM_LOG_TO_FILE="1"
          ;;
      esac
      break
    else
      print_error "Invalid input. Please enter Y or N."
    fi
  done

  # Log file size (only if file logging enabled)
  if [[ "$HARM_LOG_TO_FILE" == "1" ]]; then
    while true; do
      read -rp "Log file max size in MB [$HARM_LOG_MAX_SIZE_MB]: " input
      input="${input:-$HARM_LOG_MAX_SIZE_MB}"

      if validate_number "$input" && ((input > 0)); then
        HARM_LOG_MAX_SIZE_MB="$input"
        break
      else
        print_error "Invalid size. Must be a positive number."
      fi
    done

    # Number of rotated logs
    while true; do
      read -rp "Number of rotated logs to keep [$HARM_LOG_MAX_FILES]: " input
      input="${input:-$HARM_LOG_MAX_FILES}"

      if validate_number "$input" && ((input >= 0)); then
        HARM_LOG_MAX_FILES="$input"
        break
      else
        print_error "Invalid number. Must be 0 or greater."
      fi
    done
  fi

  print_success "Logging configuration complete"
}

prompt_ai_config() {
  echo ""
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  AI Configuration${NC}"
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  echo ""

  # Cache TTL
  while true; do
    read -rp "AI cache duration in seconds (0=no cache, 3600=1 hour) [$HARM_CLI_AI_CACHE_TTL]: " input
    input="${input:-$HARM_CLI_AI_CACHE_TTL}"

    if validate_number "$input" && ((input >= 0)); then
      HARM_CLI_AI_CACHE_TTL="$input"
      break
    else
      print_error "Invalid duration. Must be 0 or greater."
    fi
  done

  # Request timeout
  while true; do
    read -rp "AI request timeout in seconds [$HARM_CLI_AI_TIMEOUT]: " input
    input="${input:-$HARM_CLI_AI_TIMEOUT}"

    if validate_number "$input" && ((input > 0)); then
      HARM_CLI_AI_TIMEOUT="$input"
      break
    else
      print_error "Invalid timeout. Must be greater than 0."
    fi
  done

  # Max tokens
  while true; do
    read -rp "AI max tokens per request [$HARM_CLI_AI_MAX_TOKENS]: " input
    input="${input:-$HARM_CLI_AI_MAX_TOKENS}"

    if validate_number "$input" && ((input > 0)); then
      HARM_CLI_AI_MAX_TOKENS="$input"
      break
    else
      print_error "Invalid token count. Must be greater than 0."
    fi
  done

  print_success "AI configuration complete"
}

prompt_feature_config() {
  echo ""
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  Feature Configuration${NC}"
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  echo ""

  # Shell completions
  while true; do
    read -rp "Install shell completions? [Y/n]: " input
    input="${input:-Y}"

    if validate_yes_no "$input"; then
      case "$input" in
        [Nn] | [Nn][Oo])
          INSTALL_COMPLETIONS="no"
          ;;
        *)
          INSTALL_COMPLETIONS="yes"
          ;;
      esac
      break
    else
      print_error "Invalid input. Please enter Y or N."
    fi
  done

  # Add to PATH
  while true; do
    read -rp "Add $LOCAL_BIN to PATH? [Y/n]: " input
    input="${input:-Y}"

    if validate_yes_no "$input"; then
      case "$input" in
        [Nn] | [Nn][Oo])
          ADD_TO_PATH="no"
          ;;
        *)
          ADD_TO_PATH="yes"
          ;;
      esac
      break
    else
      print_error "Invalid input. Please enter Y or N."
    fi
  done

  # Default output format
  while true; do
    read -rp "Default output format (text or json) [$HARM_CLI_FORMAT]: " input
    input="${input:-$HARM_CLI_FORMAT}"

    if validate_format "$input"; then
      HARM_CLI_FORMAT="$input"
      break
    else
      print_error "Invalid format. Must be 'text' or 'json'."
    fi
  done

  print_success "Feature configuration complete"
}

# ═══════════════════════════════════════════════════════════════
# Alias Conflict Detection
# ═══════════════════════════════════════════════════════════════

get_aliases_for_style() {
  local style="$1"
  local aliases=()

  case "$style" in
    1) # Minimal
      aliases=("h")
      ;;
    2) # Balanced
      aliases=("work" "goal" "ai" "proj")
      ;;
    3) # Power User
      aliases=("h" "ws" "wo" "ww" "gs" "gg" "ask")
      ;;
    4) # Hybrid
      aliases=("h" "work" "goal" "ai" "proj" "ws" "wo" "ww")
      ;;
  esac

  printf '%s\n' "${aliases[@]}"
}

check_alias_conflicts() {
  local style="$1"
  local conflicts=()

  # Get aliases that would be created
  local proposed_aliases
  mapfile -t proposed_aliases < <(get_aliases_for_style "$style")

  # Check if shell RC exists
  if [[ ! -f "$SHELL_RC" ]]; then
    return 0 # No conflicts if no RC file
  fi

  # Check each alias
  for alias_name in "${proposed_aliases[@]}"; do
    # Check if alias exists in shell RC file
    if grep -q "^[[:space:]]*alias[[:space:]]\+${alias_name}=" "$SHELL_RC" 2>/dev/null; then
      conflicts+=("$alias_name")
    fi
  done

  # If conflicts found, handle them
  if [[ ${#conflicts[@]} -gt 0 ]]; then
    echo ""
    print_warning "Found existing aliases in $SHELL_RC:"
    echo ""
    for alias_name in "${conflicts[@]}"; do
      # Show the existing alias definition
      local existing_def
      existing_def=$(grep "^[[:space:]]*alias[[:space:]]\+${alias_name}=" "$SHELL_RC" | head -1)
      echo -e "  ${YELLOW}•${NC} ${BOLD}$alias_name${NC}"
      echo -e "    ${CYAN}Current:${NC} $existing_def"
    done
    echo ""

    return 1 # Return failure to indicate conflicts
  fi

  return 0 # No conflicts
}

handle_alias_conflicts() {
  local style="$1"

  echo -e "${BOLD}How would you like to proceed?${NC}"
  echo ""
  echo -e "  ${BOLD}1) Override${NC} - Replace existing aliases with harm-cli aliases"
  echo -e "     ${YELLOW}⚠${NC}  This will comment out your existing aliases"
  echo ""
  echo -e "  ${BOLD}2) Skip${NC} - Keep existing aliases, don't add harm-cli aliases"
  echo -e "     ${CYAN}ℹ${NC}  You can manually add later or use full commands"
  echo ""
  echo -e "  ${BOLD}3) Choose Different Style${NC} - Pick a shortcut style without conflicts"
  echo ""
  echo -e "  ${BOLD}4) Cancel${NC} - Exit installation"
  echo ""

  while true; do
    read -rp "Enter your choice [1-4] (default: 2): " choice
    choice="${choice:-2}"

    case "$choice" in
      1)
        print_warning "Will override existing aliases"
        ALIAS_CONFLICT_ACTION="override"
        return 0
        ;;
      2)
        print_info "Keeping existing aliases, skipping harm-cli alias installation"
        ALIAS_CONFLICT_ACTION="skip"
        return 0
        ;;
      3)
        print_info "Please choose a different shortcut style"
        return 1 # Signal to re-prompt
        ;;
      4)
        die "Installation cancelled by user" 0
        ;;
      *)
        print_error "Invalid choice. Please enter 1, 2, 3, or 4."
        ;;
    esac
  done
}

comment_out_conflicting_aliases() {
  local style="$1"

  # Get aliases that would be created
  local proposed_aliases
  mapfile -t proposed_aliases < <(get_aliases_for_style "$style")

  # Create backup
  cp "$SHELL_RC" "${SHELL_RC}.backup-$(date +%Y%m%d-%H%M%S)"
  print_info "Created backup: ${SHELL_RC}.backup-$(date +%Y%m%d-%H%M%S)"

  # Comment out each conflicting alias
  for alias_name in "${proposed_aliases[@]}"; do
    if grep -q "^[[:space:]]*alias[[:space:]]\+${alias_name}=" "$SHELL_RC" 2>/dev/null; then
      # Use sed to comment out the alias line
      sed -i.tmp "s/^[[:space:]]*\(alias[[:space:]]\+${alias_name}=\)/# [harm-cli override] \1/" "$SHELL_RC"
      rm -f "${SHELL_RC}.tmp"
      print_success "Commented out existing alias: $alias_name"
    fi
  done
}

# ═══════════════════════════════════════════════════════════════
# User Preferences
# ═══════════════════════════════════════════════════════════════

# Track alias conflict action
ALIAS_CONFLICT_ACTION="" # Can be: override, skip, or empty (no conflicts)

prompt_shortcuts() {
  echo ""
  print_step "Choose your shortcut style"
  echo ""
  echo "Select your preferred command shortcuts:"
  echo ""
  echo -e "  ${BOLD}1) Minimal${NC} - Just main alias"
  echo -e "     ${CYAN}h${NC} work start \"task\""
  echo -e "     ${CYAN}h${NC} goal set \"goal\" 2h"
  echo ""
  echo -e "  ${BOLD}2) Balanced${NC} - Direct subcommands (recommended)"
  echo -e "     ${CYAN}work${NC} start \"task\""
  echo -e "     ${CYAN}goal${NC} set \"goal\" 2h"
  echo -e "     ${CYAN}ai${NC} \"question\""
  echo ""
  echo -e "  ${BOLD}3) Power User${NC} - Ultra-short work shortcuts"
  echo -e "     ${CYAN}ws${NC} \"task\"    ${YELLOW}# work start${NC}"
  echo -e "     ${CYAN}ww${NC}            ${YELLOW}# work status${NC}"
  echo -e "     ${CYAN}wo${NC}            ${YELLOW}# work stop${NC}"
  echo ""
  echo -e "  ${BOLD}4) Hybrid${NC} - Balanced + Power User (best of both)"
  echo -e "     ${CYAN}work${NC} start \"task\"  ${YELLOW}# or${NC}  ${CYAN}ws${NC} \"task\""
  echo -e "     ${CYAN}goal${NC} set \"goal\" 2h"
  echo -e "     ${CYAN}ai${NC} \"question\""
  echo ""

  while true; do
    read -rp "Enter your choice [1-4] (default: 4): " choice
    choice="${choice:-4}"

    case "$choice" in
      1 | 2 | 3 | 4)
        SHORTCUT_STYLE="$choice"

        # Check for alias conflicts
        if ! check_alias_conflicts "$SHORTCUT_STYLE"; then
          # Conflicts found - handle them
          if handle_alias_conflicts "$SHORTCUT_STYLE"; then
            # User chose override or skip - we can continue
            break
          else
            # User chose to pick different style - loop again
            echo ""
            continue
          fi
        else
          # No conflicts - continue
          break
        fi
        ;;
      *)
        print_error "Invalid choice. Please enter 1, 2, 3, or 4."
        ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════
# Installation Steps
# ═══════════════════════════════════════════════════════════════

create_symlink() {
  print_step "Installing harm-cli to $LOCAL_BIN..."

  # Create ~/.local/bin if it doesn't exist
  if [[ ! -d "$LOCAL_BIN" ]]; then
    mkdir -p "$LOCAL_BIN"
    print_success "Created $LOCAL_BIN"
  fi

  # Create or update symlink
  if [[ -L "$LOCAL_BIN/harm-cli" ]]; then
    rm "$LOCAL_BIN/harm-cli"
    print_info "Removed existing symlink"
  elif [[ -e "$LOCAL_BIN/harm-cli" ]]; then
    print_warning "File exists at $LOCAL_BIN/harm-cli (not a symlink)"
    read -rp "Overwrite? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      die "Installation aborted by user"
    fi
    rm "$LOCAL_BIN/harm-cli"
  fi

  ln -s "$HARM_CLI_BIN" "$LOCAL_BIN/harm-cli"
  print_success "Created symlink: $LOCAL_BIN/harm-cli → $HARM_CLI_BIN"
}

check_path() {
  print_step "Checking PATH configuration..."

  if [[ ":$PATH:" == *":$LOCAL_BIN:"* ]]; then
    print_success "$LOCAL_BIN is in PATH"
    return 0
  else
    print_warning "$LOCAL_BIN is not in PATH"
    return 1
  fi
}

add_to_path() {
  # Skip if ADD_TO_PATH is disabled
  if [[ "$ADD_TO_PATH" != "yes" ]]; then
    if ! check_path; then
      print_warning "PATH not updated (you chose to skip this)"
      print_info "Manually add to $SHELL_RC: export PATH=\"$LOCAL_BIN:\$PATH\""
    fi
    return 0
  fi

  if ! check_path; then
    echo ""
    print_info "Adding $LOCAL_BIN to PATH in $SHELL_RC"

    {
      echo ""
      echo "# harm-cli: Add $LOCAL_BIN to PATH"
      echo "export PATH=\"$LOCAL_BIN:\$PATH\""
    } >>"$SHELL_RC"

    print_success "Added to $SHELL_RC"
    print_warning "Run: source $SHELL_RC  (or restart terminal)"
  fi
}

generate_aliases() {
  local aliases_file="/tmp/harm-cli-aliases-$$.sh"

  # Handle conflicts if override was chosen
  if [[ "$ALIAS_CONFLICT_ACTION" == "override" ]]; then
    comment_out_conflicting_aliases "$SHORTCUT_STYLE"
  fi

  # Skip alias generation if user chose to skip
  if [[ "$ALIAS_CONFLICT_ACTION" == "skip" ]]; then
    print_step "Generating shell integration (without aliases)..."
  else
    print_step "Generating shell aliases..."
  fi

  cat >"$aliases_file" <<EOF

# ═══════════════════════════════════════════════════════════════
# harm-cli: Shell Integration
# Generated by install.sh on $(date '+%Y-%m-%d')
# ═══════════════════════════════════════════════════════════════

# Source harm-cli configuration
if [[ -f "$HARM_CLI_HOME/config.sh" ]]; then
  source "$HARM_CLI_HOME/config.sh"
fi

EOF

  # Only add aliases if not skipped
  if [[ "$ALIAS_CONFLICT_ACTION" == "skip" ]]; then
    cat >>"$aliases_file" <<'EOF'
# harm-cli: Aliases skipped due to conflicts
# You can manually add aliases or use full commands:
#   harm-cli work start "task"
#   harm-cli goal set "goal" 2h
#   harm-cli ai "question"

EOF
    echo "$aliases_file"
    return 0
  fi

  case "$SHORTCUT_STYLE" in
    1) # Minimal
      cat >>"$aliases_file" <<'EOF'
# harm-cli: Main alias
alias h='harm-cli'

EOF
      ;;
    2) # Balanced
      cat >>"$aliases_file" <<'EOF'
# harm-cli: Direct subcommands
alias work='harm-cli work'
alias goal='harm-cli goal'
alias ai='harm-cli ai'
alias proj='harm-cli proj'

EOF
      ;;
    3) # Power User
      cat >>"$aliases_file" <<'EOF'
# harm-cli: Main alias
alias h='harm-cli'

# harm-cli: Ultra-short work commands
alias ws='harm-cli work start'
alias wo='harm-cli work stop'
alias ww='harm-cli work status'

# harm-cli: Quick goal commands
alias gs='harm-cli goal set'
alias gg='harm-cli goal show'

# harm-cli: AI shortcuts
alias ask='harm-cli ai'

EOF
      ;;
    4) # Hybrid
      cat >>"$aliases_file" <<'EOF'
# harm-cli: Main alias for less common commands
alias h='harm-cli'

# harm-cli: Direct subcommands for frequent use
alias work='harm-cli work'
alias goal='harm-cli goal'
alias ai='harm-cli ai'
alias proj='harm-cli proj'

# harm-cli: Ultra-short work session commands
alias ws='harm-cli work start'
alias wo='harm-cli work stop'
alias ww='harm-cli work status'

EOF
      ;;
  esac

  echo "$aliases_file"
}

install_completions() {
  # Skip if completions disabled
  if [[ "$INSTALL_COMPLETIONS" != "yes" ]]; then
    print_warning "Shell completions disabled (skipped)"
    return 0
  fi

  print_step "Installing shell completions..."

  if [[ "$USER_SHELL" == "zsh" ]]; then
    # Check if zsh completion exists, if not we'll note it
    if [[ -f "$COMPLETIONS_DIR/harm-cli.zsh" ]]; then
      {
        echo 'fpath+=("'"$COMPLETIONS_DIR"'")'
        echo 'autoload -Uz compinit && compinit'
      } >>"$aliases_file"
      print_success "Added zsh completions"
    else
      print_warning "zsh completion not found (will be created)"
      {
        echo "# harm-cli: zsh completions (not yet available)"
        echo '# fpath+=("'"$COMPLETIONS_DIR"'")'
        echo '# autoload -Uz compinit && compinit'
      } >>"$aliases_file"
    fi
  elif [[ "$USER_SHELL" == "bash" ]]; then
    if [[ -f "$COMPLETIONS_DIR/harm-cli.bash" ]]; then
      echo 'source "'"$COMPLETIONS_DIR/harm-cli.bash"'"' >>"$aliases_file"
      print_success "Added bash completions"
    else
      print_warning "bash completion not found"
    fi
  fi
}

generate_config_file() {
  print_step "Generating configuration file..."

  local config_file="$HARM_CLI_HOME/config.sh"
  local config_dir="$HARM_CLI_HOME"

  # Create directory if it doesn't exist
  if [[ ! -d "$config_dir" ]]; then
    mkdir -p "$config_dir"
    print_success "Created $config_dir"
  fi

  # Convert MB to bytes for log file size
  local log_size_bytes=$((HARM_LOG_MAX_SIZE_MB * 1024 * 1024))

  # Set log directory default if not set
  if [[ -z "$HARM_LOG_DIR" ]]; then
    HARM_LOG_DIR="$HARM_CLI_HOME/logs"
  fi

  # Generate config file
  cat >"$config_file" <<EOF
#!/usr/bin/env bash
# ~/.harm-cli/config.sh
# harm-cli Configuration File
# Generated by install.sh on $(date '+%Y-%m-%d %H:%M:%S')
#
# This file is sourced by harm-cli on initialization.
# You can edit these values manually or re-run ./install.sh to regenerate.

# ═══════════════════════════════════════════════════════════════
# Path Configuration
# ═══════════════════════════════════════════════════════════════

# Main data directory (where goals, projects, sessions are stored)
export HARM_CLI_HOME="\${HARM_CLI_HOME:-$HARM_CLI_HOME}"

# Log directory (can be separate for performance/storage reasons)
export HARM_LOG_DIR="\${HARM_LOG_DIR:-$HARM_LOG_DIR}"

# ═══════════════════════════════════════════════════════════════
# Logging Configuration
# ═══════════════════════════════════════════════════════════════

# Log level: DEBUG, INFO, WARN, ERROR
export HARM_LOG_LEVEL="\${HARM_LOG_LEVEL:-$HARM_LOG_LEVEL}"

# Enable/disable file logging (1=enabled, 0=disabled)
export HARM_LOG_TO_FILE="\${HARM_LOG_TO_FILE:-$HARM_LOG_TO_FILE}"

# Enable/disable console logging (1=enabled, 0=disabled)
export HARM_LOG_TO_CONSOLE="\${HARM_LOG_TO_CONSOLE:-1}"

# Maximum log file size in bytes (default: ${HARM_LOG_MAX_SIZE_MB}MB = ${log_size_bytes} bytes)
export HARM_LOG_MAX_SIZE="\${HARM_LOG_MAX_SIZE:-$log_size_bytes}"

# Number of rotated log files to keep
export HARM_LOG_MAX_FILES="\${HARM_LOG_MAX_FILES:-$HARM_LOG_MAX_FILES}"

# Unbuffered logging for real-time output (1=enabled, 0=disabled)
export HARM_LOG_UNBUFFERED="\${HARM_LOG_UNBUFFERED:-1}"

# ═══════════════════════════════════════════════════════════════
# AI Configuration
# ═══════════════════════════════════════════════════════════════

# AI response cache TTL in seconds (default: $HARM_CLI_AI_CACHE_TTL seconds)
export HARM_CLI_AI_CACHE_TTL="\${HARM_CLI_AI_CACHE_TTL:-$HARM_CLI_AI_CACHE_TTL}"

# AI request timeout in seconds
export HARM_CLI_AI_TIMEOUT="\${HARM_CLI_AI_TIMEOUT:-$HARM_CLI_AI_TIMEOUT}"

# AI maximum tokens per request
export HARM_CLI_AI_MAX_TOKENS="\${HARM_CLI_AI_MAX_TOKENS:-$HARM_CLI_AI_MAX_TOKENS}"

# ═══════════════════════════════════════════════════════════════
# Output Configuration
# ═══════════════════════════════════════════════════════════════

# Default output format: text or json
export HARM_CLI_FORMAT="\${HARM_CLI_FORMAT:-$HARM_CLI_FORMAT}"

# ═══════════════════════════════════════════════════════════════
# Feature Flags
# ═══════════════════════════════════════════════════════════════

# Shell completions enabled (set during install)
export HARM_CLI_COMPLETIONS_ENABLED="\${HARM_CLI_COMPLETIONS_ENABLED:-$([ "$INSTALL_COMPLETIONS" = "yes" ] && echo 1 || echo 0)}"
EOF

  print_success "Generated $config_file"

  # Show what was configured
  echo ""
  print_info "Configuration summary:"
  echo -e "  ${CYAN}Data directory:${NC}  $HARM_CLI_HOME"
  echo -e "  ${CYAN}Log directory:${NC}   $HARM_LOG_DIR"
  echo -e "  ${CYAN}Log level:${NC}       $HARM_LOG_LEVEL"
  echo -e "  ${CYAN}AI cache TTL:${NC}    ${HARM_CLI_AI_CACHE_TTL}s"
  echo -e "  ${CYAN}Output format:${NC}   $HARM_CLI_FORMAT"
  echo ""
}

add_to_shell_rc() {
  local aliases_file="$1"

  print_step "Updating $SHELL_RC..."

  # Check if already installed
  if grep -q "harm-cli: Shell Integration" "$SHELL_RC" 2>/dev/null; then
    print_warning "harm-cli integration already exists in $SHELL_RC"
    read -rp "Replace existing configuration? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      # Remove old integration
      sed -i.bak '/# harm-cli: Shell Integration/,/^$/d' "$SHELL_RC"
      print_info "Removed old configuration (backup: ${SHELL_RC}.bak)"
    else
      print_info "Keeping existing configuration"
      return
    fi
  fi

  # Append new configuration
  cat "$aliases_file" >>"$SHELL_RC"
  print_success "Updated $SHELL_RC"
}

# ═══════════════════════════════════════════════════════════════
# Test Installation
# ═══════════════════════════════════════════════════════════════

test_installation() {
  print_step "Testing installation..."

  # Test symlink
  if [[ -L "$LOCAL_BIN/harm-cli" ]]; then
    print_success "Symlink exists"
  else
    print_error "Symlink missing"
    return 1
  fi

  # Test executable
  if [[ -x "$LOCAL_BIN/harm-cli" ]]; then
    print_success "Binary is executable"
  else
    print_error "Binary is not executable"
    return 1
  fi

  # Test version command
  if "$LOCAL_BIN/harm-cli" version >/dev/null 2>&1; then
    print_success "Command executes successfully"
  else
    print_error "Command execution failed"
    return 1
  fi

  echo ""
  print_success "Installation test passed!"
}

# ═══════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════

print_summary() {
  echo ""
  echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${GREEN}║                                                            ║${NC}"
  echo -e "${BOLD}${GREEN}║${NC}  ${BOLD}Installation Complete!${NC}                                    ${BOLD}${GREEN}║${NC}"
  echo -e "${BOLD}${GREEN}║                                                            ║${NC}"
  echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  echo -e "${BOLD}Next Steps:${NC}"
  echo ""
  echo "  1. Restart your terminal or run:"
  echo -e "     ${CYAN}source $SHELL_RC${NC}"
  echo ""
  echo "  2. Verify installation:"
  echo -e "     ${CYAN}harm-cli version${NC}"
  echo ""
  echo "  3. Configuration file created:"
  echo -e "     ${CYAN}$HARM_CLI_HOME/config.sh${NC}"
  echo -e "     ${YELLOW}# You can edit this file to customize settings${NC}"
  echo ""

  # Show alias conflict info if applicable
  if [[ "$ALIAS_CONFLICT_ACTION" == "skip" ]]; then
    echo -e "  ${YELLOW}⚠${NC}  ${BOLD}Note:${NC} Aliases were skipped due to conflicts"
    echo -e "     Use full commands: ${CYAN}harm-cli work start \"task\"${NC}"
    echo "     Or manually add aliases to $SHELL_RC"
    echo ""
  elif [[ "$ALIAS_CONFLICT_ACTION" == "override" ]]; then
    echo -e "  ${CYAN}ℹ${NC}  ${BOLD}Note:${NC} Existing aliases were backed up and commented out"
    echo -e "     Backup created: ${CYAN}${SHELL_RC}.backup-*${NC}"
    echo ""
  fi

  case "$SHORTCUT_STYLE" in
    1)
      echo "  4. Try your new shortcuts:"
      echo -e "     ${CYAN}h version${NC}"
      echo -e "     ${CYAN}h work start \"my task\"${NC}"
      ;;
    2)
      echo "  4. Try your new shortcuts:"
      echo -e "     ${CYAN}work start \"my task\"${NC}"
      echo -e "     ${CYAN}goal set \"my goal\" 2h${NC}"
      echo -e "     ${CYAN}ai \"how do I...?\"${NC}"
      ;;
    3)
      echo "  4. Try your new shortcuts:"
      echo -e "     ${CYAN}ws \"my task\"${NC}     ${YELLOW}# work start${NC}"
      echo -e "     ${CYAN}ww${NC}               ${YELLOW}# work status${NC}"
      echo -e "     ${CYAN}wo${NC}               ${YELLOW}# work stop${NC}"
      ;;
    4)
      echo "  4. Try your new shortcuts:"
      echo -e "     ${CYAN}ws \"my task\"${NC}            ${YELLOW}# ultra-short work start${NC}"
      echo -e "     ${CYAN}work status${NC}              ${YELLOW}# or use full command${NC}"
      echo -e "     ${CYAN}goal set \"goal\" 2h${NC}      ${YELLOW}# direct goal command${NC}"
      echo -e "     ${CYAN}ai \"question?\"${NC}          ${YELLOW}# ask AI directly${NC}"
      ;;
  esac

  echo ""
  echo "  5. Get help anytime:"
  echo -e "     ${CYAN}harm-cli --help${NC}"
  echo -e "     ${CYAN}harm-cli work --help${NC}"
  echo ""

  print_info "To uninstall: run ${CYAN}./uninstall.sh${NC}"
  echo ""
}

# ═══════════════════════════════════════════════════════════════
# Main Installation Flow
# ═══════════════════════════════════════════════════════════════

main() {
  print_header

  # Pre-flight checks
  check_dependencies

  # Get installation mode (Quick vs Custom)
  prompt_install_mode

  # If custom mode, get all configuration
  if [[ "$INSTALL_MODE" == "custom" ]]; then
    prompt_path_config
    prompt_logging_config
    prompt_ai_config
    prompt_feature_config
  else
    # Quick mode: set log dir default
    HARM_LOG_DIR="$HARM_CLI_HOME/logs"
  fi

  # Always ask for shortcut style
  prompt_shortcuts

  echo ""
  print_step "Starting installation..."
  echo ""

  # Installation steps
  create_symlink
  add_to_path

  # Generate config.sh file with all settings
  generate_config_file

  # Generate shell aliases
  aliases_file=$(generate_aliases)
  install_completions
  add_to_shell_rc "$aliases_file"

  # Clean up temp file
  rm -f "$aliases_file"

  # Test
  echo ""
  test_installation

  # Summary
  print_summary
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
