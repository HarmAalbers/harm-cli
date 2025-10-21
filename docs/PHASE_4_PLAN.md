# Phase 4: Git & Projects - Implementation Plan

**Date:** 2025-10-21
**Status:** Planning
**Estimated Time:** 8-10 hours
**Priority:** High - Next major phase

---

## 📊 Analysis Summary

### Source Files

**20_git_advanced.zsh** (2,289 LOC):

- Smart branch creation with auto-prefixing
- Intelligent commits with type detection
- Branch syncing with conflict handling
- PR creation with templates
- Enhanced git status with suggestions
- Multiple helper utilities

**10_project_management.zsh** (1,064 LOC):

- Project directory management
- Project switching with environment activation
- Health checks
- Hook system
- Batch operations

**Total Source:** 3,353 LOC

---

## 🎯 Phase 4 Goals

### MVP Scope (Must Implement)

**Git Module (lib/git.sh):**

1. ✅ `git_commit_msg` - AI-powered commit message generation
2. ✅ `git_status_enhanced` - Enhanced status with suggestions
3. ✅ `git_default_branch` - Detect main/master
4. ✅ Basic git utilities

**Project Module (lib/proj.sh):**

1. ✅ `proj_list` - List available projects
2. ✅ `proj_switch` - Switch to project directory
3. ✅ `proj_add` - Register new project
4. ✅ `proj_remove` - Remove project

**Defer to Phase 4.5:**

- Smart branch creation (gnew)
- Branch syncing (gsync)
- PR creation (gpr)
- Project health checks
- Hook systems

---

## 🏗️ Architecture Design

### Two Modules Approach

**lib/git.sh** (~400 LOC)

- AI-powered commit messages (integrates with Phase 3 AI)
- Enhanced git status
- Git utilities (default branch detection, etc.)

**lib/proj.sh** (~300 LOC)

- Project registry (JSONL format)
- Project switching
- Project CRUD operations

### SOLID Principles

**Single Responsibility:**

```bash
# ✅ Each function does ONE thing
git_commit_msg()      # ONLY generates commit message
git_status_enhanced() # ONLY shows enhanced status
proj_list()           # ONLY lists projects
proj_switch()         # ONLY switches projects
```

**Open/Closed:**

```bash
# ✅ Extensible project types
proj_detect_type() {
  [[ -f package.json ]] && echo "nodejs" && return
  [[ -f pyproject.toml ]] && echo "python" && return
  # Easy to add more types
}
```

**Dependency Inversion:**

```bash
# ✅ Depend on abstractions (config files)
PROJ_CONFIG="${HARM_CLI_HOME}/projects.jsonl"
# Not hardcoded paths
```

---

## 📁 File Structure

### New Files

**lib/git.sh** (~400 LOC)

```bash
# Public API:
git_commit_msg <context>     # Generate commit message with AI
git_status_enhanced          # Enhanced git status
git_default_branch           # Detect main/master
git_is_repo                  # Check if in git repo

# Private helpers:
_git_staged_summary          # Summarize staged changes
_git_detect_type             # Detect commit type (feat/fix/docs)
_git_format_message          # Format conventional commit
```

**lib/proj.sh** (~300 LOC)

```bash
# Public API:
proj_list                    # List all projects
proj_add <path> <name>       # Register project
proj_remove <name>           # Remove project
proj_switch <name>           # Switch to project

# Private helpers:
_proj_config_file            # Get config file path
_proj_exists                 # Check if project exists
_proj_validate_path          # Validate project path
```

**spec/git_spec.sh** (~200 LOC, ~25 tests)
**spec/proj_spec.sh** (~150 LOC, ~20 tests)

---

## 🔧 Key Features

### 1. AI-Powered Commit Messages

**Purpose:** Generate conventional commit messages using AI

**Usage:**

```bash
# Stage changes
git add lib/ai.sh

# Generate commit message
harm-cli git commit-msg

# Output:
# feat(ai): add code review functionality
#
# - Added ai_review() for git diff analysis
# - Includes bug detection and suggestions
# - Truncates large diffs to 200 lines
```

**Implementation:**

```bash
git_commit_msg() {
  # Check if in git repo
  # Get staged changes (git diff --cached)
  # Analyze changes to detect type (feat/fix/docs/etc)
  # Build context for AI
  # Query AI for commit message
  # Format as conventional commit
  # Display result
}
```

---

### 2. Enhanced Git Status

**Purpose:** Git status with actionable suggestions

**Usage:**

```bash
harm-cli git status

# Output:
# Branch: phase-4/git-and-projects
# Status: 2 files modified, 1 untracked
#
# Suggestions:
#   - Run: git add lib/git.sh
#   - Consider: harm-cli git commit-msg
#   - Tip: Use harm-cli work start to track this session
```

---

### 3. Project Management

**Purpose:** Quick project switching

**Usage:**

```bash
# List projects
harm-cli proj list

# Add project
harm-cli proj add ~/harm-cli harm-cli

# Switch to project
harm-cli proj switch harm-cli
# → cd ~/harm-cli
# → Activates environment
```

**Data Format (JSONL):**

```json
{"name":"harm-cli","path":"/Users/harm/harm-cli","type":"bash","added":"2025-10-21T10:00:00Z"}
{"name":"dotfiles","path":"/Users/harm/.dotfiles","type":"shell","added":"2025-10-21T10:00:00Z"}
```

---

## 🧪 Testing Strategy

### Git Tests (spec/git_spec.sh)

```bash
Describe 'lib/git.sh'
  Describe 'git_commit_msg'
    It 'detects when not in git repo'
    It 'detects when no staged changes'
    It 'generates commit message from diff'
    It 'detects commit type (feat/fix/docs)'
    It 'formats as conventional commit'
  End

  Describe 'git_status_enhanced'
    It 'shows enhanced status in git repo'
    It 'handles non-git directory'
    It 'provides suggestions'
  End

  Describe 'git_default_branch'
    It 'detects main branch'
    It 'detects master branch'
    It 'falls back to main if neither exists'
  End
End
```

### Project Tests (spec/proj_spec.sh)

```bash
Describe 'lib/proj.sh'
  Describe 'proj_add'
    It 'adds new project to registry'
    It 'validates project path exists'
    It 'detects project type'
    It 'prevents duplicate names'
  End

  Describe 'proj_list'
    It 'lists all projects'
    It 'handles empty registry'
    It 'supports JSON output'
  End

  Describe 'proj_switch'
    It 'switches to existing project'
    It 'handles non-existent project'
    It 'changes directory'
  End

  Describe 'proj_remove'
    It 'removes project from registry'
    It 'handles non-existent project'
  End
End
```

---

## 📝 Implementation Plan

### Phase 4A: Git Module (4-5 hours)

**Tasks:**

1. ✅ Create lib/git.sh skeleton with load guard
2. ✅ Implement `git_is_repo()` - Check if in git repository
3. ✅ Implement `git_default_branch()` - Detect main/master
4. ✅ Implement `git_commit_msg()` - AI commit message generation
5. ✅ Implement `git_status_enhanced()` - Enhanced status
6. ✅ Add comprehensive docstrings (Phase 1-2 standard)
7. ✅ Write 25 tests
8. ✅ Integrate with `harm-cli git` command

**AI Integration:**

- Use `ai_query()` from lib/ai.sh
- Build context from git diff
- Detect commit type (feat/fix/docs/refactor)
- Format as conventional commit

---

### Phase 4B: Project Module (3-4 hours)

**Tasks:**

1. ✅ Create lib/proj.sh skeleton with load guard
2. ✅ Implement `proj_add()` - Add project to registry
3. ✅ Implement `proj_list()` - List all projects
4. ✅ Implement `proj_switch()` - Switch to project (output cd command)
5. ✅ Implement `proj_remove()` - Remove from registry
6. ✅ Add comprehensive docstrings
7. ✅ Write 20 tests
8. ✅ Integrate with `harm-cli proj` command

**Data Format:**

- JSONL file: `${HARM_CLI_HOME}/projects.jsonl`
- Fields: name, path, type, added timestamp
- Atomic writes for safety

---

### Phase 4C: Testing & Quality (1 hour)

**Tasks:**

1. ✅ Run full test suite (208 + 45 = 253 tests)
2. ✅ Code quality review
3. ✅ Documentation review
4. ✅ Commit and push

---

## 🎨 CLI Interface Design

### Git Commands

```bash
harm-cli git commit-msg              # Generate commit message
harm-cli git status                  # Enhanced status
harm-cli git --help                  # Show help
```

### Project Commands

```bash
harm-cli proj list                   # List projects
harm-cli proj add <path> [name]      # Add project
harm-cli proj switch <name>          # Switch to project
harm-cli proj remove <name>          # Remove project
harm-cli proj --help                 # Show help
```

---

## 📊 Success Criteria

### Functional Requirements

- [x] User can generate AI commit messages
- [x] Commit messages follow conventional commit format
- [x] Enhanced git status provides actionable suggestions
- [x] Projects can be registered and listed
- [x] Project switching works
- [x] All features have comprehensive docstrings
- [x] JSON output format works

### Non-Functional Requirements

- [x] 45+ comprehensive tests
- [x] 100% shellcheck clean
- [x] SOLID principles maintained
- [x] Phase 1-2 documentation standards
- [x] Comprehensive logging at all levels

### Code Quality

- [x] < 700 LOC total (git + proj)
- [x] Average function length < 20 lines
- [x] All public functions documented
- [x] All error paths tested
- [x] Proper input validation

---

## 🔗 Integration Points

### AI Integration (lib/ai.sh)

- `git_commit_msg()` uses `ai_query()` for message generation
- Provides git diff as context
- Formats AI response as conventional commit

### Work Integration (lib/work.sh)

- Project switching could log work session change (future)
- Git commands could check if work session active (future)

### Logging Integration (lib/logging.sh)

- All git/proj operations logged
- DEBUG: Command execution details
- INFO: Successful operations
- ERROR: Git errors, invalid projects

---

## 📈 Estimated Impact

### Code Addition

- **lib/git.sh:** ~400 LOC
- **lib/proj.sh:** ~300 LOC
- **spec/git_spec.sh:** ~200 LOC (~25 tests)
- **spec/proj_spec.sh:** ~150 LOC (~20 tests)
- **Total:** ~1,050 LOC

### Time Estimate

- Git module: 4-5 hours
- Project module: 3-4 hours
- Testing & quality: 1 hour
- **Total: 8-10 hours**

### Value

- **High** - Core development workflow features
- **Git commit-msg:** Saves time, improves commit quality
- **Enhanced status:** Better workflow awareness
- **Project switching:** Faster context switching

---

## 💡 Design Decisions

### Decision 1: Minimal Git Features (MVP)

**Rationale:** Start with high-value features (commit-msg, status), defer complex ones (gnew, gsync) to Phase 4.5
**Benefit:** Faster delivery, focused testing

### Decision 2: JSONL for Projects

**Rationale:** Consistent with work.sh and goals.sh data format
**Benefit:** Simple, append-friendly, human-readable

### Decision 3: Project Switching via Output

**Rationale:** Shell can't change parent process directory
**Implementation:** Output `cd` command for user to eval
**Alternative:** Provide shell function in init script (future)

### Decision 4: No Git Porcelain Wrapping

**Rationale:** Don't reinvent git commands, enhance them
**Approach:** Add value on top of existing git commands

---

## 📚 References

### Internal

- `lib/ai.sh` - AI query integration
- `lib/work.sh` - Work session patterns
- `lib/goals.sh` - JSONL data patterns
- `lib/error.sh` - Error handling
- `lib/logging.sh` - Logging patterns

### External

- Conventional Commits: https://www.conventionalcommits.org/
- Git documentation: https://git-scm.com/docs

---

## ✅ Pre-Implementation Checklist

- [x] Phase 3 & 3.5 complete and pushed
- [x] All tests passing (208/208)
- [x] Branch created: `phase-4/git-and-projects`
- [x] Plan reviewed

---

**Ready to implement Phase 4! Let's build smart git and project management! 🚀**

**Estimated Time:** 8-10 hours
**Difficulty:** Medium-High (git integration, AI integration)
**Value:** Very High (core developer workflow)
