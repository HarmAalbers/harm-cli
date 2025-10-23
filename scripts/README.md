# QA Automation Scripts

This directory contains automated QA tools for harm-cli.

## Scripts

### `qa-runner.sh` - Interactive Manual Test Runner

Guides testers through the QA checklist interactively with a menu-driven interface.

**Features:**

- Interactive test execution
- Real-time pass/fail/skip tracking
- Test result logging
- Category-based test organization
- Session summary reports

**Usage:**

```bash
./scripts/qa-runner.sh
```

**Example session:**

```
╔═══════════════════════════════════════════════════════════════╗
║              harm-cli QA Interactive Test Runner             ║
╚═══════════════════════════════════════════════════════════════╝

Select test category to run:

  1. Core Commands (12 tests)
  2. Work Session Management (6 tests)
  3. Goal Tracking (10 tests)
  ...
```

### `qa-coverage.sh` - Command Coverage Validator

Validates that all commands are documented, tested, and implemented.

**Features:**

- Compares COMMANDS.md to QA_CHECKLIST.md
- Tests command execution
- Counts ShellSpec test coverage
- Generates coverage reports

**Usage:**

```bash
./scripts/qa-coverage.sh
```

**Output:**

- Terminal summary of coverage gaps
- Markdown coverage report in `coverage-report-<timestamp>.md`

### `qa-report.sh` - Test Report Generator

Generates comprehensive test reports from ShellSpec and QA session logs.

**Features:**

- ShellSpec test reports
- QA session summaries
- Combined HTML reports
- Statistics and visualizations

**Usage:**

```bash
./scripts/qa-report.sh
```

**Outputs:**

- `qa-reports/shellspec-report-<timestamp>.md`
- `qa-reports/qa-summary-<timestamp>.md`
- `qa-reports/test-report-<timestamp>.html` (open in browser)

## Workflow

### 1. Before Release

Run all QA automation:

```bash
# Check command coverage
./scripts/qa-coverage.sh

# Run automated tests
just test

# Run manual QA
./scripts/qa-runner.sh

# Generate final report
./scripts/qa-report.sh
```

### 2. During Development

Quick validation:

```bash
# Run specific test category
./scripts/qa-runner.sh
# Select option "3" for Goal Tracking tests

# Check if new commands are documented
./scripts/qa-coverage.sh
```

### 3. CI Pipeline

Automated checks:

```bash
# In CI (see .github/workflows/qa.yml):
just test                    # Run ShellSpec tests
./scripts/qa-coverage.sh     # Validate coverage
./scripts/qa-report.sh       # Generate reports
```

## Configuration

### Environment Variables

**QA Runner:**

- `QA_LOG_DIR` - QA session log directory (default: `~/.harm-cli/qa-logs`)

**QA Report:**

- `REPORT_DIR` - Report output directory (default: `./qa-reports`)

### Log Files

**QA Session Logs:**

```
~/.harm-cli/qa-logs/qa-session-<timestamp>.log
```

Format:

```
[2025-10-23 10:30:15] [PASS] Core Commands :: version text format ::
[2025-10-23 10:30:45] [FAIL] Goal Tracking :: goal set with time :: Invalid duration
```

## Tips

### Running Specific Tests

Edit `qa-runner.sh` and add custom test categories:

```bash
run_custom_tests() {
  print_header "My Custom Tests"
  # Add your tests here
}
```

### Coverage Thresholds

Modify `qa-coverage.sh` to enforce coverage minimums:

```bash
if [[ $missing_in_qa -gt 5 ]]; then
  error "Too many undocumented commands: $missing_in_qa"
  exit 1
fi
```

### Custom Reports

Extend `qa-report.sh` to add custom report sections:

```bash
generate_custom_section() {
  echo "## My Custom Section"
  # Add your content
}
```

## Related Files

- **QA Checklist:** `docs/QA_CHECKLIST.md`
- **Command Reference:** `COMMANDS.md`
- **E2E Tests:** `spec/e2e_spec.sh`
- **CI Workflow:** `.github/workflows/qa.yml`

## Troubleshooting

### "shellspec: command not found"

Install ShellSpec:

```bash
brew install shellspec
```

### Permission denied

Make scripts executable:

```bash
chmod +x scripts/qa-*.sh
```

### No QA logs found

Run the interactive QA runner first:

```bash
./scripts/qa-runner.sh
```

## Contributing

When adding new commands:

1. ✅ Document in `COMMANDS.md`
2. ✅ Add test case to `docs/QA_CHECKLIST.md`
3. ✅ Write ShellSpec tests
4. ✅ Run `./scripts/qa-coverage.sh` to verify

---

**Questions?** See `CONTRIBUTING.md` for more details.
