# ADR-0005: Build Tool - Just

**Status**: Accepted

**Date**: 2025-12-30

## Context

Development workflows require running multiple commands: testing, linting, formatting, building. Options considered:

| Tool          | Pros                                | Cons                          |
| ------------- | ----------------------------------- | ----------------------------- |
| **Just**      | Simple syntax, cross-platform, fast | Another tool to install       |
| Make          | Universal, no install needed        | Complex syntax, tab-sensitive |
| npm scripts   | Common in JS projects               | Not a shell project           |
| Shell scripts | No dependencies                     | Scattered, hard to discover   |

## Decision

Use **Just** as the primary task runner for all development commands.

### Why Just

1. **Simple syntax**: Easy to read and write recipes
2. **Cross-platform**: Works on macOS, Linux, Windows
3. **Fast**: Rust-based, no startup overhead
4. **Discoverable**: `just --list` shows all commands
5. **Shell-native**: Recipes are shell commands

### Justfile Location

The `Justfile` lives at the repository root with strict mode enabled:

```just
set shell := ["/usr/bin/env", "bash", "-Eeuo", "pipefail", "-c"]
```

### Allowed

- All development commands in Justfile
- Recipes calling scripts in `scripts/` for complex logic
- Recipes with parameters (`just test-file FILE`)
- Default recipe for most common action (`just` = `just ci`)

### Prohibited

- Ad-hoc shell scripts for common tasks
- Development commands not documented in Justfile
- Recipes without descriptions (use comments)
- Breaking changes to existing recipe names

## Command Categories

| Category        | Commands                                      |
| --------------- | --------------------------------------------- |
| **Testing**     | `test`, `test-file`, `test-watch`, `coverage` |
| **Quality**     | `fmt`, `lint`, `spell`, `pre-commit`          |
| **CI/CD**       | `ci`, `pre-push`                              |
| **Build**       | `build`, `release`, `sign`, `sbom`, `scan`    |
| **Development** | `doctor`, `info`, `clean`, `install-local`    |

## Consequences

### Positive

- **Discoverable**: `just --list` documents all commands
- **Consistent**: Everyone uses the same commands
- **Portable**: Works across developer machines
- **Composable**: Recipes can call other recipes

### Negative

- **Dependency**: Requires Just installation
- **Learning curve**: New syntax (though simple)
- **Another tool**: One more thing in the toolchain

## Enforcement

- [x] **Documentation**: CLAUDE.md documents key commands
- [x] **README**: Installation includes Just
- [x] **CI/CD**: GitHub Actions uses just commands
- [x] **doctor**: `just doctor` checks for Just

## Key Recipes

```bash
# Quick reference
just              # Runs default (ci)
just test         # Fast tests (bash only)
just ci           # Full CI: fmt + lint + test-all
just test-file X  # Run specific test file
just doctor       # Check all dependencies
just --list       # Show all available commands
```

## Adding New Recipes

```just
# Description of what this does
recipe-name PARAM:
    @echo "Running with {{PARAM}}..."
    command --flag "{{PARAM}}"
```

Guidelines:

- Add comment describing the recipe
- Use `@` prefix to hide command echo when appropriate
- Use `{{PARAM}}` for parameters
- Group related recipes with comment headers

## References

- [Just Documentation](https://just.systems/man/en/)
- [Justfile](../../Justfile)
- [ADR-0004: Testing Framework](0004-testing-framework-shellspec.md)
