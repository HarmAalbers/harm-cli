# harm-cli

> Personal CLI toolkit for elite-tier development workflows

**Version:** 0.1.0-alpha
**Status:** 🚧 Under active development - Phase 0 (Foundation) complete

---

## 🎯 Overview

`harm-cli` is a production-grade command-line toolkit designed to streamline development workflows with professional engineering standards. Built from a complete refactoring of a 19,000-line ZSH development environment, it follows elite-tier practices:

- ✅ **Strict error handling** - `set -Eeuo pipefail` everywhere
- ✅ **Comprehensive testing** - ShellSpec with bash + zsh coverage
- ✅ **Reproducible builds** - Deterministic releases with SBOM
- ✅ **Code quality gates** - Pre-commit hooks, linting, formatting
- ✅ **JSON + text output** - All commands support both formats
- ✅ **Atomic operations** - Safe file I/O with proper locking
- ✅ **CI/CD ready** - GitHub Actions with multi-shell testing

---

## 📦 Installation

### Prerequisites

**Required:**
- **Bash 5.0+** (uses modern features: associative arrays, ${var^^} expansion)
- Zsh 5.x (for zsh-specific features)
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

# Add to PATH (add to ~/.bashrc or ~/.zshrc)
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

# Get help
harm-cli help
harm-cli --help

# Initialize shell integration (coming soon)
harm-cli init
```

---

## 🏗️ Project Structure

```
harm-cli/
├── bin/
│   └── harm-cli              # Main CLI entry point
├── lib/
│   ├── common.sh             # Core utilities (error handling, logging, I/O)
│   ├── zsh/                  # Zsh-specific helpers
│   └── bash/                 # Bash-specific helpers
├── spec/
│   ├── helpers/              # Test utilities
│   │   ├── env.sh            # Test environment setup
│   │   └── matchers.sh       # Custom assertions
│   ├── golden/               # Golden output files
│   └── cli_core_spec.sh      # ShellSpec tests
├── etc/                      # Configuration files
├── completions/              # Shell completions (bash, zsh)
├── man/                      # Man pages
├── docs/                     # Documentation
├── scripts/                  # Build and release scripts
├── .github/workflows/        # CI/CD pipelines
├── Justfile                  # Task runner commands
├── .pre-commit-config.yaml   # Pre-commit hooks
├── .shellspec                # ShellSpec configuration
└── VERSION                   # Semantic version
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
just test                # Run all tests (bash + zsh)
just test-bash           # Test with bash only
just test-zsh            # Test with zsh only
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

# Release (future)
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

### Phase 0: Foundation ✅ (Complete)

- [x] Project structure
- [x] Core CLI with argument parsing
- [x] Common utilities library
- [x] ShellSpec testing framework
- [x] Pre-commit hooks
- [x] CI/CD (GitHub Actions)
- [x] Documentation

**Metrics:**
- 472 lines of code
- 8 ShellSpec tests (100% passing)
- Bash + Zsh support

### Coming Soon (Phases 1-8)

**Phase 1: Core Infrastructure** (Next)
- Error handling module
- Logging system (multi-level, JSON output)
- Utility functions

**Phase 2: Work & Goals**
- Work session tracking
- Goal management
- Progress reporting

**Phase 3: AI Integration**
- OpenAI API integration
- AI-powered commit messages
- Goal validation

**Phase 4: Git & Projects**
- Enhanced git workflows
- Project management
- Smart commits

**Phase 5+:**
- Docker management
- Python development tools
- Health monitoring
- Activity tracking

See [PROJECT_PLAN.md](docs/PROJECT_PLAN.md) for full roadmap.

---

## 🧪 Testing Framework

Uses **ShellSpec** for BDD-style testing:

```bash
Describe 'harm-cli core'
  It 'shows version'
    When run harm-cli version
    The status should be success
    The output should include "0.1.0-alpha"
  End
End
```

**Coverage:**
- Core CLI: ✅ 8 tests
- Version command: ✅
- Help command: ✅
- Doctor command: ✅
- Error handling: ✅

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
