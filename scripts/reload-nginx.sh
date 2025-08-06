#!/bin/sh

# Reload Nginx configuration in the dockmaster stack

docker compose exec nginx nginx -s reload 