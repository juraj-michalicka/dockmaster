# DockMaster

DockMaster is a local development environment manager inspired by tools like Laravel Herd, but open-source and extensible. It provides a master Nginx reverse proxy, MySQL, Mailpit, and is ready to be extended with more services and helper scripts. DockMaster helps you manage multiple local projects and route requests to their respective containers with ease.

## Features

- Master Nginx reverse proxy for routing requests to your local projects
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

## Example Services

- **Nginx (master proxy):** Routes traffic to your local projects
- **MySQL:** Development database
- **Mailpit:** Catch-all email testing

## Extending

You can add more containers (e.g., monitoring, Redis, custom scripts) by editing `docker-compose.yml`.

## Helper scripts

### Add new site (reverse proxy) easily

You can use the `scripts/add-site.sh` script to quickly add a new domain (vhost) to your DockMaster Nginx reverse proxy, including SSL certificate generation with mkcert.

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

The script will:
1. Read `DNSMASQ_DOMAIN` from your `.env` (default: `.test`)
2. Generate a certificate for `<project_name><DNSMASQ_DOMAIN>` using mkcert
3. Create an Nginx config in `nginx/conf.d/`
4. Reload Nginx

#### Examples

```sh
# Proxy to container on port 80 (default)
./scripts/add-site.sh myapp myapp-nginx

# Proxy to container on port 443 (SSL)
./scripts/add-site.sh myapp myapp-nginx ssl

# PHP-FPM (FastCGI) proxy to port 9000
./scripts/add-site.sh myapp myapp-fpm fpm 9000
```

#### Requirements
- [mkcert](https://github.com/FiloSottile/mkcert) must be installed and available in your PATH
- Docker Compose stack must be running
- `.env` file with `DNSMASQ_DOMAIN` (e.g. `.test`)

---

**Project status:** Early stage. Contributions welcome!