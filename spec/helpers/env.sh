# ShellSpec test environment setup
# Loaded by: Include spec/helpers/env.sh

setup() {
  # Project paths
  # Use SHELLSPEC_SPECFILE if available, otherwise use a fallback
  local spec_file="${SHELLSPEC_SPECFILE:-${BASH_SOURCE[0]}}"
  export ROOT="$(cd -- "$(dirname -- "$spec_file")/.." && pwd -P)"
  export CLI="$ROOT/bin/harm-cli"
  export LIB="$ROOT/lib"

  # Add bin to PATH for tests
  export PATH="$ROOT/bin:$PATH"

  # Test-specific environment
  export HARM_CLI_LOG_LEVEL="ERROR" # Quiet during tests
  export HARM_CLI_FORMAT="text"     # Default format

  # Create temp directory for test artifacts
  export TEST_TMP="$ROOT/spec/tmp"
  mkdir -p "$TEST_TMP"

  # Set test-specific HARM_CLI_HOME to avoid using user's real config
  export HARM_CLI_HOME="$TEST_TMP/harm-cli"
  mkdir -p "$HARM_CLI_HOME"
}

cleanup() {
  # Clean up test artifacts (optional)
  # rm -rf "$TEST_TMP"
  :
}

# Call setup automatically
setup
