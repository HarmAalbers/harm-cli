# harm-cli Commands Reference

Complete reference of all available commands in the harm-cli project.

---

## 📦 Development Commands (just)

### Help & Information

Show all available just commands

```bash
just help
```

Show project information and statistics

```bash
just info
```

Check all development dependencies

```bash
just doctor
```

Show shell completions installation instructions

```bash
just completions
```

### Code Quality

Format all shell scripts with shfmt

```bash
just fmt
```

Lint all shell scripts with shellcheck

```bash
just lint
```

Run codespell on documentation

```bash
just spell
```

### Testing

Run all tests (bash + zsh)

```bash
just test
```

Run tests with bash 5+ only

```bash
just test-bash
```

Run tests with zsh only

```bash
just test-zsh
```

Run specific test file

```bash
just test-file FILE
```

Run tests in watch mode for TDD

```bash
just test-watch
```

Run tests with code coverage report

```bash
just coverage
```

### CI/CD Pipeline

Run full CI pipeline (format + lint + test)

```bash
just ci
```

Run pre-commit hooks on all files

```bash
just pre-commit
```

Run CI before pushing to remote

```bash
just pre-push
```

### Build & Release

Clean build artifacts and temporary files

```bash
just clean
```

Build release artifacts

```bash
just build
```

Create reproducible release tarball

```bash
just release
```

Sign release checksums with cosign/minisign

```bash
just sign
```

Generate SBOM (Software Bill of Materials)

```bash
just sbom
```

Scan for security vulnerabilities

```bash
just scan
```

### Documentation

Generate man page from help output

```bash
just man
```

### Development

Install development dependencies via Homebrew

```bash
just install
```

Create a new release git tag

```bash
just tag VERSION
```

---

## 🛠️ harm-cli Main Commands

### Core

Show version information

```bash
harm-cli version
```

Show version information in JSON format

```bash
harm-cli version --format json
```

Show help message

```bash
harm-cli help
```

Check system dependencies and health

```bash
harm-cli doctor
```

Initialize harm-cli in current shell

```bash
harm-cli init
```

---

## 📋 Work Session Management

Start a new work session with description

```bash
harm-cli work start "Phase 3 implementation"
```

Show current work session status

```bash
harm-cli work status
```

Stop current work session

```bash
harm-cli work stop
```

### Work Enforcement (Focus Mode)

Check current violation count

```bash
harm-cli work violations
```

Reset violation counter

```bash
harm-cli work reset-violations
```

Set enforcement mode

```bash
harm-cli work set-mode strict      # Strict enforcement
harm-cli work set-mode moderate    # Track but don't warn (default)
harm-cli work set-mode coaching    # Gentle reminders
harm-cli work set-mode off         # No enforcement
```

### Enforcement Modes Explained

**strict** - Maximum focus enforcement

- Locks you to single project
- Warns on every project switch
- Shows distraction count
- Forces goal review after 3 violations

**moderate** - Balanced tracking (default)

- Tracks violations silently
- No interruptions
- View with `harm-cli work violations`

**coaching** - Gentle guidance

- Periodic gentle reminders
- No strict enforcement
- Helpful suggestions only

**off** - No enforcement

- Basic work session tracking only
- No violation tracking

### Configuration

Set enforcement mode permanently

```bash
export HARM_WORK_ENFORCEMENT=strict
```

Set distraction threshold

```bash
export HARM_WORK_DISTRACTION_THRESHOLD=3  # Default
export HARM_WORK_DISTRACTION_THRESHOLD=5  # More lenient
```

---

## 🎯 Focus Monitoring & Pomodoro

Show focus summary and score

```bash
harm-cli focus check
harm-cli focus score
```

Start pomodoro timer

```bash
harm-cli focus pomodoro          # 25 minutes (default)
harm-cli focus pomodoro 50       # Custom duration
```

Pomodoro timer management

```bash
harm-cli focus pomodoro-status   # Check timer status
harm-cli focus pomodoro-stop     # Stop timer
```

### How Focus Monitoring Works

**Automatic Checks:**

- Runs every 15 minutes during work sessions
- Shows focus summary with recommendations
- Calculates focus score (1-10)
- Tracks context switches

**Focus Score Calculation:**

- Base score: 5
- Active work session: +2
- Zero violations: +2
- Recent activity: +1
- Violations penalty: -1 to -3

**Periodic Focus Check Includes:**

- Current goal
- Recent commands (last 10)
- Focus score
- Violation count
- Actionable recommendations

### Pomodoro Technique

Classic 25-minute focus sessions

```bash
harm-cli work start "Implement feature X"
harm-cli focus pomodoro 25
# ... work for 25 minutes ...
# 🔔 Notification: "Pomodoro Complete! Time for a 5-minute break"
```

Custom pomodoro durations

```bash
harm-cli focus pomodoro 50   # 50-minute deep work
harm-cli focus pomodoro 15   # Quick sprint
```

### Configuration

Set check interval (seconds)

```bash
export HARM_FOCUS_CHECK_INTERVAL=900   # 15 minutes (default)
export HARM_FOCUS_CHECK_INTERVAL=1800  # 30 minutes
```

Set pomodoro duration (minutes)

```bash
export HARM_POMODORO_DURATION=25  # Default
export HARM_POMODORO_DURATION=50  # Longer sessions
```

Set break duration (minutes)

```bash
export HARM_BREAK_DURATION=5   # Default
export HARM_BREAK_DURATION=10  # Longer breaks
```

Enable/disable focus monitoring

```bash
export HARM_FOCUS_ENABLED=1  # Enable (default)
export HARM_FOCUS_ENABLED=0  # Disable periodic checks
```

---

## 📊 Activity Tracking

Query activity log for today

```bash
harm-cli activity query today
```

Query activity for specific period

```bash
harm-cli activity query week        # Last 7 days
harm-cli activity query month       # Last 30 days
harm-cli activity query all         # All recorded activity
```

Show activity statistics

```bash
harm-cli activity stats today
harm-cli activity stats week
```

Clear all activity data

```bash
harm-cli activity clear
```

Clean up old entries (>90 days)

```bash
harm-cli activity cleanup
```

### Query Activity Data with jq

Extract commands only

```bash
harm-cli activity query today | jq -r '.command'
```

Find failed commands

```bash
harm-cli activity query week | jq 'select(.exit_code != 0)'
```

Find slow commands (>1 second)

```bash
harm-cli activity query today | jq 'select(.duration_ms > 1000)'
```

Get commands by project

```bash
harm-cli activity query week | jq 'select(.project == "myapp")'
```

### Configuration

Enable/disable activity tracking

```bash
export HARM_ACTIVITY_ENABLED=1     # Enable (default)
export HARM_ACTIVITY_ENABLED=0     # Disable
```

Set minimum duration threshold (ms)

```bash
export HARM_ACTIVITY_MIN_DURATION_MS=100  # Default
export HARM_ACTIVITY_MIN_DURATION_MS=500  # Only log slow commands
```

Exclude specific commands

```bash
export HARM_ACTIVITY_EXCLUDE="ls cd pwd clear"  # Default
```

Set retention period (days)

```bash
export HARM_ACTIVITY_RETENTION_DAYS=90  # Default
```

---

## 📈 Productivity Insights

Show comprehensive insights dashboard

```bash
harm-cli insights show week
harm-cli insights show today
harm-cli insights show month
```

Show specific category insights

```bash
harm-cli insights show week commands      # Command frequency
harm-cli insights show today performance  # Performance metrics
harm-cli insights show week errors        # Error analysis
harm-cli insights show month projects     # Project distribution
harm-cli insights show week hours         # Peak hours
```

Daily summary with recommendations

```bash
harm-cli insights daily
harm-cli insights daily yesterday
```

Export HTML report

```bash
harm-cli insights export report.html
```

Export JSON data

```bash
harm-cli insights json week
harm-cli insights json month
```

### Insights Categories

**commands** - Command frequency analysis

- Most used commands
- Command patterns
- Usage trends

**performance** - Performance metrics

- Average command duration
- Slowest commands
- Performance patterns

**errors** - Error analysis

- Error rate calculation
- Failed commands list
- Failure patterns

**projects** - Project activity

- Time per project
- Project switches
- Focus distribution

**hours** - Peak productivity

- Most active hours
- Activity heatmap
- Time patterns

### Example Workflows

Morning routine

```bash
harm-cli insights daily
harm-cli insights show week commands
```

Weekly review

```bash
harm-cli insights show week
harm-cli insights export weekly-report.html
```

Analyze performance issues

```bash
harm-cli insights show today performance
harm-cli insights show week errors
```

### Integration with jq

Get productivity score programmatically

```bash
harm-cli insights json week | jq -r '.error_rate'
```

Find top command

```bash
harm-cli insights json today | jq -r '.top_commands[0].command'
```

Get all projects

```bash
harm-cli insights json month | jq -r '.projects[].project'
```

---

## 🎯 Goal Tracking

Set a new goal with estimated time

```bash
harm-cli goal set "Complete AI integration" 4h
```

Show all active goals

```bash
harm-cli goal show
```

Update goal progress percentage

```bash
harm-cli goal progress 1 50
```

Mark a goal as complete

```bash
harm-cli goal complete 1
```

Clear all completed goals

```bash
harm-cli goal clear
```

### AI Goal Validation (Automatic)

**How It Works:**

AI automatically validates significant commands against your active goal:

1. You set a goal: `harm-cli goal set "Implement user authentication" 4h`
2. You run a command: `git commit -m "add login form"`
3. AI checks alignment (background, non-blocking)
4. If misaligned, you get a notification:

```
🤔 Goal Alignment Check:
   Goal: Implement user authentication
   Command: npm install lodash

   AI: NO - Installing lodash doesn't directly relate to
       implementing authentication. Consider if this is necessary.
```

**Validated Commands:**

- git, npm, docker, python (all development tools)
- vim, code, emacs (file editing)
- make, cargo, go, mvn (build tools)
- kubectl, helm (deployment)

**Ignored Commands:**

- ls, cd, pwd, cat (navigation)
- grep, find (searching)
- history, man, help (reference)

**Configuration:**

Enable/disable AI validation

```bash
export HARM_GOAL_VALIDATION_ENABLED=1  # Enable (default)
export HARM_GOAL_VALIDATION_ENABLED=0  # Disable
```

Set validation frequency (seconds)

```bash
export HARM_GOAL_VALIDATION_FREQUENCY=60   # Every minute (default)
export HARM_GOAL_VALIDATION_FREQUENCY=300  # Every 5 minutes (less intrusive)
```

**How It Helps:**

- Keeps you aligned with goals
- Detects scope creep early
- Prevents rabbit holes
- Maintains focus
- Non-blocking (doesn't slow you down)

---

## 🤖 AI Assistant (Gemini)

Ask AI a general question

```bash
harm-cli ai "How do I list files recursively?"
```

Ask AI with full context included

```bash
harm-cli ai --context "How does this work?"
```

Ask AI without using cache

```bash
harm-cli ai --no-cache "What's the latest?"
```

Review staged git changes with AI

```bash
harm-cli ai review
```

Review unstaged git changes with AI

```bash
harm-cli ai review --unstaged
```

Explain last error from logs with AI

```bash
harm-cli ai explain-error
```

Get daily productivity insights

```bash
harm-cli ai daily
```

Get yesterday's productivity insights

```bash
harm-cli ai daily --yesterday
```

Get weekly productivity insights

```bash
harm-cli ai daily --week
```

Configure Gemini API key

```bash
harm-cli ai --setup
```

---

## 🔧 Git Workflows

Enhanced git status with AI suggestions

```bash
harm-cli git status
```

Generate AI commit message from staged changes

```bash
harm-cli git commit-msg
```

Generate commit message and commit in one step

```bash
msg=$(harm-cli git commit-msg) && git commit -m "$msg"
```

---

## 📁 Project Management

List all registered projects

```bash
harm-cli proj list
```

Add current directory to project registry

```bash
harm-cli proj add .
```

Add specific path to project registry

```bash
harm-cli proj add ~/myapp
```

Add project with custom name

```bash
harm-cli proj add ~/myapp myapp
```

Remove project from registry

```bash
harm-cli proj remove myapp
```

Switch to a registered project (output cd command)

```bash
harm-cli proj switch myapp
```

Switch to project and change directory

```bash
eval "$(harm-cli proj switch myapp)"
```

---

## 🐳 Docker Management

Show Docker service status (default)

```bash
harm-cli docker status
```

Start all Docker services in detached mode

```bash
harm-cli docker up
```

Start specific Docker services

```bash
harm-cli docker up backend database
```

Stop and remove all Docker services

```bash
harm-cli docker down
```

View logs for specific service (follows)

```bash
harm-cli docker logs backend
```

Open shell in Docker container

```bash
harm-cli docker shell backend
```

Check Docker environment health

```bash
harm-cli docker health
```

---

## 🐍 Python Development

Show Python environment status

```bash
harm-cli python status
```

Run Python test suite (pytest/unittest)

```bash
harm-cli python test
```

Run Python tests with verbose output

```bash
harm-cli python test -v
```

Run Python linters (ruff/flake8)

```bash
harm-cli python lint
```

Format Python code (ruff/black)

```bash
harm-cli python format
```

---

## ☁️ Google Cloud SDK

Show Google Cloud SDK status and configuration

```bash
harm-cli gcloud status
```

---

## 🏥 Health Checks

Run comprehensive system health check

```bash
harm-cli health
```

---

## 🛡️ Safe Operations

Safe file deletion with confirmation

```bash
harm-cli safe rm <files>
```

Safe Docker cleanup with confirmation

```bash
harm-cli safe docker-prune
```

Safe git reset with automatic backup

```bash
harm-cli safe git-reset
```

Safe git reset to specific ref with backup

```bash
harm-cli safe git-reset [ref]
```

---

## 🔤 Shell Completions

Source Bash completions in current shell

```bash
source completions/harm-cli.bash
```

Load Zsh completions (add to .zshrc)

```bash
fpath+=("$PWD/completions") && autoload -U compinit && compinit
```

---

## 🌍 Environment Variables

Override default config directory

```bash
export HARM_CLI_HOME="~/.custom-harm-cli"
```

Set default log level

```bash
export HARM_CLI_LOG_LEVEL="DEBUG"
```

Set default output format

```bash
export HARM_CLI_FORMAT="json"
```

Set Gemini API key for AI features

```bash
export GEMINI_API_KEY="your-api-key-here"
```

---

## 📝 Common Workflows

### Daily Development Flow

Start work session and run tests

```bash
harm-cli work start "Feature development" && just test
```

Run full CI pipeline before committing

```bash
just ci
```

Stage changes and generate AI commit message

```bash
git add . && harm-cli git commit-msg
```

### Project Setup

Add project and switch to it

```bash
harm-cli proj add ~/myapp "My App" && eval "$(harm-cli proj switch myapp)"
```

Check project health status

```bash
harm-cli doctor && harm-cli python status && harm-cli docker status
```

### AI-Assisted Development

Ask AI for help and review changes

```bash
harm-cli ai "How do I implement feature X?" && harm-cli ai review
```

Get daily insights after work session

```bash
harm-cli work stop && harm-cli ai daily
```

---

## 📚 Interactive Learning & Discovery

### Learn Command - AI-Powered Tutorials

Get comprehensive tutorial on any topic

```bash
harm-cli learn git          # Git workflows
harm-cli learn docker       # Docker & containers
harm-cli learn python       # Python development
harm-cli learn bash         # Shell scripting
harm-cli learn productivity # Time management
harm-cli learn harm-cli     # Advanced harm-cli usage
```

List all available topics

```bash
harm-cli learn --list
```

### Discover - Feature Suggestions

Get personalized feature recommendations

```bash
harm-cli discover
```

**How it works:**
- Analyzes your command patterns from activity tracking
- AI suggests harm-cli features that match your workflow
- Shows specific examples for your use cases

Example output:
```
🔍 Discovering harm-cli Features...

Based on your git usage, here are features to try:

1. **AI Commit Messages** - Generate conventional commits
   Try: harm-cli git commit-msg

2. **Insights** - See your git patterns
   Try: harm-cli insights show week

3. **Work Enforcement** - Stay focused on one branch
   Try: harm-cli work set-mode strict
```

### Unused - Find What You're Missing

Discover commands you haven't tried

```bash
harm-cli unused
```

Shows:
- All harm-cli commands you've never used
- Suggestions to explore new features
- Helps maximize your productivity

### Cheat - Quick Reference

Get instant command examples

```bash
harm-cli cheat curl        # curl examples
harm-cli cheat git         # git examples
harm-cli cheat docker      # docker examples
harm-cli cheat tar         # tar examples
```

**Powered by:** https://cheat.sh

---

## 🪝 Shell Hooks (Advanced)

harm-cli includes a powerful shell hooks system for automation and advanced features.

### Hook Types

**chpwd** - Triggered on directory changes

```bash
my_chpwd_hook() {
  echo "Changed to: $PWD"
}
harm_add_hook chpwd my_chpwd_hook
```

**preexec** - Triggered before command execution

```bash
my_preexec_hook() {
  local cmd="$1"
  echo "About to run: $cmd"
}
harm_add_hook preexec my_preexec_hook
```

**precmd** - Triggered before prompt display

```bash
my_precmd_hook() {
  local exit_code="$1"
  local last_cmd="$2"
  echo "Last command exited with: $exit_code"
}
harm_add_hook precmd my_precmd_hook
```

### Hook Management

Register a hook

```bash
harm_add_hook <type> <function_name>
```

Remove a hook

```bash
harm_remove_hook <type> <function_name>
```

List all registered hooks

```bash
harm_list_hooks           # All hooks
harm_list_hooks chpwd     # Only chpwd hooks
```

### Configuration

Enable/disable hooks

```bash
export HARM_HOOKS_ENABLED=1    # Enable (default)
export HARM_HOOKS_ENABLED=0    # Disable
```

Enable debug logging

```bash
export HARM_HOOKS_DEBUG=1
```

### Notes

- Hooks are loaded automatically via `harm-cli init`
- Only work in interactive shells
- Recursion protection built-in
- Hook failures don't break shell

---

## 🔗 Quick Reference

| Category        | Command                       | Description             |
| --------------- | ----------------------------- | ----------------------- |
| **Development** | `just ci`                     | Run full CI pipeline    |
| **Testing**     | `just test`                   | Run all tests           |
| **Work**        | `harm-cli work start "task"`  | Start work session      |
| **Goals**       | `harm-cli goal set "goal" 4h` | Set new goal            |
| **Activity**    | `harm-cli activity stats`     | View activity stats     |
| **Insights**    | `harm-cli insights show week` | Productivity insights   |
| **Focus**       | `harm-cli focus check`        | Focus monitoring        |
| **AI**          | `harm-cli ai "question"`      | Ask AI assistant        |
| **Learn**       | `harm-cli learn git`          | Interactive tutorials   |
| **Discover**    | `harm-cli discover`           | Feature suggestions     |
| **Git**         | `harm-cli git commit-msg`     | Generate commit message |
| **Projects**    | `harm-cli proj list`          | List all projects       |
| **Docker**      | `harm-cli docker up`          | Start services          |
| **Python**      | `harm-cli python test`        | Run tests               |
| **Health**      | `harm-cli health`             | Check system health     |

---

**For more details on any command, use `--help` flag:**

```bash
harm-cli --help
harm-cli ai --help
harm-cli git --help
```
