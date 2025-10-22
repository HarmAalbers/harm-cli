# harm-cli Installation Guide

Complete guide for installing and configuring harm-cli on your system.

---

## 🚀 Quick Installation

### One-Command Install

```bash
./install.sh
```

This interactive script will:

1. ✅ Check all required dependencies
2. ✅ Choose installation mode (Quick or Custom)
3. ✅ Configure all settings (paths, logging, AI, features)
4. ✅ Create symlink in `~/.local/bin`
5. ✅ Ask for your preferred shortcut style
6. ✅ Generate configuration file (`~/.harm-cli/config.sh`)
7. ✅ Install shell completions (bash or zsh)
8. ✅ Update your shell config automatically
9. ✅ Test the installation

### Installation Modes

The installer offers two modes:

#### 1️⃣ **Quick Install** (Recommended for Most Users)

Uses sensible defaults for everything. Perfect if you just want to get started quickly.

**Defaults:**

- Installation: `~/.local/bin`
- Data directory: `~/.harm-cli`
- Log level: `INFO`
- Log max size: `10MB`
- AI cache: `1 hour`
- Completions: Enabled
- PATH: Auto-added

#### 2️⃣ **Custom Install** (For Power Users)

Interactively configure every setting. Choose this if you need:

- Custom installation paths
- Specific logging behavior
- Fine-tuned AI settings
- Selective feature installation

### Or Use Just

```bash
just install-local
```

---

## ⚙️ Shortcut Styles

When you run `./install.sh`, you'll choose from 4 shortcut styles:

### 1. Minimal - Just Main Alias

```bash
h work start "task"
h goal set "goal" 2h
h ai "question"
```

**Use if:** You want minimal changes to your shell

---

### 2. Balanced - Direct Subcommands (Recommended)

```bash
work start "task"
goal set "goal" 2h
ai "question"
proj switch myapp
```

**Use if:** You want natural, readable commands

---

### 3. Power User - Ultra-Short Shortcuts

```bash
ws "task"     # work start
ww            # work status
wo            # work stop
gs "goal" 2h  # goal set
gg            # goal show
ask "?"       # ai query
```

**Use if:** You prioritize speed over readability

---

### 4. Hybrid - Best of Both (Recommended for Most)

```bash
# Use ultra-short for frequent commands
ws "task"              # work start
ww                     # work status
wo                     # work stop

# Use full names for clarity
goal set "finish API" 3h
ai "how do I...?"
proj switch myapp

# Use 'h' for less common commands
h docker status
h python test
```

**Use if:** You want maximum flexibility

---

## 🛡️ Alias Conflict Detection

### Overview

The installer automatically checks for existing aliases that would conflict with harm-cli shortcuts. This prevents accidentally overriding your existing shell aliases.

### How It Works

1. **After you choose a shortcut style**, the installer scans your shell config file
2. **If conflicts are found**, you'll see exactly which aliases conflict
3. **You choose how to handle them** with 4 options

### Example Conflict Detection

```bash
▶ Choose your shortcut style

Enter your choice [1-4] (default: 4): 4

⚠ Found existing aliases in ~/.bashrc:

  • h
    Current: alias h='history | tail -20'
  • work
    Current: alias work='cd ~/work'
  • ai
    Current: alias ai='python ~/scripts/ai.py'

How would you like to proceed?

  1) Override - Replace existing aliases with harm-cli aliases
     ⚠  This will comment out your existing aliases

  2) Skip - Keep existing aliases, don't add harm-cli aliases
     ℹ  You can manually add later or use full commands

  3) Choose Different Style - Pick a shortcut style without conflicts

  4) Cancel - Exit installation

Enter your choice [1-4] (default: 2):
```

### Conflict Resolution Options

#### 1️⃣ **Override** - Replace Existing Aliases

- ✅ Comments out your existing aliases with `# [harm-cli override]`
- ✅ Creates timestamped backup: `.bashrc.backup-20251022-143025`
- ✅ Adds harm-cli aliases
- ⚠️ Your old aliases are preserved but inactive

**Choose this if:** You want to use harm-cli shortcuts and rarely use the old aliases.

#### 2️⃣ **Skip** - Keep Existing Aliases (Default)

- ✅ Keeps your existing aliases unchanged
- ✅ Skips adding harm-cli aliases
- ✅ Adds comment to shell config about manual setup
- ℹ️ You can still use full commands like `harm-cli work start`

**Choose this if:** Your existing aliases are important and you don't mind typing full commands.

#### 3️⃣ **Choose Different Style** - Avoid Conflicts

- ✅ Returns to shortcut selection
- ✅ Try a different style that doesn't conflict
- 📝 Example: Switch from Hybrid to Minimal (`h` only)

**Choose this if:** You want shortcuts but with minimal conflicts.

#### 4️⃣ **Cancel** - Exit Installation

- Exits the installer cleanly
- No changes made to your system

**Choose this if:** You need to review your aliases first.

### After Override: What Happened

If you chose **Override**, your `.bashrc` is modified like this:

**Before:**

```bash
alias h='history | tail -20'
alias work='cd ~/work'
alias ai='python ~/scripts/ai.py'
```

**After:**

```bash
# [harm-cli override] alias h='history | tail -20'
# [harm-cli override] alias work='cd ~/work'
# [harm-cli override] alias ai='python ~/scripts/ai.py'

# ═══════════════════════════════════════════════════════════════
# harm-cli: Shell Integration
# ═══════════════════════════════════════════════════════════════

alias h='harm-cli'
alias work='harm-cli work'
alias ai='harm-cli ai'
# ... etc
```

### Restoring Overridden Aliases

If you change your mind later:

```bash
# Use the backup file
cp ~/.bashrc.backup-20251022-143025 ~/.bashrc

# Or manually uncomment in ~/.bashrc
# Remove "# [harm-cli override] " prefix from lines
```

### Manual Alias Setup (If Skipped)

If you chose **Skip** during installation, you can manually add aliases later:

```bash
# Edit your shell config
vim ~/.bashrc

# Add selected harm-cli aliases (avoid conflicts)
alias hcli='harm-cli'        # Different name to avoid conflict
alias hwork='harm-cli work'  # Prefix with 'h'
alias hgoal='harm-cli goal'
alias hai='harm-cli ai'
```

---

## ⚙️ Configuration File

### Overview

The installer creates `~/.harm-cli/config.sh` which contains all your settings. This file is:

- ✅ **Automatically sourced** on every harm-cli command
- ✅ **Human-editable** - you can modify values manually
- ✅ **Version-controllable** - add to your dotfiles repo
- ✅ **Safe defaults** - uses fallback values if not set

### Configurable Settings

The installer prompts for these settings in **Custom Install** mode:

#### 📂 Path Configuration

| Setting         | Default            | Description                                |
| --------------- | ------------------ | ------------------------------------------ |
| `LOCAL_BIN`     | `~/.local/bin`     | Where symlink is created                   |
| `HARM_CLI_HOME` | `~/.harm-cli`      | Data directory (goals, projects, sessions) |
| `HARM_LOG_DIR`  | `~/.harm-cli/logs` | Log file directory                         |

#### 📝 Logging Configuration

| Setting              | Default       | Description                                  |
| -------------------- | ------------- | -------------------------------------------- |
| `HARM_LOG_LEVEL`     | `INFO`        | Log level (`DEBUG`, `INFO`, `WARN`, `ERROR`) |
| `HARM_LOG_TO_FILE`   | `1` (enabled) | Write logs to file (0=disabled, 1=enabled)   |
| `HARM_LOG_MAX_SIZE`  | `10MB`        | Maximum log file size before rotation        |
| `HARM_LOG_MAX_FILES` | `5`           | Number of rotated log files to keep          |

**Example:** Set `DEBUG` level for troubleshooting, `WARN` for quiet operation.

#### 🤖 AI Configuration

| Setting                  | Default         | Description                           |
| ------------------------ | --------------- | ------------------------------------- |
| `HARM_CLI_AI_CACHE_TTL`  | `3600` (1 hour) | AI response cache duration in seconds |
| `HARM_CLI_AI_TIMEOUT`    | `20`            | AI request timeout in seconds         |
| `HARM_CLI_AI_MAX_TOKENS` | `2048`          | Maximum tokens per AI request         |

**Example:** Set cache to `0` to disable caching, or `7200` for 2-hour cache.

#### 🎯 Feature Configuration

| Setting                        | Default       | Description                              |
| ------------------------------ | ------------- | ---------------------------------------- |
| `HARM_CLI_FORMAT`              | `text`        | Default output format (`text` or `json`) |
| `HARM_CLI_COMPLETIONS_ENABLED` | `1` (enabled) | Shell completions (set during install)   |

### Editing Configuration Later

You can modify settings in three ways:

#### 1. **Edit the config file directly**

```bash
# Open in your editor
vim ~/.harm-cli/config.sh

# Example changes:
export HARM_LOG_LEVEL="DEBUG"           # Enable debug logging
export HARM_CLI_AI_CACHE_TTL="7200"     # Cache for 2 hours
export HARM_CLI_FORMAT="json"           # Default to JSON output
```

#### 2. **Set environment variables in your shell**

```bash
# Add to ~/.bashrc or ~/.zshrc (overrides config.sh)
export HARM_LOG_LEVEL="DEBUG"
export HARM_CLI_FORMAT="json"
```

#### 3. **Re-run the installer**

```bash
# Uninstall first (keeps your data by default)
./uninstall.sh

# Run installer again to reconfigure
./install.sh
```

### Example config.sh File

```bash
#!/usr/bin/env bash
# ~/.harm-cli/config.sh
# Generated by install.sh on 2025-10-22

# ═══════════════════════════════════════════════════════════════
# Path Configuration
# ═══════════════════════════════════════════════════════════════

export HARM_CLI_HOME="${HARM_CLI_HOME:-$HOME/.harm-cli}"
export HARM_LOG_DIR="${HARM_LOG_DIR:-$HOME/.harm-cli/logs}"

# ═══════════════════════════════════════════════════════════════
# Logging Configuration
# ═══════════════════════════════════════════════════════════════

export HARM_LOG_LEVEL="${HARM_LOG_LEVEL:-INFO}"
export HARM_LOG_TO_FILE="${HARM_LOG_TO_FILE:-1}"
export HARM_LOG_MAX_SIZE="${HARM_LOG_MAX_SIZE:-10485760}"  # 10MB
export HARM_LOG_MAX_FILES="${HARM_LOG_MAX_FILES:-5}"

# ═══════════════════════════════════════════════════════════════
# AI Configuration
# ═══════════════════════════════════════════════════════════════

export HARM_CLI_AI_CACHE_TTL="${HARM_CLI_AI_CACHE_TTL:-3600}"
export HARM_CLI_AI_TIMEOUT="${HARM_CLI_AI_TIMEOUT:-20}"
export HARM_CLI_AI_MAX_TOKENS="${HARM_CLI_AI_MAX_TOKENS:-2048}"

# ═══════════════════════════════════════════════════════════════
# Output Configuration
# ═══════════════════════════════════════════════════════════════

export HARM_CLI_FORMAT="${HARM_CLI_FORMAT:-text}"

# ═══════════════════════════════════════════════════════════════
# Feature Flags
# ═══════════════════════════════════════════════════════════════

export HARM_CLI_COMPLETIONS_ENABLED="${HARM_CLI_COMPLETIONS_ENABLED:-1}"
```

---

## 📦 What Gets Installed

### Files Created

- **Symlink:** `~/.local/bin/harm-cli` → `~/harm-cli/bin/harm-cli`
- **Configuration:** `~/.harm-cli/config.sh` (all your settings)
- **Shell Integration:** Added to `~/.zshrc` or `~/.bashrc`

### Shell Config Additions

Example for **Hybrid** style in `.zshrc`:

```bash
# ═══════════════════════════════════════════════════════════════
# harm-cli: Shell Integration
# Generated by install.sh
# ═══════════════════════════════════════════════════════════════

# Source harm-cli configuration
if [[ -f "$HOME/.harm-cli/config.sh" ]]; then
  source "$HOME/.harm-cli/config.sh"
fi

# harm-cli: Main alias for less common commands
alias h='harm-cli'

# harm-cli: Direct subcommands for frequent use
alias work='harm-cli work'
alias goal='harm-cli goal'
alias ai='harm-cli ai'
alias proj='harm-cli proj'

# harm-cli: Ultra-short work session commands
alias ws='harm-cli work start'
alias wo='harm-cli work stop'
alias ww='harm-cli work status'

# harm-cli: Completions
fpath+=("$HOME/harm-cli/completions")
autoload -Uz compinit && compinit
```

---

## ✅ After Installation

### 1. Reload Your Shell

```bash
source ~/.zshrc
# or restart your terminal
```

### 2. Verify Installation

```bash
which harm-cli
# Output: /Users/harm/.local/bin/harm-cli

harm-cli version
# Output: harm-cli version 1.0.0

harm-cli doctor
# Checks all dependencies
```

### 3. Check Your Configuration

```bash
# View your configuration
cat ~/.harm-cli/config.sh

# Test that environment variables are set
echo $HARM_CLI_HOME
# Output: /Users/harm/.harm-cli

echo $HARM_LOG_LEVEL
# Output: INFO (or your custom value)
```

### 4. Test Your Shortcuts

```bash
# If you chose Hybrid style:
ws "testing installation"    # Start work session
ww                           # Check status
wo                           # Stop work

# Try other commands
goal set "learn harm-cli" 30m
ai "what are best practices for bash scripts?"
```

### 5. Tab Completion

```bash
harm-cli <TAB>      # Shows all commands
work <TAB>          # Shows: start, stop, status
ai <TAB>            # Shows: query, review, daily, etc.
```

---

## 🗑️ Uninstallation

### Remove harm-cli

```bash
./uninstall.sh
# or
just uninstall-local
```

This will:

- ✅ Remove symlink from `~/.local/bin`
- ✅ Remove shell integration from `.zshrc`
- ✅ **Ask** before removing user data (`~/.harm-cli/`)
- ✅ Create backup of shell config

### Manual Uninstall

If you prefer to remove manually:

```bash
# 1. Remove symlink
rm ~/.local/bin/harm-cli

# 2. Edit ~/.zshrc and remove the harm-cli section
# (between "# harm-cli: Shell Integration" and next blank line)

# 3. Optionally remove user data
rm -rf ~/.harm-cli
```

---

## 🔧 Advanced Configuration

### Change Shortcut Style Later

1. Run uninstall: `./uninstall.sh` (keep data when asked)
2. Run install again: `./install.sh`
3. Choose a different style

### Custom Aliases

Add your own shortcuts to `.zshrc`:

```bash
# Custom harm-cli shortcuts
alias daily='harm-cli ai daily'
alias review='harm-cli ai review'
alias commit='msg=$(harm-cli git commit-msg) && git commit -m "$msg"'
```

### Environment Variables

```bash
# Add to ~/.zshrc for custom configuration
export HARM_CLI_HOME="~/.harm-cli"           # Data directory
export HARM_CLI_LOG_LEVEL="DEBUG"            # Log level
export HARM_CLI_FORMAT="json"                # Default output format
export GEMINI_API_KEY="your-key-here"        # AI features
```

---

## 🆘 Troubleshooting

### "command not found: harm-cli"

**Solution:**

```bash
# Check PATH includes ~/.local/bin
echo $PATH | grep .local/bin

# If not, add to ~/.zshrc:
export PATH="$HOME/.local/bin:$PATH"

# Then reload:
source ~/.zshrc
```

### "command not found: ws" (or other shortcuts)

**Solution:**

```bash
# Reload shell config
source ~/.zshrc

# Verify aliases exist
alias | grep harm
```

### Tab Completion Not Working

**For zsh:**

```bash
# Check fpath includes completions
echo $fpath | grep harm-cli

# If not, add to ~/.zshrc:
fpath+=("$HOME/harm-cli/completions")
autoload -Uz compinit && compinit
```

**For bash:**

```bash
# Add to ~/.bashrc:
source ~/harm-cli/completions/harm-cli.bash
```

### Symlink Broken After `git pull`

This shouldn't happen (symlink is stable), but if it does:

```bash
# Recreate symlink
ln -sf ~/harm-cli/bin/harm-cli ~/.local/bin/harm-cli
```

---

## 📚 Next Steps

After installation:

1. **Read the docs:** `harm-cli help`
2. **Try the features:** See [COMMANDS.md](COMMANDS.md)
3. **Set up AI:** `harm-cli ai --setup`
4. **Start tracking:** `ws "your first task"`

---

## 🎯 Quick Reference

| Task          | Command                                    |
| ------------- | ------------------------------------------ |
| **Install**   | `./install.sh` or `just install-local`     |
| **Uninstall** | `./uninstall.sh` or `just uninstall-local` |
| **Update**    | `cd ~/harm-cli && git pull`                |
| **Verify**    | `harm-cli doctor`                          |
| **Get Help**  | `harm-cli --help`                          |

---

**Questions?** See [README.md](README.md) or run `harm-cli help`
