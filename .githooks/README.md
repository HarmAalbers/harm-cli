# Git Hooks for harm-cli

This directory contains custom git hooks to enforce code quality and conventional commits.

## Installation

```bash
# One-time setup
./.githooks/setup.sh

# Or manually
git config core.hooksPath .githooks
```

## Available Hooks

### commit-msg

Validates commit messages follow the Conventional Commits specification.

**Format**: `type(scope): description`

**Valid types**:
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation
- `test` - Tests
- `refactor` - Code refactoring
- `chore` - Maintenance
- `style` - Formatting
- `perf` - Performance
- `ci` - CI/CD
- `build` - Build system
- `revert` - Revert commit

**Examples**:
```
feat(goals): add reopen command to restore completed goals
fix(work): resolve timer cleanup on stop
docs: update installation guide
test(ai): add edge case tests for model selection
```

**Bypass**: `git commit --no-verify` (not recommended)

### pre-commit

Runs quality checks before each commit:
1. Code formatting (shfmt)
2. Linting (shellcheck)
3. Test suite (shellspec)

**Skip tests**: `SKIP_TESTS=1 git commit`

**Bypass all**: `git commit --no-verify`

## Troubleshooting

### Hook not running

Ensure hooks are executable:
```bash
chmod +x .githooks/*
```

Verify git configuration:
```bash
git config core.hooksPath
# Should output: .githooks
```

### Commit rejected

Read the error message carefully. Common issues:
- Commit message too short (min 10 chars)
- Missing type prefix (feat:, fix:, etc.)
- Code formatting issues (run `just fmt`)
- Linting errors (run `just lint`)
- Test failures (run `just test`)

### Skip hooks temporarily

For emergency commits only:
```bash
git commit --no-verify -m "emergency fix"
```

## Development

### Testing hooks locally

Test commit-msg hook:
```bash
echo "feat(test): sample commit message" | .githooks/commit-msg /dev/stdin
echo $?  # Should be 0 (success)

echo "bad commit" | .githooks/commit-msg /dev/stdin
echo $?  # Should be 1 (failure)
```

Test pre-commit hook:
```bash
./.githooks/pre-commit
```

### Adding new hooks

1. Create executable script in `.githooks/`
2. Update this README
3. Test thoroughly before committing

## See Also

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Git Hooks Documentation](https://git-scm.com/docs/githooks)
