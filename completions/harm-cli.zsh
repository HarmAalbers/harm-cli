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
    'break:Break session management'
    'goal:Goal tracking and progress'
    'activity:Activity tracking and command logging'
    'insights:Productivity insights and analytics'
    'focus:Focus monitoring and pomodoro timer'
    'log:Real-time log streaming and management'
    'learn:Interactive learning modules'
    'discover:Discover helpful features'
    'unused:Find unused commands'
    'cheat:Quick command reference'
    'md:Markdown rendering and viewing'
    'ai:AI assistant commands'
    'git:Enhanced git workflows'
    'proj:Project management'
    'docker:Docker management'
    'cleanup:Find and remove large files'
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
        break)
          _harm_cli_break
          ;;
        goal)
          _harm_cli_goal
          ;;
        activity)
          _harm_cli_activity
          ;;
        insights)
          _harm_cli_insights
          ;;
        focus)
          _harm_cli_focus
          ;;
        log)
          _harm_cli_log
          ;;
        learn)
          _harm_cli_learn
          ;;
        discover)
          _harm_cli_discover
          ;;
        unused)
          # No subcommands
          ;;
        cheat)
          # Takes a query string
          ;;
        md)
          _harm_cli_md
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
        cleanup)
          _harm_cli_cleanup
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
    'reset:Reset pomodoro counter'
    'stats:Show work statistics'
    'violations:Show violation count'
    'reset-violations:Reset violation counter'
    'set-mode:Set enforcement mode'
    'strict:Enable/disable strict mode'
  )

  _arguments \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1: :->subcmd' \
    '*:: :->args'

  case $state in
    subcmd)
      _describe 'work command' work_cmds
      ;;
    args)
      case $line[1] in
        stats)
          local -a periods
          periods=('today' 'week' 'month' 'all')
          _describe 'period' periods
          ;;
        set-mode)
          local -a modes
          modes=('strict' 'moderate' 'coaching' 'off')
          _describe 'mode' modes
          ;;
        strict)
          _arguments '1:state:(on off)'
          ;;
      esac
      ;;
  esac
}

_harm_cli_break() {
  local -a break_cmds
  break_cmds=(
    'start:Start a break session'
    'stop:Stop current break session'
    'status:Show current break status'
    'scheduled:Manage scheduled breaks'
  )

  _arguments \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1: :->subcmd' \
    '*:: :->args'

  case $state in
    subcmd)
      _describe 'break command' break_cmds
      ;;
    args)
      case $line[1] in
        scheduled)
          local -a scheduled_cmds
          scheduled_cmds=('start' 'stop' 'status')
          _describe 'scheduled command' scheduled_cmds
          ;;
      esac
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
    'reopen:Reopen a completed goal'
    'clear:Clear all goals'
    'ai-analyze:Analyze goal complexity'
    'ai-plan:Generate implementation plan'
    'ai-next:Suggest what to work on next'
    'ai-check:Verify goal completion criteria'
    'ai-context:Generate Claude Code context'
    'link-github:Link goal to GitHub issue'
    'sync-github:Sync goal with GitHub'
  )

  _arguments \
    '(-h --help)'{-h,--help}'[Show help]' \
    '(-j --json)'{-j,--json}'[JSON output]' \
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

_harm_cli_activity() {
  local -a activity_cmds
  activity_cmds=(
    'query:Query activity log by period'
    'stats:Show activity statistics'
    'clear:Remove all activity data'
    'cleanup:Remove old entries'
    'help:Show help information'
  )

  _arguments \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1: :->subcmd' \
    '*:: :->args'

  case $state in
    subcmd)
      _describe 'activity command' activity_cmds
      ;;
    args)
      case $line[1] in
        query|stats)
          local -a periods
          periods=('today' 'yesterday' 'week' 'month' 'all')
          _describe 'period' periods
          ;;
      esac
      ;;
  esac
}

_harm_cli_insights() {
  local -a insights_cmds
  insights_cmds=(
    'show:Display productivity dashboard'
    'export:Export as HTML report'
    'json:Export as JSON'
    'daily:Daily summary'
  )

  _arguments \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1: :->subcmd' \
    '*:: :->args'

  case $state in
    subcmd)
      _describe 'insights command' insights_cmds
      ;;
    args)
      case $line[1] in
        show)
          local -a periods
          periods=('today' 'yesterday' 'week' 'month' 'all')
          _describe 'period' periods
          ;;
      esac
      ;;
  esac
}

_harm_cli_focus() {
  local -a focus_cmds
  focus_cmds=(
    'check:Perform focus check'
    'pomodoro:Start pomodoro timer'
    'pomodoro-stop:Stop active pomodoro'
    'pomodoro-status:Show pomodoro status'
  )

  _arguments \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1: :->subcmd'

  case $state in
    subcmd)
      _describe 'focus command' focus_cmds
      ;;
  esac
}

_harm_cli_log() {
  local -a log_cmds
  log_cmds=(
    'tail:Show last N log lines'
    'search:Search logs'
    'clear:Clear all logs'
    'stats:Show log statistics'
    'stream:Real-time log streaming'
  )

  _arguments \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1: :->subcmd' \
    '*:: :->args'

  case $state in
    subcmd)
      _describe 'log command' log_cmds
      ;;
  esac
}

_harm_cli_learn() {
  local -a learn_topics
  learn_topics=(
    'list:List all learning topics'
    'git:Learn git workflows'
    'docker:Learn Docker'
    'python:Learn Python tools'
    'bash:Learn bash scripting'
    'productivity:Learn productivity tips'
    'harm-cli:Learn harm-cli features'
  )

  _arguments \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1: :->topic'

  case $state in
    topic)
      _describe 'learning topic' learn_topics
      ;;
  esac
}

_harm_cli_discover() {
  local -a discover_cmds
  discover_cmds=(
    'features:Suggest harm-cli features'
    'unused:Find unused commands'
  )

  _arguments \
    '1: :->subcmd'

  case $state in
    subcmd)
      _describe 'discover command' discover_cmds
      ;;
  esac
}

_harm_cli_md() {
  local -a md_cmds
  md_cmds=(
    'render:Render markdown file'
    'render-pipe:Render from stdin'
    'tui:Interactive markdown browser'
    'suggest-tools:Show tool installation status'
  )

  _arguments \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1: :->subcmd' \
    '*:: :->args'

  case $state in
    subcmd)
      _describe 'markdown command' md_cmds
      ;;
    args)
      case $line[1] in
        render)
          _files -g '*.md'
          ;;
      esac
      ;;
  esac
}

_harm_cli_cleanup() {
  local -a cleanup_cmds
  cleanup_cmds=(
    'scan:Scan for large files'
    'delete:Delete specified files'
    'preview:Preview files to delete'
  )

  _arguments \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1: :->subcmd' \
    '*:: :->args'

  case $state in
    subcmd)
      _describe 'cleanup command' cleanup_cmds
      ;;
  esac
}

# Register completion
_harm_cli "$@"
