# QA Checklist - harm-cli Manual Testing

**Version:** 1.0
**Last Updated:** 2025-10-23
**Purpose:** Manual QA checklist for all harm-cli commands
**Related:** Phase 3.3 - QA Suite

## Testing Instructions

### Pre-Test Setup

- [ ] Fresh shell session with harm-cli initialized
- [ ] Test environment variables cleared
- [ ] Clean ~/.harm-cli/ state (or use test config directory)
- [ ] All dependencies installed (`harm-cli doctor` passing)

### Test Categories

1. **Core Commands** - Basic CLI functionality
2. **Work Session Management** - work start/stop/status
3. **Goal Tracking** - goal set/show/progress/complete
4. **AI Assistant** - ai query/review/daily/explain-error
5. **Git Workflows** - git status/commit-msg
6. **Project Management** - proj add/list/switch/remove
7. **Docker Management** - docker up/down/logs/shell/health
8. **Python Development** - python status/test/lint/format
9. **Google Cloud** - gcloud status
10. **Health Checks** - health checks
11. **Safety Wrappers** - safe rm/docker-prune/git-reset
12. **Markdown Rendering** - md render/view
13. **Log Streaming** - log view/tail
14. **Development Tools** - just commands

---

## 1. Core Commands (12 tests)

### 1.1 Version Command

- [ ] `harm-cli version` - Shows version in text format
  - **Expected:** Version number, commit hash, build info
  - **Edge cases:** None
- [ ] `harm-cli version --format json` - Shows version in JSON
  - **Expected:** Valid JSON with version fields
  - **Edge cases:** None
- [ ] `harm-cli -v` - Short flag works
  - **Expected:** Same as `harm-cli version`
  - **Edge cases:** None

### 1.2 Help Command

- [ ] `harm-cli help` - Shows general help
  - **Expected:** Command list, usage examples
  - **Edge cases:** None
- [ ] `harm-cli --help` - Flag version works
  - **Expected:** Same as `harm-cli help`
  - **Edge cases:** None
- [ ] `harm-cli -h` - Short flag works
  - **Expected:** Same as `harm-cli help`
  - **Edge cases:** None

### 1.3 Doctor Command

- [ ] `harm-cli doctor` - Checks system health
  - **Expected:** Dependency check results
  - **Edge cases:** Missing dependencies show warnings
- [ ] `harm-cli doctor --format json` - JSON output
  - **Expected:** Valid JSON with health status
  - **Edge cases:** None

### 1.4 Init Command

- [ ] `harm-cli init` - Initialize in current shell
  - **Expected:** Source command for shell integration
  - **Edge cases:** Different shells (bash/zsh)

### 1.5 Global Options

- [ ] `harm-cli -q version` - Quiet mode suppresses output
  - **Expected:** No non-error output
  - **Edge cases:** Errors still shown
- [ ] `harm-cli -d doctor` - Debug mode shows extra logging
  - **Expected:** Debug log entries visible
  - **Edge cases:** None
- [ ] `HARM_CLI_FORMAT=json harm-cli version` - Env var format
  - **Expected:** JSON output
  - **Edge cases:** None

---

## 2. Work Session Management (6 tests)

### 2.1 Start Work Session

- [ ] `harm-cli work start "Phase 3 testing"` - Start new session
  - **Expected:** Session started, confirmation message
  - **Edge cases:**
    - Starting while session already active (error)
    - Empty description (error)
    - Very long description (>200 chars)

### 2.2 Show Work Status

- [ ] `harm-cli work status` - Show current session
  - **Expected:** Active session details or "No active session"
  - **Edge cases:** No session active
- [ ] `harm-cli work` - Default command is status
  - **Expected:** Same as `work status`
  - **Edge cases:** None

### 2.3 Stop Work Session

- [ ] `harm-cli work stop` - Stop current session
  - **Expected:** Session stopped, duration shown
  - **Edge cases:**
    - No active session (error)
    - Session duration >24 hours

### 2.4 JSON Output

- [ ] `harm-cli work status --format json` - JSON format
  - **Expected:** Valid JSON with session data
  - **Edge cases:** None

---

## 3. Goal Tracking (10 tests)

### 3.1 Set Goals

- [ ] `harm-cli goal set "Complete Phase 3" 4h` - Set with time
  - **Expected:** Goal created, confirmation shown
  - **Edge cases:**
    - No time estimate
    - Invalid time format ("xyz")
    - Negative time ("-1h")
    - Very long goal text (>500 chars)

- [ ] `harm-cli goal set "Quick task" 30m` - Minutes format
  - **Expected:** Goal created with 30 minutes
  - **Edge cases:** None

- [ ] `harm-cli goal set "Complex task" 2h30m` - Combined format
  - **Expected:** Goal created with 2.5 hours (150 minutes)
  - **Edge cases:** None

- [ ] `harm-cli goal set "Test task" 90` - Plain integer (minutes)
  - **Expected:** Goal created with 90 minutes
  - **Edge cases:** None

### 3.2 Show Goals

- [ ] `harm-cli goal show` - List all goals
  - **Expected:** Numbered list with progress percentages
  - **Edge cases:** No goals (friendly message)

- [ ] `harm-cli goal` - Default command is show
  - **Expected:** Same as `goal show`
  - **Edge cases:** None

- [ ] `harm-cli goal show --format json` - JSON output
  - **Expected:** Valid JSON array of goals
  - **Edge cases:** Empty array if no goals

### 3.3 Update Progress

- [ ] `harm-cli goal progress 1 50` - Set to 50%
  - **Expected:** Goal #1 updated to 50%
  - **Edge cases:**
    - Invalid goal number (0, 999)
    - Invalid progress (-1, 101)
    - Non-existent goal ID

### 3.4 Complete Goals

- [ ] `harm-cli goal complete 1` - Mark goal complete
  - **Expected:** Goal #1 at 100%, marked completed
  - **Edge cases:** Already completed goal

### 3.5 Clear Goals

- [ ] `harm-cli goal clear --force` - Clear all goals
  - **Expected:** All goals deleted
  - **Edge cases:**
    - Without --force flag (error)
    - No goals exist (safe)

---

## 4. AI Assistant (11 tests)

### 4.1 Basic Queries

- [ ] `harm-cli ai "What is the capital of France?"` - Simple query
  - **Expected:** AI response
  - **Edge cases:**
    - Empty query
    - Very long query (>10k chars)
    - Special characters in query

- [ ] `harm-cli ai "How do I use grep?"` - Technical query
  - **Expected:** Helpful AI response
  - **Edge cases:** None

### 4.2 Context-Aware Queries

- [ ] `harm-cli ai --context "Explain this codebase"` - With context
  - **Expected:** AI response with project context included
  - **Edge cases:** No project context available

### 4.3 Cache Control

- [ ] `harm-cli ai --no-cache "Current time?"` - Bypass cache
  - **Expected:** Fresh AI response
  - **Edge cases:** None

### 4.4 Code Review

- [ ] `harm-cli ai review` - Review staged changes
  - **Expected:** AI review of git staged files
  - **Edge cases:**
    - No staged changes
    - Very large diffs (>100 files)
    - Binary files staged

- [ ] `harm-cli ai review --unstaged` - Review unstaged
  - **Expected:** AI review of working directory changes
  - **Edge cases:** No unstaged changes

### 4.5 Error Explanation

- [ ] `harm-cli ai explain-error` - Explain last error
  - **Expected:** AI explanation of most recent log error
  - **Edge cases:**
    - No errors in logs
    - Multiple errors

### 4.6 Daily Insights

- [ ] `harm-cli ai daily` - Today's insights
  - **Expected:** Productivity summary for today
  - **Edge cases:** No activity today

- [ ] `harm-cli ai daily --yesterday` - Yesterday's insights
  - **Expected:** Productivity summary for yesterday
  - **Edge cases:** No activity yesterday

- [ ] `harm-cli ai daily --week` - Weekly insights
  - **Expected:** Week summary
  - **Edge cases:** First day of week

### 4.7 Setup

- [ ] `harm-cli ai --setup` - Configure API key
  - **Expected:** Interactive API key setup
  - **Edge cases:**
    - Already configured
    - Invalid API key

---

## 5. Git Workflows (3 tests)

### 5.1 Enhanced Status

- [ ] `harm-cli git status` - Git status with AI
  - **Expected:** Git status with AI suggestions
  - **Edge cases:**
    - Not a git repo (error)
    - Clean working directory
    - Merge conflicts

### 5.2 Commit Message Generation

- [ ] `harm-cli git commit-msg` - Generate message
  - **Expected:** AI-generated commit message
  - **Edge cases:**
    - No staged changes (error)
    - Very large diff

- [ ] Integration: `msg=$(harm-cli git commit-msg) && git commit -m "$msg"` - Full workflow
  - **Expected:** Commits with AI message
  - **Edge cases:** None

---

## 6. Project Management (8 tests)

### 6.1 List Projects

- [ ] `harm-cli proj list` - Show all projects
  - **Expected:** List of registered projects
  - **Edge cases:** No projects registered

- [ ] `harm-cli proj list --format json` - JSON output
  - **Expected:** Valid JSON array
  - **Edge cases:** None

### 6.2 Add Projects

- [ ] `harm-cli proj add .` - Add current directory
  - **Expected:** Current dir added to registry
  - **Edge cases:**
    - Not a directory
    - Already added

- [ ] `harm-cli proj add ~/myapp` - Add specific path
  - **Expected:** Path added to registry
  - **Edge cases:**
    - Path doesn't exist (error)
    - Relative paths

- [ ] `harm-cli proj add ~/myapp "My App"` - Add with name
  - **Expected:** Project added with custom name
  - **Edge cases:** Duplicate names

### 6.3 Remove Projects

- [ ] `harm-cli proj remove myapp` - Remove project
  - **Expected:** Project removed from registry
  - **Edge cases:**
    - Non-existent project (error)
    - Remove all projects

### 6.4 Switch Projects

- [ ] `harm-cli proj switch myapp` - Switch to project
  - **Expected:** CD command output
  - **Edge cases:** Non-existent project

- [ ] `eval "$(harm-cli proj switch myapp)"` - Actually switch
  - **Expected:** Directory changed
  - **Edge cases:** None

---

## 7. Docker Management (8 tests)

### 7.1 Service Status

- [ ] `harm-cli docker status` - Show status
  - **Expected:** Running containers, service health
  - **Edge cases:**
    - Docker not running
    - No docker-compose.yml in project
    - No containers

- [ ] `harm-cli docker` - Default is status
  - **Expected:** Same as `docker status`
  - **Edge cases:** None

### 7.2 Start Services

- [ ] `harm-cli docker up` - Start all services
  - **Expected:** Containers started in detached mode
  - **Edge cases:**
    - No docker-compose.yml
    - Containers already running
    - Port conflicts

- [ ] `harm-cli docker up backend database` - Start specific
  - **Expected:** Only specified services started
  - **Edge cases:** Invalid service names

### 7.3 Stop Services

- [ ] `harm-cli docker down` - Stop all services
  - **Expected:** Containers stopped and removed
  - **Edge cases:** No containers running

### 7.4 View Logs

- [ ] `harm-cli docker logs backend` - Follow service logs
  - **Expected:** Streaming logs for backend service
  - **Edge cases:**
    - Service doesn't exist
    - No logs available

### 7.5 Shell Access

- [ ] `harm-cli docker shell backend` - Open shell
  - **Expected:** Interactive shell in container
  - **Edge cases:**
    - Container not running
    - No shell available (e.g., scratch images)

### 7.6 Health Check

- [ ] `harm-cli docker health` - Docker environment health
  - **Expected:** Docker daemon status, resource usage
  - **Edge cases:** Docker not installed

---

## 8. Python Development (6 tests)

### 8.1 Environment Status

- [ ] `harm-cli python status` - Show Python env
  - **Expected:** Python version, venv status, packages
  - **Edge cases:**
    - No Python installed
    - No virtual environment
    - Not a Python project

### 8.2 Run Tests

- [ ] `harm-cli python test` - Run test suite
  - **Expected:** Pytest/unittest runs
  - **Edge cases:**
    - No tests found
    - Test failures
    - No test framework installed

- [ ] `harm-cli python test -v` - Verbose output
  - **Expected:** Detailed test output
  - **Edge cases:** None

### 8.3 Linting

- [ ] `harm-cli python lint` - Run linters
  - **Expected:** Ruff/flake8 output
  - **Edge cases:**
    - No linter installed
    - Lint errors found

### 8.4 Formatting

- [ ] `harm-cli python format` - Format code
  - **Expected:** Code formatted with ruff/black
  - **Edge cases:**
    - No formatter installed
    - Files modified

- [ ] `harm-cli python format --check` - Check only
  - **Expected:** Report formatting issues without changes
  - **Edge cases:** None

---

## 9. Google Cloud SDK (2 tests)

### 9.1 GCloud Status

- [ ] `harm-cli gcloud status` - Show gcloud config
  - **Expected:** Active project, account, config
  - **Edge cases:**
    - gcloud not installed
    - Not authenticated

- [ ] `harm-cli gcloud status --format json` - JSON output
  - **Expected:** Valid JSON with gcloud info
  - **Edge cases:** None

---

## 10. Health Checks (3 tests)

### 10.1 System Health

- [ ] `harm-cli health` - Run comprehensive health check
  - **Expected:** System dependencies, project health, warnings
  - **Edge cases:**
    - Multiple health issues
    - All checks pass

- [ ] `harm-cli health --format json` - JSON health report
  - **Expected:** Structured health data
  - **Edge cases:** None

- [ ] `harm-cli health --verbose` - Detailed health info
  - **Expected:** Extra diagnostic information
  - **Edge cases:** None

---

## 11. Safety Wrappers (6 tests)

### 11.1 Safe File Deletion

- [ ] `harm-cli safe rm testfile.txt` - Delete with confirmation
  - **Expected:** Interactive confirmation, file deleted
  - **Edge cases:**
    - File doesn't exist
    - No permission
    - Multiple files

### 11.2 Safe Docker Cleanup

- [ ] `harm-cli safe docker-prune` - Clean Docker with confirmation
  - **Expected:** Interactive confirmation, cleanup summary
  - **Edge cases:**
    - No containers to prune
    - Docker not running

### 11.3 Safe Git Reset

- [ ] `harm-cli safe git-reset` - Reset with backup
  - **Expected:** Automatic backup created, reset performed
  - **Edge cases:**
    - Not a git repo
    - Clean working directory

- [ ] `harm-cli safe git-reset HEAD~1` - Reset to specific ref
  - **Expected:** Backup created, reset to ref
  - **Edge cases:** Invalid ref

- [ ] `harm-cli safe git-reset --hard` - Hard reset with backup
  - **Expected:** Backup created, hard reset performed
  - **Edge cases:** Uncommitted changes backed up

- [ ] Verify backup restore works
  - **Expected:** Can restore from backup after reset
  - **Edge cases:** None

---

## 12. Markdown Rendering (4 tests)

### 12.1 Render Markdown

- [ ] `harm-cli md README.md` - Render file
  - **Expected:** Pretty-printed markdown (via glow/bat)
  - **Edge cases:**
    - File doesn't exist
    - Not a markdown file
    - Very large file (>10MB)

- [ ] `harm-cli md view README.md` - Explicit view command
  - **Expected:** Same as `harm-cli md README.md`
  - **Edge cases:** None

### 12.2 Piped Input

- [ ] `echo "# Test" | harm-cli md` - Render from stdin
  - **Expected:** Rendered markdown from pipe
  - **Edge cases:** Empty input

- [ ] `cat README.md | harm-cli md` - Pipe file contents
  - **Expected:** Rendered markdown
  - **Edge cases:** None

---

## 13. Log Streaming (3 tests)

### 13.1 View Logs

- [ ] `harm-cli log view` - Show recent logs
  - **Expected:** Recent log entries displayed
  - **Edge cases:**
    - No logs exist
    - Very large log files

### 13.2 Tail Logs

- [ ] `harm-cli log tail` - Follow logs in real-time
  - **Expected:** Streaming log output
  - **Edge cases:**
    - No new log entries
    - Stop with Ctrl+C

### 13.3 Filter Logs

- [ ] `harm-cli log view --level ERROR` - Filter by level
  - **Expected:** Only ERROR logs shown
  - **Edge cases:** No errors in logs

---

## 14. Development Tools (just commands) (15 tests)

### 14.1 Help & Info

- [ ] `just help` - Show all commands
  - **Expected:** List of all just recipes
  - **Edge cases:** None

- [ ] `just info` - Project information
  - **Expected:** Stats, dependencies, project info
  - **Edge cases:** None

### 14.2 Code Quality

- [ ] `just fmt` - Format all shell scripts
  - **Expected:** Scripts formatted with shfmt
  - **Edge cases:** Formatting changes files

- [ ] `just lint` - Lint with shellcheck
  - **Expected:** Shellcheck errors/warnings
  - **Edge cases:** Lint failures found

- [ ] `just spell` - Check spelling
  - **Expected:** Codespell output
  - **Edge cases:** Spelling errors found

### 14.3 Testing

- [ ] `just test` - Run all tests (bash + zsh)
  - **Expected:** Full test suite passes
  - **Edge cases:** Test failures

- [ ] `just test-bash` - Bash-only tests
  - **Expected:** Tests run with bash 5+
  - **Edge cases:** Bash not available

- [ ] `just test-zsh` - Zsh-only tests
  - **Expected:** Tests run with zsh
  - **Edge cases:** Zsh not available

- [ ] `just test-file spec/goals_spec.sh` - Run specific test
  - **Expected:** Single test file runs
  - **Edge cases:** File doesn't exist

- [ ] `just test-watch` - TDD watch mode
  - **Expected:** Tests run continuously on file changes
  - **Edge cases:** Stop with Ctrl+C

- [ ] `just coverage` - Coverage report
  - **Expected:** Test coverage statistics
  - **Edge cases:** Low coverage warnings

### 14.4 CI/CD

- [ ] `just ci` - Full CI pipeline
  - **Expected:** format + lint + test all pass
  - **Edge cases:** Any step fails

- [ ] `just pre-commit` - Run pre-commit hooks
  - **Expected:** All hooks pass
  - **Edge cases:** Hook failures

- [ ] `just pre-push` - CI before push
  - **Expected:** Full validation before push
  - **Edge cases:** Validation failures

### 14.5 Build & Release

- [ ] `just clean` - Clean artifacts
  - **Expected:** Build artifacts removed
  - **Edge cases:** None

---

## Summary Statistics

**Total Commands Documented:** 108
**Total Test Cases:** 108
**Estimated Testing Time:** 6-8 hours

### Coverage by Category

- Core Commands: 12 tests
- Work Sessions: 6 tests
- Goal Tracking: 10 tests
- AI Assistant: 11 tests
- Git Workflows: 3 tests
- Project Management: 8 tests
- Docker Management: 8 tests
- Python Development: 6 tests
- Google Cloud: 2 tests
- Health Checks: 3 tests
- Safety Wrappers: 6 tests
- Markdown Rendering: 4 tests
- Log Streaming: 3 tests
- Development Tools: 15 tests
- **Other:** Shell hooks (11 tests), Environment variables (4 tests)

### Testing Priorities

**P0 - Critical (must test):**

- Core commands (version, help, doctor)
- Work session management
- Goal tracking
- AI basic queries
- Git workflows

**P1 - Important (should test):**

- Project management
- Docker management
- Python development
- Safety wrappers

**P2 - Nice to have:**

- Markdown rendering
- Log streaming
- Advanced AI features

### Known Edge Cases

**Cross-cutting concerns:**

1. **JSON output** - All commands should support `--format json`
2. **Error handling** - Invalid inputs should show helpful errors
3. **Empty states** - Commands should handle "nothing to show" gracefully
4. **Permission errors** - File/directory access failures
5. **Missing dependencies** - Commands should fail gracefully
6. **Concurrent operations** - Multiple CLI instances running
7. **Large inputs** - Very long strings, large files
8. **Special characters** - Unicode, quotes, newlines in args
9. **Environment pollution** - Conflicting env vars
10. **Interrupted operations** - Ctrl+C handling

---

## Test Execution Log

**Tester:** **\*\***\_**\*\***
**Date:** **\*\***\_**\*\***
**Version:** **\*\***\_**\*\***
**Environment:** **\*\***\_**\*\***

### Results

- [ ] All critical (P0) tests passed
- [ ] All important (P1) tests passed
- [ ] All nice-to-have (P2) tests passed
- [ ] Edge cases documented and verified
- [ ] Bugs filed for any failures

### Issues Found

_Document any issues discovered during testing..._
