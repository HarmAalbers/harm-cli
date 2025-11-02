#!/usr/bin/env bash
# shellcheck shell=bash
# work_stats.sh - Statistics and reporting for harm-cli
#
# Part of SOLID refactoring: Single Responsibility = Stats & reporting
#
# This module provides:
# - Work statistics (today/week/month)
# - Break compliance analysis
# - Historical data queries
# - JSON/text output formats
#
# Dependencies:
# - lib/work_timers.sh (for work_get_pomodoro_count)
# - lib/work_session.sh (for work_is_active, work_status)
# - lib/options.sh, lib/logging.sh, lib/util.sh, lib/common.sh

set -Eeuo pipefail
IFS=$'\n\t'

[[ -n "${_HARM_WORK_STATS_LOADED:-}" ]] && return 0

# Performance optimization: Reuse already-computed directory from parent module
if [[ -n "${WORK_SCRIPT_DIR:-}" ]]; then
  WORK_STATS_SCRIPT_DIR="$WORK_SCRIPT_DIR"
else
  WORK_STATS_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
fi
readonly WORK_STATS_SCRIPT_DIR

# shellcheck source=lib/common.sh
source "$WORK_STATS_SCRIPT_DIR/common.sh"
# shellcheck source=lib/logging.sh
source "$WORK_STATS_SCRIPT_DIR/logging.sh"
# shellcheck source=lib/util.sh
source "$WORK_STATS_SCRIPT_DIR/util.sh"
# shellcheck source=lib/options.sh
source "$WORK_STATS_SCRIPT_DIR/options.sh"
# shellcheck source=lib/work_timers.sh
source "$WORK_STATS_SCRIPT_DIR/work_timers.sh"
# shellcheck source=lib/work_session.sh
source "$WORK_STATS_SCRIPT_DIR/work_session.sh"

work_stats_today() {
  local today
  today=$(date '+%Y-%m-%d')
  local current_month
  current_month=$(date '+%Y-%m')
  local archive_file="${HARM_WORK_DIR}/sessions_${current_month}.jsonl"

  if [[ ! -f "$archive_file" ]]; then
    if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
      jq -n --arg date "$today" '{date: $date, sessions: 0, total_duration_seconds: 0, pomodoros: 0}'
    else
      echo "No sessions recorded for today ($today)"
    fi
    return 0
  fi

  local sessions total_duration pomodoros
  read -r sessions total_duration pomodoros < <(
    jq -r --arg date "$today" '
      [., .] |
      (map(select(.start_time | startswith($date))) | length),
      (map(select(.start_time | startswith($date)) | .duration_seconds // 0) | add // 0),
      (map(select(.start_time | startswith($date)) | .pomodoro_count // 0) | max // 0)
    ' "$archive_file" | tr ',' '\t'
  )

  # Ensure valid numeric defaults for jq --argjson
  sessions="${sessions:-0}"
  total_duration="${total_duration:-0}"
  pomodoros="${pomodoros:-0}"

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --arg date "$today" \
      --argjson sessions "$sessions" \
      --argjson duration "$total_duration" \
      --argjson pomodoros "$pomodoros" \
      '{date: $date, sessions: $sessions, total_duration_seconds: $duration, pomodoros: $pomodoros}'
  else
    local formatted
    formatted="$(format_duration "${total_duration:-0}")"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Today's Work Statistics ($today)"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  🍅 Pomodoros completed: ${pomodoros:-0}"
    echo "  📊 Total sessions: ${sessions:-0}"
    echo "  ⏱  Total work time: $formatted"
    echo ""
  fi
}

work_stats_week() {
  local week_start
  week_start=$(date -v-mon '+%Y-%m-%d' 2>/dev/null || date -d 'last monday' '+%Y-%m-%d' 2>/dev/null)
  local current_month
  current_month=$(date '+%Y-%m')
  local archive_file="${HARM_WORK_DIR}/sessions_${current_month}.jsonl"

  if [[ ! -f "$archive_file" ]]; then
    if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
      jq -n --arg week_start "$week_start" '{week_start: $week_start, sessions: 0, total_duration_seconds: 0, pomodoros: 0}'
    else
      echo "No sessions recorded for this week"
    fi
    return 0
  fi

  local sessions total_duration pomodoros
  sessions=$(jq -r --arg start "$week_start" 'select(.start_time >= $start)' "$archive_file" | wc -l | tr -d ' ')
  total_duration=$(jq -r --arg start "$week_start" 'select(.start_time >= $start) | .duration_seconds // 0' "$archive_file" | awk '{sum+=$1} END {print sum+0}')
  pomodoros=$(jq -r --arg start "$week_start" 'select(.start_time >= $start) | .pomodoro_count // 0' "$archive_file" | sort -n | tail -1)

  # Ensure valid numeric defaults for jq --argjson
  sessions="${sessions:-0}"
  total_duration="${total_duration:-0}"
  pomodoros="${pomodoros:-0}"

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --arg week_start "$week_start" \
      --argjson sessions "$sessions" \
      --argjson duration "$total_duration" \
      --argjson pomodoros "$pomodoros" \
      '{week_start: $week_start, sessions: $sessions, total_duration_seconds: $duration, pomodoros: $pomodoros}'
  else
    local formatted
    formatted="$(format_duration "${total_duration:-0}")"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  This Week's Work Statistics (since $week_start)"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  🍅 Pomodoros completed: ${pomodoros:-0}"
    echo "  📊 Total sessions: ${sessions:-0}"
    echo "  ⏱  Total work time: $formatted"
    echo ""
  fi
}

work_stats_month() {
  local current_month
  current_month=$(date '+%Y-%m')
  local archive_file="${HARM_WORK_DIR}/sessions_${current_month}.jsonl"

  if [[ ! -f "$archive_file" ]]; then
    if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
      jq -n --arg month "$current_month" '{month: $month, sessions: 0, total_duration_seconds: 0, pomodoros: 0}'
    else
      echo "No sessions recorded for $current_month"
    fi
    return 0
  fi

  local sessions total_duration pomodoros
  sessions=$(wc -l <"$archive_file" | tr -d ' ')
  total_duration=$(jq -r '.duration_seconds // 0' "$archive_file" | awk '{sum+=$1} END {print sum+0}')
  pomodoros=$(jq -r '.pomodoro_count // 0' "$archive_file" | sort -n | tail -1)

  # Ensure valid numeric defaults for jq --argjson
  sessions="${sessions:-0}"
  total_duration="${total_duration:-0}"
  pomodoros="${pomodoros:-0}"

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --arg month "$current_month" \
      --argjson sessions "$sessions" \
      --argjson duration "$total_duration" \
      --argjson pomodoros "$pomodoros" \
      '{month: $month, sessions: $sessions, total_duration_seconds: $duration, pomodoros: $pomodoros}'
  else
    local formatted
    formatted="$(format_duration "${total_duration:-0}")"
    local avg_per_day=$((${total_duration:-0} / $(date '+%d')))
    local avg_formatted
    avg_formatted="$(format_duration "${avg_per_day:-0}")"

    echo "═══════════════════════════════════════════════════════════════"
    echo "  Monthly Work Statistics ($current_month)"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  🍅 Pomodoros completed: $pomodoros"
    echo "  📊 Total sessions: $sessions"
    echo "  ⏱  Total work time: $formatted"
    echo "  📈 Average per day: $avg_formatted"
    echo ""
  fi
}

work_stats() {
  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    local today week month
    today=$(work_stats_today)
    week=$(work_stats_week)
    month=$(work_stats_month)

    jq -n \
      --argjson today "$today" \
      --argjson week "$week" \
      --argjson month "$month" \
      '{today: $today, week: $week, month: $month}'
  else
    work_stats_today
    work_stats_week
    work_stats_month

    local current_count
    current_count=$(work_get_pomodoro_count)
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Current Session"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  🎯 Current pomodoro count: $current_count"
    echo ""

    if work_is_active; then
      echo "  ✅ Work session is ACTIVE"
      work_status
    else
      echo "  ⏸  No active work session"
    fi

    echo ""
  fi
}

work_break_compliance() {
  local current_month
  current_month=$(date '+%Y-%m')
  local breaks_file="${HARM_WORK_DIR}/breaks_${current_month}.jsonl"
  local sessions_file="${HARM_WORK_DIR}/sessions_${current_month}.jsonl"

  if [[ ! -f "$breaks_file" ]]; then
    if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
      jq -n '{breaks_taken: 0, breaks_expected: 0, completion_rate: 0, message: "No break data available"}'
    else
      echo "No break data available for this month."
      echo "Enable break tracking: harm-cli options set strict_track_breaks 1"
    fi
    return 0
  fi

  local work_sessions=0
  if [[ -f "$sessions_file" ]]; then
    work_sessions=$(wc -l <"$sessions_file" | tr -d ' ')
  fi

  local breaks_taken
  breaks_taken=$(wc -l <"$breaks_file" | tr -d ' ')

  local breaks_completed
  breaks_completed=$(jq -r 'select(.completed_fully == true)' "$breaks_file" | wc -l | tr -d ' ')

  local avg_duration avg_planned
  avg_duration=$(jq -r '.duration_seconds // 0' "$breaks_file" | awk '{sum+=$1; count++} END {if(count>0) print int(sum/count); else print 0}')
  avg_planned=$(jq -r '.planned_duration_seconds // 0' "$breaks_file" | awk '{sum+=$1; count++} END {if(count>0) print int(sum/count); else print 0}')

  local completion_rate=0
  if ((breaks_taken > 0)); then
    completion_rate=$(((breaks_completed * 100) / breaks_taken))
  fi

  local compliance_rate=0
  if ((work_sessions > 0)); then
    compliance_rate=$(((breaks_taken * 100) / work_sessions))
  fi

  if [[ "${HARM_CLI_FORMAT:-text}" == "json" ]]; then
    jq -n \
      --argjson work_sessions "$work_sessions" \
      --argjson breaks_taken "$breaks_taken" \
      --argjson breaks_completed "$breaks_completed" \
      --argjson completion_rate "$completion_rate" \
      --argjson compliance_rate "$compliance_rate" \
      --argjson avg_duration "$avg_duration" \
      --argjson avg_planned "$avg_planned" \
      '{
        work_sessions: $work_sessions,
        breaks_taken: $breaks_taken,
        breaks_completed_fully: $breaks_completed,
        completion_rate_percent: $completion_rate,
        compliance_rate_percent: $compliance_rate,
        avg_break_duration_seconds: $avg_duration,
        avg_planned_duration_seconds: $avg_planned
      }'
  else
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Break Compliance Report ($current_month)"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  📊 Work sessions: $work_sessions"
    echo "  ☕ Breaks taken: $breaks_taken"
    echo "  ✅ Breaks completed fully: $breaks_completed"
    echo ""
    echo "  📈 Compliance rate: ${compliance_rate}%"
    echo "  📈 Completion rate: ${completion_rate}%"
    echo ""

    if ((avg_planned > 0)); then
      local avg_min=$((avg_duration / 60))
      local planned_min=$((avg_planned / 60))
      echo "  ⏱  Average break: ${avg_min} min (target: ${planned_min} min)"
    fi

    echo ""

    if ((compliance_rate < 50)); then
      echo "  ⚠️  Warning: Less than half of work sessions followed by breaks"
      echo "     Consider enabling: strict_require_break"
    elif ((completion_rate < 50)); then
      echo "  ⚠️  Warning: Many breaks stopped early"
      echo "     Try to complete full break duration for better recovery"
    elif ((compliance_rate >= 80 && completion_rate >= 80)); then
      echo "  🎉 Excellent! You're maintaining good work-break balance"
    fi

    echo ""
  fi
}

readonly _HARM_WORK_STATS_LOADED=1
export _HARM_WORK_STATS_LOADED
