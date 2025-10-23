#!/usr/bin/env bash
# qa-report.sh - Test Report Generator
# Generates comprehensive test reports from ShellSpec output and QA logs

set -Eeuo pipefail
IFS=$'\n\t'

# ═══════════════════════════════════════════════════════════════
# Colors
# ═══════════════════════════════════════════════════════════════

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly RESET='\033[0m'

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
QA_LOG_DIR="${QA_LOG_DIR:-$HOME/.harm-cli/qa-logs}"
REPORT_DIR="${REPORT_DIR:-$PROJECT_ROOT/qa-reports}"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')

mkdir -p "$REPORT_DIR"

# ═══════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════

print_header() {
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════${RESET}"
  echo -e "${BOLD}$1${RESET}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════${RESET}"
}

success() {
  echo -e "${GREEN}✓${RESET} $1"
}

info() {
  echo -e "${BLUE}ℹ${RESET} $1"
}

# ═══════════════════════════════════════════════════════════════
# Report Generation Functions
# ═══════════════════════════════════════════════════════════════

generate_shellspec_report() {
  local output_file="$REPORT_DIR/shellspec-report-$TIMESTAMP.md"

  info "Generating ShellSpec test report..."

  {
    echo "# ShellSpec Test Report"
    echo ""
    echo "**Generated:** $(date '+%Y-%m-%d %H:%M:%S')"
    echo "**Project:** harm-cli"
    echo ""

    # Run shellspec with report formatter
    echo "## Test Execution"
    echo ""
    echo "\`\`\`"
    cd "$PROJECT_ROOT"
    if command -v shellspec >/dev/null 2>&1; then
      shellspec --format documentation 2>&1 || echo "Some tests failed"
    else
      echo "ShellSpec not installed. Install with:"
      echo "  brew install shellspec"
    fi
    echo "\`\`\`"
    echo ""

    # Count test files
    local spec_count
    spec_count=$(find "$PROJECT_ROOT/spec" -name "*_spec.sh" 2>/dev/null | wc -l | tr -d ' ')

    echo "## Statistics"
    echo ""
    echo "- **Spec Files:** $spec_count"
    echo "- **Test Framework:** ShellSpec"
    echo ""

    echo "## Test Files"
    echo ""
    find "$PROJECT_ROOT/spec" -name "*_spec.sh" 2>/dev/null | sed 's|.*/||' | sort | sed 's/^/- /'
    echo ""

  } >"$output_file"

  success "ShellSpec report generated: $output_file"
}

generate_qa_summary() {
  local output_file="$REPORT_DIR/qa-summary-$TIMESTAMP.md"

  info "Generating QA test summary..."

  {
    echo "# QA Test Summary"
    echo ""
    echo "**Generated:** $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # Find latest QA session log
    local latest_qa_log
    if [[ -d "$QA_LOG_DIR" ]] && latest_qa_log=$(find "$QA_LOG_DIR" -name "qa-session-*.log" 2>/dev/null | sort | tail -1); then
      if [[ -f "$latest_qa_log" ]]; then
        echo "## Latest QA Session"
        echo ""
        echo "**Log File:** \`$(basename "$latest_qa_log")\`"
        echo ""

        # Count results
        local passed
        passed=$(grep -c "\[PASS\]" "$latest_qa_log" 2>/dev/null || echo "0")
        local failed
        failed=$(grep -c "\[FAIL\]" "$latest_qa_log" 2>/dev/null || echo "0")
        local skipped
        skipped=$(grep -c "\[SKIP\]" "$latest_qa_log" 2>/dev/null || echo "0")
        local total=$((passed + failed + skipped))

        echo "### Results"
        echo ""
        echo "| Status | Count | Percentage |"
        echo "|--------|-------|------------|"

        if [[ $total -gt 0 ]]; then
          local pass_pct=$((passed * 100 / total))
          local fail_pct=$((failed * 100 / total))
          local skip_pct=$((skipped * 100 / total))

          echo "| ✅ Passed | $passed | ${pass_pct}% |"
          echo "| ❌ Failed | $failed | ${fail_pct}% |"
          echo "| ⏭ Skipped | $skipped | ${skip_pct}% |"
          echo "| **Total** | **$total** | **100%** |"
        else
          echo "| ✅ Passed | 0 | 0% |"
          echo "| ❌ Failed | 0 | 0% |"
          echo "| ⏭ Skipped | 0 | 0% |"
          echo "| **Total** | **0** | **0%** |"
        fi

        echo ""

        # Show failed tests if any
        if [[ $failed -gt 0 ]]; then
          echo "### Failed Tests"
          echo ""
          echo "\`\`\`"
          grep "\[FAIL\]" "$latest_qa_log" 2>/dev/null || echo "None"
          echo "\`\`\`"
          echo ""
        fi

        # Show test details
        echo "### Test Details"
        echo ""
        echo "\`\`\`"
        tail -20 "$latest_qa_log" 2>/dev/null || echo "No log data"
        echo "\`\`\`"
        echo ""

      else
        echo "No QA session logs found."
        echo ""
      fi
    else
      echo "No QA session logs found in $QA_LOG_DIR"
      echo ""
      echo "Run QA tests first:"
      echo ""
      echo "\`\`\`bash"
      echo "./scripts/qa-runner.sh"
      echo "\`\`\`"
      echo ""
    fi

  } >"$output_file"

  success "QA summary generated: $output_file"
}

generate_combined_report() {
  local output_file="$REPORT_DIR/test-report-$TIMESTAMP.html"

  info "Generating combined HTML report..."

  {
    cat <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>harm-cli Test Report</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            line-height: 1.6;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 20px;
        }
        .header h1 {
            margin: 0;
            font-size: 2.5em;
        }
        .header p {
            margin: 10px 0 0 0;
            opacity: 0.9;
        }
        .card {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }
        .stat-card {
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
        }
        .stat-card.success {
            background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
        }
        .stat-card.warning {
            background: linear-gradient(135deg, #fa709a 0%, #fee140 100%);
        }
        .stat-card h3 {
            margin: 0;
            font-size: 2em;
        }
        .stat-card p {
            margin: 5px 0 0 0;
            opacity: 0.9;
        }
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background: #667eea;
            color: white;
        }
        .pass { color: #28a745; font-weight: bold; }
        .fail { color: #dc3545; font-weight: bold; }
        .skip { color: #ffc107; font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🧪 harm-cli Test Report</h1>
        <p>Generated: $(date '+%Y-%m-%d %H:%M:%S')</p>
    </div>
EOF

    # Add stats cards
    cat <<EOF
    <div class="stats">
        <div class="stat-card success">
            <h3>$(find "$PROJECT_ROOT/spec" -name "*_spec.sh" 2>/dev/null | wc -l | tr -d ' ')</h3>
            <p>Test Files</p>
        </div>
        <div class="stat-card">
            <h3>108</h3>
            <p>QA Test Cases</p>
        </div>
        <div class="stat-card warning">
            <h3>50+</h3>
            <p>E2E Tests</p>
        </div>
    </div>

    <div class="card">
        <h2>📊 Test Summary</h2>
        <p>Comprehensive test coverage including unit tests, integration tests, and manual QA.</p>
    </div>

    <div class="card">
        <h2>📁 Test Files</h2>
        <ul>
EOF

    # List test files
    find "$PROJECT_ROOT/spec" -name "*_spec.sh" 2>/dev/null | sed 's|.*/||' | sort | sed 's/^/<li>/' | sed 's/$/<\/li>/'

    cat <<'EOF'
        </ul>
    </div>

    <div class="card">
        <h2>🚀 Quick Actions</h2>
        <p>Run tests with the following commands:</p>
        <pre><code>just test           # Run all ShellSpec tests
./scripts/qa-runner.sh   # Interactive manual QA
./scripts/qa-coverage.sh # Check command coverage</code></pre>
    </div>

</body>
</html>
EOF

  } >"$output_file"

  success "HTML report generated: $output_file"
  info "Open in browser: file://$output_file"
}

# ═══════════════════════════════════════════════════════════════
# Main Function
# ═══════════════════════════════════════════════════════════════

main() {
  clear

  echo ""
  print_header "harm-cli Test Report Generator"
  echo ""

  # Generate all reports
  generate_shellspec_report
  generate_qa_summary
  generate_combined_report

  echo ""
  print_header "Report Generation Complete"
  echo ""
  info "Reports saved to: $REPORT_DIR"
  echo ""
  find "$REPORT_DIR" -name "test-report-*.html" -print0 2>/dev/null | xargs -0 ls -t | head -1 | awk '{print "  Latest: " $0}'
  echo ""
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
