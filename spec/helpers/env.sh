# ShellSpec test environment setup
# Loaded by: Include spec/helpers/env.sh

setup() {
  # Project paths
  export ROOT="$(cd -- "$(dirname -- "$SHELLSPEC_SPECFILE")/.." && pwd -P)"
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
}

cleanup() {
  # Clean up test artifacts (optional)
  # rm -rf "$TEST_TMP"
  :
}

# Call setup automatically
setup
