#!/usr/bin/env bash
# shellcheck shell=bash
# lib/options.sh
# Interactive options management for harm-cli
#
# Provides commands to view, set, and reset configuration options
# Options are stored in ~/.harm-cli/config.sh with priority:
#   1. Environment variables (highest)
#   2. Config file values
#   3. Default values (lowest)
#
# Requires: bash 4.0+ (for associative arrays)

set -Eeuo pipefail
IFS=$'\n\t'

# Prevent multiple loading ONLY if schema is already declared
# (Associative arrays don't export to subshells, so we may need to redeclare)
if [[ -n "${_HARM_OPTIONS_LOADED:-}" ]] && declare -p OPTIONS_SCHEMA &>/dev/null && [[ ${#OPTIONS_SCHEMA[@]} -gt 0 ]]; then
  return 0
fi

# Require bash 4.0+ for associative arrays
if [[ -z "${BASH_VERSINFO:-}" ]] || ((BASH_VERSINFO[0] < 4)); then
  echo "Error: lib/options.sh requires bash 4.0 or higher" >&2
  echo "Current version: ${BASH_VERSION:-unknown}" >&2
  echo "Please install bash 4+ (e.g., via Homebrew: brew install bash)" >&2
  return 1
fi

# Get script directory for sourcing dependencies
OPTIONS_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd -P)"
readonly OPTIONS_SCRIPT_DIR

# Source dependencies
# shellcheck source=lib/common.sh
source "$OPTIONS_SCRIPT_DIR/common.sh"
# shellcheck source=lib/error.sh
source "$OPTIONS_SCRIPT_DIR/error.sh"
# shellcheck source=lib/logging.sh
source "$OPTIONS_SCRIPT_DIR/logging.sh"
# shellcheck source=lib/config_validation.sh
source "$OPTIONS_SCRIPT_DIR/config_validation.sh"

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════

readonly OPTIONS_CONFIG_DIR="${HARM_CLI_HOME:-$HOME/.harm-cli}"
readonly OPTIONS_CONFIG_FILE="$OPTIONS_CONFIG_DIR/config.sh"

# Ensure config directory exists
ensure_dir "$OPTIONS_CONFIG_DIR"

# ═══════════════════════════════════════════════════════════════
# Option Schema Definition
# ═══════════════════════════════════════════════════════════════
#
# Schema format: "type:default:env_var:description:validator"
#
# Types: bool, int, enum, string
# Validators: function names from config_validation.sh

declare -gA OPTIONS_SCHEMA=(
  # Paths
  ["cli_home"]="string:$HOME/.harm-cli:HARM_CLI_HOME:Main data directory:validate_path"
  ["log_dir"]="string:$HOME/.harm-cli/logs:HARM_LOG_DIR:Log directory:validate_path"

  # Logging
  ["log_level"]="enum:WARN:HARM_LOG_LEVEL:Log verbosity (DEBUG/INFO/WARN/ERROR):validate_log_level"
  ["log_to_file"]="bool:1:HARM_LOG_TO_FILE:Write logs to file (0=disabled, 1=enabled):validate_bool"
  ["log_to_console"]="bool:1:HARM_LOG_TO_CONSOLE:Write logs to console (0=disabled, 1=enabled):validate_bool"
  ["log_unbuffered"]="bool:1:HARM_LOG_UNBUFFERED:Unbuffered logging for real-time output (0=disabled, 1=enabled):validate_bool"
  ["log_max_size"]="int:10485760:HARM_LOG_MAX_SIZE:Maximum log file size in bytes:validate_number"
  ["log_max_files"]="int:5:HARM_LOG_MAX_FILES:Number of rotated log files to keep:validate_number"
  ["debug_mode"]="bool:0:HARM_CLI_DEBUG:Enable debug mode by default (0=disabled, 1=enabled):validate_bool"
  ["minimal_mode"]="bool:0:HARM_CLI_MINIMAL:Enable minimal mode by default (0=disabled, 1=enabled):validate_bool"

  # AI
  ["ai_cache_ttl"]="int:3600:HARM_CLI_AI_CACHE_TTL:AI cache duration in seconds:validate_number"
  ["ai_timeout"]="int:20:HARM_CLI_AI_TIMEOUT:AI request timeout in seconds:validate_positive_int"
  ["ai_max_tokens"]="int:2048:HARM_CLI_AI_MAX_TOKENS:AI maximum tokens per request:validate_positive_int"
  ["ai_model"]="enum:gemini-2.0-flash-exp:GEMINI_MODEL:AI model to use:validate_ai_model"
  ["ai_auto_context"]="bool:1:HARM_AI_AUTO_CONTEXT:Auto-include work sessions and goals in AI context:validate_bool"

  # Work/Goals Integration
  ["work_auto_track_goals"]="bool:1:HARM_WORK_AUTO_TRACK_GOALS:Auto-increment goal progress after work sessions:validate_bool"
  ["work_goal_increment"]="int:10:HARM_WORK_GOAL_INCREMENT:Goal progress increment percentage per session:validate_positive_int"

  # Shell Hooks
  ["hooks_enabled"]="bool:1:HARM_HOOKS_ENABLED:Enable shell hooks system (0=disabled, 1=enabled):validate_bool"
  ["hooks_debug"]="bool:0:HARM_HOOKS_DEBUG:Enable hook debugging (0=disabled, 1=enabled):validate_bool"

  # Output
  ["format"]="enum:text:HARM_CLI_FORMAT:Default output format (text/json):validate_format"

  # Work/Pomodoro Configuration
  ["work_duration"]="int:1500:HARM_WORK_DURATION:Work session length in seconds (default: 25 min):validate_positive_int"
  ["break_short"]="int:300:HARM_BREAK_SHORT:Short break length in seconds (default: 5 min):validate_positive_int"
  ["break_long"]="int:900:HARM_BREAK_LONG:Long break length in seconds (default: 15 min):validate_positive_int"
  ["pomodoros_until_long"]="int:4:HARM_POMODOROS_UNTIL_LONG:Pomodoros before long break:validate_positive_int"

  # Work Automation & Notifications
  ["work_auto_start_break"]="bool:1:HARM_WORK_AUTO_START_BREAK:Auto-start break after work ends (0=disabled, 1=enabled):validate_bool"
  ["work_notifications"]="bool:1:HARM_WORK_NOTIFICATIONS:Desktop notifications for transitions (0=disabled, 1=enabled):validate_bool"
  ["work_sound_notifications"]="bool:1:HARM_WORK_SOUND:Sound alerts for notifications (0=disabled, 1=enabled):validate_bool"
  ["work_reminder_interval"]="int:30:HARM_WORK_REMINDER:Reminder interval in minutes (0=disabled):validate_number"

  # Work Strict Mode (Discipline & Focus Enforcement)
  ["strict_block_project_switch"]="bool:0:HARM_STRICT_BLOCK_PROJECT_SWITCH:Block project switching during active work sessions (0=warn only, 1=block):validate_bool"
  ["strict_require_break"]="bool:0:HARM_STRICT_REQUIRE_BREAK:Require break completion before starting new work session (0=disabled, 1=enabled):validate_bool"
  ["strict_confirm_early_stop"]="bool:0:HARM_STRICT_CONFIRM_EARLY_STOP:Require confirmation when stopping session early (0=disabled, 1=enabled):validate_bool"
  ["strict_track_breaks"]="bool:0:HARM_STRICT_TRACK_BREAKS:Track and report break compliance (0=disabled, 1=enabled):validate_bool"

  # Break Popup & Skip Configuration
  ["break_popup_mode"]="bool:1:HARM_BREAK_POPUP:Open break timer in new window (0=inline, 1=popup):validate_bool"
  ["break_skip_mode"]="enum:always:HARM_BREAK_SKIP_MODE:Skip behavior (never/after50/always/type-based):validate_break_skip_mode"
  ["break_scheduled_enabled"]="bool:0:HARM_BREAK_SCHEDULED:Enable scheduled break reminders (0=disabled, 1=enabled):validate_bool"
  ["break_scheduled_interval"]="int:120:HARM_BREAK_SCHEDULED_INTERVAL:Scheduled break interval in minutes:validate_positive_int"

  # Cleanup Configuration
  ["cleanup_min_size"]="string:104857600:HARM_CLEANUP_MIN_SIZE:Minimum file size in bytes (or with suffix like 100M, 1G):validate_string"
  ["cleanup_max_results"]="int:50:HARM_CLEANUP_MAX_RESULTS:Maximum number of results to return:validate_positive_int"
  ["cleanup_search_path"]="string:$HOME:HARM_CLEANUP_SEARCH_PATH:Default search path for cleanup scan:validate_path"
  ["cleanup_exclude_patterns"]="string::HARM_CLEANUP_EXCLUDES:Comma-separated exclude patterns:validate_string"
)

# Dummy path validator (for now)
validate_path() {
  return 0
}

# ═══════════════════════════════════════════════════════════════
# Schema Helpers
# ═══════════════════════════════════════════════════════════════

# List all option keys
#
# Returns:
#   List of option keys (one per line)
options_list_all() {
  printf '%s\n' "${!OPTIONS_SCHEMA[@]}" | sort
}

# Get schema entry for an option
#
# Arguments:
#   $1 - Option key
#
# Returns:
#   Schema string "type:default:env_var:description:validator"
options_get_schema() {
  local key="${1:?options_get_schema requires option key}"

  if [[ -z "${OPTIONS_SCHEMA[$key]:-}" ]]; then
    error_msg "Unknown option: $key" 1
    return 1
  fi

  echo "${OPTIONS_SCHEMA[$key]}"
}

# Parse schema field
#
# Arguments:
#   $1 - Option key
#   $2 - Field index (0=type, 1=default, 2=env_var, 3=description, 4=validator)
#
# Returns:
#   Field value
_options_schema_field() {
  local key="${1:?_options_schema_field requires option key}"
  local field="${2:?_options_schema_field requires field index}"

  local schema
  schema=$(options_get_schema "$key") || return 1

  echo "$schema" | cut -d':' -f"$((field + 1))"
}

# ═══════════════════════════════════════════════════════════════
# Configuration File I/O
# ═══════════════════════════════════════════════════════════════

# Load configuration file
#
# Returns:
#   0 on success, 0 on missing file (uses defaults), 1 on error
options_load_config() {
  if [[ ! -f "$OPTIONS_CONFIG_FILE" ]]; then
    log_debug "options" "Config file not found, using defaults" ""
    return 0
  fi

  # Check if file is valid bash
  if ! bash -n "$OPTIONS_CONFIG_FILE" 2>/dev/null; then
    warn_msg "Config file is corrupted: $OPTIONS_CONFIG_FILE"

    # Backup corrupted file
    local backup="$OPTIONS_CONFIG_FILE.corrupted"
    mv "$OPTIONS_CONFIG_FILE" "$backup"
    warn_msg "Backed up to: $backup"
    warn_msg "Using default values"

    return 0
  fi

  # Source the config file to load values
  # shellcheck disable=SC1090
  # Suppress only "readonly variable" warnings (benign - variable already set correctly)
  # but log other errors
  local source_errors
  if source_errors=$(source "$OPTIONS_CONFIG_FILE" 2>&1 | grep -v "readonly variable"); then
    log_debug "options" "Loaded config from $OPTIONS_CONFIG_FILE" ""
  else
    # Log non-readonly errors if any
    if [[ -n "$source_errors" ]]; then
      log_warn "options" "Config file has errors" "file=$OPTIONS_CONFIG_FILE, errors=$source_errors"
    fi
  fi
  return 0
}

# Save option value to configuration file
#
# Arguments:
#   $1 - Option key
#   $2 - Option value
#
# Returns:
#   0 on success, 1 on error
options_save_config() {
  local key="${1:?options_save_config requires option key}"
  local value="${2:?options_save_config requires option value}"

  # Get environment variable name
  local env_var
  env_var=$(_options_schema_field "$key" 2) || return 1

  # Create config file if it doesn't exist
  if [[ ! -f "$OPTIONS_CONFIG_FILE" ]]; then
    cat >"$OPTIONS_CONFIG_FILE" <<'EOF'
#!/usr/bin/env bash
# harm-cli configuration file
# Generated automatically - edit with 'harm-cli set options' or manually
EOF
    log_info "options" "Created new config file: $OPTIONS_CONFIG_FILE" ""
  fi

  # Check if option already exists in file
  if grep -q "^export ${env_var}=" "$OPTIONS_CONFIG_FILE" 2>/dev/null; then
    # Update existing value using atomic write
    local temp_file="${OPTIONS_CONFIG_FILE}.tmp.$$"

    # Replace the line
    sed "s|^export ${env_var}=.*|export ${env_var}=\"${value}\"|" "$OPTIONS_CONFIG_FILE" >"$temp_file"

    # Atomic move
    mv "$temp_file" "$OPTIONS_CONFIG_FILE"
  else
    # Append new value
    echo "export ${env_var}=\"${value}\"" >>"$OPTIONS_CONFIG_FILE"
  fi

  log_debug "options" "Saved $key=$value to config" ""
  return 0
}

# ═══════════════════════════════════════════════════════════════
# Getting Option Values (Priority Order)
# ═══════════════════════════════════════════════════════════════

# Get option value with priority: env → config → default
#
# Arguments:
#   $1 - Option key
#
# Returns:
#   Option value
options_get() {
  local key="${1:?options_get requires option key}"

  # Check if OPTIONS_SCHEMA is available
  # In some contexts (like ShellSpec's When call), associative arrays may not be inherited
  local use_schema=0
  if [[ ${#OPTIONS_SCHEMA[@]} -gt 0 ]] && [[ -n "${OPTIONS_SCHEMA[$key]:-}" ]]; then
    use_schema=1
  fi

  if [[ $use_schema -eq 0 ]]; then
    # Fallback: Try to get from environment or use hardcoded defaults
    # This makes tests work without full schema initialization
    local env_var default_value

    # Map keys to environment variables and defaults for critical options
    case "$key" in
      work_duration)
        env_var="HARM_WORK_DURATION"
        default_value="1500"
        ;;
      break_short)
        env_var="HARM_BREAK_SHORT"
        default_value="300"
        ;;
      break_long)
        env_var="HARM_BREAK_LONG"
        default_value="900"
        ;;
      pomodoros_until_long)
        env_var="HARM_POMODOROS_UNTIL_LONG"
        default_value="4"
        ;;
      work_auto_start_break)
        env_var="HARM_WORK_AUTO_START_BREAK"
        default_value="1"
        ;;
      work_notifications)
        env_var="HARM_WORK_NOTIFICATIONS"
        default_value="1"
        ;;
      work_sound_notifications)
        env_var="HARM_WORK_SOUND"
        default_value="1"
        ;;
      work_reminder_interval)
        env_var="HARM_WORK_REMINDER"
        default_value="30"
        ;;
      strict_block_project_switch)
        env_var="HARM_STRICT_BLOCK_PROJECT_SWITCH"
        default_value="0"
        ;;
      strict_require_break)
        env_var="HARM_STRICT_REQUIRE_BREAK"
        default_value="0"
        ;;
      strict_confirm_early_stop)
        env_var="HARM_STRICT_CONFIRM_EARLY_STOP"
        default_value="0"
        ;;
      strict_track_breaks)
        env_var="HARM_STRICT_TRACK_BREAKS"
        default_value="0"
        ;;
      break_popup_mode)
        env_var="HARM_BREAK_POPUP"
        default_value="1"
        ;;
      break_skip_mode)
        env_var="HARM_BREAK_SKIP_MODE"
        default_value="always"
        ;;
      break_scheduled_enabled)
        env_var="HARM_BREAK_SCHEDULED"
        default_value="0"
        ;;
      break_scheduled_interval)
        env_var="HARM_BREAK_SCHEDULED_INTERVAL"
        default_value="120"
        ;;
      *)
        # For unknown keys, try schema if available
        if [[ -v OPTIONS_SCHEMA ]] && [[ -v OPTIONS_SCHEMA[$key] ]]; then
          env_var=$(_options_schema_field "$key" 2)
          default_value=$(_options_schema_field "$key" 1)
        else
          error_msg "Unknown option: $key (schema not loaded)" 1
          return 1
        fi
        ;;
    esac
  else
    # Schema is available - use it normally
    local env_var default_value
    env_var=$(_options_schema_field "$key" 2)
    default_value=$(_options_schema_field "$key" 1)
  fi

  # Priority 1: Environment variable
  if [[ -n "${!env_var:-}" ]]; then
    echo "${!env_var}"
    return 0
  fi

  # Priority 2: Config file (source it if not already loaded)
  if [[ -f "$OPTIONS_CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    # Suppress "readonly variable" warnings (benign - variable already set correctly)
    source "$OPTIONS_CONFIG_FILE" 2>/dev/null || true

    if [[ -n "${!env_var:-}" ]]; then
      echo "${!env_var}"
      return 0
    fi
  fi

  # Priority 3: Default value
  echo "$default_value"
}

# Get source of option value (env/config/default)
#
# Arguments:
#   $1 - Option key
#
# Returns:
#   "env", "config", or "default"
options_get_source() {
  local key="${1:?options_get_source requires option key}"

  # Get environment variable name
  local env_var
  env_var=$(_options_schema_field "$key" 2) || return 1

  # Check environment variable
  if [[ -n "${!env_var:-}" ]]; then
    echo "env"
    return 0
  fi

  # Check config file
  if [[ -f "$OPTIONS_CONFIG_FILE" ]]; then
    if grep -q "^export ${env_var}=" "$OPTIONS_CONFIG_FILE" 2>/dev/null; then
      echo "config"
      return 0
    fi
  fi

  # Default
  echo "default"
}

# ═══════════════════════════════════════════════════════════════
# Validation
# ═══════════════════════════════════════════════════════════════

# Validate option value
#
# Arguments:
#   $1 - Option key
#   $2 - Value to validate
#
# Returns:
#   0 if valid, 1 if invalid
options_validate() {
  local key="${1:?options_validate requires option key}"
  local value="${2:?options_validate requires value}"

  # Get validator function
  local validator
  validator=$(_options_schema_field "$key" 4) || return 1

  # Get option type and description
  local option_type description
  option_type=$(_options_schema_field "$key" 0) || return 1
  description=$(_options_schema_field "$key" 3) || return 1

  # Run validator
  if ! "$validator" "$value" 2>/dev/null; then
    case "$option_type" in
      bool)
        error_msg "Invalid value for $key: $value (must be 0 or 1)"
        ;;
      enum)
        if [[ "$key" == "log_level" ]]; then
          error_msg "Invalid value for $key: $value (must be DEBUG, INFO, WARN, ERROR)"
        elif [[ "$key" == "format" ]]; then
          error_msg "Invalid value for $key: $value (must be text or json)"
        elif [[ "$key" == "ai_model" ]]; then
          error_msg "Invalid value for $key: $value (must be gemini-2.0-flash-exp, gemini-1.5-pro, gemini-1.5-flash, or gemini-1.5-flash-8b)"
        else
          error_msg "Invalid value for $key: $value"
        fi
        ;;
      int)
        error_msg "Invalid value for $key: $value (must be a positive integer)"
        ;;
      *)
        error_msg "Invalid value for $key: $value"
        ;;
    esac
    return 1
  fi

  return 0
}

# ═══════════════════════════════════════════════════════════════
# Setting Option Values
# ═══════════════════════════════════════════════════════════════

# Set option value
#
# Arguments:
#   $1 - Option key
#   $2 - Option value
#
# Returns:
#   0 on success, 1 on error
options_set() {
  local key="${1:?options_set requires option key}"
  local value="${2:?options_set requires value}"

  # Validate
  if ! options_validate "$key" "$value"; then
    return 1
  fi

  # Check if environment variable is set
  local env_var
  env_var=$(_options_schema_field "$key" 2)

  if [[ -n "${!env_var:-}" ]]; then
    warn_msg "Note: Environment variable $env_var is set and will override this value"
    warn_msg "Current env value: ${!env_var}"
    warn_msg "Saving to config anyway..."
  fi

  # Save to config
  options_save_config "$key" "$value"

  info_msg "Set $key = $value"
  return 0
}

# ═══════════════════════════════════════════════════════════════
# Resetting Options
# ═══════════════════════════════════════════════════════════════

# Reset option to default (remove from config file)
#
# Arguments:
#   $1 - Option key
#
# Returns:
#   0 on success
options_reset() {
  local key="${1:?options_reset requires option key}"

  # Validate key
  if ! options_get_schema "$key" >/dev/null; then
    return 1
  fi

  # Get environment variable name
  local env_var
  env_var=$(_options_schema_field "$key" 2)

  # Warn if env var is set
  if [[ -n "${!env_var:-}" ]]; then
    warn_msg "Note: Environment variable $env_var is set"
    warn_msg "The default value will still be overridden by the env var"
  fi

  # Remove from config file
  if [[ -f "$OPTIONS_CONFIG_FILE" ]]; then
    local temp_file="${OPTIONS_CONFIG_FILE}.tmp.$$"
    grep -v "^export ${env_var}=" "$OPTIONS_CONFIG_FILE" >"$temp_file" || true
    mv "$temp_file" "$OPTIONS_CONFIG_FILE"
  fi

  local default_value
  default_value=$(_options_schema_field "$key" 1)

  info_msg "Reset $key to default: $default_value"
  return 0
}

# ═══════════════════════════════════════════════════════════════
# Displaying Options
# ═══════════════════════════════════════════════════════════════

# Show all options in text format
_options_show_text() {
  # Print header
  printf "%-20s %-30s %-10s %s\n" "Option" "Value" "Source" "Description"
  printf "%-20s %-30s %-10s %s\n" "------" "-----" "------" "-----------"

  # List all options
  while IFS= read -r key; do
    local value source description
    value=$(options_get "$key")
    source=$(options_get_source "$key")
    description=$(_options_schema_field "$key" 3)

    printf "%-20s %-30s %-10s %s\n" "$key" "$value" "$source" "$description"
  done < <(options_list_all)
}

# Show all options in JSON format
_options_show_json() {
  local first=1

  echo "{"

  while IFS= read -r key; do
    local value source description default_value env_var
    value=$(options_get "$key")
    source=$(options_get_source "$key")
    description=$(_options_schema_field "$key" 3)
    default_value=$(_options_schema_field "$key" 1)
    env_var=$(_options_schema_field "$key" 2)

    # Add comma for all but first
    if [[ $first -eq 0 ]]; then
      echo ","
    fi
    first=0

    printf '  "%s": {\n' "$key"
    printf '    "value": "%s",\n' "$value"
    printf '    "source": "%s",\n' "$source"
    printf '    "default": "%s",\n' "$default_value"
    printf '    "env_var": "%s",\n' "$env_var"
    printf '    "description": "%s"\n' "$description"
    printf '  }'
  done < <(options_list_all)

  echo ""
  echo "}"
}

# Show all options
#
# Returns:
#   0 on success
options_show() {
  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    _options_show_json
  else
    _options_show_text
  fi
}

# ═══════════════════════════════════════════════════════════════
# Interactive Set (Option C: Show current & ask to change)
# ═══════════════════════════════════════════════════════════════

# Prompt for a single option value
#
# Arguments:
#   $1 - Option key
#
# Returns:
#   New value via stdout, or empty if no change
_options_prompt_for_value() {
  local key="${1:?_options_prompt_for_value requires option key}"

  local current_value description source
  current_value=$(options_get "$key")
  description=$(_options_schema_field "$key" 3)
  source=$(options_get_source "$key")

  echo ""
  echo "Option: $key"
  echo "Description: $description"
  echo "Current value: $current_value (from $source)"

  # If env var is set, warn and skip
  if [[ "$source" == "env" ]]; then
    local env_var
    env_var=$(_options_schema_field "$key" 2)
    echo "⚠️  This option is controlled by environment variable: $env_var"
    echo "   Cannot change it here. Skipping..."
    return 0
  fi

  # Ask if they want to change it
  local change_it
  read -rp "Change this value? [y/N]: " change_it

  case "$change_it" in
    [Yy] | [Yy][Ee][Ss])
      # Prompt for new value
      while true; do
        local new_value
        read -rp "Enter new value [$current_value]: " new_value

        # Empty = keep current
        if [[ -z "$new_value" ]]; then
          return 0
        fi

        # Validate
        if options_validate "$key" "$new_value"; then
          echo "$new_value"
          return 0
        else
          echo "Invalid value. Try again."
        fi
      done
      ;;
    *)
      # No change
      return 0
      ;;
  esac
}

# Interactive option setting (Option C style)
#
# Returns:
#   0 on success
options_set_interactive() {
  echo "⚙️  Interactive Options Configuration"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""

  # Load interactive library if available
  local interactive_available=0
  if [[ -f "$OPTIONS_SCRIPT_DIR/interactive.sh" ]]; then
    source "$OPTIONS_SCRIPT_DIR/interactive.sh" 2>/dev/null || true
    if declare -F interactive_choose >/dev/null 2>&1; then
      interactive_available=1
    fi
  fi

  # Load current config
  options_load_config

  local changed_count=0

  if [[ $interactive_available -eq 1 ]]; then
    # Use menu-based interface if interactive.sh is available
    while true; do
      echo "Select an option to configure:"
      echo ""

      # Build options array with current values
      local -a menu_options=()
      while IFS= read -r key; do
        local value description
        value=$(options_get "$key")
        description=$(_options_schema_field "$key" 3)
        menu_options+=("$key = $value  ($description)")
      done < <(options_list_all)
      menu_options+=("Save and Exit")

      # Show interactive menu
      local selection
      if selection=$(interactive_choose "Options" "${menu_options[@]}"); then
        if [[ "$selection" == "Save and Exit" ]]; then
          break
        fi

        # Extract key from selection
        local key="${selection%% =*}"

        # Prompt for new value
        local new_value
        new_value=$(_options_prompt_for_value "$key")

        if [[ -n "$new_value" ]]; then
          if options_set "$key" "$new_value"; then
            changed_count=$((changed_count + 1))
          fi
        fi
      else
        # User cancelled
        break
      fi
    done
  else
    # Fallback to sequential prompts
    echo "Current configuration will be shown for each option."
    echo "Press Enter to keep current value, or enter a new value."
    echo "Options controlled by environment variables cannot be changed here."
    echo ""

    # Iterate through all options
    while IFS= read -r key; do
      local new_value
      new_value=$(_options_prompt_for_value "$key")

      if [[ -n "$new_value" ]]; then
        if options_set "$key" "$new_value"; then
          changed_count=$((changed_count + 1))
        fi
      fi
    done < <(options_list_all)
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  Configuration Complete"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  echo "Changed $changed_count option(s)"
  echo "Configuration saved to: $OPTIONS_CONFIG_FILE"
  echo ""

  return 0
}

# Export public functions
export -f options_list_all
export -f options_get_schema
export -f options_load_config
export -f options_save_config
export -f options_get
export -f options_get_source
export -f options_validate
export -f options_set
export -f options_reset
export -f options_show
export -f options_set_interactive

# Mark module as loaded
readonly _HARM_OPTIONS_LOADED=1
