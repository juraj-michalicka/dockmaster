#!/bin/sh

# Usage: ./add-site.sh project_name target_container [type] [port]
# Example: ./add-site.sh novyprojekt app-kontajner ssl
#          ./add-site.sh novyprojekt app-kontajner fpm 9000
#          ./add-site.sh novyprojekt app-kontajner

set -e

# Load .env variables (DNSMASQ_DOMAIN)
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

PROJECT_NAME="$1"
TARGET="$2"
TYPE="${3:-80}"
PORT="$4"

if [ -z "$PROJECT_NAME" ] || [ -z "$TARGET" ]; then
  echo "Usage: $0 project_name target_container [type] [port]"
  exit 1
fi

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

# Generate certificate with mkcert
if ! command -v mkcert >/dev/null 2>&1; then
  echo "mkcert is not installed!"
  exit 2
fi

mkdir -p "$CERTS_PATH"
mkcert -cert-file "$CERTS_PATH/$DOMAIN.crt" -key-file "$CERTS_PATH/$DOMAIN.key" "$DOMAIN"

# Generate nginx config
echo "Generating nginx config for $DOMAIN ($TYPE) -> $TARGET"

cat > "$CONF_PATH" <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        return 301 https://$DOMAIN$request_uri;
    }
}

EOF

if [ "$TYPE" = "ssl" ] || [ "$TYPE" = "443" ]; then
  cat >> "$CONF_PATH" <<EOF
server {
    listen 443 ssl;
    server_name $DOMAIN;
    ssl_certificate     /etc/nginx/certs/$DOMAIN.crt;
    ssl_certificate_key /etc/nginx/certs/$DOMAIN.key;
    location / {
        proxy_pass https://$TARGET:443;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
elif [ "$TYPE" = "fpm" ]; then
  FPM_PORT="${PORT:-9000}"
  cat >> "$CONF_PATH" <<EOF
server {
    listen 443 ssl;
    server_name $DOMAIN;
    ssl_certificate     /etc/nginx/certs/$DOMAIN.crt;
    ssl_certificate_key /etc/nginx/certs/$DOMAIN.key;
    root /usr/share/nginx/html; # uprav podľa potreby
    index index.php index.html;
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass $TARGET:$FPM_PORT;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_index index.php;
    }
}
EOF
else
  # Default: proxy_pass to target:80
  cat >> "$CONF_PATH" <<EOF
server {
    listen 443 ssl;
    server_name $DOMAIN;
    ssl_certificate     /etc/nginx/certs/$DOMAIN.crt;
    ssl_certificate_key /etc/nginx/certs/$DOMAIN.key;
    location / {
        proxy_pass http://$TARGET:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
fi

# Reload nginx
sh scripts/reload-nginx.sh

echo "Site $DOMAIN configured and nginx reloaded." 