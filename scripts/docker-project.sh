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

# Function to start a project
start_project() {
  local project="$1"
  
  if [ -z "$project" ]; then
    echo "Usage: $0 start <project_name>"
    exit 1
  fi
  
  local compose_path=$(get_compose_path "$project")
  
  if [ -z "$compose_path" ] || [ "$compose_path" = "null" ]; then
    echo "Error: Project '$project' has no docker.compose path configured"
    exit 1
  fi
  
  if [ ! -f "$compose_path" ]; then
    echo "Error: Docker compose file not found: $compose_path"
    exit 1
  fi
  
  local compose_dir=$(dirname "$compose_path")
  local compose_file=$(basename "$compose_path")
  
  echo "Starting project: $project"
  echo "Compose file: $compose_path"
  
  local override_path=$(get_override_path "$project")
  local compose_args="-f $compose_path"
  
  if [ -n "$override_path" ] && [ "$override_path" != "null" ] && [ -f "$override_path" ]; then
    echo "Override file: $override_path"
    compose_args="$compose_args -f $override_path"
  fi
  
  cd "$compose_dir"
  docker compose $compose_args up -d
  
  echo "Project '$project' started"
}

# Function to stop a project
stop_project() {
  local project="$1"
  
  if [ -z "$project" ]; then
    echo "Usage: $0 stop <project_name>"
    exit 1
  fi
  
  local compose_path=$(get_compose_path "$project")
  
  if [ -z "$compose_path" ] || [ "$compose_path" = "null" ]; then
    echo "Error: Project '$project' has no docker.compose path configured"
    exit 1
  fi
  
  if [ ! -f "$compose_path" ]; then
    echo "Error: Docker compose file not found: $compose_path"
    exit 1
  fi
  
  local compose_dir=$(dirname "$compose_path")
  local compose_file=$(basename "$compose_path")
  
  echo "Stopping project: $project"
  
  local override_path=$(get_override_path "$project")
  local compose_args="-f $compose_path"
  
  if [ -n "$override_path" ] && [ "$override_path" != "null" ] && [ -f "$override_path" ]; then
    compose_args="$compose_args -f $override_path"
  fi
  
  cd "$compose_dir"
  docker compose $compose_args down
  
  echo "Project '$project' stopped"
}

# Function to restart a project
restart_project() {
  local project="$1"
  
  if [ -z "$project" ]; then
    echo "Usage: $0 restart <project_name>"
    exit 1
  fi
  
  stop_project "$project"
  start_project "$project"
}

# Function to show project status
status_project() {
  local project="$1"
  
  if [ -z "$project" ]; then
    echo "Usage: $0 status <project_name>"
    exit 1
  fi
  
  local compose_path=$(get_compose_path "$project")
  
  if [ -z "$compose_path" ] || [ "$compose_path" = "null" ]; then
    echo "Error: Project '$project' has no docker.compose path configured"
    exit 1
  fi
  
  if [ ! -f "$compose_path" ]; then
    echo "Error: Docker compose file not found: $compose_path"
    exit 1
  fi
  
  local compose_dir=$(dirname "$compose_path")
  
  local override_path=$(get_override_path "$project")
  local compose_args="-f $compose_path"
  
  if [ -n "$override_path" ] && [ "$override_path" != "null" ] && [ -f "$override_path" ]; then
    compose_args="$compose_args -f $override_path"
  fi
  
  cd "$compose_dir"
  docker compose $compose_args ps
}

# Function to show project logs
logs_project() {
  local project="$1"
  shift
  local follow="${1:-}"
  
  if [ -z "$project" ]; then
    echo "Usage: $0 logs <project_name> [--follow]"
    exit 1
  fi
  
  local compose_path=$(get_compose_path "$project")
  
  if [ -z "$compose_path" ] || [ "$compose_path" = "null" ]; then
    echo "Error: Project '$project' has no docker.compose path configured"
    exit 1
  fi
  
  if [ ! -f "$compose_path" ]; then
    echo "Error: Docker compose file not found: $compose_path"
    exit 1
  fi
  
  local compose_dir=$(dirname "$compose_path")
  
  local override_path=$(get_override_path "$project")
  local compose_args="-f $compose_path"
  
  if [ -n "$override_path" ] && [ "$override_path" != "null" ] && [ -f "$override_path" ]; then
    compose_args="$compose_args -f $override_path"
  fi
  
  cd "$compose_dir"
  
  if [ "$follow" = "--follow" ] || [ "$follow" = "-f" ]; then
    docker compose $compose_args logs -f
  else
    docker compose $compose_args logs
  fi
}

# Main command dispatcher
case "${1:-}" in
  start)
    start_project "$2"
    ;;
  stop)
    stop_project "$2"
    ;;
  restart)
    restart_project "$2"
    ;;
  status)
    status_project "$2"
    ;;
  logs)
    logs_project "$2" "$3"
    ;;
  *)
    echo "DockMaster Docker Project Manager"
    echo ""
    echo "Usage: $0 <command> <project_name> [options]"
    echo ""
    echo "Commands:"
    echo "  start <project>     Start a project's Docker containers"
    echo "  stop <project>     Stop a project's Docker containers"
    echo "  restart <project>  Restart a project's Docker containers"
    echo "  status <project>   Show status of a project's containers"
    echo "  logs <project>     Show logs of a project's containers"
    echo "                     Add --follow or -f to follow logs"
    echo ""
    exit 1
    ;;
esac
