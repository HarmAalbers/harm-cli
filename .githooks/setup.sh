#!/usr/bin/env bash
# .githooks/setup.sh - Configure git to use custom hooks
#
# Usage: ./.githooks/setup.sh

set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GITHOOKS_DIR="$PROJECT_ROOT/.githooks"

echo "🔧 Setting up git hooks..."

# Configure git to use .githooks directory
git config core.hooksPath "$GITHOOKS_DIR"

echo "✅ Git hooks configured!"
echo ""
echo "Active hooks:"
find "$GITHOOKS_DIR" -type f -perm +111 ! -name "setup.sh" -exec basename {} \;
echo ""
echo "💡 To bypass hooks temporarily: git commit --no-verify"

