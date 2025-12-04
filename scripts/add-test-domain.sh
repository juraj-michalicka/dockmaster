#!/bin/bash

# Script to add .test domains to /etc/hosts with IPv4 and IPv6 support
# Usage: ./add-test-domain.sh domain.test

if [ $# -eq 0 ]; then
    echo "Usage: $0 domain.test"
    echo "Example: $0 myproject.test"
    exit 1
fi

DOMAIN=$1

# Check if IPv4 domain is already in /etc/hosts
IPV4_EXISTS=$(grep "^127.0.0.1[[:space:]].*$DOMAIN" /etc/hosts)
IPV6_EXISTS=$(grep "^::1[[:space:]].*$DOMAIN" /etc/hosts)

if [ -n "$IPV4_EXISTS" ] && [ -n "$IPV6_EXISTS" ]; then
    echo "Domain $DOMAIN already exists in /etc/hosts (IPv4 and IPv6)"
    exit 0
fi

# Add IPv4 entry if it doesn't exist
if [ -z "$IPV4_EXISTS" ]; then
    echo "127.0.0.1 $DOMAIN" | sudo tee -a /etc/hosts > /dev/null
    echo "✓ Added IPv4 entry: 127.0.0.1 $DOMAIN"
else
    echo "✓ IPv4 entry already exists"
fi

# Add IPv6 entry if it doesn't exist
if [ -z "$IPV6_EXISTS" ]; then
    echo "::1 $DOMAIN" | sudo tee -a /etc/hosts > /dev/null
    echo "✓ Added IPv6 entry: ::1 $DOMAIN"
else
    echo "✓ IPv6 entry already exists"
fi

echo ""
echo "Domain $DOMAIN is ready!"
echo "You can now access http://$DOMAIN" 