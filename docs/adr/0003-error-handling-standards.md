# ADR-0003: Error Handling and Logging Standards

**Status**: Accepted

**Date**: 2025-12-30

## Context

Consistent error handling and logging are critical for:

- Debugging issues in production
- User experience (clear error messages)
- Scriptability (predictable exit codes)
- Observability (structured logs)

Without standards, each module handles errors differently, making the CLI unpredictable.

## Decision

Adopt standardized error handling functions and logging levels.

### Error Handling Functions

| Function           | Purpose                            | Exit? |
| ------------------ | ---------------------------------- | ----- |
| `die "msg" [code]` | Fatal error, print to stderr, exit | Yes   |
| `warn "msg"`       | Non-fatal warning to stderr        | No    |
| `error_msg "msg"`  | Error message without exit         | No    |

### Logging Functions

| Function          | Level | When to Use                          |
| ----------------- | ----- | ------------------------------------ |
| `log_debug "msg"` | 0     | Development, verbose troubleshooting |
| `log_info "msg"`  | 1     | Normal operation milestones          |
| `log_warn "msg"`  | 2     | Recoverable issues, deprecations     |
| `log_error "msg"` | 3     | Errors that don't cause exit         |

### Log Level Control

```bash
export HARM_LOG_LEVEL=0  # DEBUG (all messages)
export HARM_LOG_LEVEL=1  # INFO (default)
export HARM_LOG_LEVEL=2  # WARN
export HARM_LOG_LEVEL=3  # ERROR only
```

### Exit Codes

| Code | Meaning                               |
| ---- | ------------------------------------- |
| 0    | Success                               |
| 1    | General error                         |
| 2    | Invalid input/arguments               |
| 16   | Configuration error                   |
| 64   | Usage error (EX_USAGE)                |
| 70   | Internal software error (EX_SOFTWARE) |
| 111  | Service unavailable                   |
| 124  | Timeout                               |
| 130  | Interrupted (Ctrl+C)                  |

### Allowed

- Using `die` for unrecoverable errors
- Using log functions for all diagnostic output
- Returning meaningful exit codes
- Logging to stderr, output to stdout

### Prohibited

- Using `echo` for errors (use `die` or `error_msg`)
- Using `exit` directly without error message
- Logging to stdout (breaks piping)
- Non-standard exit codes without documentation

## Output Contract

```
┌─────────────────────────────────────────┐
│              User Command               │
└───────────────┬─────────────────────────┘
                │
    ┌───────────┴───────────┐
    ▼                       ▼
┌───────────┐         ┌───────────┐
│  stdout   │         │  stderr   │
│           │         │           │
│ • Results │         │ • Logs    │
│ • Data    │         │ • Errors  │
│ • Output  │         │ • Warnings│
└───────────┘         └───────────┘
    │                       │
    ▼                       ▼
  Piped to               Displayed
  next command           to user
```

## Consequences

### Positive

- **Predictable**: Same error handling everywhere
- **Debuggable**: Log levels allow verbose troubleshooting
- **Scriptable**: Exit codes enable automation
- **User-friendly**: Clear error messages

### Negative

- **Discipline required**: Must use functions, not raw echo/exit
- **Verbosity**: More code for simple errors
- **Learning curve**: Contributors must learn the patterns

## Enforcement

- [x] **Code review**: Error handling patterns checked
- [x] **Documentation**: CLAUDE.md documents the pattern
- [x] **Linting**: shellcheck catches some issues

## Examples

### Fatal Error

```bash
validate_input() {
  local input="${1:-}"
  [[ -n "$input" ]] || die "Input required" 2
  [[ -f "$input" ]] || die "File not found: $input" 2
}
```

### Recoverable Warning

```bash
load_config() {
  local config_file="$HOME/.config/harm-cli/config.json"
  if [[ ! -f "$config_file" ]]; then
    log_warn "Config file not found, using defaults"
    return 0
  fi
  # Load config...
}
```

### Debug Logging

```bash
api_request() {
  local url="$1"
  log_debug "API request: $url"

  local response
  if response=$(curl -s "$url"); then
    log_debug "API response: ${response:0:100}..."
    echo "$response"
  else
    log_error "API request failed"
    return 111
  fi
}
```

## References

- [ADR-0001: Strict Mode Required](0001-strict-mode-required.md)
- [Sysexits.h](https://man.openbsd.org/sysexits) - Standard exit codes
- [12 Factor App - Logs](https://12factor.net/logs)
