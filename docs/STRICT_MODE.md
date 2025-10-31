# Strict Mode - Work/Break Discipline Enforcement

## Overview

Strict mode provides comprehensive discipline and focus enforcement for harm-cli's work session management. It helps maintain work-break balance, prevents context switching, and tracks compliance metrics.

## Features

### 1. **Project Switch Blocking**

Prevents switching between projects during active work sessions.

### 2. **Break Requirement Enforcement**

Requires completing breaks before starting new work sessions.

### 3. **Early Termination Detection**

Detects and confirms when stopping sessions before completion.

### 4. **Break Compliance Tracking**

Archives breaks and reports compliance metrics.

---

## Configuration

### Enable Strict Mode

```bash
# Set enforcement mode
export HARM_WORK_ENFORCEMENT=strict

# Enable in config (persistent)
echo 'export HARM_WORK_ENFORCEMENT=strict' >> ~/.harm-cli/config
```

### Strict Mode Options

All options default to `0` (disabled). Enable individually:

```bash
# Block project switching (prevents cd during work sessions)
harm-cli options set strict_block_project_switch 1

# Require break completion before new session
harm-cli options set strict_require_break 1

# Confirm early session termination
harm-cli options set strict_confirm_early_stop 1

# Track and archive break sessions
harm-cli options set strict_track_breaks 1
```

### View Current Settings

```bash
# View all strict mode settings
harm-cli options list | grep strict

# View individual setting
harm-cli options get strict_block_project_switch
```

---

## Feature Details

### 🚫 Project Switch Blocking

**Purpose**: Prevent context switching between projects during work sessions.

**Behavior**:

- **Warning Mode** (default): Counts violations, displays warnings
- **Blocking Mode**: Actually prevents directory changes

**Example**:

```bash
# Enable blocking
harm-cli options set strict_block_project_switch 1

# Start work session
cd ~/my-project
harm-cli work start "Implement feature X"

# Try to switch projects
cd ~/other-project
# OUTPUT: 🚫 PROJECT SWITCH BLOCKED!
#         Active work session in: my-project
#         Cannot switch to: other-project
#
#         To switch projects:
#         1. Stop current session: harm-cli work stop
#         2. Then switch projects

# You remain in ~/my-project
```

**Override**: Stop current session first:

```bash
harm-cli work stop
cd ~/other-project
harm-cli work start "New task"
```

---

### ☕ Break Requirement Enforcement

**Purpose**: Ensure breaks are taken between work sessions.

**Behavior**:

- After `work stop`, sets `break_required` flag
- Blocks new `work start` until break completed
- Break type determined by pomodoro count (short/long)

**Example**:

```bash
# Enable break requirements
harm-cli options set strict_require_break 1

# Complete a work session
harm-cli work start "Task 1"
# ... work for 25 minutes ...
harm-cli work stop

# Try to start new session immediately
harm-cli work start "Task 2"
# OUTPUT: ☕ Break required by strict mode!
#         You must complete a short break before starting a new session.
#
#         Start break: harm-cli break start

# Take the required break
harm-cli break start
# ... break for 5 minutes ...
harm-cli break stop

# Now can start new session
harm-cli work start "Task 2"
# ✓ Session started
```

**Break Completion**: Break must be >= 80% of planned duration to clear requirement.

---

### ⚠️ Early Termination Detection

**Purpose**: Confirm and track when sessions end before planned duration.

**Behavior**:

- Detects sessions < 80% of expected duration
- Prompts for confirmation (interactive mode)
- Asks for termination reason (optional)
- Archives early_stop flag and reason

**Example**:

```bash
# Enable early stop confirmation
harm-cli options set strict_confirm_early_stop 1

# Start session (default: 25 minutes)
harm-cli work start "Long task"

# Stop after only 10 minutes
harm-cli work stop
# OUTPUT: ⚠️  Early termination detected!
#         Expected: 25 minutes
#         Actual: 10 minutes
#
# Prompt: Do you want to stop this session early? [y/N]:
# > y
# Prompt: Reason for early stop (optional):
# > Got blocked by dependency issue
```

**Session Archive**:

```json
{
  "start_time": "2025-10-31T13:00:00Z",
  "end_time": "2025-10-31T13:10:00Z",
  "duration_seconds": 600,
  "goal": "Long task",
  "pomodoro_count": 1,
  "early_stop": true,
  "termination_reason": "Got blocked by dependency issue"
}
```

**Non-Interactive Mode**: Early stops allowed without confirmation (for scripts).

---

### 📊 Break Compliance Tracking

**Purpose**: Track break habits and report compliance metrics.

**Behavior**:

- Archives break sessions to `~/.harm-cli/work/breaks_YYYY-MM.jsonl`
- Records: duration, planned duration, type, completion status
- Generates compliance reports

**Example**:

```bash
# Enable break tracking
harm-cli options set strict_track_breaks 1

# Take breaks after work sessions
harm-cli work start "Task 1"
harm-cli work stop
harm-cli break start  # 5-min short break
# ... wait 5 minutes ...
harm-cli break stop

# View compliance report
harm-cli work break-compliance
```

**Sample Report**:

```
═══════════════════════════════════════════════════════════════
  Break Compliance Report (2025-10)
═══════════════════════════════════════════════════════════════

  📊 Work sessions: 8
  ☕ Breaks taken: 6
  ✅ Breaks completed fully: 5

  📈 Compliance rate: 75%
  📈 Completion rate: 83%

  ⏱  Average break: 4 min (target: 5 min)

  🎉 Excellent! You're maintaining good work-break balance
```

**Compliance Metrics**:

- **Compliance Rate**: Breaks taken / Work sessions
- **Completion Rate**: Full breaks / Total breaks
- **Full Break**: >= 80% of planned duration

**Feedback Thresholds**:

- < 50% compliance: Warning to enable `strict_require_break`
- < 50% completion: Suggestion to complete full duration
- > = 80% both: Excellent feedback

---

## Full Workflow Example

```bash
# 1. Enable all strict mode features
export HARM_WORK_ENFORCEMENT=strict
harm-cli options set strict_block_project_switch 1
harm-cli options set strict_require_break 1
harm-cli options set strict_confirm_early_stop 1
harm-cli options set strict_track_breaks 1

# 2. Start work session in project A
cd ~/project-a
harm-cli work start "Implement authentication"

# 3. Try to switch projects (BLOCKED)
cd ~/project-b
# Returned to ~/project-a automatically

# 4. Complete work session
harm-cli work stop

# 5. Try to start new session (BLOCKED - break required)
harm-cli work start "Add tests"
# Error: Break required

# 6. Take required break
harm-cli break start
# ... take 5-minute break ...
harm-cli break stop

# 7. Now can start new session
harm-cli work start "Add tests"
# ✓ Session started

# 8. View compliance
harm-cli work break-compliance
```

---

## Integration with Existing Features

### Shell Integration

Strict mode works with:

- Shell hooks (chpwd for project switch detection)
- `proj` command (project switching)
- Work/break commands
- Pomodoro tracking

### Options System

```bash
# View all work-related options
harm-cli options list | grep work

# Set via environment
export HARM_STRICT_BLOCK_PROJECT_SWITCH=1
export HARM_STRICT_REQUIRE_BREAK=1

# Set via config file
echo 'export HARM_STRICT_BLOCK_PROJECT_SWITCH=1' >> ~/.harm-cli/config
echo 'export HARM_STRICT_REQUIRE_BREAK=1' >> ~/.harm-cli/config

# Set via command
harm-cli options set strict_block_project_switch 1
```

---

## Enforcement Levels

### `off` (No Enforcement)

- No restrictions
- No tracking
- Pure manual control

### `moderate` (Warning Mode) - **Default**

- Warnings for context switches
- No blocking
- Violation counting

### `strict` (Enforcement Mode)

- All strict mode features available
- Can block operations
- Full tracking and compliance

### Set Enforcement Level

```bash
# Command
harm-cli work enforcement strict

# Environment
export HARM_WORK_ENFORCEMENT=strict

# Config file
echo 'export HARM_WORK_ENFORCEMENT=strict' >> ~/.harm-cli/config
```

---

## Data Files

Strict mode uses these files:

```
~/.harm-cli/work/
├── current_session.json         # Active work session state
├── current_break.json           # Active break session state
├── enforcement.json             # Enforcement state (violations, flags)
├── sessions_YYYY-MM.jsonl       # Work session history
└── breaks_YYYY-MM.jsonl         # Break session history (if tracking enabled)
```

### Session Archive Format

**Work Session**:

```json
{
  "start_time": "2025-10-31T10:00:00Z",
  "end_time": "2025-10-31T10:25:00Z",
  "duration_seconds": 1500,
  "goal": "Implement feature X",
  "pomodoro_count": 1,
  "early_stop": false,
  "termination_reason": null
}
```

**Break Session**:

```json
{
  "start_time": "2025-10-31T10:25:00Z",
  "end_time": "2025-10-31T10:30:00Z",
  "duration_seconds": 300,
  "planned_duration_seconds": 300,
  "type": "short",
  "completed_fully": true
}
```

**Enforcement State**:

```json
{
  "violations": 0,
  "project": "my-project",
  "goal": "",
  "updated": "2025-10-31T10:30:00Z",
  "last_session_end": "2025-10-31T10:25:00Z",
  "break_required": false,
  "break_type_required": null,
  "last_break_end": "2025-10-31T10:30:00Z"
}
```

---

## Tips & Best Practices

### For Maximum Discipline

Enable all features:

```bash
harm-cli options set strict_block_project_switch 1
harm-cli options set strict_require_break 1
harm-cli options set strict_confirm_early_stop 1
harm-cli options set strict_track_breaks 1
```

### For Gradual Adoption

Start with tracking only:

```bash
harm-cli options set strict_track_breaks 1
# Review compliance after 1 week
harm-cli work break-compliance
```

Then add break requirements:

```bash
harm-cli options set strict_require_break 1
```

Finally add project blocking:

```bash
harm-cli options set strict_block_project_switch 1
```

### For Focus Sessions

Use project blocking only:

```bash
harm-cli options set strict_block_project_switch 1
```

### For Work-Life Balance

Use break requirements only:

```bash
harm-cli options set strict_require_break 1
harm-cli options set strict_track_breaks 1
```

---

## Troubleshooting

### "Project switch blocked" but I'm in the same project

**Issue**: Directory name changed or using symlinks

**Solution**:

```bash
# Stop current session
harm-cli work stop

# Clear enforcement state
rm ~/.harm-cli/work/enforcement.json

# Start new session
harm-cli work start "Task"
```

### "Break required" but I already took a break

**Issue**: Break wasn't completed fully (< 80% duration)

**Solution**:

```bash
# Check break history
cat ~/.harm-cli/work/breaks_$(date +%Y-%m).jsonl | tail -1

# If completed_fully is false, take another break
harm-cli break start
# Wait for full duration
harm-cli break stop
```

### Early stop confirmation not showing

**Issue**: Not in interactive mode or option disabled

**Solution**:

```bash
# Check option
harm-cli options get strict_confirm_early_stop

# Enable it
harm-cli options set strict_confirm_early_stop 1

# Ensure running in interactive shell (not script)
```

### Want to disable strict mode temporarily

```bash
# Disable enforcement
export HARM_WORK_ENFORCEMENT=moderate

# Or disable specific features
harm-cli options set strict_block_project_switch 0
```

---

## See Also

- [Work Session Management](./WORK_SESSIONS.md)
- [Options System](./OPTIONS.md)
- [Pomodoro Technique](./POMODORO.md)
- [Shell Hooks](./HOOKS.md)
