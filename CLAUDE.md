# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

All commands use `just` (command runner). Run `just --list` for full list.

```bash
# Quick reference
just test              # Run tests (bash, 60s timeout)
just test-file FILE    # Run single test file
just ci                # Full CI: format + lint + test-all
just fmt               # Format with shfmt
just lint              # Lint with shellcheck
just doctor            # Check dependencies
```

### Testing

- Framework: ShellSpec (BDD-style)
- Config: `.shellspec`
- Tests: `spec/*_spec.sh`
- Helpers: `spec/helpers/` (env.sh, matchers.sh, mocks.sh)

```bash
just test-file spec/work_spec.sh    # Single file
just test-watch                     # Watch mode (TDD)
just coverage                       # With kcov coverage
shellspec --format trace FILE       # Debug output
```

## Architecture

### Core Structure

```
bin/harm-cli           # CLI entry point - dispatches to lib/*.sh
lib/
├── common.sh          # Foundation: sources error.sh, logging.sh, util.sh
├── error.sh           # Exit codes, die(), colored output
├── logging.sh         # log_debug/info/warn/error (levels 0-3)
├── util.sh            # String, array, file utilities
├── ai.sh              # Gemini API integration
├── work*.sh           # Work session tracking (5 modules)
├── goals.sh           # Goal management
├── safety.sh          # Dangerous operation protection
└── [others]           # docker, python, git, proj, health, etc.
```

### Module Loading Pattern

```bash
# bin/harm-cli bootstraps with:
source "$SCRIPT_DIR/../lib/common.sh"  # Loads error + logging + util

# Other modules loaded on-demand per command
```

### Key Functions

- `die "msg" [code]` - Fatal error with exit
- `log_info/warn/error/debug "msg"` - Leveled logging to stderr
- `atomic_write "$file"` - Safe file writes
- `require_arg "$val" "name"` - Input validation

## Code Standards

### Strict Mode (Required in ALL files)

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
```

### Function Pattern

```bash
my_function() {
  local input="${1:?input required}"   # Mandatory
  local optional="${2:-default}"       # Optional with default

  [[ -n "$input" ]] || die "Input empty" 2

  local result
  result="$(do_something)"
  printf '%s\n' "$result"              # Output via stdout
}
```

### Output Formats

All commands support `--format json` or `HARM_CLI_FORMAT=json`:

```bash
harm-cli version           # Text output
harm-cli version json      # JSON output
```

### ShellCheck Exclusions

These are disabled in `Justfile` (intentional patterns):

- SC2016: Unexpanded variables in single quotes
- SC2034: Unused variables (often intentional)
- SC2094: File descriptor issues
- SC2148: Missing shebang (sourced files)
- SC2155: Declare and assign separately

## Testing Patterns

### Test Structure

```bash
Describe 'feature'
  Include spec/helpers/env.sh

  It 'does something'
    When run command args
    The status should be success
    The output should include "expected"
  End
End
```

### Mocking

```bash
# In spec file:
curl() { echo '{"status": "ok"}'; }  # Override external commands

# Or use helpers:
Include spec/helpers/mocks.sh
```

### Test Isolation

- `HARM_CLI_HOME` - Override config directory per test
- `spec/tmp/` - Temporary test artifacts (gitignored)
- `spec/golden/` - Expected output snapshots

## Pre-commit Hooks

Configured in `.pre-commit-config.yaml`:

- shfmt (formatting)
- shellcheck (linting)
- codespell (spelling)
- Custom: bash arithmetic check, function parameter validation

## CI/CD

GitHub Actions (`.github/workflows/test.yml`):

- Runs on push to main/develop and PRs
- Parallel jobs: tests, shellcheck, shfmt, prettier, codespell
- Exit codes 0 and 101 both treated as success (shellspec quirk)
