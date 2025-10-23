# Git Signing with SSH

This guide explains how to use the SSH commit signing tools integrated into harm-cli's GitHub module.

## Overview

The GitHub module (`lib/github.sh`) provides functions to easily configure SSH-based commit signing for repositories. This is simpler than GPG signing and reuses your existing SSH keys.

## Prerequisites

- SSH keys set up for your Git identities
- Git 2.34+ (for SSH signing support)
- Repository configured with the correct remote

## Quick Start

### Configure Signing for a Repository

```bash
# Source the github module
source lib/github.sh

# For HarmAalbers identity
github_setup_ssh_signing harmaalbers

# For SolarHarm identity
github_setup_ssh_signing solarharm
```

This command will:

- ✅ Set GPG format to SSH
- ✅ Configure the appropriate SSH key
- ✅ Enable auto-signing for commits and tags
- ✅ Set up the user name and email
- ✅ Configure the allowed signers file for verification

### Sign an Existing Commit

If you have an unsigned commit at HEAD:

```bash
github_sign_commit
```

**⚠️ Warning:** This rewrites the commit (changes its hash). If already pushed, you'll need to force-push:

```bash
git push --force-with-lease origin <branch-name>
```

### Verify a Signature

```bash
# Verify HEAD
github_verify_signature

# Verify specific commit
github_verify_signature a51ac96

# Verify any ref
github_verify_signature origin/main
```

## Supported Identities

The `github_setup_ssh_signing` function supports two identities:

### HarmAalbers

- **Email:** haalbers@gmail.com
- **SSH Key:** `~/.ssh/id_rsa_harm_cli.pub`
- **Usage:** `github_setup_ssh_signing harmaalbers`

### SolarHarm

- **Email:** solarharm@users.noreply.github.com
- **SSH Key:** `~/.ssh/id_ed25519.pub`
- **Usage:** `github_setup_ssh_signing solarharm`

## Configuration Details

When you run `github_setup_ssh_signing`, it configures the following Git settings **locally** (repository-specific):

```bash
git config --local gpg.format ssh
git config --local user.signingkey <path-to-public-key>
git config --local commit.gpgsign true
git config --local tag.gpgsign true
git config --local user.name <identity-name>
git config --local user.email <identity-email>
git config --local gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers
```

## Allowed Signers File

The allowed signers file (`~/.ssh/allowed_signers`) tells Git which SSH keys are trusted for verification. The setup function automatically:

1. Creates the file if it doesn't exist
2. Adds your SSH key with the associated email if not already present
3. Configures Git to use this file for verification

Format:

```
email@example.com ssh-rsa AAAAB3NzaC1yc2E...
```

## Manual Configuration

If you need to configure signing manually or for a different identity:

```bash
# Enable SSH signing
git config --local gpg.format ssh

# Set signing key
git config --local user.signingkey ~/.ssh/your_key.pub

# Enable auto-signing
git config --local commit.gpgsign true
git config --local tag.gpgsign true

# Configure verification
git config --local gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers

# Add key to allowed signers
echo "your@email.com $(cat ~/.ssh/your_key.pub)" >> ~/.ssh/allowed_signers
```

## GitHub Integration

### Adding SSH Key to GitHub

For GitHub to verify your signatures, you need to add your SSH public key:

1. Copy your public key:

   ```bash
   cat ~/.ssh/id_rsa_harm_cli.pub
   # or
   cat ~/.ssh/id_ed25519.pub
   ```

2. Go to GitHub Settings → SSH and GPG keys
3. Click "New SSH key"
4. Select **"Signing Key"** as the key type
5. Paste your public key
6. Save

### Verifying on GitHub

Once configured:

- Commits will show a "Verified" badge on GitHub
- The badge confirms the commit was signed with your registered key
- This proves commit authenticity

## Troubleshooting

### "No signature" error

If you see "No signature" but the commit is signed:

```bash
# Check if allowedSignersFile is configured
git config --local gpg.ssh.allowedSignersFile

# If empty, run setup again
github_setup_ssh_signing <identity>
```

### "SSH key not found" error

Make sure your SSH key exists:

```bash
ls -la ~/.ssh/id_rsa_harm_cli.pub  # HarmAalbers
ls -la ~/.ssh/id_ed25519.pub       # SolarHarm
```

### Signature not verified on GitHub

1. Check that you've added the **public key** to GitHub as a **Signing Key** (not Authentication)
2. Verify the email in the commit matches the email associated with the key on GitHub
3. Check the commit signature locally: `github_verify_signature`

## Best Practices

### Per-Repository Configuration

Configure signing per-repository rather than globally:

- ✅ Explicit control over which repos use signing
- ✅ No surprises with automatic signing
- ✅ Easy to switch between identities per project

### Force Push Safety

Always use `--force-with-lease` instead of `--force`:

```bash
git push --force-with-lease origin branch-name
```

This prevents overwriting commits if someone else has pushed to the branch.

### Commit Message Hygiene

When using `github_sign_commit`, the commit message is preserved. If you want to update it:

```bash
git commit --amend -S  # Opens editor for message
```

## Advanced Usage

### Sign Multiple Commits

To sign multiple commits in history, use interactive rebase:

```bash
# Rebase last 3 commits
git rebase -i HEAD~3

# In the editor, change 'pick' to 'edit' for commits to sign
# Then for each commit:
git commit --amend --no-edit -S
git rebase --continue

# Force push when done
git push --force-with-lease origin <branch-name>
```

### Add Second Identity

To add another identity's key to allowed signers:

```bash
echo "another@email.com $(cat ~/.ssh/another_key.pub)" >> ~/.ssh/allowed_signers
```

### Check Current Configuration

```bash
# Show all signing-related config
git config --local --list | grep -E "(gpg|sign)"

# Check current signing key
git config --local user.signingkey

# Check if auto-signing is enabled
git config --local commit.gpgsign
```

## API Reference

### `github_setup_ssh_signing <identity>`

Configure SSH commit signing for the current repository.

**Arguments:**

- `identity` (required): `harmaalbers` or `solarharm`

**Returns:**

- `0` - Success
- `1` - Error (not in repo, invalid identity, key not found)

**Example:**

```bash
github_setup_ssh_signing harmaalbers
```

### `github_verify_signature [commit]`

Verify the signature on a commit.

**Arguments:**

- `commit` (optional): Commit hash or ref (default: `HEAD`)

**Returns:**

- `0` - Signature valid
- `1` - Signature invalid or not signed

**Example:**

```bash
github_verify_signature HEAD
github_verify_signature a51ac96
```

### `github_sign_commit`

Sign the HEAD commit by amending it.

**Returns:**

- `0` - Success
- `1` - Error (not in repo, signing not configured, amend failed)

**Warning:** Rewrites commit (changes hash). Requires force-push if already pushed.

**Example:**

```bash
github_sign_commit
git push --force-with-lease origin feature/my-branch
```

## See Also

- [GitHub SSH Signing Documentation](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification)
- [Git SSH Signing Documentation](https://git-scm.com/docs/git-config#Documentation/git-config.txt-gpgformat)
- harm-cli GitHub module: `lib/github.sh`

## Change Log

- **2025-10-23**: Initial implementation of SSH signing support
  - Added `github_setup_ssh_signing` function
  - Added `github_verify_signature` function
  - Added `github_sign_commit` function
  - Support for HarmAalbers and SolarHarm identities
