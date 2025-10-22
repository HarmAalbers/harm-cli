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
| **AI**          | `harm-cli ai "question"`      | Ask AI assistant        |
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
