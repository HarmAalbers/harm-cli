# Modern Git Stack Workflows for harm-cli

**Author:** Claude Code git-stack-expert agent
**Created:** 2025-10-24
**Last Updated:** 2025-10-24

---

## 📚 Overview

This guide explains modern git workflows using **stacked branches**, **git-absorb**, and advanced git techniques to maintain clean history while enabling fast, incremental code reviews.

### What You'll Learn

- ✅ How to use git-absorb for automatic fixup commits
- ✅ How to create and manage stacked branches
- ✅ How to handle squash merges in stacked workflows
- ✅ Modern git features (--update-refs, --empty=drop, --onto)
- ✅ Advanced conflict resolution strategies

---

## 🚀 Quick Start

### Install git-absorb

```bash
# macOS
brew install git-absorb

# Linux (requires Rust/Cargo)
cargo install git-absorb

# Verify installation
git absorb --version
```

### Configure Git for Modern Workflows

```bash
# Enable autosquash by default
git config --global rebase.autosquash true

# Enable rerere (reuse recorded conflict resolutions)
git config --global rerere.enabled true

# Use diff3 conflict style (shows original + both sides)
git config --global merge.conflictstyle diff3

# Safer force push
git config --global alias.force-push 'push --force-with-lease'

# Useful stack management aliases
git config --global alias.stack-rebase '!f() { git rebase "$1" --update-refs --empty=drop; }; f'
git config --global alias.absorb-all '!git add -u && git absorb --and-rebase'
```

### Check Git Version

```bash
git --version
# Recommended: 2.39+ (for --update-refs support)
# Minimum: 2.36+ (for --empty=drop support)

# Upgrade if needed:
# macOS: brew upgrade git
# Linux: apt update && apt upgrade git
```

---

## 🎯 Workflow 1: Using git-absorb

**Problem:** After code review, you need to fix issues in commits deep in your branch history.

**Old way:**

```bash
# Find the commit that needs fixing
git log --oneline
# abc123 feat(ai): add streaming support  ← Need to fix this
# def456 test(ai): add streaming tests
# ghi789 docs(ai): document streaming

# Create fixup commit
git add lib/ai.sh
git commit --fixup=abc123

# Interactive rebase to squash
git rebase -i --autosquash HEAD~3

# Manual reordering and squashing in editor...
```

**New way with git-absorb:**

```bash
# Make your improvements
vim lib/ai.sh  # Fix issues in the streaming code

# Stage the changes
git add lib/ai.sh

# Let git-absorb automatically figure out where they belong
git absorb --and-rebase

# Done! Changes automatically absorbed into abc123
```

**How it works:**

1. git-absorb analyzes your staged changes
2. Matches each hunk to the commit that introduced that code
3. Creates fixup! commits automatically
4. Rebases with autosquash to merge them in

**When to use:**

- ✅ Addressing code review feedback
- ✅ Fixing typos in previous commits
- ✅ Improving code from earlier in the branch
- ✅ Maintaining atomic, clean commits

---

## 🎯 Workflow 2: Stacked Branches

**Problem:** Large feature requires multiple PRs for reviewability, but they depend on each other.

**Solution:** Create a stack of dependent branches, each with a focused PR.

### Example: Adding Analytics Feature

```bash
# === Part 1: Database Schema ===
git checkout main
git checkout -b feature/analytics-db

# Implement database changes
vim lib/db/goals.sh
git add lib/db/goals.sh
git commit -m "feat(db): add analytics tables for goals"

# Push and create PR #1
git push -u origin feature/analytics-db
gh pr create --base main --title "Analytics Part 1: Database Schema"

# === Part 2: Business Logic (stacked on Part 1) ===
git checkout -b feature/analytics-logic

# Implement analytics logic
vim lib/analytics.sh
git add lib/analytics.sh
git commit -m "feat(analytics): implement goal tracking logic"

# Push and create PR #2 (base: feature/analytics-db)
git push -u origin feature/analytics-logic
gh pr create --base feature/analytics-db --title "Analytics Part 2: Business Logic"

# === Part 3: CLI Commands (stacked on Part 2) ===
git checkout -b feature/analytics-ui

# Implement CLI commands
vim bin/harm-cli
git add bin/harm-cli
git commit -m "feat(cli): add analytics view commands"

# Push and create PR #3 (base: feature/analytics-logic)
git push -u origin feature/analytics-ui
gh pr create --base feature/analytics-logic --title "Analytics Part 3: CLI Commands"
```

**Benefits:**

- ✅ Small, focused PRs (faster review)
- ✅ Parallel development possible
- ✅ Early feedback on each layer
- ✅ Easier to understand changes

---

## 🎯 Workflow 3: Handling Squash Merges in Stacks

**Problem:** PR #1 got squash-merged to main. Now PR #2 has "duplicate" commits that are already in main.

**Visual:**

```
Before merge:
main:     A -- B
            \
PR #1:       C -- D (feature/analytics-db)
                  \
PR #2:             E -- F (feature/analytics-logic)

After squash-merge PR #1:
main:     A -- B -- [CD]  ← Squashed C+D into one commit
            \
PR #1:       C -- D (merged, can delete)
                  \
PR #2:             E -- F  ← Still has C and D in history!
```

**Solution: Rebase with `--onto` and `--empty=drop`**

```bash
# Update main
git checkout main
git pull origin main

# Rebase PR #2 onto main, skipping the merged base
git checkout feature/analytics-logic
git rebase --onto main feature/analytics-db --empty=drop

# What this does:
# - Takes commits from analytics-logic that come AFTER analytics-db
# - Replays them onto main
# - Drops any commits that become empty (already in main via squash)

# Force push (safe, it's your feature branch)
git push --force-with-lease origin feature/analytics-logic

# Update PR base from feature/analytics-db to main
gh pr edit --base main
```

**Verification:**

```bash
# Check that only unique commits remain
git log --oneline origin/main..HEAD

# Should show only E and F, not C and D
```

---

## 🎯 Workflow 4: Rebasing Entire Stack (Git 2.39+)

**Problem:** Need to rebase a 4-level stack onto latest main. Don't want to rebase each level manually.

**Solution: Use `--update-refs`**

```bash
# Traditional way (tedious):
git checkout feature/layer-1
git rebase main
git checkout feature/layer-2
git rebase feature/layer-1
git checkout feature/layer-3
git rebase feature/layer-2
git checkout feature/layer-4
git rebase feature/layer-3

# Modern way (automatic!):
git checkout feature/layer-4  # Top of stack
git rebase main --update-refs --empty=drop

# Git automatically:
# 1. Identifies all branches in the stack
# 2. Rebases them in order
# 3. Updates all branch pointers
# 4. Drops empty commits from squash merges
```

**Force push all updated branches:**

```bash
git push --force-with-lease origin feature/layer-1
git push --force-with-lease origin feature/layer-2
git push --force-with-lease origin feature/layer-3
git push --force-with-lease origin feature/layer-4
```

---

## 🎯 Workflow 5: Conflict Resolution with rerere

**Problem:** Rebasing the same branch multiple times causes the same conflicts repeatedly.

**Solution: Enable rerere (reuse recorded resolution)**

```bash
# Enable rerere globally
git config --global rerere.enabled true

# Now when you resolve a conflict:
# 1. Resolve it once
# 2. Git records the resolution
# 3. Same conflict in future → auto-resolved!
```

**Example:**

```bash
# First rebase - conflict occurs
git rebase main
# ... conflict in lib/goals.sh ...

# Resolve manually
vim lib/goals.sh
git add lib/goals.sh
git rebase --continue

# ✅ rerere recorded the resolution

# Later: rebase again (e.g., main updated)
git rebase main
# ✅ Same conflict → auto-resolved by rerere!
```

---

## 🎯 Workflow 6: Testing Each Commit During Rebase

**Problem:** Want to ensure every commit in history builds and tests pass, not just the final state.

**Solution: Use `--exec` flag**

```bash
# Rebase and run tests after each commit
git rebase -i main --exec "just test"

# Git will:
# 1. Apply first commit
# 2. Run `just test`
# 3. If tests fail, pause for you to fix
# 4. Continue to next commit

# If tests fail:
# - Fix the issue
# - git add fixed-file.sh
# - git commit --amend (if fixing current commit)
# - git rebase --continue

# Result: Every commit in history passes tests!
```

---

## 📊 Decision Matrix: Which Workflow to Use?

| Situation                            | Recommended Workflow     | Command                                               |
| ------------------------------------ | ------------------------ | ----------------------------------------------------- |
| Need to fix code in previous commits | git-absorb               | `git absorb --and-rebase`                             |
| Large feature, want multiple PRs     | Stacked branches         | Create branch stack                                   |
| Base branch squash-merged            | --onto with --empty=drop | `git rebase --onto main old-base branch --empty=drop` |
| Rebase entire stack at once          | --update-refs            | `git rebase main --update-refs --empty=drop`          |
| Same conflict repeatedly             | Enable rerere            | `git config rerere.enabled true`                      |
| Ensure all commits pass tests        | --exec                   | `git rebase -i main --exec "just test"`               |

---

## 🚨 Common Issues & Solutions

### Issue 1: "git-absorb says 'nothing to absorb'"

**Cause:** Changes don't match any existing commits perfectly.

**Solution:**

```bash
# Use manual fixup instead
git log --oneline  # Find target commit SHA
git add <files>
git commit --fixup=<sha>
git rebase -i --autosquash main
```

### Issue 2: "Rebase created empty commits"

**Cause:** Commits were already applied via squash merge.

**Solution:**

```bash
# Use --empty=drop to skip them
git rebase --onto main old-base branch --empty=drop
```

### Issue 3: "--update-refs not recognized"

**Cause:** Git version too old (need 2.39+).

**Solution:**

```bash
# Upgrade git
brew upgrade git  # macOS
apt upgrade git   # Linux

# Or rebase manually (each level)
```

### Issue 4: "Force push rejected"

**Cause:** Remote has commits you don't have locally.

**Solution:**

```bash
# Fetch first
git fetch origin

# Use force-with-lease (safer)
git push --force-with-lease origin branch-name

# If intentional overwrite:
git push --force origin branch-name  # USE WITH CAUTION
```

---

## 🎓 Learning Path

### Beginner

1. ✅ Enable autosquash and rerere
2. ✅ Practice git-absorb on small branches
3. ✅ Create a simple 2-level stack

### Intermediate

1. ✅ Handle squash merge with --onto
2. ✅ Use --exec to run tests during rebase
3. ✅ Manage 3-level stacks

### Advanced

1. ✅ Use --update-refs for full stack rebases
2. ✅ Combine git-absorb with stacked workflows
3. ✅ Manage complex 5+ level stacks

---

## 🔗 Related Documentation

- **git-absorb GitHub**: https://github.com/tummychow/git-absorb
- **Git official docs**: https://git-scm.com/docs
- **Stacked Diffs Guide**: https://graphite.dev/guides/stacked-diffs
- **harm-cli Git Conventions**: See `.claude/agents/git-workflow-expert.md`

---

## 💡 Tips & Tricks

### Alias for Quick Stack Rebase

```bash
git config --global alias.sr '!git rebase --update-refs --empty=drop'

# Usage:
git sr main  # Rebases entire stack onto main
```

### Alias for git-absorb + Push

```bash
git config --global alias.absorb-push '!git absorb --and-rebase && git push --force-with-lease'

# Usage:
git absorb-push  # Absorbs changes and pushes
```

### View Stack Structure

```bash
# See all branches and their relationships
git log --oneline --graph --all --decorate
```

### Dry Run Before Rebase

```bash
# See what commits would be applied
git rebase --onto main old-base branch --dry-run
```

---

## 🤝 Getting Help

### Ask the git-stack-expert Agent

In Claude Code, you can invoke the git-stack-expert agent for guidance:

```
"How do I handle a squash merge in my stack?"
"Use git-absorb to clean up my fixup commits"
"My stack won't rebase after the base was merged"
```

The agent will provide:

- ✅ Current situation analysis
- ✅ Recommended strategy
- ✅ Step-by-step commands
- ✅ Verification steps
- ✅ Recovery plan if something goes wrong

---

## 📝 Changelog

### 2025-10-24 - Initial Version

- Created comprehensive guide for modern git workflows
- Documented git-absorb usage
- Explained stacked branch workflows
- Covered squash merge handling
- Added troubleshooting section

---

**Happy stacking! 🚀**

_For basic git workflows, see: `.claude/agents/git-workflow-expert.md`_
_For advanced git workflows, see: `.claude/agents/git-stack-expert.md`_
