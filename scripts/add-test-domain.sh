#!/bin/bash

# Script to add .test domains to /etc/hosts
# Usage: ./add-test-domain.sh domain.test

if [ $# -eq 0 ]; then
    echo "Usage: $0 domain.test"
    echo "Example: $0 myproject.test"
    exit 1
fi

DOMAIN=$1

# Check if domain is already in /etc/hosts
if grep -q "$DOMAIN" /etc/hosts; then
    echo "Domain $DOMAIN already exists in /etc/hosts"
    exit 0
fi

# Add domain to /etc/hosts
echo "127.0.0.1 $DOMAIN" | sudo tee -a /etc/hosts

echo "Added $DOMAIN to /etc/hosts"
echo "You can now access http://$DOMAIN" 