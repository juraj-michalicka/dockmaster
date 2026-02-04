# DockMaster

DockMaster is a local development environment manager inspired by tools like Laravel Herd, but open-source and extensible. It provides a master Nginx reverse proxy, MySQL, Mailpit, and is ready to be extended with more services and helper scripts. DockMaster helps you manage multiple local projects and route requests to their respective containers with ease.

## Features

- **nginx**: Unified Nginx reverse proxy for routing requests to both localhost ports (host machine services) and Docker containers on dockmaster network
- MySQL database container
- Mailpit for email testing
- Easy to extend with more services (monitoring, helpers, etc.)

## Getting Started

1. Clone this repository:
   ```sh
   git clone https://github.com/your-username/dockmaster.git
   cd dockmaster
   ```
2. Start the stack:
   ```sh
   docker compose up -d
   ```
3. Add your projects and configure Nginx as needed.

## Services

- **nginx (Nginx):** Unified reverse proxy that forwards requests to both localhost ports on your host machine (via host.docker.internal) and Docker containers on dockmaster network
- **MySQL:** Development database
- **Mailpit:** Catch-all email testing

## Extending

You can add more containers (e.g., monitoring, Redis, custom scripts) by editing `docker-compose.yml`.

## Projects Configuration System

DockMaster uses a centralized YAML-based configuration system (`projects.conf`) to manage all your projects. This replaces the older `add-proxy.sh` and `add-site.sh` scripts with a unified management interface.

### Requirements

- **[yq](https://github.com/mikefarah/yq)** - YAML processor (required)
  ```sh
  # macOS
  brew install yq
  
  # Or download from: https://github.com/mikefarah/yq/releases
  ```
- **[mkcert](https://github.com/FiloSottile/mkcert)** - For SSL certificate generation (optional, needed for HTTPS)

### Getting Started

1. Copy the example configuration:
   ```sh
   cp projects.conf.example projects.conf
   ```

2. Edit `projects.conf` and configure your projects (or use the project manager script)

3. Generate nginx configurations:
   ```sh
   ./scripts/project-manager.sh regenerate
   ```

### Project Manager

The `scripts/project-manager.sh` script is the main tool for managing projects:

#### Commands

```sh
# List all projects
./scripts/project-manager.sh list

# Add a new project (interactive)
./scripts/project-manager.sh add myproject

# Remove a project
./scripts/project-manager.sh remove myproject

# Enable/disable a project
./scripts/project-manager.sh enable myproject
./scripts/project-manager.sh disable myproject

# Regenerate all nginx configs from projects.conf
./scripts/project-manager.sh regenerate

# Find free ports
./scripts/project-manager.sh find-free-ports [http|https|mysql|all]
```

### Projects Configuration Format

Projects are defined in `projects.conf` using YAML format:

#### Proxy Project (localhost ports)

```yaml
myproject:
  type: proxy
  domain: myproject.test
  http:
    port: 8091
    enabled: true
  https:
    port: null
    enabled: false
  mysql:
    port: 33000
    target: localhost
    target_port: 3306
    enabled: true
  ssl: false
  docker:
    compose: /path/to/docker-compose.yml
    override: null
  enabled: true
```

#### Site Project (Docker containers)

**By container name (Docker DNS):** Nginx resolves the container name on the dockmaster network. Your project's override must attach the service to the `dockmaster` network and set `container_name` to match (e.g. `container_name: myapp-nginx`). If you see wrong-project routing or "file not found", prefer **by port** below.

```yaml
myapp:
  type: site
  domain: myapp.test
  target:
    container: myapp-nginx
    proxy_type: fpm
    fpm:
      container: myapp-php-fpm
      port: 9000
      enabled: true
  mysql:
    port: 33001
    target: myapp-mysql
    target_port: 3306
    enabled: true
  ssl: true
  docker:
    compose: /path/to/myapp/docker-compose.yml
    override: /path/to/myapp/docker-compose.override.yml
  enabled: true
```

**By port (recommended on shared dockmaster network):** Set `target.port` to a unique host port. The project's nginx must publish that port (e.g. in `docker-compose.override.yml`: `ports: ["8081:80"]` and attach to the dockmaster network). Routing then goes to `host.docker.internal:PORT` and does not depend on Docker DNS, so it is deterministic. Use `scripts/find-free-ports.sh` to pick a free port (HTTP range 8000–8099).

```yaml
myapp:
  type: site
  domain: myapp.test
  target:
    container: myapp-nginx
    port: 8081
    proxy_type: 80
  ssl: true
  docker:
    compose: /path/to/myapp/docker-compose.yml
    override: /path/to/myapp/docker-compose.override.yml
  enabled: true
```

When the site is reached via HTTPS (e.g. https://myapp.test), DockMaster sends `X-Forwarded-Proto: https` and related headers. The backend app (e.g. Laravel) must **trust these headers** and generate asset/redirect URLs with `https://`, otherwise the browser will block CSS/JS as mixed content. In Laravel: configure `TrustProxies` (e.g. trust the proxy IP or `*` in local) and set `APP_URL=https://myapp.test`.

### Docker Project Management

Use `scripts/docker-project.sh` to manage Docker Compose projects:

```sh
# Start a project
./scripts/docker-project.sh start myproject

# Stop a project
./scripts/docker-project.sh stop myproject

# Restart a project
./scripts/docker-project.sh restart myproject

# Show project status
./scripts/docker-project.sh status myproject

# Show project logs
./scripts/docker-project.sh logs myproject
./scripts/docker-project.sh logs myproject --follow
```

### MySQL Stream Proxying

Projects can configure MySQL TCP proxying through nginx stream module. When enabled, nginx will proxy MySQL connections from the configured port to the target MySQL server.

Example:
```yaml
myproject:
  mysql:
    port: 33000
    target: myproject-mysql
    target_port: 3306
    enabled: true
```

This allows you to connect to `localhost:33000` and it will be proxied to `myproject-mysql:3306` on the Docker network.

### Migration from Old Scripts

If you have existing nginx configurations created with `add-proxy.sh` or `add-site.sh`, you can migrate them:

```sh
./scripts/migrate-to-projects-conf.sh
```

This will parse your existing `nginx/conf.d/*.conf` files and create a `projects.conf` file. Review and update the generated configuration as needed.

### Helper Scripts

#### Reload Nginx

After manual changes to configurations:

```sh
./scripts/reload-nginx.sh
```

#### Find Free Ports

Find available ports for new projects:

```sh
./scripts/find-free-ports.sh [http|https|mysql|all]
```

### Port Ranges

Default port ranges (configurable in `find-free-ports.sh`):
- HTTP: 8000-8099
- HTTPS: 44300-44399
- MySQL: 33000-33099

---

## Legacy Scripts (Deprecated)

The following scripts are deprecated in favor of the new `projects.conf` system:
- `scripts/add-proxy.sh` - Use `project-manager.sh add` instead
- `scripts/add-site.sh` - Use `project-manager.sh add` instead

These scripts may still work but are not recommended for new projects.

---

**Project status:** Early stage. Contributions welcome!