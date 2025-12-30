# ADR-0001: Strict Mode Required in All Bash Files

**Status**: Accepted

**Date**: 2025-12-30

## Context

Bash scripts are notoriously error-prone. By default, Bash:

- Continues execution after command failures
- Allows use of undefined variables
- Ignores pipeline failures
- Treats whitespace inconsistently in word splitting

These defaults lead to silent failures, data corruption, and difficult-to-debug issues. A professional CLI toolkit requires predictable, fail-fast behavior.

## Decision

All Bash files in this repository MUST begin with strict mode settings.

### Required Header

Every `.sh` file and the main CLI entry point must include:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
```

### Flag Meanings

| Flag          | Effect                                                 |
| ------------- | ------------------------------------------------------ |
| `-E`          | ERR traps are inherited by functions and subshells     |
| `-e`          | Exit immediately on command failure                    |
| `-u`          | Treat unset variables as errors                        |
| `-o pipefail` | Pipeline fails if any command fails, not just the last |
| `IFS=$'\n\t'` | Safer word splitting (no space splitting)              |

### Allowed

- Temporarily disabling flags for specific commands that legitimately fail:
  ```bash
  set +e
  result=$(command_that_might_fail)
  exit_code=$?
  set -e
  ```
- Using `|| true` for commands where failure is expected and handled
- Using `|| :` as a no-op for intentional ignoring

### Prohibited

- Files without the strict mode header
- Using `set +e` without re-enabling with `set -e`
- Global disabling of strict mode
- Unquoted variable expansion (except in `[[ ]]` conditionals)

## Consequences

### Positive

- **Early failure detection**: Errors surface immediately, not silently
- **Predictable behavior**: No surprises from unset variables
- **Pipeline safety**: Hidden failures in pipes are caught
- **Cleaner code**: Forces explicit error handling

### Negative

- **Learning curve**: Contributors must understand strict mode patterns
- **More verbose**: Some patterns require explicit error handling
- **grep/find edge cases**: Commands that return non-zero for "not found" need special handling

## Enforcement

- [x] **Pre-commit hook**: shellcheck validates scripts
- [x] **CI/CD check**: GitHub Actions runs shellcheck
- [x] **Code review**: Required for all PRs
- [x] **Documentation**: CLAUDE.md references this ADR

## Patterns for Common Issues

### grep with no matches

```bash
# Bad: Fails with strict mode when no match
matches=$(grep "pattern" file)

# Good: Handle no-match case explicitly
if matches=$(grep "pattern" file 2>/dev/null); then
  echo "Found: $matches"
else
  echo "No matches"
fi
```

### Optional commands

```bash
# Bad: Fails if command doesn't exist
optional_tool --version

# Good: Check existence first
if command -v optional_tool >/dev/null 2>&1; then
  optional_tool --version
fi
```

## References

- [Bash Strict Mode](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
- [ShellCheck SC2086](https://www.shellcheck.net/wiki/SC2086) - Quote to prevent word splitting
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
