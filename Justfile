# harm-cli Justfile
# Elite-tier CLI development commands
#
# Usage: just <command>
# Run 'just --list' to see all available commands

# Set shell with strict error handling
set shell := ["/usr/bin/env", "bash", "-Eeuo", "pipefail", "-c"]

# Default recipe - run full CI pipeline
default: ci

# Show all available commands
help:
    @just --list

# ═══════════════════════════════════════════════════════════════
# Formatting & Linting
# ═══════════════════════════════════════════════════════════════

# Format all shell scripts with shfmt
fmt:
    @echo "📝 Formatting shell scripts..."
    shfmt -w -i 2 -ci -bn bin/* lib/*.sh lib/**/*.sh lib/**/*.zsh spec/*.sh spec/**/*.sh 2>/dev/null || true
    @echo "✅ Formatting complete"

# Lint all shell scripts with shellcheck
lint:
    @echo "🔍 Linting shell scripts..."
    @find bin lib -type f \( -name "*.sh" -o -perm +111 \) 2>/dev/null | xargs shellcheck
    @echo "✅ Linting complete"

# Run codespell on documentation
spell:
    @echo "📖 Checking spelling..."
    codespell docs/ *.md || true

# ═══════════════════════════════════════════════════════════════
# Testing
# ═══════════════════════════════════════════════════════════════

# Run tests with bash shell (bash 5+ required)
test-bash:
    @echo "🧪 Running tests with bash 5+..."
    shellspec -s /opt/homebrew/bin/bash

# Run tests with zsh shell
test-zsh:
    @echo "🧪 Running tests with zsh..."
    shellspec -s /bin/zsh --pattern 'spec/cli_core_spec.sh'

# Run all tests (bash + zsh)
test: test-bash test-zsh

# Run specific test file
test-file FILE:
    @echo "🧪 Running {{FILE}}..."
    shellspec "{{FILE}}"

# Run tests in watch mode
test-watch:
    @echo "👀 Watching for changes..."
    shellspec --watch

# Run tests with code coverage
coverage:
    @echo "📊 Running tests with coverage..."
    shellspec --kcov

# ═══════════════════════════════════════════════════════════════
# CI/CD
# ═══════════════════════════════════════════════════════════════

# Run full CI pipeline (fmt + lint + test)
ci: fmt lint test
    @echo ""
    @echo "═══════════════════════════════════════"
    @echo "✅ CI pipeline passed!"
    @echo "═══════════════════════════════════════"

# Run pre-commit hooks on all files
pre-commit:
    @echo "🪝 Running pre-commit hooks..."
    pre-commit run --all-files

# ═══════════════════════════════════════════════════════════════
# Documentation
# ═══════════════════════════════════════════════════════════════

# Generate man page from help output
man:
    @echo "📚 Generating man page..."
    mkdir -p man
    help2man -N -n "Personal CLI toolkit for development" -o man/harm-cli.1 ./bin/harm-cli || true
    @echo "✅ Man page generated: man/harm-cli.1"

# Show completions installation instructions
completions:
    @echo "📝 Shell Completions Installation:"
    @echo ""
    @echo "Bash:"
    @echo "  source completions/harm-cli.bash"
    @echo ""
    @echo "Zsh:"
    @echo '  fpath+=("$$PWD/completions")'
    @echo "  autoload -U compinit && compinit"

# ═══════════════════════════════════════════════════════════════
# Build & Release
# ═══════════════════════════════════════════════════════════════

# Clean build artifacts
clean:
    @echo "🧹 Cleaning build artifacts..."
    rm -rf dist/ build/ coverage/ spec/tmp/
    @echo "✅ Clean complete"

# Build release artifacts
build:
    @echo "🔨 Building release..."
    bash scripts/release.sh build

# Create reproducible release tarball
release:
    @echo "📦 Creating release..."
    bash scripts/release.sh

# Sign release checksums
sign:
    @echo "🔐 Signing release..."
    cosign sign-blob --yes --output-signature dist/harm-cli-$$(cat VERSION)_checksums.txt.sig dist/harm-cli-$$(cat VERSION)_checksums.txt || \
    minisign -Sm dist/harm-cli-$$(cat VERSION)_checksums.txt

# Generate SBOM (Software Bill of Materials)
sbom:
    @echo "📋 Generating SBOM..."
    syft scan dir:. -o spdx-json > dist/harm-cli-$$(cat VERSION)_sbom.json

# Scan for vulnerabilities
scan:
    @echo "🔍 Scanning for vulnerabilities..."
    grype dir:. --fail-on critical

# ═══════════════════════════════════════════════════════════════
# Development
# ═══════════════════════════════════════════════════════════════

# Install development dependencies
install:
    @echo "📦 Installing development dependencies..."
    @echo ""
    @echo "Required tools:"
    @echo "  - just (command runner)"
    @echo "  - shellcheck (linting)"
    @echo "  - shfmt (formatting)"
    @echo "  - shellspec (testing)"
    @echo "  - jq (JSON processing)"
    @echo "  - coreutils (GNU tools)"
    @echo ""
    @echo "Optional (for release):"
    @echo "  - git-cliff (changelog)"
    @echo "  - cosign/minisign (signing)"
    @echo "  - syft (SBOM generation)"
    @echo "  - grype (vulnerability scanning)"
    @echo ""
    @command -v brew >/dev/null && echo "Run: brew install just shellcheck shfmt shellspec jq coreutils git-cliff cosign minisign anchore/syft/syft anchore/grype/grype" || echo "Install Homebrew first"

# Verify all dependencies are installed
doctor:
    @echo "🏥 Checking dependencies..."
    @command -v just >/dev/null && echo "✅ just" || echo "❌ just (missing)"
    @command -v shellcheck >/dev/null && echo "✅ shellcheck" || echo "❌ shellcheck (missing)"
    @command -v shfmt >/dev/null && echo "✅ shfmt" || echo "❌ shfmt (missing)"
    @command -v shellspec >/dev/null && echo "✅ shellspec" || echo "❌ shellspec (missing)"
    @command -v jq >/dev/null && echo "✅ jq" || echo "❌ jq (missing)"
    @echo ""
    @echo "Optional dependencies:"
    @command -v git-cliff >/dev/null && echo "✅ git-cliff" || echo "⚠️  git-cliff (optional)"
    @command -v cosign >/dev/null && echo "✅ cosign" || echo "⚠️  cosign (optional)"
    @command -v syft >/dev/null && echo "✅ syft" || echo "⚠️  syft (optional)"
    @command -v grype >/dev/null && echo "✅ grype" || echo "⚠️  grype (optional)"

# Show project information
info:
    @echo "harm-cli v$$(cat VERSION)"
    @echo ""
    @echo "Directory: $$(pwd)"
    @echo "Git branch: $$(git branch --show-current 2>/dev/null || echo 'not a git repo')"
    @echo "Git status: $$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ') changed files"
    @echo ""
    @echo "Lines of code:"
    @find bin lib -type f \( -name '*.sh' -o -name '*.zsh' -o -name 'harm-cli' \) -exec wc -l {} + 2>/dev/null | tail -1 || echo "  0 total"
    @echo ""
    @echo "Test files:"
    @find spec -type f -name '*_spec.sh' | wc -l | xargs echo "  " spec files

# ═══════════════════════════════════════════════════════════════
# Git Helpers
# ═══════════════════════════════════════════════════════════════

# Run CI before committing
pre-push: ci
    @echo "✅ Ready to push!"

# Create a new release tag
tag VERSION:
    @echo "🏷️  Creating release tag v{{VERSION}}..."
    git tag -a "v{{VERSION}}" -m "Release v{{VERSION}}"
    @echo "✅ Tag created. Push with: git push origin v{{VERSION}}"
