# harm-cli

> Personal CLI toolkit for elite-tier development workflows

**Version:** 1.0.0
**Status:** ✅ Production Ready - All 8 phases complete!

---

## 🎯 Overview

`harm-cli` is a production-grade command-line toolkit designed to streamline development workflows with professional engineering standards. Built from a complete refactoring of a 19,000-line ZSH development environment, it follows elite-tier practices:

- ✅ **Strict error handling** - `set -Eeuo pipefail` everywhere
- ✅ **Comprehensive testing** - 287 ShellSpec tests (100% passing)
- ✅ **Reproducible builds** - Deterministic releases with SBOM
- ✅ **Code quality gates** - Pre-commit hooks, linting, formatting
- ✅ **JSON + text output** - All commands support both formats
- ✅ **Atomic operations** - Safe file I/O with proper locking
- ✅ **CI/CD ready** - GitHub Actions with automated testing
- ✅ **AI-powered workflows** - Gemini integration for code review & commit messages
- ✅ **Docker & Python support** - Environment management built-in
- ✅ **Safety features** - Dangerous operation protection with confirmations

---

## 📦 Installation

### Prerequisites

**Required:**

- **Bash 5.0+** (uses modern features: associative arrays, ${var^^} expansion)
- Git
- jq

**Recommended:**

- just (command runner)
- shellspec (testing)
- shellcheck (linting)
- shfmt (formatting)

### Quick Install

```bash
# Clone the repository
git clone https://github.com/HarmAalbers/harm-cli.git
cd harm-cli

# Add to PATH (add to ~/.bashrc)
export PATH="$HOME/harm-cli/bin:$PATH"

# Verify installation
harm-cli --version
```

### Development Setup

```bash
# Install all development tools
brew install just shellcheck shfmt shellspec jq

# Install pre-commit hooks
brew install pre-commit
pre-commit install

# Verify everything works
just doctor
just ci
```

---

## 🚀 Quick Start

```bash
# Show version
harm-cli version
harm-cli version json  # JSON output

# Check system health
harm-cli doctor

# Work session tracking
harm-cli work start "Phase 3 implementation"
harm-cli work status
harm-cli work stop

# Goal management
harm-cli goal set "Complete AI integration" 4h
harm-cli goal show
harm-cli goal progress 1 50
harm-cli goal complete 1

# AI assistant (requires Gemini API key)
harm-cli ai "How do I list files recursively?"
harm-cli ai review               # Review git changes
harm-cli ai daily                # Daily productivity insights

# Git workflows
harm-cli git status              # Enhanced status
harm-cli git commit-msg          # AI-powered commit message

# Project management
harm-cli proj list               # List projects
harm-cli proj add ~/myapp        # Add project

# Docker management
harm-cli docker up               # Start services
harm-cli docker status           # Service status
harm-cli docker logs backend     # View logs
harm-cli docker cleanup          # Safe resource cleanup

# Python development
harm-cli python test             # Run tests
harm-cli python lint             # Lint code
harm-cli python format           # Format code

# Health monitoring
harm-cli health                  # System health check
harm-cli gcloud status           # GCloud status

# Safety operations
harm-cli safe rm file.txt        # Safe file deletion
harm-cli safe git-reset          # Safe git reset with backup

# Get help
harm-cli help
harm-cli ai --help
```

---

## 🏗️ Project Structure

```
harm-cli/
├── bin/
│   └── harm-cli              # Main CLI entry point
├── lib/                      # Core library modules (14 modules)
│   ├── common.sh             # Common utilities and initialization
│   ├── error.sh              # Error handling and exit codes
│   ├── logging.sh            # Multi-level logging system
│   ├── util.sh               # String, array, file utilities
│   ├── work.sh               # Work session tracking
│   ├── goals.sh              # Goal management
│   ├── ai.sh                 # Gemini AI integration
│   ├── git.sh                # Enhanced git workflows
│   ├── proj.sh               # Project registry and switching
│   ├── docker.sh             # Docker management
│   ├── python.sh             # Python development tools
│   ├── gcloud.sh             # Google Cloud SDK integration
│   ├── health.sh             # Health monitoring
│   └── safety.sh             # Safety wrappers for dangerous ops
├── spec/                     # ShellSpec test suite (287 tests)
│   ├── helpers/              # Test utilities
│   │   ├── env.sh            # Test environment setup
│   │   └── matchers.sh       # Custom assertions
│   ├── golden/               # Golden output files
│   └── *_spec.sh             # Test specifications (18 files)
├── etc/                      # Configuration files
├── completions/              # Shell completions (bash)
├── man/                      # Man pages
├── docs/                     # Documentation
│   ├── PROGRESS.md           # Migration history
│   └── COMMANDS.md           # Complete command reference
├── scripts/                  # Build and release scripts
├── .github/workflows/        # CI/CD pipelines
├── Justfile                  # Task runner commands
├── .pre-commit-config.yaml   # Pre-commit hooks
├── .shellspec                # ShellSpec configuration
└── VERSION                   # Semantic version (1.0.0)
```

---

## 🛠️ Development

### Available Commands (via `just`)

```bash
# Formatting & Linting
just fmt                 # Format all shell scripts
just lint                # Lint with shellcheck
just spell               # Spell check documentation

# Testing
just test                # Run all tests
just test-bash           # Test with bash
just test-file FILE      # Run specific test file
just test-watch          # Watch mode for TDD
just coverage            # Run with coverage report

# CI/CD
just ci                  # Full CI pipeline (fmt + lint + test)
just pre-commit          # Run pre-commit hooks

# Development
just doctor              # Check dependencies
just info                # Show project info
just clean               # Clean build artifacts

# Documentation
just man                 # Generate man page
just completions         # Show completion setup

# Release
just build               # Build release
just release             # Create release tarball
just sign                # Sign checksums
just sbom                # Generate SBOM
just scan                # Scan for vulnerabilities
```

### Running Tests

```bash
# Run all tests
just test

# Run specific shell
shellspec -s /bin/bash
shellspec -s /bin/zsh

# Run specific test file
shellspec spec/cli_core_spec.sh

# Watch mode for TDD
shellspec --watch
```

### Code Standards

All code follows strict standards enforced by CI:

- **Error handling**: `set -Eeuo pipefail; IFS=$'\n\t'`
- **Input validation**: Validate early, fail fast
- **Atomic I/O**: Use `atomic_write()` for file operations
- **Quoting**: Quote all variables
- **Functions**: Pure where possible, clear side effects
- **Documentation**: Docstrings for all public functions
- **Testing**: ShellSpec tests for all features

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed standards.

---

## 📊 Current Status

### Phase 0: Foundation ✅ (Complete - Merged)

- [x] Project structure
- [x] Core CLI with argument parsing
- [x] Common utilities library
- [x] ShellSpec testing framework
- [x] Pre-commit hooks
- [x] CI/CD (GitHub Actions)
- [x] Documentation

**Metrics:** 1,951 LOC, 8 tests (100%)

### Phase 1: Core Infrastructure ✅ (Complete - Merged)

- [x] Error handling module (239 LOC, 21 tests)
- [x] Logging system (356 LOC, 32 tests)
- [x] Utility functions (268 LOC, 40 tests)

**Metrics:** 1,100 LOC, 101 tests (100%), 59% code reduction

### Phase 2: Work & Goals ✅ (Complete - Merged)

- [x] Work session tracking (270 LOC, 18 tests)
- [x] Goal management (222 LOC, 20 tests)
- [x] CLI integration (`harm-cli work|goal`)

**Metrics:** 492 LOC, 38 tests (100%), 79% code reduction

### Phase 3: AI Integration ✅ (Complete - Ready for PR)

- [x] Gemini API integration (692 LOC, 39 tests)
- [x] Context-aware queries
- [x] Secure API key management (keychain/env)
- [x] Response caching (1-hour TTL)
- [x] CLI integration (`harm-cli ai`)

**Metrics:** 1,022 LOC, 50 tests (100%), 99% code reduction

**Key Features:**

- Pure bash implementation (no Python dependencies)
- 5-level security fallback (env → keychain → secret-tool → pass → config)
- Comprehensive logging (DEBUG/INFO/WARN/ERROR)
- Offline fallback suggestions
- JSON + text output formats

### Phase 4: Git & Projects ✅ (Complete - Ready for PR)

- [x] Enhanced git workflows (280 LOC, 11 tests)
- [x] AI-powered commit messages
- [x] Project management (244 LOC, 18 tests)
- [x] Project switching and registry

**Metrics:** 524 LOC, 29 tests (100%)

**Key Features:**

- AI-generated conventional commit messages
- Enhanced git status with suggestions
- Project registry (JSONL format)
- Quick project switching
- Type auto-detection (nodejs, python, rust, go, shell)

### Phase 5: Development Tools ✅ (Complete - Merged)

- [x] Docker management (container lifecycle, logs, health checks)
- [x] Python development tools (test, lint, format)
- [x] Google Cloud SDK integration
- [x] Health monitoring system

**Key Features:**

- Full Docker Compose integration
- Python environment detection and management
- GCloud configuration and status
- Comprehensive health checks

### Phase 6: Safety & Monitoring ✅ (Complete - Merged)

- [x] Safety module (dangerous operation protection)
- [x] Work session enhancements (focus tracking)
- [x] Goal validation with AI
- [x] Activity monitoring

**Key Features:**

- Confirmation prompts for risky operations
- Automatic backups before destructive commands
- AI-powered goal validation
- Enhanced work session enforcement

### Phase 7: Shell Integration ✅ (Complete - Merged)

- [x] Bash completions
- [x] Shell initialization hooks
- [x] Command integration

**Key Features:**

- Tab completion for all commands
- Shell initialization via `harm-cli init`
- Seamless integration with existing workflows

### Phase 8: Polish & Release ✅ (Complete - Merged)

- [x] Man page generation
- [x] Comprehensive documentation
- [x] Release engineering (v1.0.0)
- [x] Production-ready quality

**Key Features:**

- Professional man pages
- Complete command reference (COMMANDS.md)
- Semantic versioning
- Production stability

---

## 🎉 What's New in v1.0.0

The complete migration from 19,000 LOC ZSH to modern Bash is **COMPLETE**!

**Major Features:**

- 🤖 **AI Assistant** - Gemini-powered code review, commit messages, and daily insights
- 🐳 **Docker Management** - Full lifecycle control with health checks
- 🐍 **Python Support** - Testing, linting, and formatting built-in
- ☁️ **Google Cloud** - GCloud SDK integration
- 🛡️ **Safety Features** - Protection for dangerous operations
- 📊 **Work Tracking** - Sessions, goals, and productivity insights
- 🔧 **Git Workflows** - AI-powered commit messages and enhanced status
- 📁 **Project Registry** - Quick project switching with type detection

**By the Numbers:**

- **287 tests** (100% passing)
- **14 library modules** covering all use cases
- **93% code reduction** from original ZSH implementation
- **Zero dependencies** beyond Bash 5+, Git, and jq

See [docs/PROGRESS.md](docs/PROGRESS.md) for detailed migration history.

---

## 🧪 Testing Framework

Uses **ShellSpec** for BDD-style testing:

```bash
Describe 'harm-cli core'
  It 'shows version'
    When run harm-cli version
    The status should be success
    The output should include "1.0.0"
  End
End
```

**Coverage:**

- Core CLI: ✅ 10 tests
- Error handling: ✅ 21 tests
- Logging: ✅ 32 tests
- Utilities: ✅ 40 tests
- Work sessions: ✅ 18 tests
- Goals: ✅ 20 tests
- AI integration: ✅ 50 tests
- Git workflows: ✅ 11 tests
- Project management: ✅ 18 tests
- Docker management: ✅ 12 tests
- Python development: ✅ 15 tests
- GCloud integration: ✅ 8 tests
- Health checks: ✅ 14 tests
- Safety module: ✅ 18 tests
- Shell integration: ✅ 10 tests
- **Total: 287 tests (100% passing)**

---

## 📝 License

MIT License - See [LICENSE](LICENSE) for details

---

## 🤝 Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**Quick start for contributors:**

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make changes following code standards
4. Run tests: `just ci`
5. Commit: `git commit -m "feat: add amazing feature"`
6. Push: `git push origin feature/amazing-feature`
7. Open a Pull Request

---

## 🔒 Security

Report security vulnerabilities privately to: **haalbers@gmail.com**

See [SECURITY.md](SECURITY.md) for details.

---

## 📚 Resources

- **Documentation**: [docs/](docs/)
- **Issue Tracker**: [GitHub Issues](https://github.com/HarmAalbers/harm-cli/issues)
- **Discussions**: [GitHub Discussions](https://github.com/HarmAalbers/harm-cli/discussions)

---

**Built with ❤️ by Harm Aalbers**
