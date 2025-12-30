# ADR-0006: JSON Output Support

**Status**: Accepted

**Date**: 2025-12-30

## Context

CLI tools are often used in scripts and pipelines. Human-readable output is great for interactive use, but machine-readable output is essential for:

- Automation scripts
- Integration with other tools
- Parsing in CI/CD pipelines
- Building UIs on top of the CLI

## Decision

All harm-cli commands MUST support JSON output format.

### Activation Methods

```bash
# Method 1: Command argument
harm-cli version json
harm-cli work status json

# Method 2: Environment variable
export HARM_CLI_FORMAT=json
harm-cli version
harm-cli work status

# Method 3: Flag (where supported)
harm-cli --format json version
```

### Output Rules

| Mode               | stdout                | stderr                                     |
| ------------------ | --------------------- | ------------------------------------------ |
| **Text** (default) | Human-readable output | Logs, errors, warnings                     |
| **JSON**           | Valid JSON only       | Logs, errors (also as JSON where possible) |

### Allowed

- Commands outputting valid JSON to stdout
- Text fallback when JSON not requested
- JSON errors with `{"error": "message", "code": N}` format
- Nested JSON for complex data

### Prohibited

- Invalid JSON (must pass `jq .` validation)
- Mixing text and JSON in stdout
- JSON output without text fallback
- Breaking JSON schema changes without version bump

## Implementation Pattern

```bash
cmd_example() {
  local format="${HARM_CLI_FORMAT:-text}"

  # Gather data
  local data
  data=$(get_data)

  # Output based on format
  if [[ "$format" == "json" ]]; then
    jq -n \
      --arg data "$data" \
      --arg timestamp "$(date -Iseconds)" \
      '{data: $data, timestamp: $timestamp}'
  else
    echo "Data: $data"
    echo "Time: $(date)"
  fi
}
```

## Consequences

### Positive

- **Scriptable**: Easy to parse in bash, Python, etc.
- **Composable**: Works with jq, pipes, other tools
- **Testable**: JSON output can be validated
- **API-like**: CLI becomes a local API

### Negative

- **More code**: Every command needs two output paths
- **Maintenance**: Must keep text and JSON in sync
- **Complexity**: JSON formatting adds overhead

## Enforcement

- [x] **Code review**: New commands must support JSON
- [x] **Testing**: Tests verify JSON output validity
- [x] **Documentation**: CLAUDE.md documents the pattern
- [ ] **CI check**: Could add JSON schema validation

## JSON Schema Examples

### Version Command

```json
{
  "version": "1.1.0",
  "shell": "bash",
  "bash_version": "5.2.15"
}
```

### Work Status

```json
{
  "active": true,
  "session": {
    "task": "Implementing feature X",
    "started": "2025-12-30T10:00:00Z",
    "duration_minutes": 45
  }
}
```

### Error Response

```json
{
  "error": "Configuration file not found",
  "code": 16,
  "details": {
    "path": "/home/user/.config/harm-cli/config.json"
  }
}
```

## Testing JSON Output

```bash
Describe 'version command'
  It 'outputs valid JSON'
    When run harm-cli version json
    The status should be success
    The output should be valid json
  End

  It 'includes version field'
    When run harm-cli version json
    The output should include '"version"'
  End
End
```

Custom matcher in `spec/helpers/matchers.sh`:

```bash
shellspec_syntax 'shellspec_matcher_be_valid_json'
shellspec_matcher_be_valid_json() {
  shellspec_matcher__match() {
    echo "$SHELLSPEC_SUBJECT" | jq . >/dev/null 2>&1
  }
}
```

## References

- [jq Manual](https://stedolan.github.io/jq/manual/)
- [ADR-0003: Error Handling Standards](0003-error-handling-standards.md)
- [12 Factor CLI Apps](https://medium.com/@jdxcode/12-factor-cli-apps-dd3c227a0e46)
