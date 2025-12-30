# Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records (ADRs) for harm-cli.

## What are ADRs?

ADRs document significant architectural decisions made in this project. Each ADR describes:

- The context and problem being addressed
- The decision made
- The consequences (positive and negative)
- How the decision is enforced

## When to Create an ADR

Create an ADR when making decisions about:

- Code standards and conventions
- Tool choices (testing frameworks, build tools, etc.)
- Module organization and dependencies
- Interface contracts (CLI flags, output formats)
- Security practices

## ADR Lifecycle

| Status         | Meaning                            |
| -------------- | ---------------------------------- |
| **Proposed**   | Under discussion, not yet accepted |
| **Accepted**   | Decision is active and enforced    |
| **Deprecated** | No longer applies to new code      |
| **Superseded** | Replaced by another ADR            |

## Index

| ADR                                         | Title                                  | Status   |
| ------------------------------------------- | -------------------------------------- | -------- |
| [0001](0001-strict-mode-required.md)        | Strict Mode Required in All Bash Files | Accepted |
| [0002](0002-module-loading-pattern.md)      | Module Loading and Bootstrap Pattern   | Accepted |
| [0003](0003-error-handling-standards.md)    | Error Handling and Logging Standards   | Accepted |
| [0004](0004-testing-framework-shellspec.md) | Testing Framework - ShellSpec          | Accepted |
| [0005](0005-build-tool-just.md)             | Build Tool - Just                      | Accepted |
| [0006](0006-json-output-support.md)         | JSON Output Support                    | Accepted |

## Creating a New ADR

1. Copy `_template.md` to `NNNN-short-title.md`
2. Fill in all sections
3. Submit PR for review
4. Update this README's index

## Enforcement

ADRs are enforced through:

- **Pre-commit hooks** - Automated checks on commit
- **CI/CD pipeline** - GitHub Actions validation
- **Code review** - Manual verification during PR review
- **CLAUDE.md** - AI assistant guidance
