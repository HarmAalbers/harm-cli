# harm-cli Command Reference

Complete documentation for all harm-cli commands.

---

## Table of Contents

- [Core Commands](#core-commands)
- [Work & Goal Management](#work--goal-management)
- [AI Assistant](#ai-assistant)
- [Git Workflows](#git-workflows)
- [Project Management](#project-management)
- [Docker Management](#docker-management)
- [Python Development](#python-development)
- [Google Cloud](#google-cloud)
- [Health & Safety](#health--safety)

---

## Core Commands

### `harm-cli version`

Display version information.

**Usage:**

```bash
harm-cli version       # Text output
harm-cli version json  # JSON output
```

**Output:**

```
harm-cli version 1.0.0
```

### `harm-cli help`

Show help information for harm-cli.

**Usage:**

```bash
harm-cli help
harm-cli <command> --help
```

### `harm-cli doctor`

Check system health and dependencies.

**Usage:**

```bash
harm-cli doctor
```

**Checks:**

- Bash version (5.0+ required)
- Required tools (git, jq)
- Optional tools (docker, python, gcloud)
- Configuration files
- Module health

---

## Work & Goal Management

### `harm-cli work start`

Start a new work session.

**Usage:**

```bash
harm-cli work start "Task description"
```

**Example:**

```bash
harm-cli work start "Implementing AI integration"
```

**Output:**

- Session ID
- Start time
- Description

**State:** Saves to `~/.harm-cli/state/work_session.json`

### `harm-cli work stop`

Stop the current work session.

**Usage:**

```bash
harm-cli work stop
```

**Output:**

- Session duration
- Archived session summary

**State:** Archives to `~/.harm-cli/state/work_history.jsonl`

### `harm-cli work status`

Show current work session status.

**Usage:**

```bash
harm-cli work status       # Text output
harm-cli work status json  # JSON output
```

**Output:**

- Session ID
- Description
- Duration
- Start time

### `harm-cli goal set`

Set a new daily goal.

**Usage:**

```bash
harm-cli goal set "Goal description" <estimated_time>
```

**Example:**

```bash
harm-cli goal set "Complete test coverage" 4h
harm-cli goal set "Fix bug #42" 2h30m
```

**Time formats:** `1h`, `30m`, `2h30m`, `1.5h`

### `harm-cli goal show`

Show all goals for today.

**Usage:**

```bash
harm-cli goal show       # Text output
harm-cli goal show json  # JSON output
```

**Output:**

- Goal ID
- Description
- Progress (%)
- Estimated time
- Status

### `harm-cli goal progress`

Update goal progress.

**Usage:**

```bash
harm-cli goal progress <goal_id> <percentage>
```

**Example:**

```bash
harm-cli goal progress 1 50   # 50% complete
harm-cli goal progress 2 100  # Done
```

### `harm-cli goal complete`

Mark a goal as complete.

**Usage:**

```bash
harm-cli goal complete <goal_id>
```

**Example:**

```bash
harm-cli goal complete 1
```

### `harm-cli goal clear`

Clear all goals for today.

**Usage:**

```bash
harm-cli goal clear
```

---

## AI Assistant

### `harm-cli ai`

Ask the AI assistant a question.

**Usage:**

```bash
harm-cli ai "<question>"
harm-cli ai --context "<question>"  # Include project context
harm-cli ai --no-cache "<question>" # Skip cache
```

**Examples:**

```bash
harm-cli ai "How do I list files recursively in bash?"
harm-cli ai --context "Explain this error"
```

**Context includes:**

- Current directory
- Git repository info
- Project type detection
- Recent files

**Requirements:** Gemini API key (see `harm-cli ai --setup`)

### `harm-cli ai --setup`

Configure Gemini API key.

**Usage:**

```bash
harm-cli ai --setup
```

**Storage priority:**

1. Environment: `$GEMINI_API_KEY`
2. Keychain (macOS): `security add-generic-password`
3. Secret Tool (Linux): `secret-tool store`
4. Pass (Unix): `pass insert`
5. Config file: `~/.harm-cli/config.json`

### `harm-cli ai review`

AI-powered code review of git changes.

**Usage:**

```bash
harm-cli ai review
```

**Reviews:**

- Staged changes
- Code quality
- Potential issues
- Best practices
- Suggestions

### `harm-cli ai explain-error`

Explain the last error from logs.

**Usage:**

```bash
harm-cli ai explain-error
```

**Analyzes:**

- Last error from `~/.harm-cli/logs/harm-cli.log`
- Error context
- Provides solutions
- Suggests fixes

### `harm-cli ai daily`

Daily productivity insights.

**Usage:**

```bash
harm-cli ai daily        # Today's insights
harm-cli ai daily --week # Weekly summary
```

**Insights from:**

- Work sessions
- Goals progress
- Git commits
- Code changes

---

## Git Workflows

### `harm-cli git status`

Enhanced git status with suggestions.

**Usage:**

```bash
harm-cli git status
```

**Output:**

- Standard git status
- Actionable suggestions
- Next steps

**Example suggestions:**

- "Unstaged changes: Run `git add .`"
- "Ready to commit: Run `git commit`"

### `harm-cli git commit-msg`

Generate AI-powered commit message from staged changes.

**Usage:**

```bash
harm-cli git commit-msg
```

**Output:**

- Conventional commit format
- Type (feat/fix/docs/refactor/etc)
- Scope
- Description
- Body (if needed)

**Example:**

```
feat(docker): add cleanup command for safe resource management

Implements comprehensive Docker cleanup with safety features:
- Removes stopped containers (>24h old)
- Removes dangling and old images (>30 days)
- Cleans build cache
- Never touches volumes (data safety)
```

---

## Project Management

### `harm-cli proj list`

List all registered projects.

**Usage:**

```bash
harm-cli proj list       # Text output
harm-cli proj list json  # JSON output
```

**Output:**

- Project name
- Path
- Type (nodejs, python, rust, go, shell)
- Last updated

### `harm-cli proj add`

Add a project to registry.

**Usage:**

```bash
harm-cli proj add <path> [name]
```

**Examples:**

```bash
harm-cli proj add ~/myapp                    # Auto-detect name
harm-cli proj add ~/projects/api backend-api # Custom name
```

**Auto-detection:**

- Name: From directory name
- Type: From project files (package.json, setup.py, Cargo.toml, etc)

### `harm-cli proj remove`

Remove a project from registry.

**Usage:**

```bash
harm-cli proj remove <name>
```

**Example:**

```bash
harm-cli proj remove backend-api
```

### `harm-cli proj switch`

Output cd command for project switching.

**Usage:**

```bash
# In shell function (see installation):
proj switch <name>

# Direct (outputs cd command):
harm-cli proj switch <name>
```

**Example:**

```bash
proj switch backend-api  # Changes to project directory
```

**Note:** Requires shell function integration (see docs/INSTALLATION.md)

---

## Docker Management

### `harm-cli docker up`

Start Docker Compose services.

**Usage:**

```bash
harm-cli docker up [services...]
```

**Examples:**

```bash
harm-cli docker up                   # Start all services
harm-cli docker up backend database  # Start specific services
```

**Features:**

- Detached mode (`-d`)
- Auto-detects compose files
- Supports overrides (compose.override.yaml)
- Environment-specific files (compose.dev.yaml)

### `harm-cli docker down`

Stop and remove Docker Compose services.

**Usage:**

```bash
harm-cli docker down [--volumes|-v]
```

**Examples:**

```bash
harm-cli docker down     # Stop services
harm-cli docker down -v  # Stop and remove volumes
```

**WARNING:** `--volumes` flag removes data. Use with caution.

### `harm-cli docker status`

Show Docker Compose service status.

**Usage:**

```bash
harm-cli docker status
```

**Output:**

- Service name
- Status (running/stopped)
- Ports
- Health check status

### `harm-cli docker logs`

View service logs.

**Usage:**

```bash
harm-cli docker logs <service> [options]
```

**Examples:**

```bash
harm-cli docker logs backend
harm-cli docker logs backend --tail 100
harm-cli docker logs backend --follow
```

### `harm-cli docker shell`

Open shell in container.

**Usage:**

```bash
harm-cli docker shell <service>
```

**Example:**

```bash
harm-cli docker shell backend  # Opens bash (or sh)
```

**Auto-detection:** Tries bash first, falls back to sh.

### `harm-cli docker health`

Check Docker environment health.

**Usage:**

```bash
harm-cli docker health
```

**Checks:**

- Docker daemon status
- Docker Compose availability
- Compose file presence
- Service count (defined vs running)

### `harm-cli docker cleanup`

**⭐ NEW:** Safe Docker resource cleanup.

**Purpose:** Performs comprehensive Docker cleanup in a stepwise, safe manner.

**Usage:**

```bash
harm-cli docker cleanup
```

**Cleanup Steps:**

1. **Removes stopped containers (>24h old)**
   - Filter: `--filter "until=24h"`
   - Safe: Only removes old containers

2. **Removes dangling images**
   - Untagged images not referenced by any container
   - Safe to remove (can be rebuilt)

3. **Removes unused networks**
   - Custom networks not used by any container
   - Excludes: bridge, host, none

4. **Removes old unused images (>30 days)**
   - Filter: `--filter "until=720h"` (30 days)
   - Safe: Recent images preserved

5. **Cleans build cache**
   - Removes all build cache
   - Safe: Automatically rebuilds when needed

**Safety Features:**

- ✅ **Never touches volumes** - Explicit protection against data loss
- ✅ **Time-based filters** - Only removes old/unused resources
- ✅ **Disk usage reporting** - Shows before/after comparison
- ✅ **Progressive output** - Clear feedback for each step
- ✅ **Safe for automation** - Can run via cron without risk

**Output:**

```
🧹 Docker Cleanup
══════════════════════════════════════════

📊 Disk usage before cleanup:
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          5         2         1.5GB     500MB (33%)
Containers      3         1         50MB      25MB (50%)
Build Cache     10        0         2GB       2GB (100%)

🗑️  Removing stopped containers (>24h old)...
Deleted Containers:
abc123
Total reclaimed space: 25MB

🗑️  Removing dangling images...
deleted: sha256:abc123
Total reclaimed space: 500MB

🗑️  Removing unused networks...
Deleted Networks:
test-network

🗑️  Removing unused images (>30 days old)...
Total reclaimed space: 1GB

🗑️  Removing build cache...
Total: 2GB

📊 Disk usage after cleanup:
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          2         2         1GB       0B (0%)
Containers      1         1         25MB      0B (0%)
Build Cache     0         0         0B        0B

✅ Cleanup complete!

💡 Note: Volumes were NOT touched. To review unused volumes, run:
   docker volume ls -f 'dangling=true'
   docker volume inspect <volume_name>
   docker volume prune  # CAUTION: Data loss risk!
```

**Performance:** 5-30 seconds (depends on resources to clean)

**Comparison with `docker system prune`:**

| Feature      | `docker system prune`     | `harm-cli docker cleanup` |
| ------------ | ------------------------- | ------------------------- |
| Volumes      | Optional with `--volumes` | ✅ **Never touches**      |
| Containers   | All stopped               | ✅ Only >24h old          |
| Images       | All unused                | ✅ Only >30 days old      |
| Build cache  | All                       | All (same)                |
| Networks     | All unused                | All unused (same)         |
| Confirmation | Required (unless `-f`)    | ❌ Automatic              |
| Progress     | Minimal                   | ✅ Detailed with emojis   |

**Aliases:**

```bash
harm-cli docker clean   # Same as cleanup
harm-cli docker prune   # Same as cleanup
```

**Use cases:**

- Regular maintenance (weekly/monthly)
- CI/CD cleanup after builds
- Development environment cleanup
- Disk space recovery

**Manual volume review:**

```bash
# List dangling volumes
docker volume ls -f 'dangling=true'

# Inspect specific volume
docker volume inspect <volume_name>

# Cleanup volumes (CAREFUL - DATA LOSS!)
docker volume prune
```

---

## Python Development

### `harm-cli python test`

Run Python tests.

**Usage:**

```bash
harm-cli python test [args...]
```

**Auto-detection:**

- pytest (if available)
- unittest (fallback)

**Example:**

```bash
harm-cli python test
harm-cli python test tests/test_api.py
harm-cli python test -v
```

### `harm-cli python lint`

Lint Python code.

**Usage:**

```bash
harm-cli python lint [path]
```

**Auto-detection:**

- ruff (preferred)
- pylint (fallback)
- flake8 (fallback)

**Example:**

```bash
harm-cli python lint
harm-cli python lint src/
```

### `harm-cli python format`

Format Python code.

**Usage:**

```bash
harm-cli python format [path]
```

**Auto-detection:**

- ruff format (preferred)
- black (fallback)

**Example:**

```bash
harm-cli python format
harm-cli python format src/
```

---

## Google Cloud

### `harm-cli gcloud status`

Show Google Cloud SDK status.

**Usage:**

```bash
harm-cli gcloud status
```

**Output:**

- Active account
- Active project
- Active configuration
- SDK version

---

## Health & Safety

### `harm-cli health`

Comprehensive system health check.

**Usage:**

```bash
harm-cli health
```

**Checks:**

- Bash version
- Required tools
- Docker environment
- Python environment
- Google Cloud SDK
- Configuration files
- Log files

### `harm-cli safe rm`

Safe file deletion with confirmation.

**Usage:**

```bash
harm-cli safe rm <file>
```

**Safety:**

- Confirmation prompt
- Shows file info before deletion
- Optional backup

### `harm-cli safe git-reset`

Safe git reset with backup.

**Usage:**

```bash
harm-cli safe git-reset [commit]
```

**Safety:**

- Creates backup branch
- Confirmation prompt
- Shows changes that will be lost

---

## Environment Variables

### Global Configuration

```bash
# API Keys
export GEMINI_API_KEY="your-api-key"     # Gemini AI API key

# Output Format
export HARM_CLI_FORMAT="text"            # text (default) | json

# Logging
export HARM_CLI_LOG_LEVEL="INFO"         # DEBUG | INFO | WARN | ERROR
export HARM_CLI_LOG_FILE="~/.harm-cli/logs/harm-cli.log"

# Paths
export HARM_CLI_HOME="~/.harm-cli"       # Configuration directory

# Docker
export HARM_DOCKER_ENV="dev"             # Environment for compose files
```

### Feature Flags

```bash
# AI Features
export HARM_AI_CACHE_TTL="3600"          # Cache duration (seconds)
export HARM_AI_MODEL="gemini-pro"        # Gemini model

# Work Sessions
export HARM_WORK_ENFORCE="false"         # Enforce work session
```

---

## JSON Output

All commands that support JSON output use `--format json` or `json` subcommand:

```bash
# Text output (default)
harm-cli version
harm-cli work status
harm-cli goal show

# JSON output
harm-cli version json
harm-cli work status json
harm-cli goal show json
```

**JSON Structure:**

```json
{
  "version": "1.0.0",
  "commit": "abc123",
  "bash_version": "5.2.15"
}
```

---

## Exit Codes

```bash
0   - Success
1   - General error
2   - Invalid arguments
3   - Invalid state (e.g., Docker not running)
4   - Command failed (e.g., docker compose up failed)
5   - Not found (e.g., project not found)
```

---

## Configuration Files

```
~/.harm-cli/
├── config.json              # Global configuration
├── state/
│   ├── work_session.json    # Current work session
│   ├── work_history.jsonl   # Archived sessions
│   └── goals.jsonl          # Daily goals
├── projects.jsonl           # Project registry
├── logs/
│   └── harm-cli.log         # Application logs
└── cache/
    └── ai_responses/        # AI response cache
```

---

## Tips & Best Practices

### Docker Cleanup

- **Regular maintenance:** Run weekly with `harm-cli docker cleanup`
- **CI/CD:** Add to post-build cleanup scripts
- **Automation:** Safe for cron jobs (no confirmation needed)
- **Volume review:** Manually inspect volumes before pruning

### AI Assistant

- **Context mode:** Use `--context` for better project-aware answers
- **Cache:** Responses cached for 1 hour (configurable)
- **API key:** Secure storage via keychain/secret-tool

### Work Sessions

- **Start early:** Begin sessions before coding
- **Track breaks:** Stop session during long breaks
- **Review history:** Check `work_history.jsonl` for patterns

### Goals

- **Daily practice:** Set goals every morning
- **Be specific:** "Complete test coverage" > "Work on tests"
- **Track progress:** Update regularly during work
- **Reflect:** Review completion at day end

---

**Last Updated:** 2025-10-24
**Version:** 1.0.0 (includes docker cleanup feature)
