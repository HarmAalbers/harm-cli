# Contributing to harm-cli

Thank you for considering contributing to harm-cli! This document outlines the standards and workflow for contributions.

---

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Development Setup](#development-setup)
- [Code Standards](#code-standards)
- [Testing Requirements](#testing-requirements)
- [Commit Convention](#commit-convention)
- [Pull Request Process](#pull-request-process)

---

## 🤝 Code of Conduct

- Be respectful and constructive
- Focus on the code, not the person
- Welcome newcomers and help them learn
- Follow professional engineering practices

---

## 🛠️ Development Setup

### 1. Fork and Clone

```bash
git clone https://github.com/YOUR_USERNAME/harm-cli.git
cd harm-cli
```

### 2. Install Dependencies

```bash
# macOS
brew install just shellcheck shfmt shellspec jq pre-commit

# Verify installation
just doctor
```

### 3. Set Up Pre-commit Hooks

```bash
pre-commit install
```

### 4. Create Feature Branch

```bash
git checkout -b feature/your-feature-name
```

---

## 📏 Code Standards

### Shell Script Standards

**ALL code must follow these rules:**

#### 1. Strict Mode (MANDATORY)

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
```

#### 2. Function Structure

```bash
# Good: Clear, documented, validated
my_function() {
  local input="${1:?input required}"
  local optional="${2:-default}"

  # Validate early
  [[ -n "$input" ]] || die "Input cannot be empty" 2

  # Do work
  local result
  result="$(process "$input")"

  # Return via stdout
  printf '%s\n' "$result"
}

# Bad: No validation, global mutation, unclear contract
my_function() {
  RESULT=$(echo $1 | sed 's/foo/bar/')  # ❌ Many violations
}
```

#### 3. Input Validation

```bash
# ALWAYS validate inputs
require_arg "$name" "Name"
validate_int "$count" || die "Count must be integer" 2
validate_format "$format"
```

#### 4. Atomic File Operations

```bash
# Good: Atomic write
echo "content" | atomic_write "$file"

# Bad: Direct write (not atomic)
echo "content" > "$file"  # ❌ Not safe for concurrent access
```

#### 5. Error Handling

```bash
# Good: Proper error handling
if ! command_that_might_fail; then
  log_error "Command failed: $(command_that_might_fail 2>&1)"
  die "Fatal error occurred" 1
fi

# Bad: Ignoring errors
command_that_might_fail || true  # ❌ Silent failure
```

#### 6. Quoting (ALWAYS)

```bash
# Good: Everything quoted
local file="$1"
local dir="$(dirname -- "$file")"
rm -f -- "$file"

# Bad: Unquoted (breaks on spaces)
file=$1              # ❌
dir=$(dirname $file) # ❌
rm -f $file          # ❌
```

#### 7. Output Contracts

```bash
# User-facing output → stdout
# Logs/diagnostics → stderr
# Exit codes → meaningful (0, 2, 16, 64, 70, 111, 124, 130)

my_command() {
  log_info "Processing..."  # → stderr
  echo "result"             # → stdout
  return 0                  # success
}
```

### Documentation Standards

```bash
# function_name: Brief description
# Usage: function_name "arg1" "arg2"
# Returns: Description of output
# Exit codes: 0=success, 1=error, 2=invalid input
function_name() {
  # Implementation
}
```

---

## 🧪 Testing Requirements

### EVERY change MUST include tests

#### 1. Write Tests First (TDD)

```bash
# spec/my_feature_spec.sh
Describe 'My Feature'
  It 'handles valid input'
    When run harm-cli my-feature "valid"
    The status should be success
    The output should include "expected"
  End

  It 'rejects invalid input'
    When run harm-cli my-feature ""
    The status should be failure
    The error should include "required"
  End
End
```

#### 2. Test Coverage Requirements

- **New features**: 100% coverage
- **Bug fixes**: Test reproducing the bug FIRST
- **Refactoring**: Maintain existing coverage

#### 3. Test Both Shells

```bash
# Run with both bash and zsh
just test-bash
just test-zsh
```

#### 4. Mock External Dependencies

```bash
Describe 'API calls'
  # Mock curl for testing
  curl() { echo '{"status": "ok"}'; }

  It 'handles API response'
    When run harm-cli api-command
    The output should include "ok"
  End
End
```

---

## 📝 Commit Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```bash
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting (no code change)
- `refactor`: Code restructuring (no behavior change)
- `perf`: Performance improvement
- `test`: Adding tests
- `chore`: Maintenance (dependencies, tooling)

### Examples

```bash
feat(work): add work session start/stop commands

Implements work session tracking with:
- Start/stop commands
- Session persistence in JSON
- Automatic time tracking

Closes #42

---

fix(logging): prevent log rotation during active write

Previously, log rotation could occur mid-write, causing
corruption. Now uses file locking.

Fixes #56

---

docs(readme): add installation instructions for Linux

---

test(cli): add tests for error handling edge cases
```

---

## 🔄 Pull Request Process

### 1. Before Opening PR

```bash
# Ensure everything passes
just ci

# Run pre-commit hooks
just pre-commit

# Check for unstaged changes
git status
```

### 2. PR Description Template

```markdown
## Summary

Brief description of changes

## Motivation

Why is this change needed?

## Changes

- List of specific changes
- One per line

## Testing

- [ ] Added unit tests
- [ ] Tested with bash
- [ ] Tested with zsh
- [ ] All tests pass (`just ci`)

## Checklist

- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] Commit messages follow convention
- [ ] No breaking changes (or documented)
```

### 3. Review Process

1. Automated checks must pass (CI)
2. Code review by maintainer
3. Requested changes addressed
4. Approval + merge

### 4. After Merge

- Feature branch deleted
- Changelog updated (automated)
- Release notes (if applicable)

---

## 🎯 What to Contribute

### High Priority

- **Phase 1-8 Features**: See [PROJECT_PLAN.md](docs/PROJECT_PLAN.md)
- **Bug Fixes**: Check [Issues](https://github.com/HarmAalbers/harm-cli/issues)
- **Test Coverage**: Improve existing tests
- **Documentation**: Examples, guides, tutorials

### Good First Issues

Look for issues tagged `good-first-issue`:

- Documentation improvements
- Adding tests to existing features
- Minor bug fixes
- Shell completion enhancements

---

## ❓ Questions?

- **Documentation**: Check [docs/](docs/)
- **Discussions**: [GitHub Discussions](https://github.com/HarmAalbers/harm-cli/discussions)
- **Issues**: [GitHub Issues](https://github.com/HarmAalbers/harm-cli/issues)

---

## 📚 Additional Resources

- [ShellSpec Documentation](https://shellspec.info/)
- [ShellCheck Wiki](https://www.shellcheck.net/wiki/)
- [Bash Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Conventional Commits](https://www.conventionalcommits.org/)

---

**Thank you for contributing!** 🎉
