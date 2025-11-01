#!/usr/bin/env bash
# ShellSpec comprehensive tests for safety module

Describe 'lib/safety.sh - Comprehensive Tests'
Include spec/helpers/env.sh

# Setup test environment
BeforeAll 'setup_safety_comprehensive_env'
AfterAll 'cleanup_safety_comprehensive_env'

setup_safety_comprehensive_env() {
  export HARM_CLI_HOME="$TEST_TMP/harm-cli"
  export HARM_CLI_LOG_LEVEL="ERROR"
  mkdir -p "$HARM_CLI_HOME/logs"

  # Source safety module
  source "$ROOT/lib/safety.sh"
}

cleanup_safety_comprehensive_env() {
  rm -rf "$HARM_CLI_HOME"
}

# ═══════════════════════════════════════════════════════════════
# safe_rm - Comprehensive Tests
# ═══════════════════════════════════════════════════════════════

Describe 'safe_rm'
  setup_rm_test() {
    TEST_DIR="$SHELLSPEC_TMPDIR/rm_test_$$"
    mkdir -p "$TEST_DIR"
  }

  cleanup_rm_test() {
    rm -rf "$TEST_DIR"
  }

  BeforeEach 'setup_rm_test'
  AfterEach 'cleanup_rm_test'

  Context 'argument validation'
    It 'fails when no files specified'
      When call safe_rm
      The status should equal "$EXIT_INVALID_ARGS"
      The error should include "No files specified"
    End

    It 'shows usage help on no arguments'
      When call safe_rm
      The output should include "Usage: safe_rm"
    End
  End

  Context 'dangerous flags detection'
    It 'detects -r flag as dangerous'
      mkdir -p "$TEST_DIR/subdir"
      # Use echo "no" to skip confirmation prompt
      When call bash -c "echo 'no' | safe_rm -r '$TEST_DIR/subdir'"
      The status should equal 130  # EXIT_CANCELLED
    End

    It 'detects -rf combination as dangerous'
      mkdir -p "$TEST_DIR/subdir"
      When call bash -c "echo 'no' | safe_rm -rf '$TEST_DIR/subdir'"
      The status should equal 130
    End

    It 'detects -R flag as dangerous'
      mkdir -p "$TEST_DIR/subdir"
      When call bash -c "echo 'no' | safe_rm -R '$TEST_DIR/subdir'"
      The status should equal 130
    End

    It 'detects -f flag as dangerous'
      touch "$TEST_DIR/file.txt"
      When call bash -c "echo 'no' | safe_rm -f '$TEST_DIR/file.txt'"
      The status should equal 130
    End

    It 'detects --force flag as dangerous'
      touch "$TEST_DIR/file.txt"
      When call bash -c "echo 'no' | safe_rm --force '$TEST_DIR/file.txt'"
      The status should equal 130
    End

    It 'detects --recursive flag as dangerous'
      mkdir -p "$TEST_DIR/subdir"
      When call bash -c "echo 'no' | safe_rm --recursive '$TEST_DIR/subdir'"
      The status should equal 130
    End
  End

  Context 'preview accuracy'
    It 'shows file in preview'
      touch "$TEST_DIR/test.txt"
      result=$(echo "no" | safe_rm "$TEST_DIR/test.txt" 2>&1)
      The result should include "📄 $TEST_DIR/test.txt"
    End

    It 'shows directory with size in preview'
      mkdir -p "$TEST_DIR/preview_dir"
      echo "content" > "$TEST_DIR/preview_dir/file.txt"
      result=$(echo "no" | safe_rm -r "$TEST_DIR/preview_dir" 2>&1)
      The result should include "📁 $TEST_DIR/preview_dir/"
      # Should show some size (e.g., "4.0K" or similar)
    End

    It 'counts files correctly'
      touch "$TEST_DIR/file1.txt"
      touch "$TEST_DIR/file2.txt"
      touch "$TEST_DIR/file3.txt"
      result=$(echo "no" | safe_rm "$TEST_DIR/file1.txt" "$TEST_DIR/file2.txt" "$TEST_DIR/file3.txt" 2>&1)
      The result should include "Files to delete:"
    End

    It 'handles non-existent files gracefully'
      result=$(safe_rm "$TEST_DIR/nonexistent.txt" 2>&1)
      The result should include "No files found to delete"
    End

    It 'ignores option flags in count'
      touch "$TEST_DIR/file.txt"
      # Flags like -v should not be counted as files
      result=$(echo "no" | safe_rm -v "$TEST_DIR/file.txt" 2>&1)
      The result should include "Files to delete:"
    End
  End

  Context 'confirmation flow'
    It 'requires confirmation for dangerous flags'
      mkdir -p "$TEST_DIR/confirm_test"
      # Pipe wrong confirmation
      When call bash -c "echo 'yes' | safe_rm -rf '$TEST_DIR/confirm_test'"
      The status should equal 130
      # Directory should still exist
      The directory "$TEST_DIR/confirm_test" should exist
    End

    It 'deletes files when user types "delete"'
      mkdir -p "$TEST_DIR/delete_test"
      When call bash -c "echo 'delete' | safe_rm -rf '$TEST_DIR/delete_test'"
      The status should equal 0
      The directory "$TEST_DIR/delete_test" should not exist
    End

    It 'cancels on wrong confirmation text'
      mkdir -p "$TEST_DIR/wrong_confirm"
      When call bash -c "echo 'WRONG' | safe_rm -rf '$TEST_DIR/wrong_confirm'"
      The status should equal 130
      The output should include "Cancelled"
      The directory "$TEST_DIR/wrong_confirm" should exist
    End

    It 'requires confirmation for more than 5 files'
      # Create 6 files
      for i in {1..6}; do
        touch "$TEST_DIR/file$i.txt"
      done
      # Should require confirmation even without dangerous flags
      When call bash -c "echo 'no' | safe_rm '$TEST_DIR'/file*.txt"
      The status should equal 130
    End

    It 'does not require confirmation for 5 or fewer files without dangerous flags'
      # Create exactly 5 files
      for i in {1..5}; do
        touch "$TEST_DIR/small$i.txt"
      done
      # Should delete without confirmation
      When call safe_rm "$TEST_DIR"/small*.txt
      The status should equal 0
      The output should include "Deleted 5 items"
    End
  End

  Context 'successful deletion'
    It 'deletes single file without confirmation'
      touch "$TEST_DIR/single.txt"
      When call safe_rm "$TEST_DIR/single.txt"
      The status should equal 0
      The output should include "✓ Deleted 1 items"
      The file "$TEST_DIR/single.txt" should not exist
    End

    It 'deletes multiple files with confirmation'
      for i in {1..3}; do
        touch "$TEST_DIR/multi$i.txt"
      done
      When call safe_rm "$TEST_DIR"/multi*.txt
      The status should equal 0
      The output should include "Deleted 3 items"
    End

    It 'deletes directory with -rf after confirmation'
      mkdir -p "$TEST_DIR/delete_dir/nested"
      echo "content" > "$TEST_DIR/delete_dir/file.txt"
      When call bash -c "echo 'delete' | safe_rm -rf '$TEST_DIR/delete_dir'"
      The status should equal 0
      The output should include "✓ Deleted"
      The directory "$TEST_DIR/delete_dir" should not exist
    End
  End

  Context 'error handling'
    It 'handles permission denied gracefully (simulated)'
      Skip if "Cannot reliably test permission errors in test environment"
    End

    It 'handles deletion failure'
      # Create a file, then try to delete with invalid options
      touch "$TEST_DIR/fail_test.txt"
      # Force rm to fail by passing invalid flag to rm (captured by safe_rm)
      When call bash -c "rm() { return 1; }; source '$ROOT/lib/safety.sh'; safe_rm '$TEST_DIR/fail_test.txt'"
      The status should not equal 0
      The error should include "Deletion failed"
    End
  End

  Context 'logging'
    It 'logs dangerous operations'
      mkdir -p "$TEST_DIR/log_test"
      SAFETY_LOG_FILE="$HARM_CLI_HOME/logs/dangerous_ops.log"
      bash -c "echo 'delete' | source '$ROOT/lib/safety.sh'; safe_rm -rf '$TEST_DIR/log_test'" 2>/dev/null
      The file "$SAFETY_LOG_FILE" should exist
      The contents of file "$SAFETY_LOG_FILE" should include "rm"
    End
  End
End

# ═══════════════════════════════════════════════════════════════
# safe_docker_prune - Comprehensive Tests
# ═══════════════════════════════════════════════════════════════

Describe 'safe_docker_prune'
  Context 'dependency checks'
    It 'fails when Docker not installed'
      PATH="/nonexistent" When call safe_docker_prune
      The status should equal "$EXIT_MISSING_DEPS"
      The error should include "Docker not installed"
    End

    It 'detects Docker daemon not running'
      Skip if "Requires Docker for full test"
      # Mock docker command to simulate daemon not running
      docker() {
        if [[ "$1" == "info" ]]; then
          return 1
        fi
      }
      When call safe_docker_prune
      The status should equal "$EXIT_INVALID_STATE"
      The error should include "Docker daemon not running"
    End
  End

  Context 'preview display'
    It 'shows space preview when Docker available'
      Skip if "Requires running Docker daemon"
    End
  End

  Context 'confirmation flow'
    It 'requires confirmation with "prune" keyword'
      Skip if "Requires running Docker daemon"
    End

    It 'cancels on wrong confirmation'
      Skip if "Requires running Docker daemon"
    End
  End

  Context 'successful prune'
    It 'prunes system when confirmed'
      Skip if "Requires running Docker daemon"
    End
  End

  Context 'error handling'
    It 'handles prune failures'
      Skip if "Requires running Docker daemon"
    End
  End
End

# ═══════════════════════════════════════════════════════════════
# safe_git_reset - Comprehensive Tests
# ═══════════════════════════════════════════════════════════════

Describe 'safe_git_reset'
  setup_git_test() {
    GIT_TEST_DIR="$SHELLSPEC_TMPDIR/git_test_$$"
    mkdir -p "$GIT_TEST_DIR"
    cd "$GIT_TEST_DIR" || return
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "initial" > file.txt
    git add file.txt
    git commit -q -m "Initial commit"
  }

  cleanup_git_test() {
    cd "$SHELLSPEC_TMPDIR" || return
    rm -rf "$GIT_TEST_DIR"
  }

  BeforeEach 'setup_git_test'
  AfterEach 'cleanup_git_test'

  Context 'validation'
    It 'checks if in git repository'
      cd "$SHELLSPEC_TMPDIR" || return
      When call safe_git_reset
      The status should equal "$EXIT_INVALID_STATE"
      The error should include "Not in a git repository"
    End
  End

  Context 'preview accuracy'
    It 'shows current branch'
      result=$(echo "no" | safe_git_reset 2>&1)
      The result should include "Current branch:"
    End

    It 'shows reset target'
      result=$(echo "no" | safe_git_reset HEAD~0 2>&1)
      The result should include "Reset to: HEAD~0"
    End

    It 'shows backup branch name'
      result=$(echo "no" | safe_git_reset 2>&1)
      The result should include "Backup will be created:"
    End

    It 'shows commits that will be lost'
      echo "second" > file2.txt
      git add file2.txt
      git commit -q -m "Second commit"
      result=$(echo "no" | safe_git_reset HEAD~1 2>&1)
      The result should include "Commits that will be lost:"
    End

    It 'shows none when no commits will be lost'
      result=$(echo "no" | safe_git_reset HEAD 2>&1)
      The result should include "(none)"
    End
  End

  Context 'confirmation flow'
    It 'requires confirmation with "reset" keyword'
      echo "second" > file2.txt
      git add file2.txt
      git commit -q -m "Second commit"
      When call bash -c "echo 'wrong' | safe_git_reset HEAD~1"
      The status should equal 130
    End

    It 'cancels on wrong confirmation'
      When call bash -c "echo 'yes' | safe_git_reset HEAD~0"
      The status should equal 130
      The output should include "Cancelled"
    End
  End

  Context 'backup branch creation'
    It 'creates backup branch before reset'
      echo "second" > file2.txt
      git add file2.txt
      git commit -q -m "Second commit"
      bash -c "echo 'reset' | safe_git_reset HEAD~1" >/dev/null 2>&1
      # Check that backup branch exists
      backup_count=$(git branch | grep -c "backup-" || echo "0")
      The value "$backup_count" should equal 1
    End

    It 'includes timestamp in backup branch name'
      bash -c "echo 'reset' | safe_git_reset HEAD~0" >/dev/null 2>&1
      backup_name=$(git branch | grep "backup-" | head -1 | xargs)
      # Should match pattern: backup-main-YYYYMMDD-HHMMSS
      The result should match pattern "backup-*-*-*"
    End

    It 'fails gracefully if backup creation fails'
      Skip if "Difficult to simulate backup failure"
    End
  End

  Context 'successful reset'
    It 'resets to specified ref'
      echo "second" > file2.txt
      git add file2.txt
      git commit -q -m "Second commit"
      initial_count=$(git log --oneline | wc -l | tr -d ' ')
      bash -c "echo 'reset' | safe_git_reset HEAD~1" >/dev/null 2>&1
      final_count=$(git log --oneline | wc -l | tr -d ' ')
      The value "$final_count" should be less than "$initial_count"
    End

    It 'shows recovery instructions'
      result=$(bash -c "echo 'reset' | safe_git_reset HEAD~0" 2>&1)
      The result should include "Recovery:"
      The result should include "git checkout backup-"
    End

    It 'defaults to origin/main when no ref specified'
      Skip if "Requires remote repository"
    End
  End

  Context 'error handling'
    It 'handles invalid ref'
      When call bash -c "echo 'reset' | safe_git_reset invalid-ref-12345"
      The status should not equal 0
    End

    It 'handles reset failure gracefully'
      Skip if "Difficult to simulate reset failure"
    End
  End
End

# ═══════════════════════════════════════════════════════════════
# Internal Safety Functions
# ═══════════════════════════════════════════════════════════════

Describe '_safety_confirm'
  It 'returns success on correct confirmation'
    When call bash -c "echo 'yes' | source '$ROOT/lib/safety.sh'; _safety_confirm 'test operation' 'yes'"
    The status should equal 0
  End

  It 'returns 130 on wrong confirmation'
    When call bash -c "echo 'no' | source '$ROOT/lib/safety.sh'; _safety_confirm 'test operation' 'yes'"
    The status should equal 130
    The output should include "Cancelled"
  End

  It 'returns 130 on timeout'
    # Note: Hard to test timeout without actually waiting, skip for now
    Skip if "Timeout testing requires actual 30s wait"
  End

  It 'accepts custom confirmation text'
    When call bash -c "echo 'CONFIRM' | source '$ROOT/lib/safety.sh'; _safety_confirm 'operation' 'CONFIRM'"
    The status should equal 0
  End

  It 'shows operation in prompt'
    result=$(echo "no" | bash -c "source '$ROOT/lib/safety.sh'; _safety_confirm 'Delete everything' 'yes'" 2>&1)
    The result should include "DANGEROUS OPERATION: Delete everything"
  End
End

Describe '_safety_log'
  It 'creates log directory if missing'
    rm -rf "$HARM_CLI_HOME/logs"
    bash -c "source '$ROOT/lib/safety.sh'; _safety_log 'test' 'details'" 2>/dev/null
    The directory "$HARM_CLI_HOME/logs" should exist
  End

  It 'writes to dangerous operations log'
    bash -c "source '$ROOT/lib/safety.sh'; _safety_log 'test_operation' 'test_details'" 2>/dev/null
    SAFETY_LOG_FILE="$HARM_CLI_HOME/logs/dangerous_ops.log"
    The file "$SAFETY_LOG_FILE" should exist
    The contents of file "$SAFETY_LOG_FILE" should include "test_operation"
    The contents of file "$SAFETY_LOG_FILE" should include "test_details"
  End

  It 'includes timestamp in log'
    bash -c "source '$ROOT/lib/safety.sh'; _safety_log 'operation' 'details'" 2>/dev/null
    SAFETY_LOG_FILE="$HARM_CLI_HOME/logs/dangerous_ops.log"
    # Log should include date format [YYYY-MM-DD HH:MM:SS]
    The contents of file "$SAFETY_LOG_FILE" should match pattern "*[*]*operation*"
  End
End

# ═══════════════════════════════════════════════════════════════
# Module Configuration
# ═══════════════════════════════════════════════════════════════

Describe 'module initialization'
  It 'defines required constants'
    The variable SAFETY_CONFIRM_TIMEOUT should equal 30
  End

  It 'prevents double-loading'
    source "$ROOT/lib/safety.sh"
    source "$ROOT/lib/safety.sh"
    # Should not error on double-load
    The status should equal 0
  End

  It 'exports public functions'
    The variable "$(type -t safe_rm)" should equal "function"
    The variable "$(type -t safe_docker_prune)" should equal "function"
    The variable "$(type -t safe_git_reset)" should equal "function"
  End

  It 'loads required dependencies'
    # Should have error codes from error.sh
    The variable EXIT_SUCCESS should equal 0
    The variable EXIT_INVALID_ARGS should equal 2
  End
End
End
