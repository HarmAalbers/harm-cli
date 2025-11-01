# Git Workflow Guide for harm-cli

This guide documents the git workflow, branching strategy, and release process for harm-cli.

## Table of Contents

1. [Branch Strategy](#branch-strategy)
2. [Commit Message Format](#commit-message-format)
3. [Development Workflow](#development-workflow)
4. [Release Process](#release-process)
5. [Git Hooks](#git-hooks)

## Branch Strategy

harm-cli uses a simplified trunk-based development model:

```
main (production-ready, protected)
  │
  ├── feature/goal-reopen          # New features
  ├── feature/ai-integration       # New features
  ├── fix/bug-in-logging          # Bug fixes
  ├── docs/update-readme          # Documentation
  ├── refactor/improve-error      # Refactoring
  └── chore/update-deps           # Maintenance
```

### Branch Naming Convention

- `feature/<description>` - New features
- `fix/<description>` - Bug fixes
- `docs/<description>` - Documentation only
- `refactor/<description>` - Code refactoring
- `chore/<description>` - Maintenance tasks
- `test/<description>` - Test improvements
- `perf/<description>` - Performance improvements

**Examples**:

```bash
git checkout -b feature/goal-reopen
git checkout -b fix/timer-cleanup
git checkout -b docs/installation-guide
```

## Commit Message Format

harm-cli follows [Conventional Commits](https://www.conventionalcommits.org/) specification.

### Format

```
type(scope): subject

[optional body]

[optional footer]
```

### Types

- `feat` - New feature for the user
- `fix` - Bug fix for the user
- `docs` - Documentation changes
- `style` - Code style (formatting, whitespace)
- `refactor` - Code change (neither fix nor feature)
- `test` - Adding or updating tests
- `chore` - Tooling, dependencies, etc.
- `perf` - Performance improvement
- `ci` - CI/CD changes
- `build` - Build system changes
- `revert` - Revert previous commit

### Scope (Optional)

Component being changed: `goals`, `work`, `ai`, `git`, `config`, etc.

### Subject Rules

- Use imperative mood ("add" not "added")
- Don't capitalize first letter
- No period at the end
- Maximum 72 characters
- Minimum 10 characters

### Examples

**Good commits**:

```
feat(goals): add reopen command to restore completed goals
fix(work): resolve timer cleanup on stop
docs: update installation guide with Homebrew instructions
test(ai): add edge case tests for model selection
chore(deps): update shellcheck to v0.10.0
```

**Bad commits**:

```
❌ update stuff
❌ Fixed bug
❌ WIP
❌ feat: a
```

### Body (Optional)

Explain **WHAT** and **WHY**, not HOW:

```
feat(goals): add reopen command to restore completed goals

Allows users to reopen a completed goal if they need to continue
working on it. The goal is restored with its original settings but
progress is reset to 0.
```

### Footer (Optional)

Reference issues or breaking changes:

```
feat(config): migrate to XDG Base Directory specification

BREAKING CHANGE: Config location moved from ~/.harm-cli to
~/.config/harm-cli. Run migration: harm-cli config migrate

Closes #42
```

## Development Workflow

### 1. Start New Feature

```bash
# Ensure main is up to date
git checkout main
git pull origin main

# Create feature branch
git checkout -b feature/goal-reopen

# Verify branch
git branch --show-current
```

### 2. Development Cycle

```bash
# Make changes
vim lib/goals.sh

# Run tests frequently
just test-file spec/goals_spec.sh

# Commit small, focused changes
git add lib/goals.sh spec/goals_spec.sh
git commit
# Editor opens with template from .gitmessage
```

### 3. Before Committing

```bash
# Run full CI pipeline
just ci

# This runs:
# - just fmt (format code)
# - just lint (shellcheck)
# - just test (full test suite)
```

### 4. Preparing for PR

```bash
# Update main and rebase
git fetch origin main
git rebase origin/main

# Force push (safe on feature branch)
git push -f origin feature/goal-reopen
```

### 5. Creating Pull Request

```bash
# Using GitHub CLI
gh pr create \
  --title "feat(goals): add reopen command to restore completed goals" \
  --body "$(cat <<EOF
## Summary
Adds \`harm-cli goal reopen <id>\` command to restore completed goals.

## Changes
- Added \`goal_reopen()\` function in \`lib/goals.sh\`
- Added tests for reopen functionality
- Updated COMMANDS.md documentation

## Testing
\`\`\`bash
just test-file spec/goals_spec.sh
\`\`\`

## Closes
Closes #42
EOF
)"
```

## Release Process

harm-cli uses automated releases with semantic versioning.

### Version Numbering

`MAJOR.MINOR.PATCH` (e.g., `1.2.3`)

- **MAJOR** - Breaking changes
- **MINOR** - New features (backward compatible)
- **PATCH** - Bug fixes (backward compatible)

### Creating a Release

```bash
# Ensure you're on main and up to date
git checkout main
git pull origin main

# Run release script
./scripts/release.sh [major|minor|patch]

# Examples:
./scripts/release.sh patch   # 1.0.0 -> 1.0.1
./scripts/release.sh minor   # 1.0.0 -> 1.1.0
./scripts/release.sh major   # 1.0.0 -> 2.0.0
```

### What the Release Script Does

1. **Validates** - Checks git state, runs tests
2. **Bumps version** - Updates VERSION file
3. **Generates changelog** - Uses git-cliff
4. **Commits changes** - `chore(release): bump version to X.Y.Z`
5. **Creates tag** - `vX.Y.Z`
6. **Builds artifacts** - Tarball + checksums
7. **Pushes to remote** - main branch + tag
8. **Creates GitHub release** - With artifacts

### Manual Release Steps

If you need to release manually:

```bash
# 1. Update VERSION file
echo "1.2.0" > VERSION

# 2. Generate changelog
git-cliff --tag v1.2.0 --output CHANGELOG.md

# 3. Commit version bump
git add VERSION CHANGELOG.md
git commit -m "chore(release): bump version to 1.2.0"

# 4. Create annotated tag
git tag -a v1.2.0 -m "Release v1.2.0"

# 5. Push to remote
git push origin main
git push origin v1.2.0

# 6. Build release artifacts
just build

# 7. Create GitHub release
gh release create v1.2.0 \
  --title "v1.2.0" \
  --notes-file CHANGELOG.md \
  dist/harm-cli-1.2.0.tar.gz
```

### Dry Run

Preview release without making changes:

```bash
DRY_RUN=1 ./scripts/release.sh minor
```

### Skip Tests (Emergency Only)

```bash
SKIP_TESTS=1 ./scripts/release.sh patch
```

## Git Hooks

harm-cli includes custom git hooks for quality enforcement.

### Installation

```bash
# Run once after cloning
./.githooks/setup.sh
```

This configures git to use hooks from `.githooks/` directory.

### Available Hooks

#### commit-msg

Validates commit message format before commit is created.

**Enforces**:

- Conventional Commits format
- Minimum description length (10 chars)
- Valid commit types

**Bypass** (not recommended):

```bash
git commit --no-verify
```

#### pre-commit

Runs quality checks before commit:

1. Code formatting check
2. Linting (shellcheck)
3. Test suite

**Skip tests only**:

```bash
SKIP_TESTS=1 git commit
```

### Commit Message Template

Set up git to use commit message template:

```bash
git config commit.template .gitmessage
```

Now when you run `git commit`, your editor opens with helpful hints.

## Advanced Git Workflows

### Interactive Rebase

Clean up commits before pushing:

```bash
# View last 5 commits
git log --oneline -5

# Start interactive rebase
git rebase -i HEAD~5

# Commands:
# pick   - use commit
# reword - edit commit message
# squash - merge into previous commit
# drop   - remove commit
```

### Cherry-Picking

Apply specific commit to current branch:

```bash
git cherry-pick <commit-sha>
```

### Stashing

Save uncommitted changes temporarily:

```bash
# Save changes
git stash push -m "WIP: feature X"

# List stashes
git stash list

# Restore and remove
git stash pop

# Restore without removing
git stash apply stash@{0}
```

## CI/CD Integration

### GitHub Actions

harm-cli runs automated checks on every PR:

- Shellcheck linting
- Test suite (bash + zsh)
- Code formatting verification

### Pre-Push Checks

Run CI locally before pushing:

```bash
just pre-push
```

This runs the full CI pipeline and ensures your code will pass GitHub Actions.

## Troubleshooting

### Commit Rejected by Hook

**Error**: "Invalid commit message format"

**Solution**: Follow conventional commits format

```bash
feat(component): description at least 10 chars
```

### Rebase Conflicts

**Error**: Conflicts during `git rebase origin/main`

**Solution**:

```bash
# 1. View conflicted files
git status

# 2. Edit conflicts manually

# 3. Mark as resolved
git add <file>

# 4. Continue rebase
git rebase --continue

# Or abort and try differently
git rebase --abort
```

### Accidentally Committed to Wrong Branch

```bash
# Create feature branch from current state
git branch feature/new-feature

# Reset main
git checkout main
git reset --hard origin/main

# Switch to feature branch
git checkout feature/new-feature
```

## Best Practices

### DO ✅

- Write small, focused commits
- Commit frequently during development
- Run `just ci` before pushing
- Write descriptive commit messages
- Include tests with features
- Rebase feature branches on main
- Keep PRs focused and reviewable

### DON'T ❌

- Commit directly to main
- Use `--no-verify` routinely
- Write vague commit messages
- Mix unrelated changes in one commit
- Force push to main
- Leave broken code in commits

## See Also

- [Conventional Commits Specification](https://www.conventionalcommits.org/)
- [Git Best Practices](https://git-scm.com/book/en/v2)
- [harm-cli Contributing Guide](../CONTRIBUTING.md)
