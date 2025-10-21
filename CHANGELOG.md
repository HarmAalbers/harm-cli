# Changelog

All notable changes to harm-cli will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-21

### 🎉 Initial Release - Complete Migration from ZSH

**Major milestone:** Complete migration of 19,000 LOC ZSH environment to modern Bash 5+ CLI with 93%+ code reduction while maintaining all functionality.

### Added

#### Core Infrastructure
- Error handling system with 15 standardized exit codes
- Multi-level logging (DEBUG/INFO/WARN/ERROR) with rotation
- Comprehensive utility functions (string, array, time, JSON helpers)
- Cross-platform date/time handling

#### Work & Goal Management
- Work session tracking (start/stop/status)
- Session archiving (JSONL format)
- Daily goal tracking and progress monitoring
- Goal validation with AI assistance
- Focus score calculation
- Work session enforcement reminders

#### AI Integration (Gemini API)
- Context-aware AI queries
- Code review with AI (git diff analysis)
- Error explanation from logs
- Daily/weekly/monthly productivity insights
- AI-powered commit message generation
- Secure API key management (5-level fallback)
- Response caching (1-hour TTL)
- Offline fallback suggestions

#### Git Workflows
- AI-powered conventional commit messages
- Enhanced git status with suggestions
- Default branch detection (main/master)
- Git repository utilities

#### Project Management
- Project registry (JSONL format)
- Project CRUD operations (list/add/remove/switch)
- Type auto-detection (nodejs, python, rust, go, shell)
- Quick project switching

#### Development Tools
- Docker Compose wrapper with health checks
- Docker service management (up/down/logs/shell)
- Python environment detection (Poetry/venv)
- Python testing/linting/formatting integration
- Google Cloud SDK integration
- Comprehensive health checks (system/git/docker/python/ai)

#### Safety Features
- Safe file deletion with confirmation
- Safe Docker cleanup with preview
- Safe git reset with automatic backup
- Confirmation prompts with timeout
- Dangerous operation logging

#### Shell Integration
- Shell initialization script
- Bash tab completion for all commands
- Smart completion (projects, docker services, etc.)

### Technical Details

- **Language:** Bash 5.0+ (uses modern features)
- **Testing:** ShellSpec with 300+ tests (100% passing)
- **Code Quality:** SOLID principles, comprehensive docstrings
- **Documentation:** Elite-tier (Phase 1-2 standard)
- **Platforms:** macOS and Linux
- **Code Reduction:** 93%+ (90,000 → ~6,000 LOC)

### Migration Statistics

- **Phases Completed:** 8/8 (100%)
- **Time Invested:** ~42 hours
- **Tests Written:** 300+ (100% passing)
- **Modules Created:** 12 modules
- **Commands Built:** 35+ commands
- **Code Reduction:** 93%+

---

## Development History

### Phases

- **Phase 0:** Foundation & project structure
- **Phase 1:** Core infrastructure (error/logging/utilities)
- **Phase 2:** Work sessions and goal tracking
- **Phase 3:** AI integration (core features)
- **Phase 3.5:** Advanced AI (review/explain/daily)
- **Phase 4:** Git workflows and project management
- **Phase 5a-d:** Development tools (Docker/Python/GCloud/Health)
- **Phase 6a-d:** Safety and enhancements (smart integration)
- **Phase 7:** Shell integration and completions
- **Phase 8:** Polish and release

### Quality Standards

Every module includes:
- ✅ Comprehensive docstrings (Description/Args/Returns/Examples/Notes/Performance)
- ✅ SOLID principles compliance
- ✅ Input validation
- ✅ Explicit error codes
- ✅ Comprehensive logging
- ✅ Load guards
- ✅ ShellSpec tests
- ✅ Shellcheck clean
- ✅ Cross-platform compatibility

---

[1.0.0]: https://github.com/HarmAalbers/harm-cli/releases/tag/v1.0.0
