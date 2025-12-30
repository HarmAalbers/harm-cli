# ADR-0004: Testing Framework - ShellSpec

**Status**: Accepted

**Date**: 2025-12-30

## Context

Bash scripts require testing just like any other code. Options considered:

| Framework     | Pros                                        | Cons                             |
| ------------- | ------------------------------------------- | -------------------------------- |
| **ShellSpec** | BDD syntax, good isolation, mocking support | Another tool to install          |
| Bats          | Popular, simple                             | Limited mocking, less expressive |
| shunit2       | xUnit style, mature                         | Verbose, dated                   |
| Plain bash    | No dependencies                             | No structure, poor isolation     |

## Decision

Use **ShellSpec** as the testing framework for all harm-cli tests.

### Why ShellSpec

1. **BDD syntax**: Readable, self-documenting tests
2. **Proper isolation**: Each test runs in a subshell
3. **Mocking support**: Function and command mocking
4. **Good output**: Multiple formatters (documentation, tap, junit)
5. **Active maintenance**: Regular updates, good documentation

### Test Location

```
spec/
├── helpers/
│   ├── env.sh         # Test environment setup
│   ├── matchers.sh    # Custom assertions
│   └── mocks.sh       # Shared mock functions
├── *_spec.sh          # Test files (one per module)
├── golden/            # Expected output snapshots
└── tmp/               # Temporary test artifacts (gitignored)
```

### Allowed

- One spec file per module (`work_spec.sh` for `work.sh`)
- Helper files in `spec/helpers/`
- Golden files for snapshot testing
- Mocking external commands and functions

### Prohibited

- Tests without corresponding spec file
- Skipped tests without explanation (`Skip "reason"`)
- Tests that depend on external state (network, specific files)
- Tests that modify files outside `spec/tmp/`

## Test Structure

```bash
Describe 'module_name'
  Include spec/helpers/env.sh

  Describe 'function_name'
    It 'handles valid input'
      When run function_name "valid"
      The status should be success
      The output should include "expected"
    End

    It 'rejects invalid input'
      When run function_name ""
      The status should be failure
      The stderr should include "required"
    End
  End
End
```

## Consequences

### Positive

- **Readable tests**: BDD syntax is self-documenting
- **Reliable**: Subshell isolation prevents test pollution
- **Flexible**: Supports multiple output formats for CI
- **Comprehensive**: 287+ tests covering all modules

### Negative

- **Dependency**: Requires ShellSpec installation
- **Learning curve**: BDD syntax differs from xUnit
- **Shellspec quirks**: Exit code 101 on some edge cases

## Enforcement

- [x] **CI/CD**: GitHub Actions runs all tests
- [x] **Pre-commit**: Tests can be run via `just test`
- [x] **Code review**: New code requires tests
- [x] **Documentation**: CLAUDE.md documents test patterns

## Test Isolation

### Environment Isolation

```bash
# In spec/helpers/env.sh
export HARM_CLI_HOME="$SHELLSPEC_TMPBASE/config"
export HARM_WORK_DIR="$SHELLSPEC_TMPBASE/work"
```

### Mocking External Commands

```bash
Describe 'api calls'
  # Mock curl for testing
  curl() {
    echo '{"status": "ok"}'
  }

  It 'parses API response'
    When run my_api_function
    The output should include "ok"
  End
End
```

## Running Tests

```bash
# All tests
just test

# Single file
just test-file spec/work_spec.sh

# Watch mode (TDD)
just test-watch

# With coverage
just coverage

# Debug output
shellspec --format trace spec/work_spec.sh
```

## References

- [ShellSpec Documentation](https://shellspec.info/)
- [ADR-0001: Strict Mode Required](0001-strict-mode-required.md)
- [CLAUDE.md - Testing Patterns](../../CLAUDE.md#testing-patterns)
