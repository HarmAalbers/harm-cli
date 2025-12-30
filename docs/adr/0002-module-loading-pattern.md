# ADR-0002: Module Loading and Bootstrap Pattern

**Status**: Accepted

**Date**: 2025-12-30

## Context

harm-cli consists of 32+ library modules providing various functionality. Loading all modules at startup would:

- Slow down CLI startup time
- Increase memory usage
- Create unnecessary dependencies between unrelated features

We need a consistent, predictable way to load shared code while keeping startup fast.

## Decision

Use a layered module loading pattern with a core bootstrap and on-demand loading.

### Architecture

```
bin/harm-cli (entry point)
    │
    └── source lib/common.sh (bootstrap)
            │
            ├── source lib/error.sh    (always loaded)
            ├── source lib/logging.sh  (always loaded)
            └── source lib/util.sh     (always loaded)

    Command dispatch loads additional modules on-demand:
    └── work command  → source lib/work.sh
    └── ai command    → source lib/ai.sh
    └── docker command → source lib/docker.sh
    └── etc.
```

### Core Modules (Always Loaded)

| Module       | Purpose                               |
| ------------ | ------------------------------------- |
| `common.sh`  | Bootstrap, sources other core modules |
| `error.sh`   | Exit codes, `die()`, colored output   |
| `logging.sh` | `log_debug/info/warn/error` functions |
| `util.sh`    | String, array, file utilities         |

### Allowed

- Sourcing `common.sh` from entry point only
- On-demand loading of feature modules in command handlers
- Feature modules sourcing other feature modules they depend on
- Using `source` with shellcheck directive for path resolution

### Prohibited

- Sourcing `common.sh` multiple times
- Circular dependencies between modules
- Feature modules directly sourcing core modules (they get them via common.sh)
- Loading all modules at startup

## Module Dependency Rules

```
┌─────────────────────────────────────────────────┐
│                   Entry Point                    │
│                  bin/harm-cli                    │
└─────────────────────┬───────────────────────────┘
                      │ sources
                      ▼
┌─────────────────────────────────────────────────┐
│                   Bootstrap                      │
│                  lib/common.sh                   │
│    ┌──────────┬──────────────┬────────────┐     │
│    │ error.sh │ logging.sh   │  util.sh   │     │
│    └──────────┴──────────────┴────────────┘     │
└─────────────────────┬───────────────────────────┘
                      │ provides to
                      ▼
┌─────────────────────────────────────────────────┐
│              Feature Modules                     │
│  work.sh, ai.sh, docker.sh, git.sh, etc.        │
│  (loaded on-demand per command)                  │
└─────────────────────────────────────────────────┘
```

## Consequences

### Positive

- **Fast startup**: Only load what's needed for the command
- **Clear dependencies**: Easy to understand what each command needs
- **Isolation**: Feature modules don't affect each other
- **Testability**: Modules can be tested in isolation

### Negative

- **Boilerplate**: Each command handler must source its modules
- **Load order matters**: Must source dependencies before dependents
- **No compile-time checking**: Missing sources fail at runtime

## Enforcement

- [x] **Code review**: Module loading patterns checked in PRs
- [x] **Documentation**: CLAUDE.md documents the pattern
- [ ] **CI check**: Could add static analysis for circular deps

## Example: Command Handler

```bash
# In bin/harm-cli
cmd_work() {
  # Load work module on-demand
  # shellcheck source=lib/work.sh
  source "$SCRIPT_DIR/../lib/work.sh"

  case "${1:-}" in
    start) work_start "${@:2}" ;;
    stop)  work_stop "${@:2}" ;;
    *)     work_status ;;
  esac
}
```

## References

- [ADR-0001: Strict Mode Required](0001-strict-mode-required.md)
- [ADR-0003: Error Handling Standards](0003-error-handling-standards.md)
