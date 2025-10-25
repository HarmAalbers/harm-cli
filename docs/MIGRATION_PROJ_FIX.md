# Migration Guide: Project Switching Fix

## Overview

We've fixed the project switching issue where `proj switch` would output a `cd` command but wouldn't actually change directories. This fix ensures that the `proj()` shell function is automatically loaded during installation.

## What Changed

### Before (Broken Behavior)
```bash
$ proj switch solarmonkey
Alias tip: proj switch solarmonkey

$ pwd
/Users/harm/harm-cli  # Still in old directory!
```

### After (Fixed Behavior)
```bash
$ proj switch solarmonkey

$ pwd
/Users/harm/solarmonkey  # Directory actually changed! ✅
```

## Technical Details

The installer now:
1. **Loads init script automatically** - `~/.harm-cli/harm-cli.sh` now sources `etc/harm-cli-init.sh`
2. **Removes proj alias** - The `proj` alias has been removed from `aliases.sh` since the shell function provides better functionality
3. **Shell function priority** - The `proj()` shell function is loaded before aliases, ensuring correct behavior

## Migration Steps for Existing Users

### Option 1: Re-run the Installer (Recommended)

This is the easiest method:

```bash
cd ~/harm-cli
./install.sh
```

The installer will:
- Regenerate `~/.harm-cli/harm-cli.sh` with init script loading
- Regenerate `~/.harm-cli/aliases.sh` without the `proj` alias
- Preserve all your existing configuration

Then restart your shell:
```bash
source ~/.zshrc  # or ~/.bashrc
```

### Option 2: Manual Migration

If you prefer to update manually:

#### Step 1: Update `~/.harm-cli/harm-cli.sh`

Add this section after the PATH configuration and before the aliases loading:

```bash
# ═══════════════════════════════════════════════════════════════
# Load Shell Integration (Functions & Hooks)
# ═══════════════════════════════════════════════════════════════

# Detect harm-cli installation directory
if [[ -z "${HARM_CLI_ROOT:-}" ]]; then
  # Resolve from harm-cli command in PATH
  if command -v harm-cli >/dev/null 2>&1; then
    HARM_CLI_ROOT="$(cd "$(dirname "$(readlink -f "$(command -v harm-cli)" 2>/dev/null || command -v harm-cli)")/.." 2>/dev/null && pwd || echo "$HOME/harm-cli")"
    export HARM_CLI_ROOT
  fi
fi

# Source the init script for shell functions (proj, etc.)
if [[ -n "${HARM_CLI_ROOT:-}" ]] && [[ -f "$HARM_CLI_ROOT/etc/harm-cli-init.sh" ]]; then
  source "$HARM_CLI_ROOT/etc/harm-cli-init.sh"
fi
```

#### Step 2: Update `~/.harm-cli/aliases.sh`

Remove the `proj` alias line:
```bash
# Remove this line:
alias proj='harm-cli proj'

# Replace with this comment:
# Note: 'proj' is provided as a shell function by harm-cli-init.sh for directory switching
```

#### Step 3: Reload your shell

```bash
source ~/.zshrc  # or ~/.bashrc
```

## Verification

After migrating, verify the fix works:

### Test 1: Check that proj is a function
```bash
type proj
```

Expected output:
```
proj is a shell function from /path/to/harm-cli/etc/harm-cli-init.sh
```

### Test 2: Test directory switching

```bash
# Add a test project
proj add ~/some-project test-proj

# Switch to it
proj switch test-proj

# Verify you actually switched
pwd
```

The directory should change without needing to `eval` or manually run `cd`.

## Troubleshooting

### Issue: "proj is an alias"

**Cause:** Your current shell session still has the old alias loaded.

**Solution:**
```bash
unalias proj
source ~/.zshrc
```

### Issue: "proj: command not found"

**Cause:** The init script isn't being sourced.

**Solution:** Check that `~/.harm-cli/harm-cli.sh` includes the init script loading (see Option 2 above).

### Issue: Directory doesn't change

**Cause:** You're running `harm-cli proj switch` directly instead of using the shell function.

**Solution:** Use `proj switch` (without `harm-cli` prefix) to invoke the shell function.

### Issue: Shell exits immediately after sourcing or running commands

**Cause:** (Fixed in v1.1.0+) Multiple issues caused shell exits:
1. Unprotected `$ZSH_VERSION` variable check
2. **Critical**: Shell options (`set -u`) from library files leaked into interactive shell

**Symptoms:**
- Shell exits when opening new terminal
- Shell exits when running `cd` command
- Shell exits when accessing unset variables

**Solution:** Re-run the installer to get the fully fixed version:
```bash
cd ~/harm-cli
./install.sh
source ~/.zshrc
```

**What the fix does:**
1. Protects variable checks: `$ZSH_VERSION` → `${ZSH_VERSION:-}`
2. Saves and restores shell options around init script sourcing
3. Prevents `set -u` (nounset) from leaking into your interactive shell

## Why This Fix Matters

### Technical Explanation

When you run a command in your shell, it executes in a **subprocess**. Subprocesses can't modify the parent shell's environment, including the current working directory. This is a fundamental Unix limitation.

**The Problem:**
```bash
harm-cli proj switch myproject   # Runs in subprocess
  ↳ cd /path/to/myproject        # Changes subprocess dir, not parent shell
```

**The Solution:**
```bash
proj() {                         # Shell function runs in current shell
  eval "$(harm-cli proj switch)" # Evaluates the cd command in current shell
}
```

### Benefits of Shell Functions

1. **Seamless UX** - Users don't need to remember to use `eval`
2. **Smart switching** - Can handle both `proj switch name` and `proj sw name`
3. **Error handling** - Shows helpful messages if project doesn't exist
4. **Extensible** - Future enhancements (venv activation, etc.) will work automatically

## Related Commands

This fix pattern also applies to any command that needs to modify the parent shell environment. Currently, only `proj switch` has this requirement, but the architecture now supports future commands that might need similar functionality.

## Rollback (if needed)

If you need to rollback to the old behavior for any reason:

```bash
# Remove function
unset -f proj

# Restore alias
alias proj='harm-cli proj'
```

Though we don't recommend this, as the old behavior was broken.

## Questions?

If you encounter any issues not covered in this guide:
1. Check the [COMMANDS.md](../COMMANDS.md) documentation
2. Run `harm-cli proj --help`
3. Report issues at https://github.com/harm/harm-cli/issues

---

**Last Updated:** 2025-10-24
**Applies to:** harm-cli v1.1.0+
