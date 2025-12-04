#!/bin/sh

# Reload Nginx configuration in the dock-proxy container

docker compose exec dock-proxy nginx -s reload

