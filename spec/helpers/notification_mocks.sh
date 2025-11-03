#!/usr/bin/env bash
# spec/helpers/notification_mocks.sh - Notification system mocking
#
# Provides:
# - Mock osascript (macOS AppleScript/notifications)
# - Mock notify-send (Linux notifications)
# - Mock paplay (Linux sound)
# - Notification verification helpers
#
# Usage:
#   source spec/helpers/notification_mocks.sh
#   mock_osascript <<EOF
#     display notification "message" with title "title"
#   EOF
#   mock_notification_was_sent "Pomodoro Complete"

# Prevent multiple loading
[[ -n "${_NOTIFICATION_MOCKS_LOADED:-}" ]] && return 0

# Ensure core mocks are loaded
if [[ -z "${_MOCKS_LOADED:-}" ]]; then
  HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=spec/helpers/mocks.sh
  source "${HELPER_DIR}/mocks.sh"
fi

# Notifications log
MOCK_NOTIFICATIONS_LOG="${MOCK_STATE_DIR}/notifications.log"
: > "$MOCK_NOTIFICATIONS_LOG"

# mock_osascript: Mock version of osascript (macOS AppleScript)
#
# Description:
#   Mocks osascript to prevent actual GUI notifications.
#   Parses AppleScript and logs notification details.
#
# Arguments:
#   Same as osascript (typically reads from stdin)
#
# Examples:
#   mock_osascript <<EOF
#     display notification "Break time!" with title "Pomodoro"
#   EOF
mock_osascript() {
  mock_record_call "osascript" "$@"

  # Read AppleScript from stdin if heredoc, otherwise from args
  local script=""
  if [[ ! -t 0 ]]; then
    script=$(cat)
  else
    script="$*"
  fi

  # Log the raw script
  echo "$(command date +%s)|osascript|${script}" >> "$MOCK_NOTIFICATIONS_LOG"

  # Parse notification if present
  if [[ "$script" == *"display notification"* ]]; then
    # Extract message and title using basic grep/cut
    # Format: display notification "message" with title "title"
    local message=""
    local title=""

    # Extract message (between first pair of quotes)
    if [[ "$script" =~ \"([^\"]+)\" ]]; then
      message="${BASH_REMATCH[1]}"
    fi

    # Extract title (after "with title")
    if [[ "$script" =~ with\ title\ \"([^\"]+)\" ]]; then
      title="${BASH_REMATCH[1]}"
    fi

    # Log parsed notification
    echo "NOTIFICATION|${title}|${message}" >> "$MOCK_NOTIFICATIONS_LOG"
  fi

  # Always succeed
  return 0
}

# mock_notify_send: Mock version of notify-send (Linux notifications)
#
# Description:
#   Mocks notify-send to prevent actual desktop notifications.
#
# Arguments:
#   $1 - title: Notification title
#   $2 - message: Notification message
#
# Examples:
#   mock_notify_send "Pomodoro Complete" "Time for a break!"
mock_notify_send() {
  mock_record_call "notify-send" "$@"

  local title="${1:-}"
  local message="${2:-}"

  # Log the notification
  echo "$(command date +%s)|notify-send|${title}|${message}" >> "$MOCK_NOTIFICATIONS_LOG"
  echo "NOTIFICATION|${title}|${message}" >> "$MOCK_NOTIFICATIONS_LOG"

  return 0
}

# mock_paplay: Mock version of paplay (Linux sound player)
#
# Description:
#   Mocks paplay to prevent actual sound playback.
#
# Arguments:
#   Same as paplay
#
# Examples:
#   mock_paplay /usr/share/sounds/notification.oga
mock_paplay() {
  mock_record_call "paplay" "$@"
  echo "$(command date +%s)|paplay|$*" >> "$MOCK_NOTIFICATIONS_LOG"
  return 0
}

# mock_notification_was_sent: Check if notification was sent
#
# Description:
#   Searches notification log for specific text.
#   Matches title or message.
#
# Arguments:
#   $1 - pattern: Text to search for
#
# Returns:
#   0 - Notification found
#   1 - Notification not found
#
# Examples:
#   mock_notification_was_sent "Pomodoro Complete"
#   mock_notification_was_sent "Break time"
mock_notification_was_sent() {
  local pattern="${1:?mock_notification_was_sent requires pattern}"
  grep -q "$pattern" "$MOCK_NOTIFICATIONS_LOG" 2>/dev/null
}

# mock_notification_count: Count total notifications sent
#
# Outputs:
#   Number of notifications sent
#
# Examples:
#   count=$(mock_notification_count)
#   echo "$count notifications sent"
mock_notification_count() {
  grep -c "^NOTIFICATION|" "$MOCK_NOTIFICATIONS_LOG" 2>/dev/null || echo "0"
}

# mock_notification_get_last: Get last notification details
#
# Outputs:
#   Last notification in format: "TITLE|MESSAGE"
#
# Examples:
#   last=$(mock_notification_get_last)
#   echo "Last notification: $last"
mock_notification_get_last() {
  grep "^NOTIFICATION|" "$MOCK_NOTIFICATIONS_LOG" | tail -1 | cut -d'|' -f2-
}

# mock_notification_get_last_title: Get last notification title
#
# Outputs:
#   Title of last notification
mock_notification_get_last_title() {
  grep "^NOTIFICATION|" "$MOCK_NOTIFICATIONS_LOG" | tail -1 | cut -d'|' -f2
}

# mock_notification_get_last_message: Get last notification message
#
# Outputs:
#   Message of last notification
mock_notification_get_last_message() {
  grep "^NOTIFICATION|" "$MOCK_NOTIFICATIONS_LOG" | tail -1 | cut -d'|' -f3
}

# mock_notification_clear: Clear notification log
#
# Description:
#   Clears all recorded notifications.
#
# Examples:
#   mock_notification_clear
mock_notification_clear() {
  : > "$MOCK_NOTIFICATIONS_LOG"
}

# mock_notification_dump: Dump all notifications (for debugging)
#
# Outputs:
#   All recorded notifications
mock_notification_dump() {
  if [[ -f "$MOCK_NOTIFICATIONS_LOG" ]]; then
    grep "^NOTIFICATION|" "$MOCK_NOTIFICATIONS_LOG"
  else
    echo "No notifications recorded"
  fi
}

# Export mock functions
export -f mock_osascript
export -f mock_notify_send
export -f mock_paplay
export -f mock_notification_was_sent
export -f mock_notification_count
export -f mock_notification_get_last
export -f mock_notification_get_last_title
export -f mock_notification_get_last_message
export -f mock_notification_clear
export -f mock_notification_dump

# Export state
export MOCK_NOTIFICATIONS_LOG

# Mark as loaded
readonly _NOTIFICATION_MOCKS_LOADED=1
export _NOTIFICATION_MOCKS_LOADED
