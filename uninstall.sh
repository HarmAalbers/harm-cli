#!/usr/bin/env bash
# harm-cli Uninstaller
# Cleanly removes harm-cli installation and shell integration

set -Eeuo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Installation paths
LOCAL_BIN="$HOME/.local/bin"
HARM_CLI_DATA="$HOME/.harm-cli"

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
  echo -e "${BOLD}${CYAN}║${NC}  ${BOLD}harm-cli Uninstaller${NC}                                     ${BOLD}${CYAN}║${NC}"
  echo -e "${BOLD}${CYAN}║                                                            ║${NC}"
  echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}\n"
}

print_step() {
  echo -e "${BOLD}${CYAN}▶${NC} $*"
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

# ═══════════════════════════════════════════════════════════════
# Uninstallation Steps
# ═══════════════════════════════════════════════════════════════

confirm_uninstall() {
  echo ""
  print_warning "This will remove:"
  echo "  • Symlink: $LOCAL_BIN/harm-cli"
  echo "  • Shell aliases from: $SHELL_RC"
  echo ""
  print_info "This will NOT remove:"
  echo "  • Source code in: $(dirname "$(readlink -f "$LOCAL_BIN/harm-cli" 2>/dev/null || echo "unknown")")"
  echo "  • User data in: $HARM_CLI_DATA"
  echo ""

  read -rp "Continue with uninstallation? [y/N]: " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo ""
    print_info "Uninstallation cancelled"
    exit 0
  fi
}

remove_symlink() {
  print_step "Removing symlink..."

  if [[ -L "$LOCAL_BIN/harm-cli" ]]; then
    rm "$LOCAL_BIN/harm-cli"
    print_success "Removed symlink: $LOCAL_BIN/harm-cli"
  elif [[ -e "$LOCAL_BIN/harm-cli" ]]; then
    print_warning "File exists but is not a symlink: $LOCAL_BIN/harm-cli"
    read -rp "Remove anyway? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      rm "$LOCAL_BIN/harm-cli"
      print_success "Removed file: $LOCAL_BIN/harm-cli"
    fi
  else
    print_info "Symlink not found (already removed)"
  fi
}

remove_shell_integration() {
  print_step "Removing shell integration from $SHELL_RC..."

  if [[ ! -f "$SHELL_RC" ]]; then
    print_info "Shell config not found: $SHELL_RC"
    return
  fi

  if grep -q "harm-cli: Shell Integration" "$SHELL_RC" 2>/dev/null; then
    # Create backup
    cp "$SHELL_RC" "${SHELL_RC}.backup-$(date +%Y%m%d-%H%M%S)"
    print_info "Created backup: ${SHELL_RC}.backup-$(date +%Y%m%d-%H%M%S)"

    # Remove harm-cli section
    # Remove from "# harm-cli: Shell Integration" to the next empty line
    sed -i.tmp '/# ═.*harm-cli: Shell Integration/,/^$/d' "$SHELL_RC"
    # Also remove individual alias lines that might remain
    sed -i.tmp '/# harm-cli:/d' "$SHELL_RC"
    rm -f "${SHELL_RC}.tmp"

    print_success "Removed shell integration from $SHELL_RC"
  else
    print_info "No shell integration found in $SHELL_RC"
  fi
}

offer_data_removal() {
  echo ""
  print_step "User data location: $HARM_CLI_DATA"

  if [[ ! -d "$HARM_CLI_DATA" ]]; then
    print_info "No user data directory found"
    return
  fi

  echo ""
  print_warning "Your data contains:"
  echo "  • Work session history"
  echo "  • Goal tracking data"
  echo "  • Project registry"
  echo "  • AI response cache"
  echo "  • Application logs"
  echo ""

  read -rp "Remove user data? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    # Validate path before deletion
    if [[ -z "$HARM_CLI_DATA" || "$HARM_CLI_DATA" == "/" || "$HARM_CLI_DATA" == "$HOME" ]]; then
      print_error "Invalid HARM_CLI_DATA path: '$HARM_CLI_DATA'"
      print_error "Refusing to delete for safety reasons"
      return 1
    fi

    if [[ ! -d "$HARM_CLI_DATA" ]]; then
      print_warning "Data directory does not exist: $HARM_CLI_DATA"
    else
      rm -rf "$HARM_CLI_DATA"
      print_success "Removed user data: $HARM_CLI_DATA"
    fi
  else
    print_info "Kept user data in: $HARM_CLI_DATA"
    print_info "To remove manually later: rm -rf $HARM_CLI_DATA"
  fi
}

# ═══════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════

print_summary() {
  echo ""
  echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${GREEN}║                                                            ║${NC}"
  echo -e "${BOLD}${GREEN}║${NC}  ${BOLD}Uninstallation Complete!${NC}                                 ${BOLD}${GREEN}║${NC}"
  echo -e "${BOLD}${GREEN}║                                                            ║${NC}"
  echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  echo -e "${BOLD}Next Steps:${NC}"
  echo ""
  echo "  1. Restart your terminal or run:"
  echo -e "     ${CYAN}source $SHELL_RC${NC}"
  echo ""
  echo "  2. Verify removal:"
  echo -e "     ${CYAN}which harm-cli${NC}"
  echo "     (should return: not found)"
  echo ""

  if [[ -d "$HARM_CLI_DATA" ]]; then
    echo "  3. Your data is still available at:"
    echo -e "     ${CYAN}$HARM_CLI_DATA${NC}"
    echo ""
  fi

  print_info "To reinstall: run ${CYAN}./install.sh${NC}"
  echo ""
}

# ═══════════════════════════════════════════════════════════════
# Main Uninstallation Flow
# ═══════════════════════════════════════════════════════════════

main() {
  print_header
  confirm_uninstall

  echo ""
  print_step "Starting uninstallation..."
  echo ""

  remove_symlink
  remove_shell_integration
  offer_data_removal

  print_summary
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
