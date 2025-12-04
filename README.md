# DockMaster

DockMaster is a local development environment manager inspired by tools like Laravel Herd, but open-source and extensible. It provides a master Nginx reverse proxy, MySQL, Mailpit, and is ready to be extended with more services and helper scripts. DockMaster helps you manage multiple local projects and route requests to their respective containers with ease.

## Features

- **dock-proxy**: Nginx reverse proxy for routing requests to localhost ports (your host machine services)
- **nginx-master** (optional): Nginx reverse proxy for routing to Docker containers on dockmaster network
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

- **dock-proxy (Nginx):** Reverse proxy that forwards requests to localhost ports on your host machine
- **nginx-master (optional):** Reverse proxy for Docker containers on dockmaster network (currently disabled)
- **MySQL:** Development database
- **Mailpit:** Catch-all email testing

## Extending

You can add more containers (e.g., monitoring, Redis, custom scripts) by editing `docker-compose.yml`.

## Helper scripts

### Add new proxy site (localhost ports)

The `scripts/add-proxy.sh` script allows you to quickly add a new domain that proxies to ports on your **host machine** (localhost). This is ideal for projects running directly on your Mac/Linux machine outside of Docker.

#### Usage

```sh
./scripts/add-proxy.sh <domain> [--http=PORT] [--https=PORT]
```

- `<domain>`: Name of your project (without domain suffix, e.g. `castable`)
- `--http=PORT`: (optional) HTTP port on localhost to proxy to
- `--https=PORT`: (optional) HTTPS port on localhost to proxy to

If no ports are specified, the script will run in **interactive mode** and prompt you for configuration.

The script will:
1. Read `DNSMASQ_DOMAIN` from your `.env` (default: `.test`)
2. Add the domain to `/etc/hosts` (requires sudo)
3. Generate SSL certificate with mkcert (only if HTTPS is enabled)
4. Create an Nginx config in `proxy/conf.d/`
5. Reload dock-proxy

#### Examples

```sh
# HTTP and HTTPS on different ports
./scripts/add-proxy.sh castable --http=8091 --https=8092

# Only HTTP (no SSL certificate generated)
./scripts/add-proxy.sh myapp --http=8080

# Only HTTPS
./scripts/add-proxy.sh secure-app --https=8443

# Interactive mode (prompts for configuration)
./scripts/add-proxy.sh myproject
```

#### How it works (macOS/Windows)

On macOS and Windows, Docker runs in a VM, so the proxy uses `host.docker.internal` to access your host machine's ports. The dock-proxy container maps ports 80 and 443 from the container to your host, making your `.test` domains accessible in your browser.

#### Requirements
- [mkcert](https://github.com/FiloSottile/mkcert) must be installed (only needed for HTTPS)
- Docker Compose stack must be running
- `.env` file with `DNSMASQ_DOMAIN` (e.g. `.test`)

---

### Add new site (Docker containers - nginx-master)

You can use the `scripts/add-site.sh` script to add domains that proxy to **Docker containers** on the dockmaster network. This requires enabling the `nginx-master` service in `docker-compose.yml`.

#### Usage

```sh
./scripts/add-site.sh <project_name> <target_container> [type] [port]
```

- `<project_name>`: Name of your project (without domain suffix, e.g. `myapp`)
- `<target_container>`: Name of the Docker container to proxy to (e.g. `myapp-nginx`)
- `[type]`: (optional) Type of proxy. Options:
  - `ssl` (proxy_pass to target:443)
  - `fpm` (fastcgi_pass to target:9000 or custom port)
  - `80` (default, proxy_pass to target:80)
- `[port]`: (optional) For `fpm` type, specify the FastCGI port (default: 9000)

#### Examples

```sh
# Proxy to container on port 80 (default)
./scripts/add-site.sh myapp myapp-nginx

# Proxy to container on port 443 (SSL)
./scripts/add-site.sh myapp myapp-nginx ssl

# PHP-FPM (FastCGI) proxy to port 9000
./scripts/add-site.sh myapp myapp-fpm fpm 9000
```

---

### Reload Nginx

After manual changes to configurations, you can reload the respective Nginx service:

```sh
# Reload dock-proxy (for localhost proxies)
./scripts/reload-proxy.sh

# Reload nginx-master (for Docker container proxies)
./scripts/reload-nginx.sh
```

---

## Switching between dock-proxy and nginx-master

By default, **dock-proxy** is enabled (for localhost ports). If you need to proxy to Docker containers instead:

1. Comment out the `dock-proxy` service in `docker-compose.yml`
2. Uncomment the `nginx-master` service
3. Restart: `docker compose up -d`

Both services use ports 80 and 443, so only one can run at a time.

---

**Project status:** Early stage. Contributions welcome!