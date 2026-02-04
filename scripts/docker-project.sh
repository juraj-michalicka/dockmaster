#!/bin/sh

# Docker project management script
# Manages Docker Compose projects defined in projects.conf

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/projects.conf"

# Check if yq is installed
if ! command -v yq >/dev/null 2>&1; then
  echo "Error: yq is not installed. Install it with: brew install yq"
  exit 1
fi

# Check if projects.conf exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: projects.conf not found"
  exit 1
fi

# Function to get docker compose path for a project
get_compose_path() {
  local project="$1"
  yq eval ".$project.docker.compose" "$CONFIG_FILE" 2>/dev/null || echo ""
}

# Function to get docker override path for a project
get_override_path() {
  local project="$1"
  yq eval ".$project.docker.override" "$CONFIG_FILE" 2>/dev/null || echo ""
}

# Output compose_dir and compose_args (two lines) for a project.
# use_compose_base=1: use compose + override (both). use_compose_base=0: prefer override only.
get_compose_setup() {
  local project="$1"
  local use_compose_base="${2:-0}"
  local compose_path override_path compose_dir compose_args

  compose_path=$(get_compose_path "$project")
  override_path=$(get_override_path "$project")

  if [ "$use_compose_base" = "1" ] && [ -n "$compose_path" ] && [ "$compose_path" != "null" ] && [ -f "$compose_path" ]; then
    compose_dir=$(dirname "$compose_path")
    compose_args="-f $compose_path"
    if [ -n "$override_path" ] && [ "$override_path" != "null" ] && [ -f "$override_path" ]; then
      compose_args="$compose_args -f $override_path"
    fi
  elif [ -n "$override_path" ] && [ "$override_path" != "null" ] && [ -f "$override_path" ]; then
    compose_dir=$(dirname "$override_path")
    compose_args="-f $override_path"
  elif [ -n "$compose_path" ] && [ "$compose_path" != "null" ] && [ -f "$compose_path" ]; then
    compose_dir=$(dirname "$compose_path")
    compose_args="-f $compose_path"
  else
    echo "Error: Project '$project' has no docker compose or override file" >&2
    exit 1
  fi
  echo "$compose_dir"
  echo "$compose_args"
}

# Function to start a project
# Usage: start_project <project> [--compose]
# Default: use override only when present. Use --compose to use compose + override.
start_project() {
  local project="$1"
  local opt="${2:-}"
  local use_compose_base=0
  local compose_dir compose_args setup

  if [ -z "$project" ]; then
    echo "Usage: $0 start <project_name> [--compose]"
    exit 1
  fi
  [ "$opt" = "--compose" ] && use_compose_base=1

  setup=$(get_compose_setup "$project" "$use_compose_base")
  compose_dir=$(echo "$setup" | sed -n '1p')
  compose_args=$(echo "$setup" | sed -n '2p')

  echo "Starting project: $project"
  cd "$compose_dir"
  docker compose $compose_args up -d
  echo "Project '$project' started"
}

# Function to stop a project
# Default: override only. Use --compose for compose + override.
stop_project() {
  local project="$1"
  local opt="${2:-}"
  local use_compose_base=0
  local compose_dir compose_args setup

  if [ -z "$project" ]; then
    echo "Usage: $0 stop <project_name> [--compose]"
    exit 1
  fi
  [ "$opt" = "--compose" ] && use_compose_base=1

  setup=$(get_compose_setup "$project" "$use_compose_base")
  compose_dir=$(echo "$setup" | sed -n '1p')
  compose_args=$(echo "$setup" | sed -n '2p')

  echo "Stopping project: $project"
  cd "$compose_dir"
  docker compose $compose_args down
  echo "Project '$project' stopped"
}

# Function to restart a project
# Default: override only. Use --compose for compose + override.
restart_project() {
  local project="$1"
  local opt="${2:-}"

  if [ -z "$project" ]; then
    echo "Usage: $0 restart <project_name> [--compose]"
    exit 1
  fi
  stop_project "$project" "$opt"
  start_project "$project" "$opt"
}

# Function to show project status
# Default: override only. Use --compose for compose + override.
status_project() {
  local project="$1"
  local opt="${2:-}"
  local use_compose_base=0
  local compose_dir compose_args setup

  if [ -z "$project" ]; then
    echo "Usage: $0 status <project_name> [--compose]"
    exit 1
  fi
  [ "$opt" = "--compose" ] && use_compose_base=1

  setup=$(get_compose_setup "$project" "$use_compose_base")
  compose_dir=$(echo "$setup" | sed -n '1p')
  compose_args=$(echo "$setup" | sed -n '2p')

  cd "$compose_dir"
  docker compose $compose_args ps
}

# Function to list all configured projects
list_projects() {
  if ! [ -f "$CONFIG_FILE" ]; then
    echo "Error: projects.conf not found"
    exit 1
  fi
  echo "Configured projects:"
  echo ""
  yq eval 'keys | .[]' "$CONFIG_FILE" 2>/dev/null | while read -r project; do
    [ -z "$project" ] && continue
    domain=$(yq eval ".$project.domain // \"-\"" "$CONFIG_FILE" 2>/dev/null)
    has_compose="no"
    has_override="no"
    compose_path=$(get_compose_path "$project")
    override_path=$(get_override_path "$project")
    [ -n "$compose_path" ] && [ "$compose_path" != "null" ] && has_compose="yes"
    [ -n "$override_path" ] && [ "$override_path" != "null" ] && [ -f "$override_path" ] && has_override="yes"
    printf "  %-20s domain: %-25s compose: %-3s  override: %s\n" "$project" "$domain" "$has_compose" "$has_override"
  done
}

# Function to show project logs
# Default: override only. Use --compose for compose + override.
logs_project() {
  local project="$1"
  local use_compose_base=0
  local follow=""
  local compose_dir compose_args setup
  shift
  while [ -n "${1:-}" ]; do
    case "$1" in
      --compose) use_compose_base=1 ;;
      --follow|-f) follow="-f" ;;
    esac
    shift
  done

  if [ -z "$project" ]; then
    echo "Usage: $0 logs <project_name> [--compose] [--follow|-f]"
    exit 1
  fi

  setup=$(get_compose_setup "$project" "$use_compose_base")
  compose_dir=$(echo "$setup" | sed -n '1p')
  compose_args=$(echo "$setup" | sed -n '2p')

  cd "$compose_dir"
  if [ -n "$follow" ]; then
    docker compose $compose_args logs -f
  else
    docker compose $compose_args logs
  fi
}

# Main command dispatcher
case "${1:-}" in
  start)
    start_project "$2" "$3"
    ;;
  stop)
    stop_project "$2" "$3"
    ;;
  restart)
    restart_project "$2" "$3"
    ;;
  status)
    status_project "$2" "$3"
    ;;
  logs)
    logs_project "$2" "$3" "$4" "$5"
    ;;
  list)
    list_projects
    ;;
  *)
    echo "DockMaster Docker Project Manager"
    echo ""
    echo "Usage: $0 <command> <project_name> [options]"
    echo ""
    echo "Commands:"
    echo "  list                List all configured projects"
    echo "  start <project>     Start a project's Docker containers (override only by default)"
    echo "                      Add --compose to use compose + override"
    echo "  stop <project>      Stop a project's Docker containers"
    echo "  restart <project>  Restart a project's Docker containers"
    echo "  status <project>   Show status of a project's containers"
    echo "  logs <project>     Show logs (options: --compose, --follow|-f)"
    echo ""
    exit 1
    ;;
esac
