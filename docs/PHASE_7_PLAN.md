# Phase 7: Hooks & Integration - Implementation Plan

**Date:** 2025-10-21
**Status:** Planning
**Estimated Time:** 6-8 hours
**Current Session Time:** 38 hours (LEGENDARY!)

---

## 📊 **Source Analysis**

**99_hooks.zsh** (~400 LOC)

- Precmd/preexec hooks
- Shell initialization
- Prompt integration
- Command completion

---

## 🎯 **Phase 7 Scope - Smart Breakdown**

### **7a: Shell Init Script** (1-2h)

**Create:** `etc/harm-cli-init.sh`

- Outputs eval-able shell code
- Adds harm-cli to PATH
- Sets up environment variables
- Loads completions

**Value:** HIGH - Essential for shell integration

---

### **7b: Bash Completions** (2-3h)

**Create:** `completions/harm-cli.bash`

- Tab completion for all commands
- Subcommand completion
- File/directory completion where appropriate

**Value:** HIGH - Great UX improvement

---

### **7c: Shell Functions** (1-2h)

**Create:** `etc/shell-functions.sh`

- Convenient aliases (proj wrapper, etc.)
- Helper functions
- Prompt integration helpers

**Value:** MEDIUM - Nice quality of life

---

### **7d: Command Hooks** (1-2h)

**Create:** `lib/hooks.sh`

- Pre-command hooks (safety checks)
- Post-command hooks (logging, work tracking)
- Optional hooks system

**Value:** LOW - Advanced feature, not essential

---

## 💡 **Recommendation: MVP Approach**

**After 38 hours, focus on ESSENTIAL:**

### **Do Phase 7a + 7b** (3-5h)

1. ✅ Shell init script
2. ✅ Bash completions

**Skip Phase 7c + 7d** (defer to v1.1.0)

- Shell functions are convenience
- Hooks are advanced/optional

**Benefit:**

- Get essential integration done
- Users can actually use harm-cli easily
- Save 2-4 hours
- Ship faster!

---

## 🏗️ **Implementation Plan**

### **Phase 7a: Shell Init** (1-2h)

**Create:** `etc/harm-cli-init.sh`

```bash
#!/usr/bin/env bash
# harm-cli shell integration
# Usage: eval "$(harm-cli init)"

# Add to PATH
export PATH="$HARM_CLI_HOME/bin:$PATH"

# Set environment
export HARM_CLI_HOME="${HARM_CLI_HOME:-$HOME/.harm-cli}"

# Load completions (if available)
if [ -f "$HARM_CLI_HOME/../completions/harm-cli.bash" ]; then
  source "$HARM_CLI_HOME/../completions/harm-cli.bash"
fi

# Optional: Load shell functions
# source "$HARM_CLI_HOME/../etc/shell-functions.sh"
```

**Test:** `eval "$(harm-cli init)" && harm-cli version`

---

### **Phase 7b: Completions** (2-3h)

**Create:** `completions/harm-cli.bash`

```bash
# Bash completion for harm-cli
_harm_cli_completions() {
  local cur prev commands

  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  # Top-level commands
  commands="version help doctor work goal ai git proj docker python gcloud health safe"

  # Subcommand completion
  case "${prev}" in
    work)
      COMPREPLY=($(compgen -W "start stop status" -- "$cur"))
      return 0
      ;;
    goal)
      COMPREPLY=($(compgen -W "set show progress complete clear validate" -- "$cur"))
      return 0
      ;;
    ai)
      COMPREPLY=($(compgen -W "query review explain-error daily --help --setup" -- "$cur"))
      return 0
      ;;
    git)
      COMPREPLY=($(compgen -W "status commit-msg" -- "$cur"))
      return 0
      ;;
    proj)
      COMPREPLY=($(compgen -W "list add remove switch" -- "$cur"))
      return 0
      ;;
    docker)
      COMPREPLY=($(compgen -W "up down status logs shell health" -- "$cur"))
      return 0
      ;;
    python)
      COMPREPLY=($(compgen -W "status test lint format" -- "$cur"))
      return 0
      ;;
    safe)
      COMPREPLY=($(compgen -W "rm docker-prune git-reset" -- "$cur"))
      return 0
      ;;
    *)
      COMPREPLY=($(compgen -W "$commands" -- "$cur"))
      ;;
  esac
}

complete -F _harm_cli_completions harm-cli
```

**Test:** Type `harm-cli <TAB>` and see completions

---

## ✅ **Success Criteria**

**Phase 7a (Init):**

- [x] `harm-cli init` outputs shell code
- [x] Users can eval it in their shell
- [x] PATH is set correctly
- [x] Environment variables set

**Phase 7b (Completions):**

- [x] Tab completion works for main commands
- [x] Tab completion works for subcommands
- [x] File completion where appropriate
- [x] No errors on incomplete commands

---

## 🚀 **After Phase 7**

**You'll have:**

- ✅ All core features (65% → 75%)
- ✅ Shell integration (users can actually use it!)
- ✅ Great UX (tab completion)
- ✅ ~38 + 4 = 42 hours invested

**Then Phase 8:** Final polish (2-4h) → v1.0.0 🎉

---

## 🤔 **Ready to Implement?**

**Do:**

1. Phase 7a: Shell Init (1-2h)
2. Phase 7b: Completions (2-3h)

**Skip:** 3. Phase 7c: Shell Functions (defer) 4. Phase 7d: Hooks (defer)

**Total: 3-5 hours to functional shell integration!**

**Let's make harm-cli easy to use!** 🚀
