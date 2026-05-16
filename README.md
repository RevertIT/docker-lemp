# Local LEMP Launcher

Create local PHP or ASP.NET projects behind one shared Nginx reverse proxy.

The script builds a Docker-based development environment with:

- Nginx reverse proxy for `http://project-name.localhost`
- PHP 8.5 with php-fpm, MariaDB, Redis, and phpMyAdmin
- ASP.NET 8 with `dotnet watch`, MariaDB, Redis, and phpMyAdmin
- A shared external Docker network named `global_network`
- A graphical starter page that checks Redis and MariaDB from the app

## First Run

Run the setup script from this directory:

```bash
./setup_nginx_project.sh
```

On Windows, run it from Git Bash. If the file is not executable on Linux or macOS, run:

```bash
chmod +x setup_nginx_project.sh
./setup_nginx_project.sh
```

The script now creates the missing global Docker network automatically:

```bash
docker network create global_network
```

You do not need to create it manually. This fixes the common Docker Compose error:

```text
network global_network declared as external, but could not be found
```

## How It Works

The first part of the script starts shared services from the root `docker-compose.yml`:

- `nginx_proxy` listens on port `80`
- `mariadb` stores databases in a Docker volume
- `redis` stores data in a Docker volume
- `phpmyadmin` is available through the proxy and on port `8081`

After the shared services are running, the script can create a project in:

```text
www/<project-name>/
```

The project name becomes the local subdomain. A project named `billing-api` is available at:

```text
http://billing-api.localhost
```

phpMyAdmin is available at:

```text
http://billing-api.localhost/phpmyadmin/
```

Login:

- Server: `mariadb`
- Username: `root`
- Password: `root`

## Project Types

### PHP

Generated structure:

```text
www/<project-name>/
  public/
    index.php
  nginx/
    site.conf
  logs/
  Dockerfile
  docker-compose.yml
```

The starter page includes a responsive visual dashboard and live checks for MariaDB and Redis. Edit PHP files in `public/` and refresh the browser.

Useful shell:

```bash
docker exec -it php-<project-name> bash
```

### ASP.NET

Generated structure:

```text
www/<project-name>/
  source/
    Program.cs
    <project-name>.csproj
  nginx/
    site.conf
  Dockerfile
  docker-compose.yml
  docker-compose.override.yml
```

The override file runs `dotnet watch`, so edits in `source/` restart the app automatically.

Useful shell:

```bash
docker exec -it app-<project-name> bash
```

## Common Commands

From the root directory:

```bash
docker compose ps
docker compose logs -f
docker compose up -d
docker compose down
```

From a project directory:

```bash
cd www/<project-name>
docker compose ps
docker compose logs -f
docker compose up -d --build
docker compose down
```

## Ports

The default ports are:

- `80`: global Nginx reverse proxy
- `8081`: direct phpMyAdmin access
- `6379`: Redis

If port `80` is already used by IIS, Apache, another Nginx instance, or another Docker stack, stop that service before running the launcher.

## Notes

- Project names are normalized to lowercase letters, numbers, and dashes.
- Every project joins the same external Docker network so Nginx can route by container name.
- MariaDB and Redis data persist in Docker volumes.
- The generated starter pages are meant to be replaced by your application code.
