# Branch Cleanup Documentation

## Issue

22 merged feature/phase branches remain on origin after being merged to main.

## Impact

- Cluttered branch namespace
- Confuses contributors about active work
- Makes `git branch -r` output overwhelming
- Violates git workflow best practices

## Merged Branches to Delete

All branches listed below are **fully merged** to `origin/main` and safe to delete:

```
origin/argh
origin/feature/ai-audit-trail
origin/feature/ai-markdown-output-formatting
origin/feature/comprehensive-testing-strategy
origin/feature/cross-terminal-log-streaming
origin/feature/docker-compose-overrides
origin/feature/enhance-project-switch
origin/feature/github-integration
origin/feature/interactive-installer-config
origin/feature/interactive-options-management
origin/feature/log-streaming-all-levels
origin/phase-1/core-infrastructure
origin/phase-2/work-and-goals
origin/phase-4/git-and-projects
origin/phase-5a/docker-management
origin/phase-5b/python-development
origin/phase-5c/gcloud-integration
origin/phase-5d/health-checks
origin/phase-6a/safety-module
origin/phase-6c/work-enhancements
origin/phase-6d/goal-validation
origin/phase-7/shell-integration
```

## Cleanup Command

After this PR is merged, run:

```bash
# Delete all merged feature/phase branches
git branch -r --merged origin/main | \
  grep -v "HEAD\|main" | \
  sed 's/origin\///' | \
  xargs -I {} git push origin --delete {}
```

Or manually:

```bash
git push origin --delete argh
git push origin --delete feature/ai-audit-trail
# ... etc
```

## Prevention

Going forward:

1. Delete branch immediately after PR merge
2. Use GitHub's "Delete branch after merge" auto-option
3. Review branches monthly: `git branch -r --merged origin/main`

## Policy

**Branch Retention Policy:**

- Feature branches: Delete immediately after merge
- Release branches: Keep indefinitely (v1.0.0, v1.1.0, etc)
- Hotfix branches: Delete after merge
- Development branches (main): Keep forever
