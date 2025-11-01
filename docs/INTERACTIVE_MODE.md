# Interactive Mode Implementation Guide

## Overview

This guide documents the interactive mode pattern used in `harm-cli` and provides examples for implementing new interactive features.

## Architecture: Three-Tier Progressive Enhancement

Interactive mode follows a three-tier architecture that ensures graceful degradation:

### Tier 1: CLI Arguments (Always Works)

- **No dependencies**: Pure bash, works everywhere
- **Explicit**: All parameters provided via command-line
- **Script-friendly**: Ideal for automation and CI/CD
- **Example**: `harm-cli work start "Complete documentation"`

### Tier 2: Interactive Bash (Enhanced)

- **Built-in**: Uses bash `select` for menus
- **TTY-aware**: Only activates in interactive terminals
- **No external deps**: Works with standard bash 5+
- **Example**: Numbered menu with `select`

### Tier 3: Beautiful UX (Delightful)

- **Optional deps**: Requires `gum` and/or `fzf`
- **Polished**: Animated spinners, fuzzy search, colors
- **Progressive**: Falls back to Tier 2 if not available
- **Example**: Fuzzy-searchable list with live preview

## Implementation Pattern

### Complete Example

```bash
my_feature() {
  local selected_item="${1:-}"
  local progress="${2:-}"

  # ═══════════════════════════════════════════════════════════════
  # Interactive Mode Detection
  # ═══════════════════════════════════════════════════════════════

  if [[ -z "$selected_item" ]] && \
     [[ -t 0 ]] && \
     [[ -t 1 ]] && \
     [[ "${HARM_CLI_FORMAT:-text}" == "text" ]]; then

    # Source interactive module
    if [[ -f "$SCRIPT_DIR/interactive.sh" ]]; then
      # shellcheck source=lib/interactive.sh
      source "$SCRIPT_DIR/interactive.sh"
    fi

    # Check if interactive functions available
    if type interactive_choose >/dev/null 2>&1; then
      log_debug "my_feature" "Entering interactive mode"

      # Build options from data source
      local -a options=()
      local -a items

      # Example: Load from file/database
      if items=$(get_items); then
        while IFS= read -r item; do
          options+=("$item")
        done <<< "$items"
      fi

      # Add custom option
      options+=("Custom item...")

      # Interactive selection (Tier 3 → Tier 2 fallback)
      if selected_item=$(interactive_choose "Select an item:" "${options[@]}"); then
        log_debug "my_feature" "Selected" "$selected_item"

        # Handle custom input
        if [[ "$selected_item" == "Custom item..." ]]; then
          if selected_item=$(interactive_input "Enter custom item:"); then
            log_debug "my_feature" "Custom input" "$selected_item"
          else
            error_msg "Custom input cancelled"
            return $EXIT_USER_CANCELLED
          fi
        fi

        # Get second parameter if needed
        if [[ -z "$progress" ]]; then
          if progress=$(interactive_input "Enter progress (0-100):"); then
            log_debug "my_feature" "Progress" "$progress"
          else
            error_msg "Progress input cancelled"
            return $EXIT_USER_CANCELLED
          fi
        fi
      else
        error_msg "Selection cancelled"
        return $EXIT_USER_CANCELLED
      fi
    fi
  fi

  # ═══════════════════════════════════════════════════════════════
  # Validation (works for both interactive and CLI)
  # ═══════════════════════════════════════════════════════════════

  [[ -n "$selected_item" ]] || die "Item required" $EXIT_INVALID_ARGS
  [[ -n "$progress" ]] || die "Progress required" $EXIT_INVALID_ARGS

  # Validate progress range
  if [[ ! "$progress" =~ ^[0-9]+$ ]] || \
     [[ "$progress" -lt 0 ]] || \
     [[ "$progress" -gt 100 ]]; then
    die "Progress must be 0-100" $EXIT_INVALID_ARGS
  fi

  # ═══════════════════════════════════════════════════════════════
  # Business Logic (unchanged whether interactive or CLI)
  # ═══════════════════════════════════════════════════════════════

  log_info "my_feature" "Processing" "item=$selected_item, progress=$progress"

  # Do the actual work
  process_item "$selected_item" "$progress"

  # Output success
  echo "✓ Updated: $selected_item to $progress%"
}
```

## Interactive Functions Available

From `lib/interactive.sh`:

### `interactive_choose`

Single-selection menu with fuzzy search

```bash
if choice=$(interactive_choose "Select option:" "Option 1" "Option 2" "Option 3"); then
  echo "Selected: $choice"
fi
```

**Behavior:**

- **gum available**: Beautiful fuzzy-searchable menu
- **fzf available**: Terminal fuzzy finder
- **fallback**: bash `select` menu

### `interactive_choose_multi`

Multi-selection menu (space to toggle, enter to confirm)

```bash
if selected=$(interactive_choose_multi "Select features:" "Feature A" "Feature B" "Feature C"); then
  # Returns newline-separated list
  echo "Selected: $selected"
fi
```

### `interactive_input`

Text input with optional default

```bash
if name=$(interactive_input "Enter name:" "Default Name"); then
  echo "Name: $name"
fi
```

**Behavior:**

- **gum available**: Beautiful input with placeholder
- **fallback**: bash `read` with prompt

### `interactive_password`

Secure password input (hidden)

```bash
if password=$(interactive_password "Enter password:"); then
  echo "Password length: ${#password}"
fi
```

### `interactive_confirm`

Yes/No confirmation

```bash
if interactive_confirm "Delete all files?"; then
  echo "Confirmed"
else
  echo "Cancelled"
fi
```

**Behavior:**

- **gum available**: Beautiful yes/no selector
- **fallback**: bash read with y/n prompt

### `interactive_filter`

Live-filtered list with preview

```bash
if item=$(interactive_filter "Search:" "${items[@]}"); then
  echo "Selected: $item"
fi
```

## Future Interactive Feature Examples

### Example 1: Multi-Goal Selection

```bash
goal_batch_update() {
  # Interactive: Select multiple goals to update
  if [[ $# -eq 0 ]] && [[ -t 1 ]]; then
    # Load incomplete goals
    local -a goals=()
    while IFS= read -r goal; do
      goals+=("$goal")
    done < <(get_incomplete_goals)

    if selected=$(interactive_choose_multi "Select goals to update:" "${goals[@]}"); then
      # Process each selected goal
      while IFS= read -r goal_id; do
        echo "Processing goal: $goal_id"
        # Update logic here
      done <<< "$selected"
    fi
  else
    # CLI mode: accept goal IDs as arguments
    for goal_id in "$@"; do
      echo "Processing goal: $goal_id"
    done
  fi
}
```

### Example 2: Docker Service Selection

```bash
docker_restart() {
  local service="${1:-}"

  if [[ -z "$service" ]] && [[ -t 1 ]]; then
    # Load running services
    local -a services=()
    while IFS= read -r svc; do
      services+=("$svc")
    done < <(docker_list_services)

    services+=("All services")

    if service=$(interactive_choose "Select service to restart:" "${services[@]}"); then
      if [[ "$service" == "All services" ]]; then
        echo "Restarting all services..."
        docker compose restart
      else
        echo "Restarting: $service"
        docker compose restart "$service"
      fi
    fi
  else
    # CLI mode
    echo "Restarting: $service"
    docker compose restart "$service"
  fi
}
```

### Example 3: AI Setup Wizard

```bash
ai_setup() {
  if [[ -t 1 ]]; then
    echo "🤖 AI Assistant Setup Wizard"
    echo ""

    # Step 1: API key input
    if api_key=$(interactive_password "Enter Gemini API key:"); then
      # Validate key
      if validate_api_key "$api_key"; then
        save_api_key "$api_key"
        echo "✓ API key saved"
      else
        error_msg "Invalid API key"
        return 1
      fi
    else
      echo "Setup cancelled"
      return 130
    fi

    # Step 2: Model selection
    local -a models=("gemini-pro" "gemini-pro-vision" "gemini-ultra")
    if model=$(interactive_choose "Select model:" "${models[@]}"); then
      set_config "ai_model" "$model"
      echo "✓ Model set to: $model"
    fi

    # Step 3: Confirmation
    if interactive_confirm "Enable AI features?"; then
      set_config "ai_enabled" "true"
      echo "✓ AI features enabled"
    fi

    echo ""
    echo "Setup complete! Try: harm-cli ai 'hello'"
  fi
}
```

### Example 4: Project Health Dashboard

```bash
health_interactive() {
  if [[ -t 1 ]] && command -v gum >/dev/null 2>&1; then
    while true; do
      clear
      echo "📊 harm-cli Health Dashboard"
      echo ""

      # Show real-time metrics
      health_check

      echo ""
      local -a actions=("Refresh" "Run tests" "View logs" "Exit")
      if action=$(interactive_choose "Action:" "${actions[@]}"); then
        case "$action" in
          "Refresh") continue ;;
          "Run tests") just test ;;
          "View logs") log_tail 50 ;;
          "Exit") break ;;
        esac

        # Pause after action
        read -p "Press Enter to continue..."
      else
        break
      fi
    done
  else
    # Non-interactive fallback
    health_check
  fi
}
```

### Example 5: Safe File Deletion with Preview

```bash
safe_delete_interactive() {
  local pattern="${1:-}"

  if [[ -z "$pattern" ]] && [[ -t 1 ]]; then
    # Interactive file selection with preview
    local -a files=()
    while IFS= read -r file; do
      files+=("$file")
    done < <(find . -type f -name "*.tmp" -o -name "*.bak")

    if [[ ${#files[@]} -eq 0 ]]; then
      echo "No temporary files found"
      return 0
    fi

    # Multi-select with preview
    if selected=$(interactive_choose_multi "Select files to delete:" "${files[@]}"); then
      # Show what will be deleted
      echo "Files to delete:"
      echo "$selected" | sed 's/^/  - /'
      echo ""

      # Confirm deletion
      if interactive_confirm "Delete these files?"; then
        while IFS= read -r file; do
          rm "$file"
          echo "✓ Deleted: $file"
        done <<< "$selected"
      else
        echo "Deletion cancelled"
      fi
    fi
  else
    # CLI mode: use pattern
    find . -type f -name "$pattern" -delete
  fi
}
```

## Best Practices

### ✅ DO

- **Always check TTY**: `[[ -t 0 ]] && [[ -t 1 ]]`
- **Skip in JSON mode**: `[[ "${HARM_CLI_FORMAT:-text}" == "text" ]]`
- **Validate all inputs**: Whether from interactive or CLI
- **Log selections**: `log_debug "command" "Selection" "$choice"`
- **Handle cancellation**: Return proper exit codes
- **Preserve CLI mode**: CLI arguments must always work
- **Test both modes**: Unit tests for CLI, manual tests for interactive

### ❌ DON'T

- **Don't require interactive**: CLI must work without it
- **Don't use for destructive ops**: Keep explicit (use `interactive_confirm`)
- **Don't skip validation**: Interactive inputs need validation too
- **Don't force gum/fzf**: Must work with bash `select` fallback
- **Don't break scripts**: Check TTY before interactive mode
- **Don't modify files in interactive code**: Only in business logic

## Testing Interactive Features

### Unit Tests (ShellSpec)

```bash
Describe 'my_feature'
  It 'works with CLI arguments'
    When call my_feature "item1" 50
    The status should be success
    The output should include "Updated: item1"
  End

  It 'requires arguments in non-TTY'
    When call my_feature
    The status should be failure
    The stderr should include "Item required"
  End
End
```

### Manual Testing Checklist

```bash
# Test CLI mode (always)
$ harm-cli my-feature "item" 50        # Should work

# Test interactive mode (terminal)
$ harm-cli my-feature                   # Should show menu

# Test script mode (non-TTY)
$ echo | harm-cli my-feature            # Should require args

# Test JSON mode (skip interactive)
$ HARM_CLI_FORMAT=json harm-cli my-feature   # Should require args

# Test cancellation (Ctrl+C)
$ harm-cli my-feature  # Then Ctrl+C   # Should exit cleanly

# Test without gum/fzf
$ PATH=/usr/bin:/bin harm-cli my-feature  # Should use bash select
```

## Performance Considerations

### Overhead

- **Interactive mode detection**: ~1ms (negligible)
- **Module sourcing**: ~10-20ms (one-time)
- **Menu display**: ~50-100ms (user-perceived)
- **CLI mode**: 0ms (bypassed entirely)

### Optimization Tips

1. **Lazy load**: Source `interactive.sh` only when needed
2. **Cache checks**: Don't repeatedly check for gum/fzf
3. **Async data**: Load menu options in background if slow
4. **Pagination**: For large lists, paginate instead of showing all

## Troubleshooting

### Interactive mode not triggering

**Check:**

- Running in a TTY? `[[ -t 1 ]] && echo "yes" || echo "no"`
- Not in JSON mode? `echo $HARM_CLI_FORMAT`
- interactive.sh exists? `ls lib/interactive.sh`

### Fallback to bash select

**This is expected when:**

- `gum` not installed
- `fzf` not installed
- Running in restricted environment

**To test with gum:**

```bash
brew install gum
harm-cli my-feature  # Should use beautiful gum menu
```

### Input validation failing

**Remember:**

- Interactive inputs need same validation as CLI
- Empty inputs should be caught
- Range checks (e.g., 0-100) must apply to both modes

## Resources

- **gum**: https://github.com/charmbracelet/gum
- **fzf**: https://github.com/junegunn/fzf
- **bash select**: `help select` in bash
- **Examples**: See `lib/work.sh`, `lib/goals.sh`, `lib/ai.sh`

## Summary

Interactive mode in `harm-cli`:

- ✅ Enhances UX without breaking CLI compatibility
- ✅ Three-tier progressive enhancement
- ✅ Script-safe and automation-friendly
- ✅ Optional dependencies with graceful degradation
- ✅ Follows SOLID principles
- ✅ Zero breaking changes

**When in doubt:** Keep it simple, maintain CLI compatibility, and test both modes.
