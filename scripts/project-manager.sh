#!/bin/sh

# DockMaster Project Manager
# Centralized management script for projects.conf YAML system
# Replaces add-proxy.sh and add-site.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/projects.conf"
CONFIG_EXAMPLE="$PROJECT_ROOT/projects.conf.example"

# Check if yq is installed
if ! command -v yq >/dev/null 2>&1; then
  echo "Error: yq is not installed. Install it with: brew install yq"
  echo "Or visit: https://github.com/mikefarah/yq"
  exit 1
fi

# Check if projects.conf exists, create from example if not
if [ ! -f "$CONFIG_FILE" ]; then
  if [ -f "$CONFIG_EXAMPLE" ]; then
    echo "Creating projects.conf from projects.conf.example..."
    cp "$CONFIG_EXAMPLE" "$CONFIG_FILE"
    echo "Please edit projects.conf and remove example projects before adding real ones."
  else
    echo "Error: Neither projects.conf nor projects.conf.example found"
    exit 1
  fi
fi

# Load .env variables
if [ -f "$PROJECT_ROOT/.env" ]; then
  export $(grep -v '^#' "$PROJECT_ROOT/.env" | xargs)
fi

# Function to list all projects
list_projects() {
  echo "Projects in projects.conf:"
  echo ""
  
  local projects=$(yq eval 'keys | .[]' "$CONFIG_FILE" 2>/dev/null || echo "")
  
  if [ -z "$projects" ]; then
    echo "No projects found."
    return
  fi
  
  for project in $projects; do
    local enabled=$(yq eval ".$project.enabled" "$CONFIG_FILE" 2>/dev/null || echo "true")
    local type=$(yq eval ".$project.type" "$CONFIG_FILE" 2>/dev/null || echo "unknown")
    local domain=$(yq eval ".$project.domain" "$CONFIG_FILE" 2>/dev/null || echo "")
    
    local status=""
    if [ "$enabled" = "true" ]; then
      status="✓ enabled"
    else
      status="✗ disabled"
    fi
    
    echo "  $project ($type) - $domain [$status]"
  done
}

# Function to add a new project
add_project() {
  local project_name="$1"
  
  if [ -z "$project_name" ]; then
    echo "Usage: $0 add <project_name>"
    exit 1
  fi
    
  # Check if project already exists
  if yq eval "has(\"$project_name\")" "$CONFIG_FILE" 2>/dev/null | grep -q "true"; then
    echo "Error: Project '$project_name' already exists"
    exit 1
  fi
  
  echo "Adding new project: $project_name"
  echo ""
  
  # Get free ports
  echo "Finding free ports..."
  local http_port=""
  local https_port=""
  local mysql_port=""
  
  if [ -f "$SCRIPT_DIR/find-free-ports.sh" ]; then
    local ports_output=$(sh "$SCRIPT_DIR/find-free-ports.sh" all)
    http_port=$(echo "$ports_output" | grep "Free HTTP port:" | awk '{print $3}')
    https_port=$(echo "$ports_output" | grep "Free HTTPS port:" | awk '{print $3}')
    mysql_port=$(echo "$ports_output" | grep "Free MySQL port:" | awk '{print $3}')
  fi
  
  # Interactive configuration
  printf "Project type (proxy/site) [proxy]: "
  read -r project_type
  project_type="${project_type:-proxy}"
  
  printf "Domain [${project_name}.test]: "
  read -r domain
  domain="${domain:-${project_name}.test}"
  
  # Add domain to /etc/hosts
  if [ -f "$SCRIPT_DIR/add-test-domain.sh" ]; then
    sh "$SCRIPT_DIR/add-test-domain.sh" "$domain"
  fi
  
  if [ "$project_type" = "proxy" ]; then
    printf "Enable HTTP? (y/n) [y]: "
    read -r enable_http
    enable_http="${enable_http:-y}"
    
    if [ "$enable_http" = "y" ] || [ "$enable_http" = "Y" ]; then
      printf "HTTP port [${http_port:-8091}]: "
      read -r http_port_input
      http_port="${http_port_input:-${http_port:-8091}}"
    fi
    
    printf "Enable HTTPS? (y/n) [n]: "
    read -r enable_https
    enable_https="${enable_https:-n}"
    
    if [ "$enable_https" = "y" ] || [ "$enable_https" = "Y" ]; then
      printf "HTTPS port [${https_port:-44300}]: "
      read -r https_port_input
      https_port="${https_port_input:-${https_port:-44300}}"
    fi
  else
    # Site type
    printf "Target container name: "
    read -r target_container
    
    printf "Proxy type (80/fpm/ssl) [80]: "
    read -r proxy_type
    proxy_type="${proxy_type:-80}"
    
    if [ "$proxy_type" = "fpm" ]; then
      printf "FPM port [9000]: "
      read -r fpm_port
      fpm_port="${fpm_port:-9000}"
    fi
  fi
  
  printf "Enable MySQL proxying? (y/n) [n]: "
  read -r enable_mysql
  enable_mysql="${enable_mysql:-n}"
  
  if [ "$enable_mysql" = "y" ] || [ "$enable_mysql" = "Y" ]; then
    printf "MySQL port [${mysql_port:-33000}]: "
    read -r mysql_port_input
    mysql_port="${mysql_port_input:-${mysql_port:-33000}}"
    
    printf "MySQL target (container name or localhost) [localhost]: "
    read -r mysql_target
    mysql_target="${mysql_target:-localhost}"
    
    printf "MySQL target port [3306]: "
    read -r mysql_target_port
    mysql_target_port="${mysql_target_port:-3306}"
  fi
  
  printf "Enable SSL? (y/n) [n]: "
  read -r enable_ssl
  enable_ssl="${enable_ssl:-n}"
  
  printf "Docker compose path (optional): "
  read -r docker_compose
  
  # Build YAML structure using yq
  yq eval ".$project_name.type = \"$project_type\"" -i "$CONFIG_FILE"
  yq eval ".$project_name.domain = \"$domain\"" -i "$CONFIG_FILE"
  yq eval ".$project_name.enabled = true" -i "$CONFIG_FILE"
  yq eval ".$project_name.ssl = $([ "$enable_ssl" = "y" ] && echo "true" || echo "false")" -i "$CONFIG_FILE"
  
  if [ "$project_type" = "proxy" ]; then
    if [ -n "$http_port" ]; then
      yq eval ".$project_name.http.port = $http_port" -i "$CONFIG_FILE"
      yq eval ".$project_name.http.enabled = true" -i "$CONFIG_FILE"
    else
      yq eval ".$project_name.http.port = null" -i "$CONFIG_FILE"
      yq eval ".$project_name.http.enabled = false" -i "$CONFIG_FILE"
    fi
    
    if [ -n "$https_port" ]; then
      yq eval ".$project_name.https.port = $https_port" -i "$CONFIG_FILE"
      yq eval ".$project_name.https.enabled = true" -i "$CONFIG_FILE"
    else
      yq eval ".$project_name.https.port = null" -i "$CONFIG_FILE"
      yq eval ".$project_name.https.enabled = false" -i "$CONFIG_FILE"
    fi
  else
    # Site type
    yq eval ".$project_name.target.container = \"$target_container\"" -i "$CONFIG_FILE"
    yq eval ".$project_name.target.proxy_type = \"$proxy_type\"" -i "$CONFIG_FILE"
    
    if [ "$proxy_type" = "fpm" ]; then
      yq eval ".$project_name.target.fpm.container = \"$target_container\"" -i "$CONFIG_FILE"
      yq eval ".$project_name.target.fpm.port = ${fpm_port:-9000}" -i "$CONFIG_FILE"
      yq eval ".$project_name.target.fpm.enabled = true" -i "$CONFIG_FILE"
    fi
  fi
  
  if [ "$enable_mysql" = "y" ] || [ "$enable_mysql" = "Y" ]; then
    yq eval ".$project_name.mysql.port = $mysql_port" -i "$CONFIG_FILE"
    yq eval ".$project_name.mysql.target = \"$mysql_target\"" -i "$CONFIG_FILE"
    yq eval ".$project_name.mysql.target_port = $mysql_target_port" -i "$CONFIG_FILE"
    yq eval ".$project_name.mysql.enabled = true" -i "$CONFIG_FILE"
  else
    yq eval ".$project_name.mysql.enabled = false" -i "$CONFIG_FILE"
  fi
  
  if [ -n "$docker_compose" ]; then
    yq eval ".$project_name.docker.compose = \"$docker_compose\"" -i "$CONFIG_FILE"
    yq eval ".$project_name.docker.override = null" -i "$CONFIG_FILE"
  else
    yq eval ".$project_name.docker.compose = null" -i "$CONFIG_FILE"
    yq eval ".$project_name.docker.override = null" -i "$CONFIG_FILE"
  fi
  
  echo ""
  echo "Project '$project_name' added successfully!"
  echo "Run '$0 regenerate' to generate nginx configs."
}

# Function to remove a project
remove_project() {
  local project_name="$1"
  
  if [ -z "$project_name" ]; then
    echo "Usage: $0 remove <project_name>"
    exit 1
  fi
  
  if ! yq eval "has(\"$project_name\")" "$CONFIG_FILE" 2>/dev/null | grep -q "true"; then
    echo "Error: Project '$project_name' does not exist"
    exit 1
  fi
  
  yq eval "del(.\"$project_name\")" -i "$CONFIG_FILE"
  echo "Project '$project_name' removed successfully!"
}

# Function to enable/disable a project
toggle_project() {
  local action="$1"
  local project_name="$2"
  
  if [ -z "$project_name" ]; then
    echo "Usage: $0 $action <project_name>"
    exit 1
  fi
  
  if ! yq eval "has(\"$project_name\")" "$CONFIG_FILE" 2>/dev/null | grep -q "true"; then
    echo "Error: Project '$project_name' does not exist"
    exit 1
  fi
  
  if [ "$action" = "enable" ]; then
    yq eval ".$project_name.enabled = true" -i "$CONFIG_FILE"
    echo "Project '$project_name' enabled"
  else
    yq eval ".$project_name.enabled = false" -i "$CONFIG_FILE"
    echo "Project '$project_name' disabled"
  fi
}

# Function to regenerate nginx configs
regenerate_configs() {
  if [ -f "$SCRIPT_DIR/generate-nginx-configs.sh" ]; then
    sh "$SCRIPT_DIR/generate-nginx-configs.sh"
  else
    echo "Error: generate-nginx-configs.sh not found"
    exit 1
  fi
}

# Function to find free ports
find_free_ports() {
  if [ -f "$SCRIPT_DIR/find-free-ports.sh" ]; then
    sh "$SCRIPT_DIR/find-free-ports.sh" "${1:-all}"
  else
    echo "Error: find-free-ports.sh not found"
    exit 1
  fi
}

# Main command dispatcher
case "${1:-}" in
  list)
    list_projects
    ;;
  add)
    add_project "$2"
    ;;
  remove|rm)
    remove_project "$2"
    ;;
  enable)
    toggle_project "enable" "$2"
    ;;
  disable)
    toggle_project "disable" "$2"
    ;;
  regenerate)
    regenerate_configs
    ;;
  find-free-ports)
    find_free_ports "$2"
    ;;
  *)
    echo "DockMaster Project Manager"
    echo ""
    echo "Usage: $0 <command> [args]"
    echo ""
    echo "Commands:"
    echo "  list                    List all projects"
    echo "  add <project>            Add a new project (interactive)"
    echo "  remove <project>        Remove a project"
    echo "  enable <project>        Enable a project"
    echo "  disable <project>       Disable a project"
    echo "  regenerate              Regenerate all nginx configs"
    echo "  find-free-ports [type]   Find free ports (http|https|mysql|all)"
    echo ""
    exit 1
    ;;
esac
