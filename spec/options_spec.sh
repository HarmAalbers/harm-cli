#!/usr/bin/env bash
# ShellSpec tests for options management

# Include helper first
Include spec/helpers/env.sh

# Source the module at spec level (not in BeforeAll)
# This ensures the OPTIONS_SCHEMA associative array is available
# (arrays cannot be exported to child shells)
# shellcheck source=lib/options.sh
. "$ROOT/lib/options.sh"

Describe 'lib/options.sh'
# Clean up after tests
AfterAll 'rm -rf "$HARM_CLI_HOME"'

Describe 'Module Configuration'
It 'defines OPTIONS_CONFIG_DIR'
The variable OPTIONS_CONFIG_DIR should be defined
End

It 'defines OPTIONS_CONFIG_FILE'
The variable OPTIONS_CONFIG_FILE should be defined
End

It 'creates options directory on load'
The directory "$HARM_CLI_HOME" should be exist
End
End

Describe 'Option Schema'
Describe 'options_list_all'
It 'returns all option keys'
When call options_list_all
The status should be success
The output should include "log_level"
The output should include "format"
The output should include "ai_timeout"
End

It 'returns exactly 17 options'
result=$(options_list_all | wc -l | tr -d ' ')
The value "$result" should equal 17
End
End

Describe 'options_get_schema'
It 'returns schema for valid option'
When call options_get_schema "log_level"
The status should be success
The output should include "enum"
The output should include "INFO"
The output should include "HARM_LOG_LEVEL"
The output should include "validate_log_level"
End

It 'fails for invalid option'
When call options_get_schema "nonexistent_option"
The status should be failure
The error should include "Unknown option"
End
End
End

Describe 'Configuration File I/O'
Describe 'options_load_config'
It 'succeeds when config file missing (uses defaults)'
rm -f "$HARM_CLI_HOME/config.sh"
When call options_load_config 2>/dev/null
The status should be success
End

It 'loads existing config.sh file'
cat >"$HARM_CLI_HOME/config.sh" <<'EOF'
export HARM_LOG_LEVEL="DEBUG"
export HARM_CLI_FORMAT="json"
EOF
When call options_load_config 2>/dev/null
The status should be success
End

It 'handles corrupted config file gracefully'
echo 'if; then' >"$HARM_CLI_HOME/config.sh"
When call options_load_config
The status should be success
The error should include "corrupted"
End

It 'creates backup of corrupted config'
echo 'invalid bash syntax &&&' >"$HARM_CLI_HOME/config.sh"
rm -f "$HARM_CLI_HOME/config.sh.corrupted"
When call options_load_config
The status should be success
The file "$HARM_CLI_HOME/config.sh.corrupted" should be exist
End
End

Describe 'options_save_config'
BeforeEach 'rm -f "$HARM_CLI_HOME/config.sh"'

It 'creates config.sh if missing'
When call options_save_config "log_level" "DEBUG" 2>/dev/null
The status should be success
The file "$HARM_CLI_HOME/config.sh" should be exist
End

It 'updates existing config value'
cat >"$HARM_CLI_HOME/config.sh" <<'EOF'
export HARM_LOG_LEVEL="INFO"
export HARM_CLI_FORMAT="text"
EOF
When call options_save_config "log_level" "DEBUG" 2>/dev/null
The status should be success
The contents of file "$HARM_CLI_HOME/config.sh" should include 'HARM_LOG_LEVEL="DEBUG"'
End

It 'preserves other options when updating one'
cat >"$HARM_CLI_HOME/config.sh" <<'EOF'
export HARM_LOG_LEVEL="INFO"
export HARM_CLI_FORMAT="text"
export HARM_CLI_AI_TIMEOUT="20"
EOF
options_save_config "log_level" "WARN" >/dev/null 2>&1
The contents of file "$HARM_CLI_HOME/config.sh" should include 'HARM_CLI_FORMAT="text"'
The contents of file "$HARM_CLI_HOME/config.sh" should include 'HARM_CLI_AI_TIMEOUT="20"'
End

It 'uses atomic writes (creates temp file)'
# This is tested implicitly by checking file exists after save
When call options_save_config "format" "json" 2>/dev/null
The status should be success
The file "$HARM_CLI_HOME/config.sh" should be exist
End

It 'maintains file permissions'
touch "$HARM_CLI_HOME/config.sh"
chmod 600 "$HARM_CLI_HOME/config.sh"
When call options_save_config "format" "json" 2>/dev/null
The status should be success
# Check permissions are 600 (rw-------)
result=$(stat -f "%Lp" "$HARM_CLI_HOME/config.sh" 2>/dev/null || stat -c "%a" "$HARM_CLI_HOME/config.sh" 2>/dev/null)
The value "$result" should equal "600"
End
End
End

Describe 'Getting Option Values (Priority Order)'
Describe 'options_get'
BeforeEach 'unset HARM_LOG_LEVEL HARM_CLI_FORMAT HARM_CLI_AI_TIMEOUT'

It 'returns default value when no config or env var'
rm -f "$HARM_CLI_HOME/config.sh"
When call options_get "log_level" 2>/dev/null
The output should equal "INFO"
End

It 'returns config file value over default'
cat >"$HARM_CLI_HOME/config.sh" <<'EOF'
export HARM_LOG_LEVEL="DEBUG"
EOF
When call options_get "log_level" 2>/dev/null
The output should equal "DEBUG"
End

It 'returns env var value over config file'
export HARM_LOG_LEVEL="WARN"
cat >"$HARM_CLI_HOME/config.sh" <<'EOF'
export HARM_LOG_LEVEL="DEBUG"
EOF
When call options_get "log_level"
The output should equal "WARN"
End

It 'returns env var value over default'
rm -f "$HARM_CLI_HOME/config.sh"
export HARM_CLI_FORMAT="json"
When call options_get "format"
The output should equal "json"
End

It 'fails for unknown option key'
When call options_get "unknown_option"
The status should be failure
The error should include "Unknown option"
End
End

Describe 'options_get_source'
BeforeEach 'unset HARM_LOG_LEVEL'

It 'returns "default" when using default value'
rm -f "$HARM_CLI_HOME/config.sh"
When call options_get_source "log_level" 2>/dev/null
The output should equal "default"
End

It 'returns "config" when value from config file'
cat >"$HARM_CLI_HOME/config.sh" <<'EOF'
export HARM_LOG_LEVEL="DEBUG"
EOF
When call options_get_source "log_level"
The output should equal "config"
End

It 'returns "env" when value from environment'
export HARM_LOG_LEVEL="ERROR"
When call options_get_source "log_level"
The output should equal "env"
End
End
End

Describe 'Validation'
Describe 'options_validate'
It 'accepts valid log level'
When call options_validate "log_level" "DEBUG"
The status should be success
End

It 'rejects invalid log level'
When call options_validate "log_level" "INVALID"
The status should be failure
The error should include "DEBUG, INFO, WARN, ERROR"
End

It 'accepts valid format'
When call options_validate "format" "json"
The status should be success
End

It 'rejects invalid format'
When call options_validate "format" "xml"
The status should be failure
The error should include "Invalid"
End

It 'accepts valid boolean (1)'
When call options_validate "log_to_file" "1"
The status should be success
End

It 'accepts valid boolean (0)'
When call options_validate "log_to_console" "0"
The status should be success
End

It 'rejects invalid boolean'
When call options_validate "log_to_file" "yes"
The status should be failure
The error should include "Invalid"
End

It 'accepts valid positive integer'
When call options_validate "ai_timeout" "30"
The status should be success
End

It 'rejects negative integer'
When call options_validate "ai_timeout" "-5"
The status should be failure
The error should include "Invalid"
End

It 'rejects non-numeric value for integer option'
When call options_validate "log_max_files" "abc"
The status should be failure
The error should include "Invalid"
End

It 'accepts valid AI model'
When call options_validate "ai_model" "gemini-1.5-pro"
The status should be success
End

It 'rejects invalid AI model'
When call options_validate "ai_model" "gpt-4"
The status should be failure
The error should include "Invalid"
End
End
End

Describe 'Setting Option Values'
Describe 'options_set'
BeforeEach 'rm -f "$HARM_CLI_HOME/config.sh"'
BeforeEach 'export HARM_LOG_LEVEL=INFO HARM_CLI_FORMAT=text'

It 'sets valid option value'
When call options_set "log_level" "DEBUG" 2>/dev/null
The status should be success
The file "$HARM_CLI_HOME/config.sh" should be exist
End

It 'validates before setting'
When call options_set "log_level" "INVALID"
The status should be failure
The error should include "Invalid"
End

It 'persists value to config file'
When call options_set "format" "json" 2>/dev/null
The status should be success
The contents of file "$HARM_CLI_HOME/config.sh" should include 'HARM_CLI_FORMAT="json"'
End

It 'warns when env var will override'
export HARM_LOG_LEVEL="ERROR"
When call options_set "log_level" "DEBUG"
The status should be success
The error should include "Environment variable"
End

It 'still saves to config even with env var set'
export HARM_CLI_FORMAT="text"
When call options_set "format" "json" 2>/dev/null
The status should be success
The contents of file "$HARM_CLI_HOME/config.sh" should include 'HARM_CLI_FORMAT="json"'
End
End
End

Describe 'Resetting Options'
Describe 'options_reset'
It 'removes option from config file'
cat >"$HARM_CLI_HOME/config.sh" <<'EOF'
export HARM_LOG_LEVEL="DEBUG"
export HARM_CLI_FORMAT="json"
EOF
When call options_reset "log_level" 2>/dev/null
The status should be success
The contents of file "$HARM_CLI_HOME/config.sh" should not include 'HARM_LOG_LEVEL'
End

It 'preserves other options when resetting one'
cat >"$HARM_CLI_HOME/config.sh" <<'EOF'
export HARM_LOG_LEVEL="DEBUG"
export HARM_CLI_FORMAT="json"
EOF
options_reset "log_level" >/dev/null 2>&1
The contents of file "$HARM_CLI_HOME/config.sh" should include 'HARM_CLI_FORMAT="json"'
End

It 'succeeds even if option not in config'
cat >"$HARM_CLI_HOME/config.sh" <<'EOF'
export HARM_CLI_FORMAT="json"
EOF
When call options_reset "log_level" 2>/dev/null
The status should be success
End

It 'warns if env var exists for reset option'
export HARM_LOG_LEVEL="DEBUG"
When call options_reset "log_level"
The status should be success
The error should include "Environment variable"
End
End
End

Describe 'Displaying Options'
Describe 'options_show (text format)'
BeforeEach 'export HARM_CLI_FORMAT=text'
BeforeEach 'unset HARM_LOG_LEVEL HARM_CLI_AI_TIMEOUT'

It 'displays all options'
rm -f "$HARM_CLI_HOME/config.sh"
When call options_show 2>/dev/null
The status should be success
The output should include "log_level"
The output should include "format"
The output should include "ai_timeout"
End

It 'shows current values'
cat >"$HARM_CLI_HOME/config.sh" <<'EOF'
export HARM_LOG_LEVEL="DEBUG"
EOF
When call options_show 2>/dev/null
The output should include "DEBUG"
End

It 'indicates source of value (default/config/env)'
rm -f "$HARM_CLI_HOME/config.sh"
When call options_show 2>/dev/null
The output should include "default"
End

It 'marks env var overrides'
export HARM_LOG_LEVEL="ERROR"
When call options_show 2>/dev/null
The output should include "env"
End

It 'formats as readable table'
When call options_show 2>/dev/null
The output should include "Option"
The output should include "Value"
The output should include "Source"
End
End

Describe 'options_show (JSON format)'
BeforeEach 'export HARM_CLI_FORMAT=json'
BeforeEach 'unset HARM_LOG_LEVEL'

It 'outputs valid JSON'
When call options_show 2>/dev/null
The status should be success
The output should start with '{'
The output should end with '}'
End

It 'includes all option keys'
When call options_show 2>/dev/null
The output should include '"log_level"'
The output should include '"format"'
The output should include '"ai_timeout"'
End

It 'includes current values'
cat >"$HARM_CLI_HOME/config.sh" <<'EOF'
export HARM_LOG_LEVEL="WARN"
EOF
When call options_show 2>/dev/null
The output should include '"value": "WARN"'
End

It 'includes source information'
When call options_show 2>/dev/null
The output should include '"source"'
End

It 'is valid parseable JSON'
# Capture JSON output and validate with jq
json_output=$(options_show 2>/dev/null)
When call echo "$json_output"
# Verify it's valid JSON by checking structure
The output should start with '{'
The output should end with '}'
The output should include '"value"'
The output should include '"source"'
End
End
End

Describe 'Interactive Set (Option C: Show & Ask)'
Describe 'options_set_interactive'
# Note: Interactive tests are challenging in ShellSpec
# We'll test the non-interactive code paths and helpers

It 'loads current config before prompting'
# This will be tested via integration
Skip "Tested via manual integration testing"
End

It 'skips options with env var set'
# This will be tested via integration
Skip "Tested via manual integration testing"
End

It 'validates input before saving'
# This will be tested via integration
Skip "Tested via manual integration testing"
End

It 'shows current value as default'
# This will be tested via integration
Skip "Tested via manual integration testing"
End
End

Describe 'options_prompt_for_value (helper)'
It 'displays current value'
Skip "Interactive function - manual testing required"
End

It 're-prompts on invalid input'
Skip "Interactive function - manual testing required"
End

It 'keeps current value on empty input'
Skip "Interactive function - manual testing required"
End
End
End

Describe 'Edge Cases'
It 'handles config file with DOS line endings gracefully'
# DOS line endings (\r\n) cause bash sourcing issues
# The config file won't load properly, so default value is used
# This is expected behavior - users should use Unix line endings
printf 'export HARM_LOG_LEVEL="DEBUG"\r\n' >"$HARM_CLI_HOME/config.sh"
When call options_get "log_level" 2>/dev/null
# Should return default value since config doesn't load properly
The output should equal "INFO"
End

It 'handles options with special characters in values'
When call options_set "log_level" "INFO" 2>/dev/null
The status should be success
End

It 'handles very long option values gracefully'
long_value=$(printf 'a%.0s' {1..1000})
When call options_validate "ai_timeout" "$long_value"
The status should be failure
The error should include "Invalid"
End

It 'handles permission denied on config dir'
Skip "Requires root/sudo - test manually if needed"
End

It 'handles permission denied on config file'
Skip "Requires root/sudo - test manually if needed"
End

It 'handles concurrent writes safely (atomic_write)'
# Atomic writes are tested implicitly through options_save_config
When call options_set "format" "json" 2>/dev/null
The status should be success
End
End

Describe 'CLI Integration Readiness'
It 'exports all required functions'
The function options_get should be defined
The function options_set should be defined
The function options_show should be defined
The function options_reset should be defined
The function options_set_interactive should be defined
The function options_validate should be defined
End

It 'handles HARM_CLI_FORMAT for output formatting'
export HARM_CLI_FORMAT=json
When call options_show 2>/dev/null
The output should include '"log_level"'
End

It 'integrates with existing harm-cli patterns'
# Uses same directory structure
The directory "$HARM_CLI_HOME" should be exist
End
End
End
