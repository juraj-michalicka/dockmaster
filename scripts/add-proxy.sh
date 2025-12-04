#!/bin/sh

# Usage: ./add-proxy.sh domain [--http=PORT] [--https=PORT]
# Example: ./add-proxy.sh castable --http=8091 --https=8092
#          ./add-proxy.sh castable --http=8091
#          ./add-proxy.sh castable (interactive mode)

set -e

# Load .env variables (DNSMASQ_DOMAIN)
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

PROJECT_NAME="$1"
HTTP_PORT=""
HTTPS_PORT=""

if [ -z "$PROJECT_NAME" ]; then
  echo "Usage: $0 domain [--http=PORT] [--https=PORT]"
  echo "Examples:"
  echo "  $0 castable --http=8091 --https=8092"
  echo "  $0 castable --http=8091"
  echo "  $0 castable (interactive mode)"
  exit 1
fi

# Parse arguments
shift
while [ $# -gt 0 ]; do
  case "$1" in
    --http=*)
      HTTP_PORT="${1#*=}"
      ;;
    --https=*)
      HTTPS_PORT="${1#*=}"
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

# Interactive mode if no ports specified
if [ -z "$HTTP_PORT" ] && [ -z "$HTTPS_PORT" ]; then
  echo "Interactive mode - configure proxy ports for $PROJECT_NAME"
  echo ""
  
  # Ask for HTTP
  printf "Enable HTTP proxy? (y/n) [y]: "
  read -r ENABLE_HTTP
  ENABLE_HTTP="${ENABLE_HTTP:-y}"
  
  if [ "$ENABLE_HTTP" = "y" ] || [ "$ENABLE_HTTP" = "Y" ]; then
    printf "HTTP port (localhost:PORT): "
    read -r HTTP_PORT
  fi
  
  # Ask for HTTPS
  printf "Enable HTTPS proxy? (y/n) [y]: "
  read -r ENABLE_HTTPS
  ENABLE_HTTPS="${ENABLE_HTTPS:-y}"
  
  if [ "$ENABLE_HTTPS" = "y" ] || [ "$ENABLE_HTTPS" = "Y" ]; then
    printf "HTTPS port (localhost:PORT): "
    read -r HTTPS_PORT
  fi
fi

# Validate at least one port is specified
if [ -z "$HTTP_PORT" ] && [ -z "$HTTPS_PORT" ]; then
  echo "Error: At least one port (HTTP or HTTPS) must be specified"
  exit 1
fi

# Construct domain from project name and DNSMASQ_DOMAIN
DOMAIN="$PROJECT_NAME${DNSMASQ_DOMAIN:-.test}"

CONF_PATH="nginx/conf.d/$PROJECT_NAME.conf"
CERTS_PATH="nginx/certs"

# Add domain to /etc/hosts
if [ -f "scripts/add-test-domain.sh" ]; then
  echo "Adding $DOMAIN to /etc/hosts..."
  sh scripts/add-test-domain.sh "$DOMAIN"
else
  echo "Warning: add-test-domain.sh not found, manually add $DOMAIN to /etc/hosts"
fi

# Generate certificate with mkcert (only if HTTPS is enabled)
if [ -n "$HTTPS_PORT" ]; then
  if ! command -v mkcert >/dev/null 2>&1; then
    echo "mkcert is not installed!"
    exit 2
  fi

  mkdir -p "$CERTS_PATH"
  mkcert -cert-file "$CERTS_PATH/$DOMAIN.crt" -key-file "$CERTS_PATH/$DOMAIN.key" "$DOMAIN"
fi

# Generate nginx config
echo "Generating nginx proxy config for $DOMAIN"
if [ -n "$HTTP_PORT" ]; then
  echo "  HTTP (port 80) -> localhost:$HTTP_PORT"
fi
if [ -n "$HTTPS_PORT" ]; then
  echo "  HTTPS (port 443) -> localhost:$HTTPS_PORT"
fi

# Start writing config
> "$CONF_PATH"

# HTTP server block (if HTTP_PORT is set)
if [ -n "$HTTP_PORT" ]; then
  cat >> "$CONF_PATH" <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    location / {
        proxy_pass http://host.docker.internal:$HTTP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

EOF
fi

# HTTPS server block (if HTTPS_PORT is set)
if [ -n "$HTTPS_PORT" ]; then
  cat >> "$CONF_PATH" <<EOF
server {
    listen 443 ssl;
    server_name $DOMAIN;
    ssl_certificate     /etc/nginx/certs/$DOMAIN.crt;
    ssl_certificate_key /etc/nginx/certs/$DOMAIN.key;
    
    location / {
        proxy_pass https://host.docker.internal:$HTTPS_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port 443;
        proxy_set_header X-Forwarded-Ssl on;
    }
}
EOF
fi

# Reload nginx
sh scripts/reload-nginx.sh

echo "Proxy for $DOMAIN configured and nginx reloaded."

