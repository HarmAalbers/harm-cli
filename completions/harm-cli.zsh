#compdef harm-cli
# shellcheck shell=bash disable=SC1087,SC2128,SC2086,SC2206,SC2296

# Zsh completion for harm-cli
# Install: Add completions dir to fpath and run compinit
# Or let harm-cli installer handle it

_harm_cli() {
  local curcontext="$curcontext" state line
  typeset -A opt_args

  # Global options
  local -a global_opts
  global_opts=(
    '(-h --help)'{-h,--help}'[Show help message]'
    '(-v --version)'{-v,--version}'[Show version information]'
    '(-F --format)'{-F,--format}'[Output format]:format:(text json)'
    '(-q --quiet)'{-q,--quiet}'[Suppress non-error output]'
    '(-d --debug)'{-d,--debug}'[Enable debug output]'
  )

  # Top-level commands
  local -a commands
  commands=(
    'version:Show version information'
    'help:Show help message'
    'doctor:Check system dependencies and health'
    'init:Initialize harm-cli in current shell'
    'work:Work session management'
    'goal:Goal tracking and progress'
    'ai:AI assistant commands'
    'git:Enhanced git workflows'
    'proj:Project management'
    'docker:Docker management'
    'python:Python development tools'
    'gcloud:Google Cloud SDK integration'
    'health:System and project health checks'
    'safe:Safety wrappers for dangerous operations'
  )

  _arguments -C \
    $global_opts \
    '1: :->command' \
    '*:: :->args'

  case $state in
    command)
      _describe 'command' commands
      ;;
    args)
      case $line[1] in
        work)
          _harm_cli_work
          ;;
        goal)
          _harm_cli_goal
          ;;
        ai)
          _harm_cli_ai
          ;;
        git)
          _harm_cli_git
          ;;
        proj)
          _harm_cli_proj
          ;;
        docker)
          _harm_cli_docker
          ;;
        python)
          _harm_cli_python
          ;;
        gcloud)
          _harm_cli_gcloud
          ;;
        health)
          _harm_cli_health
          ;;
        safe)
          _harm_cli_safe
          ;;
        version)
          _arguments '--format[Output format]:format:(text json)'
          ;;
      esac
      ;;
  esac
}

_harm_cli_work() {
  local -a work_cmds
  work_cmds=(
    'start:Start a new work session'
    'stop:Stop current work session'
    'status:Show current work session status'
  )

  _arguments \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1: :->subcmd' \
    '*:: :->args'

  case $state in
    subcmd)
      _describe 'work command' work_cmds
      ;;
  esac
}

_harm_cli_goal() {
  local -a goal_cmds
  goal_cmds=(
    'set:Set a new goal'
    'show:Show all goals'
    'progress:Update goal progress'
    'complete:Mark goal as complete'
    'clear:Clear all goals'
    'validate:Validate goal file'
  )

  _arguments \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1: :->subcmd' \
    '*:: :->args'

  case $state in
    subcmd)
      _describe 'goal command' goal_cmds
      ;;
  esac
}

_harm_cli_ai() {
  local -a ai_cmds
  ai_cmds=(
    'query:Ask AI a question'
    'review:Review git changes'
    'explain-error:Explain last error'
    'daily:Daily productivity insights'
  )

  local -a ai_opts
  ai_opts=(
    '--setup:Configure API key'
    '--no-cache:Disable response cache'
    '--context:Include full context'
    '(-h --help)'{-h,--help}'[Show help]'
  )

  _arguments \
    $ai_opts \
    '1: :->subcmd' \
    '*:: :->args'

  case $state in
    subcmd)
      _describe 'ai command' ai_cmds
      ;;
    args)
      case $line[1] in
        review)
          _arguments \
            '--staged[Review staged changes]' \
            '--unstaged[Review unstaged changes]'
          ;;
        daily)
          _arguments \
            '--yesterday[Yesterday insights]' \
            '--week[Weekly insights]' \
            '--month[Monthly insights]'
          ;;
      esac
      ;;
  esac
}

_harm_cli_git() {
  local -a git_cmds
  git_cmds=(
    'status:Enhanced git status'
    'commit-msg:Generate commit message'
  )

  _arguments \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1: :->subcmd'

  case $state in
    subcmd)
      _describe 'git command' git_cmds
      ;;
  esac
}

_harm_cli_proj() {
  local -a proj_cmds
  proj_cmds=(
    'list:List all projects'
    'add:Add project to registry'
    'remove:Remove project from registry'
    'switch:Switch to a project'
  )

  _arguments \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1: :->subcmd' \
    '*:: :->args'

  case $state in
    subcmd)
      _describe 'project command' proj_cmds
      ;;
    args)
      case $line[1] in
        add)
          _directories
          ;;
        switch|remove)
          # Complete with project names from registry
          local registry="${HARM_CLI_HOME:-$HOME/.harm-cli}/projects/registry.jsonl"
          if [[ -f "$registry" ]]; then
            local -a projects
            projects=(${(f)"$(jq -r '.name' "$registry" 2>/dev/null)"})
            _describe 'project' projects
          fi
          ;;
      esac
      ;;
  esac
}

_harm_cli_docker() {
  local -a docker_cmds
  docker_cmds=(
    'up:Start Docker services'
    'down:Stop Docker services'
    'status:Show service status'
    'logs:View service logs'
    'shell:Open shell in container'
    'health:Check Docker health'
  )

  _arguments \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1: :->subcmd' \
    '*:: :->args'

  case $state in
    subcmd)
      _describe 'docker command' docker_cmds
      ;;
    args)
      case $line[1] in
        logs|shell|up)
          # Complete with service names from compose file
          local compose_file=""
          for f in compose.yaml docker-compose.yml docker-compose.yaml; do
            [[ -f "$f" ]] && compose_file="$f" && break
          done
          if [[ -n "$compose_file" ]] && command -v docker >/dev/null 2>&1; then
            local -a services
            services=(${(f)"$(docker compose -f "$compose_file" config --services 2>/dev/null)"})
            _describe 'service' services
          fi
          ;;
      esac
      ;;
  esac
}

_harm_cli_python() {
  local -a python_cmds
  python_cmds=(
    'status:Show Python environment status'
    'test:Run test suite'
    'lint:Run linters'
    'format:Format code'
  )

  _arguments \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1: :->subcmd'

  case $state in
    subcmd)
      _describe 'python command' python_cmds
      ;;
  esac
}

_harm_cli_gcloud() {
  local -a gcloud_cmds
  gcloud_cmds=(
    'status:Show Google Cloud SDK status'
  )

  _arguments \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1: :->subcmd'

  case $state in
    subcmd)
      _describe 'gcloud command' gcloud_cmds
      ;;
  esac
}

_harm_cli_health() {
  local -a health_cats
  health_cats=(
    'all:Check all categories'
    'system:System health'
    'git:Git health'
    'docker:Docker health'
    'python:Python health'
    'ai:AI health'
  )

  _arguments \
    '--quick[Quick check]' \
    '--json[JSON output]' \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1: :->category'

  case $state in
    category)
      _describe 'health category' health_cats
      ;;
  esac
}

_harm_cli_safe() {
  local -a safe_cmds
  safe_cmds=(
    'rm:Safe file deletion'
    'docker-prune:Safe Docker cleanup'
    'git-reset:Safe git reset with backup'
  )

  _arguments \
    '1: :->subcmd' \
    '*:: :->args'

  case $state in
    subcmd)
      _describe 'safe command' safe_cmds
      ;;
    args)
      case $line[1] in
        rm)
          _files
          ;;
      esac
      ;;
  esac
}
