#!/usr/bin/env bash
# shellcheck disable=SC2207
# Bash completion for harm-cli
# Install: source this file or let harm-cli init handle it
# Note: SC2207 disabled - compgen pattern is standard for bash completion

_harm_cli_completions() {
  local cur prev words cword
  _init_completion || return

  # Get current word and previous word
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"

  # Top-level commands
  local commands="version help doctor init work break goal activity insights focus log learn discover unused cheat md ai git proj docker cleanup python gcloud health safe"

  # Global options
  local global_opts="--help --version --format --quiet --debug --minimal"

  # Command-specific completion
  case "${COMP_WORDS[1]}" in
    work)
      case "$prev" in
        work)
          local work_cmds="start stop status reset stats violations reset-violations set-mode strict"
          COMPREPLY=($(compgen -W "$work_cmds" -- "$cur"))
          ;;
        stats)
          local periods="today week month all"
          COMPREPLY=($(compgen -W "$periods" -- "$cur"))
          ;;
        set-mode)
          local modes="strict moderate coaching off"
          COMPREPLY=($(compgen -W "$modes" -- "$cur"))
          ;;
        strict)
          COMPREPLY=($(compgen -W "on off" -- "$cur"))
          ;;
        *)
          COMPREPLY=()
          ;;
      esac
      return 0
      ;;
    break)
      case "$prev" in
        break)
          local break_cmds="start stop status scheduled"
          COMPREPLY=($(compgen -W "$break_cmds" -- "$cur"))
          ;;
        scheduled)
          local scheduled_cmds="start stop status"
          COMPREPLY=($(compgen -W "$scheduled_cmds" -- "$cur"))
          ;;
        *)
          COMPREPLY=()
          ;;
      esac
      return 0
      ;;
    goal)
      case "$prev" in
        goal)
          local goal_cmds="set show progress complete reopen clear ai-analyze ai-plan ai-next ai-check ai-context link-github sync-github"
          COMPREPLY=($(compgen -W "$goal_cmds" -- "$cur"))
          ;;
        *)
          COMPREPLY=()
          ;;
      esac
      return 0
      ;;
    activity)
      case "$prev" in
        activity)
          local activity_cmds="query stats clear cleanup help"
          COMPREPLY=($(compgen -W "$activity_cmds" -- "$cur"))
          ;;
        query | stats)
          local periods="today yesterday week month all"
          COMPREPLY=($(compgen -W "$periods" -- "$cur"))
          ;;
        *)
          COMPREPLY=()
          ;;
      esac
      return 0
      ;;
    insights)
      case "$prev" in
        insights)
          local insights_cmds="show export json daily"
          COMPREPLY=($(compgen -W "$insights_cmds" -- "$cur"))
          ;;
        show)
          local periods="today yesterday week month all"
          COMPREPLY=($(compgen -W "$periods" -- "$cur"))
          ;;
        *)
          COMPREPLY=()
          ;;
      esac
      return 0
      ;;
    focus)
      local focus_cmds="check pomodoro pomodoro-stop pomodoro-status"
      COMPREPLY=($(compgen -W "$focus_cmds" -- "$cur"))
      return 0
      ;;
    log)
      case "$prev" in
        log)
          local log_cmds="tail search clear stats stream"
          COMPREPLY=($(compgen -W "$log_cmds" -- "$cur"))
          ;;
        *)
          COMPREPLY=()
          ;;
      esac
      return 0
      ;;
    learn)
      case "$prev" in
        learn)
          local learn_cmds="list git docker python bash productivity harm-cli"
          COMPREPLY=($(compgen -W "$learn_cmds" -- "$cur"))
          ;;
        *)
          COMPREPLY=()
          ;;
      esac
      return 0
      ;;
    discover)
      local discover_cmds="features unused"
      COMPREPLY=($(compgen -W "$discover_cmds" -- "$cur"))
      return 0
      ;;
    unused)
      # No subcommands, just runs
      COMPREPLY=()
      return 0
      ;;
    cheat)
      # Cheat takes a query string, no completion
      COMPREPLY=()
      return 0
      ;;
    md)
      case "$prev" in
        md)
          local md_cmds="render render-pipe tui suggest-tools"
          COMPREPLY=($(compgen -W "$md_cmds" -- "$cur"))
          ;;
        render)
          # Complete markdown files
          COMPREPLY=($(compgen -f -X '!*.md' -- "$cur"))
          ;;
        *)
          COMPREPLY=()
          ;;
      esac
      return 0
      ;;
    cleanup)
      case "$prev" in
        cleanup)
          local cleanup_cmds="scan delete preview"
          COMPREPLY=($(compgen -W "$cleanup_cmds" -- "$cur"))
          ;;
        *)
          COMPREPLY=()
          ;;
      esac
      return 0
      ;;
    ai)
      case "$prev" in
        ai)
          local ai_cmds="query review explain-error daily --help --setup --no-cache --context"
          COMPREPLY=($(compgen -W "$ai_cmds" -- "$cur"))
          ;;
        daily)
          local ai_daily_opts="--yesterday --week --month"
          COMPREPLY=($(compgen -W "$ai_daily_opts" -- "$cur"))
          ;;
        review)
          local ai_review_opts="--staged --unstaged"
          COMPREPLY=($(compgen -W "$ai_review_opts" -- "$cur"))
          ;;
        *)
          # Default: no completion
          COMPREPLY=()
          ;;
      esac
      return 0
      ;;
    git)
      local git_cmds="status commit-msg --help"
      COMPREPLY=($(compgen -W "$git_cmds" -- "$cur"))
      return 0
      ;;
    proj)
      case "$prev" in
        proj)
          local proj_cmds="list add remove switch --help"
          COMPREPLY=($(compgen -W "$proj_cmds" -- "$cur"))
          ;;
        add)
          # Directory completion for proj add
          COMPREPLY=($(compgen -d -- "$cur"))
          ;;
        switch | remove)
          # Complete with project names (if registry exists)
          if [[ -f "${HARM_CLI_HOME:-$HOME/.harm-cli}/projects/registry.jsonl" ]]; then
            local projects
            projects=$(jq -r '.name' "${HARM_CLI_HOME:-$HOME/.harm-cli}/projects/registry.jsonl" 2>/dev/null || echo "")
            COMPREPLY=($(compgen -W "$projects" -- "$cur"))
          fi
          ;;
        *)
          COMPREPLY=()
          ;;
      esac
      return 0
      ;;
    docker)
      case "$prev" in
        docker)
          local docker_cmds="up down status logs shell health --help"
          COMPREPLY=($(compgen -W "$docker_cmds" -- "$cur"))
          ;;
        logs | shell)
          # Complete with service names from compose file
          if command -v docker >/dev/null 2>&1; then
            local compose_file=""
            for f in compose.yaml docker-compose.yml docker-compose.yaml; do
              [[ -f "$f" ]] && compose_file="$f" && break
            done
            if [[ -n "$compose_file" ]]; then
              local services
              services=$(docker compose -f "$compose_file" config --services 2>/dev/null || echo "")
              COMPREPLY=($(compgen -W "$services" -- "$cur"))
            fi
          fi
          ;;
        *)
          COMPREPLY=()
          ;;
      esac
      return 0
      ;;
    python)
      local python_cmds="status test lint format --help"
      COMPREPLY=($(compgen -W "$python_cmds" -- "$cur"))
      return 0
      ;;
    gcloud)
      local gcloud_cmds="status --help"
      COMPREPLY=($(compgen -W "$gcloud_cmds" -- "$cur"))
      return 0
      ;;
    health)
      local health_cats="all system git docker python ai --quick --json --help"
      COMPREPLY=($(compgen -W "$health_cats" -- "$cur"))
      return 0
      ;;
    safe)
      local safe_cmds="rm docker-prune git-reset"
      COMPREPLY=($(compgen -W "$safe_cmds" -- "$cur"))
      return 0
      ;;
    --format)
      COMPREPLY=($(compgen -W "text json" -- "$cur"))
      return 0
      ;;
    *)
      # Top-level completion
      if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "$global_opts" -- "$cur"))
      else
        COMPREPLY=($(compgen -W "$commands" -- "$cur"))
      fi
      return 0
      ;;
  esac
}

# Register completion
complete -F _harm_cli_completions harm-cli
