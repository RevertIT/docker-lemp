#!/usr/bin/env bash

set -Eeuo pipefail

APP_NAME="Local LEMP Launcher"
BASE_DIR="$(pwd)"
WWW_DIR="$BASE_DIR/www"
GLOBAL_NETWORK="${GLOBAL_NETWORK:-global_network}"
GLOBAL_NGINX_DIR="$BASE_DIR/nginx"
GLOBAL_NGINX_COMPOSE="$BASE_DIR/docker-compose.yml"
GLOBAL_NGINX_PROXY="$GLOBAL_NGINX_DIR/_proxy.conf"
GLOBAL_NGINX_CONFIG="$GLOBAL_NGINX_DIR/nginx.conf"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

on_error() {
    local exit_code=$?
    echo
    echo -e "${RED}Setup stopped.${NC} The last command failed on line ${BASH_LINENO[0]}."
    echo "Fix the issue above and run this script again."
    exit "$exit_code"
}
trap on_error ERR

print_banner() {
    clear 2>/dev/null || true
    cat <<'EOF'
██████╗ ███████╗██╗   ██╗███████╗██████╗ ████████╗██╗████████╗
██╔══██╗██╔════╝██║   ██║██╔════╝██╔══██╗╚══██╔══╝██║╚══██╔══╝
██████╔╝█████╗  ██║   ██║█████╗  ██████╔╝   ██║   ██║   ██║
██╔══██╗██╔══╝  ╚██╗ ██╔╝██╔══╝  ██╔══██╗   ██║   ██║   ██║
██║  ██║███████╗ ╚████╔╝ ███████╗██║  ██║   ██║   ██║   ██║
╚═╝  ╚═╝╚══════╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝   ╚═╝
-------------------------------------------------------------
Automated Project Setup for PHP/ASP.NET, Nginx, and Docker
-------------------------------------------------------------

Author: @RevertIT
License: MIT
Copyright (C) 2025 RevertIT
Description:
This script automates the creation of a PHP or ASP.NET project
environment with Nginx and Docker integration.
EOF
    echo
    echo -e "${BOLD}${APP_NAME}${NC}"
    echo "Create local PHP or ASP.NET projects behind one Nginx reverse proxy."
    echo
}

section() {
    echo
    echo -e "${CYAN}==>${NC} ${BOLD}$1${NC}"
}

info() {
    echo -e "${BLUE}--${NC} $1"
}

success() {
    echo -e "${GREEN}OK${NC} $1"
}

warn() {
    echo -e "${YELLOW}!!${NC} $1"
}

fail() {
    echo -e "${RED}Error:${NC} $1" >&2
    exit 1
}

prompt() {
    local label="$1"
    local default="${2:-}"
    local value

    if [ -n "$default" ]; then
        read -r -p "$label [$default]: " value
        echo "${value:-$default}"
    else
        read -r -p "$label: " value
        echo "$value"
    fi
}

confirm() {
    local label="$1"
    local default="${2:-y}"
    local answer
    read -r -p "$label [$default/n]: " answer
    answer="${answer:-$default}"
    [[ "$answer" =~ ^([yY]|yes|YES)$ ]]
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "$1 is required but was not found in PATH."
}

compose() {
    if docker compose version >/dev/null 2>&1; then
        docker compose "$@"
    elif command -v docker-compose >/dev/null 2>&1; then
        docker-compose "$@"
    else
        fail "Docker Compose is required. Install Docker Desktop or the docker-compose plugin."
    fi
}

normalize_project_name() {
    local raw="$1"
    raw="$(echo "$raw" | tr '[:upper:]' '[:lower:]')"
    raw="$(echo "$raw" | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
    echo "$raw"
}

validate_project_name() {
    local name="$1"

    [ -n "$name" ] || fail "Project name cannot be empty."
    [[ "$name" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]] || \
        fail "Use 1-63 lowercase letters, numbers, and dashes. Start and end with a letter or number."
}

ensure_global_network() {
    section "Checking Docker network"

    if docker network inspect "$GLOBAL_NETWORK" >/dev/null 2>&1; then
        success "Docker network '$GLOBAL_NETWORK' already exists."
        return
    fi

    info "Creating missing external network '$GLOBAL_NETWORK'."
    docker network create "$GLOBAL_NETWORK" >/dev/null
    success "Docker network '$GLOBAL_NETWORK' created."
}

write_global_nginx() {
    section "Preparing global reverse proxy"
    mkdir -p "$GLOBAL_NGINX_DIR" "$WWW_DIR"

    cat > "$GLOBAL_NGINX_CONFIG" <<'EOF'
user nginx;
pid /var/run/nginx.pid;
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    multi_accept on;
    worker_connections 65535;
}

http {
    charset utf-8;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    server_tokens off;
    log_not_found off;
    types_hash_max_size 2048;
    client_max_body_size 32M;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    include /etc/nginx/conf.d/*.conf;
}
EOF

    cat > "$GLOBAL_NGINX_PROXY" <<'EOF'
server {
    listen 80;
    server_name localhost;

    location / {
        return 200 'Local LEMP Launcher is running. Open http://project-name.localhost after creating a project.';
        add_header Content-Type text/plain;
    }
}

server {
    listen 80;
    server_name ~^(?<project>[a-z0-9-]+)\.localhost$;

    resolver 127.0.0.11 valid=30s ipv6=off;

    location = /phpmyadmin {
        return 301 /phpmyadmin/;
    }

    location /phpmyadmin/ {
        proxy_pass http://phpmyadmin:80/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300;
    }

    location / {
        proxy_pass http://$project;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300;
        proxy_connect_timeout 30;
        proxy_send_timeout 300;
    }
}
EOF

    cat > "$GLOBAL_NGINX_COMPOSE" <<EOF
services:
  nginx:
    image: nginx:1.27-alpine
    container_name: nginx_proxy
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./nginx/_proxy.conf:/etc/nginx/conf.d/_proxy.conf:ro
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    networks:
      - ${GLOBAL_NETWORK}

  mariadb:
    image: mariadb:11.4
    container_name: mariadb
    restart: unless-stopped
    environment:
      MARIADB_ROOT_PASSWORD: root
    volumes:
      - mariadb_data:/var/lib/mysql
    networks:
      - ${GLOBAL_NETWORK}
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 10

  phpmyadmin:
    image: phpmyadmin:5-apache
    container_name: phpmyadmin
    restart: unless-stopped
    environment:
      PMA_HOST: mariadb
      PMA_PORT: 3306
      MYSQL_ROOT_PASSWORD: root
      PMA_ABSOLUTE_URI: /phpmyadmin/
      UPLOAD_LIMIT: 64M
    ports:
      - "8081:80"
    networks:
      - ${GLOBAL_NETWORK}
    depends_on:
      mariadb:
        condition: service_healthy

  redis:
    image: redis:7-alpine
    container_name: redis
    restart: unless-stopped
    command: ["redis-server", "--requirepass", "root", "--appendonly", "yes"]
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    networks:
      - ${GLOBAL_NETWORK}
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "root", "ping"]
      interval: 10s
      timeout: 3s
      retries: 10

networks:
  ${GLOBAL_NETWORK}:
    external: true

volumes:
  mariadb_data:
  redis_data:
EOF

    success "Global Nginx, MariaDB, Redis, and phpMyAdmin configuration is ready."
}

start_global_stack() {
    section "Starting shared services"
    compose -f "$GLOBAL_NGINX_COMPOSE" up -d
    success "Shared services are running."
}

php_index() {
    local project="$1"
    cat <<EOF
<?php
\$checks = [];

try {
    \$redis = new Redis();
    \$redis->connect('redis', 6379, 2.0);
    \$redis->auth('root');
    \$redis->set('${project}:status', 'ready');
    \$checks[] = ['Redis', true, 'Connected and wrote a test key.'];
} catch (Throwable \$e) {
    \$checks[] = ['Redis', false, \$e->getMessage()];
}

try {
    \$mysqli = new mysqli('mariadb', 'root', 'root');
    if (\$mysqli->connect_error) {
        throw new RuntimeException(\$mysqli->connect_error);
    }
    \$checks[] = ['MariaDB', true, 'Connected to server ' . \$mysqli->server_info . '.'];
    \$mysqli->close();
} catch (Throwable \$e) {
    \$checks[] = ['MariaDB', false, \$e->getMessage()];
}
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${project} | PHP Workspace</title>
    <style>
        :root {
            color-scheme: light;
            --ink: #172026;
            --muted: #5f6c72;
            --line: #d9e1e5;
            --panel: #ffffff;
            --wash: #f4f7f6;
            --accent: #0f8b8d;
            --accent-2: #f25f5c;
            --ok: #18794e;
            --bad: #b42318;
        }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            min-height: 100vh;
            font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            color: var(--ink);
            background: linear-gradient(135deg, #f7fbfa 0%, #eef4f2 48%, #fff8f2 100%);
        }
        main {
            width: min(1080px, calc(100% - 32px));
            margin: 0 auto;
            padding: 48px 0;
        }
        .hero {
            display: grid;
            grid-template-columns: 1.2fr .8fr;
            gap: 28px;
            align-items: stretch;
        }
        .intro, .panel {
            background: rgba(255,255,255,.86);
            border: 1px solid var(--line);
            border-radius: 8px;
            box-shadow: 0 20px 50px rgba(23,32,38,.08);
        }
        .intro { padding: 36px; }
        .eyebrow {
            color: var(--accent);
            font-size: 13px;
            font-weight: 800;
            letter-spacing: .08em;
            text-transform: uppercase;
        }
        h1 {
            margin: 12px 0;
            font-size: clamp(36px, 7vw, 76px);
            line-height: .95;
            letter-spacing: 0;
        }
        p { color: var(--muted); line-height: 1.65; }
        .actions { display: flex; flex-wrap: wrap; gap: 12px; margin-top: 28px; }
        .button {
            display: inline-flex;
            align-items: center;
            min-height: 42px;
            padding: 0 16px;
            border-radius: 6px;
            text-decoration: none;
            font-weight: 800;
            border: 1px solid var(--line);
            color: var(--ink);
            background: #fff;
        }
        .button.primary { background: var(--accent); border-color: var(--accent); color: #fff; }
        .panel { padding: 24px; }
        .panel h2 { margin: 0 0 16px; font-size: 20px; }
        .check {
            display: grid;
            grid-template-columns: auto 1fr;
            gap: 12px;
            padding: 14px 0;
            border-top: 1px solid var(--line);
        }
        .dot {
            width: 12px;
            height: 12px;
            margin-top: 6px;
            border-radius: 50%;
            background: var(--bad);
        }
        .dot.ok { background: var(--ok); }
        code {
            display: inline-block;
            max-width: 100%;
            overflow-wrap: anywhere;
            padding: 3px 6px;
            border-radius: 5px;
            background: #eef3f2;
            color: #294147;
        }
        @media (max-width: 820px) {
            main { padding: 24px 0; }
            .hero { grid-template-columns: 1fr; }
            .intro { padding: 24px; }
        }
    </style>
</head>
<body>
<main>
    <section class="hero">
        <div class="intro">
            <div class="eyebrow">PHP 8.5 + Nginx + MariaDB + Redis</div>
            <h1>${project}</h1>
            <p>This workspace is ready for local development. Edit files in <code>www/${project}/public</code> and refresh the browser.</p>
            <div class="actions">
                <a class="button primary" href="/phpmyadmin/">Open phpMyAdmin</a>
                <a class="button" href="http://${project}.localhost">Reload app</a>
            </div>
        </div>
        <aside class="panel">
            <h2>Service health</h2>
            <?php foreach (\$checks as [\$name, \$ok, \$message]): ?>
                <div class="check">
                    <span class="dot <?= \$ok ? 'ok' : '' ?>"></span>
                    <div>
                        <strong><?= htmlspecialchars(\$name) ?></strong>
                        <p><?= htmlspecialchars(\$message) ?></p>
                    </div>
                </div>
            <?php endforeach; ?>
        </aside>
    </section>
</main>
</body>
</html>
EOF
}

write_php_project() {
    local project="$1"
    local dir="$WWW_DIR/$project"

    section "Creating PHP project"
    mkdir -p "$dir/nginx" "$dir/public" "$dir/logs"

    php_index "$project" > "$dir/public/index.php"

    cat > "$dir/nginx/site.conf" <<EOF
server {
    listen 80;
    server_name ${project}.localhost;
    root /var/www/${project}/public;
    index index.php index.html;

    access_log /var/www/${project}/logs/access.log;
    error_log /var/www/${project}/logs/error.log warn;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_pass php-${project}:9000;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param SCRIPT_NAME \$fastcgi_script_name;
    }
}
EOF

    cat > "$dir/Dockerfile" <<'EOF'
FROM php:8.5-fpm

RUN docker-php-ext-install pdo pdo_mysql mysqli \
    && pecl install redis \
    && docker-php-ext-enable redis mysqli

WORKDIR /var/www/app
EXPOSE 9000
CMD ["php-fpm"]
EOF

    cat > "$dir/docker-compose.yml" <<EOF
services:
  php:
    build:
      context: .
    container_name: php-${project}
    restart: unless-stopped
    working_dir: /var/www/${project}
    volumes:
      - ./:/var/www/${project}
    networks:
      - ${GLOBAL_NETWORK}

  nginx:
    image: nginx:1.27-alpine
    container_name: ${project}
    restart: unless-stopped
    volumes:
      - ./nginx/site.conf:/etc/nginx/conf.d/default.conf:ro
      - ./:/var/www/${project}
    networks:
      - ${GLOBAL_NETWORK}
    depends_on:
      - php

networks:
  ${GLOBAL_NETWORK}:
    external: true
EOF

    success "PHP project files created in $dir."
}

asp_program() {
    local project="$1"
    cat <<EOF
using System.Text;
using MySql.Data.MySqlClient;
using StackExchange.Redis;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", async context =>
{
    var checks = new List<(string Name, bool Ok, string Message)>();

    try
    {
        using var redis = await ConnectionMultiplexer.ConnectAsync("redis,password=root,connectTimeout=2000");
        var db = redis.GetDatabase();
        await db.StringSetAsync("${project}:status", "ready");
        checks.Add(("Redis", true, "Connected and wrote a test key."));
    }
    catch (Exception ex)
    {
        checks.Add(("Redis", false, ex.Message));
    }

    try
    {
        await using var connection = new MySqlConnection("Server=mariadb;User=root;Password=root;");
        await connection.OpenAsync();
        checks.Add(("MariaDB", true, $"Connected to server {connection.ServerVersion}."));
    }
    catch (Exception ex)
    {
        checks.Add(("MariaDB", false, ex.Message));
    }

    var html = new StringBuilder();
    html.Append("""
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${project} | ASP.NET Workspace</title>
    <style>
        :root { --ink:#172026; --muted:#5f6c72; --line:#d9e1e5; --accent:#4f46e5; --accent2:#0f8b8d; --ok:#18794e; --bad:#b42318; }
        * { box-sizing:border-box; }
        body { margin:0; min-height:100vh; font-family:Inter,ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; color:var(--ink); background:linear-gradient(135deg,#f8f9ff 0%,#eef6f4 52%,#fff8f2 100%); }
        main { width:min(1080px,calc(100% - 32px)); margin:0 auto; padding:48px 0; }
        .hero { display:grid; grid-template-columns:1.2fr .8fr; gap:28px; align-items:stretch; }
        .intro,.panel { background:rgba(255,255,255,.88); border:1px solid var(--line); border-radius:8px; box-shadow:0 20px 50px rgba(23,32,38,.08); }
        .intro { padding:36px; }
        .eyebrow { color:var(--accent); font-size:13px; font-weight:800; letter-spacing:.08em; text-transform:uppercase; }
        h1 { margin:12px 0; font-size:clamp(36px,7vw,76px); line-height:.95; letter-spacing:0; }
        p { color:var(--muted); line-height:1.65; }
        .actions { display:flex; flex-wrap:wrap; gap:12px; margin-top:28px; }
        .button { display:inline-flex; align-items:center; min-height:42px; padding:0 16px; border-radius:6px; text-decoration:none; font-weight:800; border:1px solid var(--line); color:var(--ink); background:#fff; }
        .button.primary { background:var(--accent); border-color:var(--accent); color:#fff; }
        .panel { padding:24px; }
        .panel h2 { margin:0 0 16px; font-size:20px; }
        .check { display:grid; grid-template-columns:auto 1fr; gap:12px; padding:14px 0; border-top:1px solid var(--line); }
        .dot { width:12px; height:12px; margin-top:6px; border-radius:50%; background:var(--bad); }
        .dot.ok { background:var(--ok); }
        code { display:inline-block; max-width:100%; overflow-wrap:anywhere; padding:3px 6px; border-radius:5px; background:#eef3f2; color:#294147; }
        @media (max-width:820px) { main { padding:24px 0; } .hero { grid-template-columns:1fr; } .intro { padding:24px; } }
    </style>
</head>
<body>
<main>
    <section class="hero">
        <div class="intro">
            <div class="eyebrow">ASP.NET 8 + Nginx + MariaDB + Redis</div>
            <h1>${project}</h1>
            <p>This workspace runs with dotnet watch. Edit files in <code>www/${project}/source</code> and the app restarts automatically.</p>
            <div class="actions">
                <a class="button primary" href="/phpmyadmin/">Open phpMyAdmin</a>
                <a class="button" href="http://${project}.localhost">Reload app</a>
            </div>
        </div>
        <aside class="panel">
            <h2>Service health</h2>
""");

    foreach (var check in checks)
    {
        var dotClass = check.Ok ? "dot ok" : "dot";
        html.Append($"""
            <div class="check">
                <span class="{dotClass}"></span>
                <div>
                    <strong>{System.Net.WebUtility.HtmlEncode(check.Name)}</strong>
                    <p>{System.Net.WebUtility.HtmlEncode(check.Message)}</p>
                </div>
            </div>
""");
    }

    html.Append("""
        </aside>
    </section>
</main>
</body>
</html>
""");

    context.Response.ContentType = "text/html";
    await context.Response.WriteAsync(html.ToString());
});

app.Run();
EOF
}

write_asp_project() {
    local project="$1"
    local dir="$WWW_DIR/$project"

    section "Creating ASP.NET project"
    mkdir -p "$dir/source" "$dir/nginx"

    asp_program "$project" > "$dir/source/Program.cs"

    cat > "$dir/source/$project.csproj" <<'EOF'
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="MySql.Data" Version="8.4.0" />
    <PackageReference Include="StackExchange.Redis" Version="2.7.33" />
  </ItemGroup>
</Project>
EOF

    cat > "$dir/nginx/site.conf" <<EOF
server {
    listen 80;

    resolver 127.0.0.11 valid=30s ipv6=off;

    location / {
        proxy_pass http://app-${project}:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300;
        proxy_connect_timeout 30;
        proxy_send_timeout 300;
    }
}
EOF

    cat > "$dir/Dockerfile" <<EOF
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS base
WORKDIR /source
EXPOSE 8080

FROM base AS build
COPY ["source/${project}.csproj", "source/"]
RUN dotnet restore "source/${project}.csproj"
COPY ["source/", "source/"]
RUN dotnet publish "source/${project}.csproj" -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "${project}.dll"]
EOF

    cat > "$dir/docker-compose.yml" <<EOF
services:
  app:
    container_name: app-${project}
    build:
      context: .
      dockerfile: Dockerfile
      target: final
    restart: unless-stopped
    networks:
      - ${GLOBAL_NETWORK}

  nginx:
    image: nginx:1.27-alpine
    container_name: ${project}
    restart: unless-stopped
    volumes:
      - ./nginx/site.conf:/etc/nginx/conf.d/default.conf:ro
    networks:
      - ${GLOBAL_NETWORK}
    depends_on:
      - app

networks:
  ${GLOBAL_NETWORK}:
    external: true
EOF

    cat > "$dir/docker-compose.override.yml" <<'EOF'
services:
  app:
    build:
      target: base
    volumes:
      - ./source:/source
    command: dotnet watch run --urls "http://+:8080"
    environment:
      ASPNETCORE_ENVIRONMENT: Development
      DOTNET_USE_POLLING_FILE_WATCHER: "true"
EOF

    success "ASP.NET project files created in $dir."
}

choose_technology() {
    local choice
    local normalized

    echo "Project type:" >&2
    echo "  php  PHP 8.5 with php-fpm" >&2
    echo "  asp  ASP.NET 8 with dotnet watch" >&2
    echo >&2
    choice="$(prompt "Project type" "php")"
    normalized="$(echo "$choice" | tr '[:upper:]' '[:lower:]')"

    case "$normalized" in
        php) echo "php" ;;
        asp|aspnet|dotnet) echo "asp" ;;
        *) fail "Unknown project type '$choice'." ;;
    esac
}

start_project() {
    local project="$1"
    local dir="$WWW_DIR/$project"

    section "Starting $project"
    (cd "$dir" && compose up -d --build)
    success "$project is running at http://${project}.localhost"
}

print_summary() {
    local project="$1"
    local tech="$2"

    echo
    echo "------------------------------------------------------------"
    echo -e "${GREEN}${BOLD}Project ready:${NC} $project ($tech)"
    echo "App:        http://${project}.localhost"
    echo "phpMyAdmin: http://${project}.localhost/phpmyadmin/"
    echo "Database:   mariadb / root / root"
    echo "Redis:      redis:6379 / password root"
    echo "Files:      $WWW_DIR/$project"
    echo
    echo "Useful commands:"
    echo "  cd \"$WWW_DIR/$project\""
    echo "  docker compose ps"
    echo "  docker compose logs -f"
    echo "  docker compose down"
    echo "------------------------------------------------------------"
}

main() {
    print_banner
    require_command docker

    ensure_global_network
    write_global_nginx
    start_global_stack

    echo
    if ! confirm "Create a new project now?" "y"; then
        success "Shared services are ready. Run this script again when you want to add a project."
        exit 0
    fi

    local entered project tech project_dir
    entered="$(prompt "Project name" "demo-app")"
    project="$(normalize_project_name "$entered")"
    validate_project_name "$project"

    if [ "$entered" != "$project" ]; then
        warn "Using normalized project name: $project"
    fi

    project_dir="$WWW_DIR/$project"
    [ ! -d "$project_dir" ] || fail "Project '$project' already exists at $project_dir."

    tech="$(choose_technology)"

    if [ "$tech" = "php" ]; then
        write_php_project "$project"
    else
        write_asp_project "$project"
    fi

    start_project "$project"
    print_summary "$project" "$tech"

    read -r -p "Press Enter to close..."
}

main "$@"
