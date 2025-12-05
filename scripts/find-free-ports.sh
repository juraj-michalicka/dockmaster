#!/bin/sh

# Find free ports for new projects
# Usage: ./find-free-ports.sh [http|https|mysql]

set -e

CONFIG_FILE="projects.conf"
CONFIG_EXAMPLE="projects.conf.example"

# Check if projects.conf exists, if not use example
if [ ! -f "$CONFIG_FILE" ]; then
  if [ -f "$CONFIG_EXAMPLE" ]; then
    echo "Warning: projects.conf not found, using projects.conf.example for reference"
    CONFIG_FILE="$CONFIG_EXAMPLE"
  else
    echo "Error: Neither projects.conf nor projects.conf.example found"
    exit 1
  fi
fi

# Check if yq is installed
if ! command -v yq >/dev/null 2>&1; then
  echo "Error: yq is not installed. Install it with: brew install yq"
  echo "Or visit: https://github.com/mikefarah/yq"
  exit 1
fi

# Default port ranges
HTTP_START=8000
HTTP_END=8099
HTTPS_START=44300
HTTPS_END=44399
MYSQL_START=33000
MYSQL_END=33099
POSTGRES_START=54300
POSTGRES_END=54399

# Function to check if port is in use on system
check_system_port() {
  local port=$1
  if command -v lsof >/dev/null 2>&1; then
    lsof -i :$port >/dev/null 2>&1
  elif command -v netstat >/dev/null 2>&1; then
    netstat -an | grep -q ":$port " 2>/dev/null
  else
    # If neither tool available, assume port is free
    return 1
  fi
}

# Function to extract used ports from projects.conf
get_used_ports() {
  local port_type=$1
  local used_ports=""
  
  # Get all project names
  local projects=$(yq eval 'keys | .[]' "$CONFIG_FILE" 2>/dev/null || echo "")
  
  for project in $projects; do
    local enabled=$(yq eval ".$project.enabled" "$CONFIG_FILE" 2>/dev/null || echo "true")
    if [ "$enabled" != "true" ]; then
      continue
    fi
    
    case "$port_type" in
      http)
        local port=$(yq eval ".$project.http.port" "$CONFIG_FILE" 2>/dev/null || echo "")
        if [ -n "$port" ] && [ "$port" != "null" ]; then
          used_ports="$used_ports $port"
        fi
        ;;
      https)
        local port=$(yq eval ".$project.https.port" "$CONFIG_FILE" 2>/dev/null || echo "")
        if [ -n "$port" ] && [ "$port" != "null" ]; then
          used_ports="$used_ports $port"
        fi
        ;;
      mysql)
        local port=$(yq eval ".$project.mysql.port" "$CONFIG_FILE" 2>/dev/null || echo "")
        if [ -n "$port" ] && [ "$port" != "null" ]; then
          used_ports="$used_ports $port"
        fi
        ;;
    esac
  done
  
  echo "$used_ports"
}

# Function to find free port in range
find_free_port() {
  local start=$1
  local end=$2
  local used_ports=$3
  local port_type=$4
  
  for port in $(seq $start $end); do
    # Check if port is in used_ports list
    if echo "$used_ports" | grep -q " $port "; then
      continue
    fi
    
    # Check if port is in use on system
    if check_system_port $port; then
      continue
    fi
    
    echo $port
    return 0
  done
  
  echo ""
  return 1
}

# Main logic
PORT_TYPE="${1:-all}"

case "$PORT_TYPE" in
  http)
    echo "Finding free HTTP port..."
    used=$(get_used_ports http)
    free_port=$(find_free_port $HTTP_START $HTTP_END "$used" http)
    if [ -n "$free_port" ]; then
      echo "Free HTTP port: $free_port"
    else
      echo "No free HTTP port found in range $HTTP_START-$HTTP_END"
      exit 1
    fi
    ;;
  https)
    echo "Finding free HTTPS port..."
    used=$(get_used_ports https)
    free_port=$(find_free_port $HTTPS_START $HTTPS_END "$used" https)
    if [ -n "$free_port" ]; then
      echo "Free HTTPS port: $free_port"
    else
      echo "No free HTTPS port found in range $HTTPS_START-$HTTPS_END"
      exit 1
    fi
    ;;
  mysql)
    echo "Finding free MySQL port..."
    used=$(get_used_ports mysql)
    free_port=$(find_free_port $MYSQL_START $MYSQL_END "$used" mysql)
    if [ -n "$free_port" ]; then
      echo "Free MySQL port: $free_port"
    else
      echo "No free MySQL port found in range $MYSQL_START-$MYSQL_END"
      exit 1
    fi
    ;;
  all|*)
    echo "Finding free ports for all types..."
    echo ""
    
    # HTTP
    used_http=$(get_used_ports http)
    free_http=$(find_free_port $HTTP_START $HTTP_END "$used_http" http)
    if [ -n "$free_http" ]; then
      echo "Free HTTP port: $free_http"
    else
      echo "No free HTTP port found in range $HTTP_START-$HTTP_END"
    fi
    
    # HTTPS
    used_https=$(get_used_ports https)
    free_https=$(find_free_port $HTTPS_START $HTTPS_END "$used_https" https)
    if [ -n "$free_https" ]; then
      echo "Free HTTPS port: $free_https"
    else
      echo "No free HTTPS port found in range $HTTPS_START-$HTTPS_END"
    fi
    
    # MySQL
    used_mysql=$(get_used_ports mysql)
    free_mysql=$(find_free_port $MYSQL_START $MYSQL_END "$used_mysql" mysql)
    if [ -n "$free_mysql" ]; then
      echo "Free MySQL port: $free_mysql"
    else
      echo "No free MySQL port found in range $MYSQL_START-$MYSQL_END"
    fi
    ;;
esac

