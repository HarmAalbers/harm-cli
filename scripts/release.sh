#!/usr/bin/env bash
# scripts/release.sh - Automated release management for harm-cli
#
# Features:
#   - Version bumping (major.minor.patch)
#   - Changelog generation with git-cliff
#   - Git tagging with annotations
#   - GitHub release creation
#   - Reproducible release tarballs
#
# Usage:
#   ./scripts/release.sh [major|minor|patch]  # Bump version and create release
#   ./scripts/release.sh build                # Build release tarball only
#
# Environment:
#   SKIP_TESTS=1    - Skip test suite before release
#   DRY_RUN=1       - Show what would happen without making changes

set -Eeuo pipefail
trap 'echo "❌ Release failed at line $LINENO"' ERR

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$PROJECT_ROOT/VERSION"
CHANGELOG_FILE="$PROJECT_ROOT/CHANGELOG.md"
DIST_DIR="$PROJECT_ROOT/dist"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ═══════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════

log_info() {
  echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
  echo -e "${GREEN}✅${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
  echo -e "${RED}❌${NC} $*" >&2
}

dry_run() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo -e "${YELLOW}[DRY RUN]${NC} $*"
    return 0
  fi
  return 1
}

require_command() {
  local cmd="$1"
  local install_hint="${2:-}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "Required command not found: $cmd"
    [ -n "$install_hint" ] && log_info "$install_hint"
    exit 1
  fi
}

# ═══════════════════════════════════════════════════════════════
# Validation Functions
# ═══════════════════════════════════════════════════════════════

check_prerequisites() {
  log_info "Checking prerequisites..."

  require_command "git"
  require_command "jq" "Install with: brew install jq"

  # git-cliff is optional but recommended
  if ! command -v git-cliff >/dev/null 2>&1; then
    log_warning "git-cliff not found - changelog generation will be skipped"
    log_info "Install with: brew install git-cliff"
  fi

  # gh CLI is optional
  if ! command -v gh >/dev/null 2>&1; then
    log_warning "gh CLI not found - GitHub release creation will be skipped"
    log_info "Install with: brew install gh"
  fi

  log_success "Prerequisites checked"
}

check_git_state() {
  log_info "Checking git state..."

  # Must be on main branch
  current_branch=$(git branch --show-current)
  if [ "$current_branch" != "main" ]; then
    log_error "Must be on main branch (currently on: $current_branch)"
    exit 1
  fi

  # Must be clean working directory
  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    log_error "Working directory has uncommitted changes"
    git status --short
    exit 1
  fi

  # Must be up to date with remote
  git fetch origin main --quiet
  local_commit=$(git rev-parse HEAD)
  remote_commit=$(git rev-parse origin/main)
  if [ "$local_commit" != "$remote_commit" ]; then
    log_error "Local branch is not up to date with origin/main"
    log_info "Run: git pull origin main"
    exit 1
  fi

  log_success "Git state is clean"
}

run_tests() {
  if [ "${SKIP_TESTS:-0}" = "1" ]; then
    log_warning "Skipping tests (SKIP_TESTS=1)"
    return 0
  fi

  log_info "Running test suite..."
  if ! just ci >/dev/null 2>&1; then
    log_error "Tests failed - fix before releasing"
    exit 1
  fi
  log_success "Tests passed"
}

# ═══════════════════════════════════════════════════════════════
# Version Management
# ═══════════════════════════════════════════════════════════════

get_current_version() {
  if [ ! -f "$VERSION_FILE" ]; then
    echo "0.0.0"
    return
  fi
  tr -d '\n' < "$VERSION_FILE"
}

bump_version() {
  local bump_type="$1"
  local current_version
  current_version=$(get_current_version)

  IFS='.' read -r major minor patch <<< "$current_version"

  case "$bump_type" in
    major)
      major=$((major + 1))
      minor=0
      patch=0
      ;;
    minor)
      minor=$((minor + 1))
      patch=0
      ;;
    patch)
      patch=$((patch + 1))
      ;;
    *)
      log_error "Invalid bump type: $bump_type (use: major|minor|patch)"
      exit 1
      ;;
  esac

  echo "$major.$minor.$patch"
}

update_version_file() {
  local new_version="$1"

  if dry_run "Would update VERSION file to: $new_version"; then
    return 0
  fi

  echo "$new_version" > "$VERSION_FILE"
  log_success "Updated VERSION file to: $new_version"
}

# ═══════════════════════════════════════════════════════════════
# Changelog Management
# ═══════════════════════════════════════════════════════════════

generate_changelog() {
  local new_version="$1"

  if ! command -v git-cliff >/dev/null 2>&1; then
    log_warning "Skipping changelog generation (git-cliff not installed)"
    return 0
  fi

  if dry_run "Would generate changelog for v$new_version"; then
    return 0
  fi

  log_info "Generating changelog..."

  if git-cliff --tag "v$new_version" --output "$CHANGELOG_FILE" 2>/dev/null; then
    log_success "Changelog generated"
  else
    log_warning "Changelog generation failed (continuing anyway)"
  fi
}

# ═══════════════════════════════════════════════════════════════
# Git Operations
# ═══════════════════════════════════════════════════════════════

commit_version_bump() {
  local new_version="$1"

  if dry_run "Would commit version bump to v$new_version"; then
    return 0
  fi

  log_info "Committing version bump..."

  git add "$VERSION_FILE" "$CHANGELOG_FILE"
  git commit -m "chore(release): bump version to $new_version" --quiet

  log_success "Version bump committed"
}

create_git_tag() {
  local new_version="$1"
  local tag_name="v$new_version"

  if dry_run "Would create tag: $tag_name"; then
    return 0
  fi

  log_info "Creating git tag: $tag_name"

  # Extract recent changes for tag message
  local tag_message
  tag_message=$(cat <<EOF
Release v$new_version

See CHANGELOG.md for full details.
EOF
)

  git tag -a "$tag_name" -m "$tag_message"
  log_success "Tag created: $tag_name"
}

push_to_remote() {
  local new_version="$1"

  if dry_run "Would push to remote: main + v$new_version"; then
    return 0
  fi

  log_info "Pushing to remote..."

  git push origin main --quiet
  git push origin "v$new_version" --quiet

  log_success "Pushed to remote"
}

# ═══════════════════════════════════════════════════════════════
# Release Artifacts
# ═══════════════════════════════════════════════════════════════

build_release_tarball() {
  local version
  version=$(get_current_version)

  log_info "Building release tarball for v$version..."

  # Create dist directory
  mkdir -p "$DIST_DIR"

  # Create reproducible tarball
  local tarball_name="harm-cli-${version}.tar.gz"
  local tarball_path="$DIST_DIR/$tarball_name"

  # Files to include in release
  tar czf "$tarball_path" \
    --exclude='.git' \
    --exclude='.idea' \
    --exclude='node_modules' \
    --exclude='coverage' \
    --exclude='spec/tmp' \
    --exclude='dist' \
    --exclude='.DS_Store' \
    -C "$PROJECT_ROOT" \
    bin/ \
    lib/ \
    completions/ \
    docs/ \
    scripts/ \
    install.sh \
    uninstall.sh \
    VERSION \
    README.md \
    CHANGELOG.md \
    COMMANDS.md \
    LICENSE \
    Justfile

  log_success "Created: $tarball_path"

  # Generate checksums
  (cd "$DIST_DIR" && shasum -a 256 "$tarball_name" > "${tarball_name}.sha256")
  log_success "Created: ${tarball_path}.sha256"

  # Show tarball info
  local size
  size=$(du -h "$tarball_path" | awk '{print $1}')
  log_info "Tarball size: $size"
}

create_github_release() {
  local new_version="$1"

  if ! command -v gh >/dev/null 2>&1; then
    log_warning "Skipping GitHub release (gh CLI not installed)"
    return 0
  fi

  if dry_run "Would create GitHub release for v$new_version"; then
    return 0
  fi

  log_info "Creating GitHub release..."

  # Extract changelog for this version
  local release_notes="See [CHANGELOG.md](https://github.com/harm-less/harm-cli/blob/v$new_version/CHANGELOG.md) for details."

  if gh release create "v$new_version" \
    --title "v$new_version" \
    --notes "$release_notes" \
    --latest \
    "$DIST_DIR/harm-cli-${new_version}.tar.gz" \
    "$DIST_DIR/harm-cli-${new_version}.tar.gz.sha256"; then
    log_success "GitHub release created"
  else
    log_warning "GitHub release creation failed (continuing anyway)"
  fi
}

# ═══════════════════════════════════════════════════════════════
# Main Release Flow
# ═══════════════════════════════════════════════════════════════

release() {
  local bump_type="${1:-patch}"

  log_info "Starting release process (bump: $bump_type)..."

  # Validation
  check_prerequisites
  check_git_state
  run_tests

  # Version management
  local current_version
  local new_version
  current_version=$(get_current_version)
  new_version=$(bump_version "$bump_type")

  log_info "Version: $current_version → $new_version"

  # Update files
  update_version_file "$new_version"
  generate_changelog "$new_version"

  # Git operations
  commit_version_bump "$new_version"
  create_git_tag "$new_version"

  # Build artifacts
  build_release_tarball

  # Remote operations
  push_to_remote "$new_version"
  create_github_release "$new_version"

  # Success!
  echo ""
  log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_success "Release v$new_version complete!"
  log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  log_info "Next steps:"
  log_info "  1. Verify release on GitHub"
  log_info "  2. Announce release to users"
  log_info "  3. Update documentation if needed"
}

# ═══════════════════════════════════════════════════════════════
# CLI Interface
# ═══════════════════════════════════════════════════════════════

show_usage() {
  cat <<EOF
Usage: $0 [COMMAND]

Commands:
  major               Bump major version (1.0.0 -> 2.0.0)
  minor               Bump minor version (1.0.0 -> 1.1.0)
  patch               Bump patch version (1.0.0 -> 1.0.1) [default]
  build               Build release tarball only
  help                Show this help message

Environment:
  SKIP_TESTS=1        Skip test suite
  DRY_RUN=1           Show what would happen without making changes

Examples:
  $0 minor            # Release v1.1.0
  $0 build            # Build tarball for current version
  DRY_RUN=1 $0 major  # Preview major release

EOF
}

main() {
  local command="${1:-patch}"

  case "$command" in
    major|minor|patch)
      release "$command"
      ;;
    build)
      build_release_tarball
      ;;
    help|--help|-h)
      show_usage
      ;;
    *)
      log_error "Unknown command: $command"
      show_usage
      exit 1
      ;;
  esac
}

# Run main if not sourced
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
