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
LOCAL_BIN="$HOME/.local/bin"
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
# User Preferences
# ═══════════════════════════════════════════════════════════════

prompt_shortcuts() {
  echo ""
  print_step "Choose your shortcut style"
  echo ""
  echo "Select your preferred command shortcuts:"
  echo ""
  echo "  ${BOLD}1) Minimal${NC} - Just main alias"
  echo "     ${CYAN}h${NC} work start \"task\""
  echo "     ${CYAN}h${NC} goal set \"goal\" 2h"
  echo ""
  echo "  ${BOLD}2) Balanced${NC} - Direct subcommands (recommended)"
  echo "     ${CYAN}work${NC} start \"task\""
  echo "     ${CYAN}goal${NC} set \"goal\" 2h"
  echo "     ${CYAN}ai${NC} \"question\""
  echo ""
  echo "  ${BOLD}3) Power User${NC} - Ultra-short work shortcuts"
  echo "     ${CYAN}ws${NC} \"task\"    ${YELLOW}# work start${NC}"
  echo "     ${CYAN}ww${NC}            ${YELLOW}# work status${NC}"
  echo "     ${CYAN}wo${NC}            ${YELLOW}# work stop${NC}"
  echo ""
  echo "  ${BOLD}4) Hybrid${NC} - Balanced + Power User (best of both)"
  echo "     ${CYAN}work${NC} start \"task\"  ${YELLOW}# or${NC}  ${CYAN}ws${NC} \"task\""
  echo "     ${CYAN}goal${NC} set \"goal\" 2h"
  echo "     ${CYAN}ai${NC} \"question\""
  echo ""

  while true; do
    read -rp "Enter your choice [1-4] (default: 4): " choice
    choice="${choice:-4}"

    case "$choice" in
      1 | 2 | 3 | 4)
        SHORTCUT_STYLE="$choice"
        break
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
  if ! check_path; then
    echo ""
    print_info "Adding $LOCAL_BIN to PATH in $SHELL_RC"

    {
      echo ""
      echo "# harm-cli: Add ~/.local/bin to PATH"
      echo 'export PATH="$HOME/.local/bin:$PATH"'
    } >>"$SHELL_RC"

    print_success "Added to $SHELL_RC"
    print_warning "Run: source $SHELL_RC  (or restart terminal)"
  fi
}

generate_aliases() {
  local aliases_file="/tmp/harm-cli-aliases-$$.sh"

  print_step "Generating shell aliases..."

  cat >"$aliases_file" <<'EOF'

# ═══════════════════════════════════════════════════════════════
# harm-cli: Shell Integration
# Generated by install.sh
# ═══════════════════════════════════════════════════════════════

EOF

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

  case "$SHORTCUT_STYLE" in
    1)
      echo "  3. Try your new shortcuts:"
      echo -e "     ${CYAN}h version${NC}"
      echo -e "     ${CYAN}h work start \"my task\"${NC}"
      ;;
    2)
      echo "  3. Try your new shortcuts:"
      echo -e "     ${CYAN}work start \"my task\"${NC}"
      echo -e "     ${CYAN}goal set \"my goal\" 2h${NC}"
      echo -e "     ${CYAN}ai \"how do I...?\"${NC}"
      ;;
    3)
      echo "  3. Try your new shortcuts:"
      echo -e "     ${CYAN}ws \"my task\"${NC}     ${YELLOW}# work start${NC}"
      echo -e "     ${CYAN}ww${NC}               ${YELLOW}# work status${NC}"
      echo -e "     ${CYAN}wo${NC}               ${YELLOW}# work stop${NC}"
      ;;
    4)
      echo "  3. Try your new shortcuts:"
      echo -e "     ${CYAN}ws \"my task\"${NC}            ${YELLOW}# ultra-short work start${NC}"
      echo -e "     ${CYAN}work status${NC}              ${YELLOW}# or use full command${NC}"
      echo -e "     ${CYAN}goal set \"goal\" 2h${NC}      ${YELLOW}# direct goal command${NC}"
      echo -e "     ${CYAN}ai \"question?\"${NC}          ${YELLOW}# ask AI directly${NC}"
      ;;
  esac

  echo ""
  echo "  4. Get help anytime:"
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

  # Get user preferences
  prompt_shortcuts

  echo ""
  print_step "Starting installation..."
  echo ""

  # Installation steps
  create_symlink
  add_to_path

  # Generate configuration
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
