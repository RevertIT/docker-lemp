#!/bin/bash

# shellcheck disable=SC2188
<<'EOF'
██████╗ ███████╗██╗   ██╗███████╗██████╗ ████████╗██╗████████╗
██╔══██╗██╔════╝██║   ██║██╔════╝██╔══██╗╚══██╔══╝██║╚══██╔══╝
██████╔╝█████╗  ██║   ██║█████╗  ██████╔╝   ██║   ██║   ██║
██╔══██╗██╔══╝  ╚██╗ ██╔╝██╔══╝  ██╔══██╗   ██║   ██║   ██║
██║  ██║███████╗ ╚████╔╝ ███████╗██║  ██║   ██║   ██║   ██║
╚═╝  ╚═╝╚══════╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝   ╚═╝
-------------------------------------------------------------
Automated Project Setup for PHP/ASP.NET, Nginx, and Docker
-------------------------------------------------------------

Author: @RevertIT & Gemini
License: MIT
Copyright (C) 2025 RevertIT
Description:
This script automates the creation of a PHP or ASP.NET project
environment with Nginx and Docker integration.
EOF

# Exit immediately if a command exits with a non-zero status.
set -e

# Dynamically determine the current directory (environment folder)
BASE_DIR=$(pwd)

# Global Nginx setup
GLOBAL_NGINX_DIR="$BASE_DIR/nginx"
GLOBAL_NGINX_COMPOSE="$BASE_DIR/docker-compose.yml"
GLOBAL_NGINX_PROXY="$BASE_DIR/nginx/_proxy.conf"
GLOBAL_NGINX_CONFIG="$BASE_DIR/nginx/nginx.conf"

# Ensure the global proxy exists and is running
echo "Checking global Nginx reverse proxy setup..."

if [ ! -d "$GLOBAL_NGINX_DIR" ]; then
    echo "Global Nginx directory not found. Creating..."
    mkdir -p "$GLOBAL_NGINX_DIR"
fi

# Create Global Nginx Configuration
if [ ! -f "$GLOBAL_NGINX_CONFIG" ]; then
    echo "Global Nginx nginx.conf config not found. Creating..."
    cat > "$GLOBAL_NGINX_CONFIG" <<EOL
user                  nginx;
pid                   /var/run/nginx.pid;
worker_processes      auto;
worker_rlimit_nofile  65535;

# Load modules
include               /etc/nginx/modules-enabled/*.conf;

events {
    multi_accept       on;
    worker_connections 65535;
}

http {
    charset                utf-8;
    sendfile               on;
    tcp_nopush             on;
    tcp_nodelay            on;
    server_tokens          off;
    log_not_found          off;
    types_hash_max_size    2048;
    types_hash_bucket_size 64;
    client_max_body_size   16M;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    # MIME
    include                mime.types;
    default_type           application/octet-stream;

    include /etc/nginx/conf.d/*.conf;
}
EOL
    echo "Created Global Nginx nginx.conf config."
fi

# Create Global Nginx _proxy.conf Configuration
if [ ! -f "$GLOBAL_NGINX_PROXY" ]; then
    echo "Global Nginx proxy config not found. Creating..."
    cat > "$GLOBAL_NGINX_PROXY" <<EOL
server {
    listen 80;
    server_name ~^(?<subdomain>.+)\.localhost$;

    resolver 127.0.0.11 valid=30s;

    # Routing for phpMyAdmin
    location /phpmyadmin/ {
        proxy_pass http://phpmyadmin:80/;  # Forwarding to phpmyadmin container
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location / {
        proxy_pass http://\$subdomain;

        # Pass necessary headers
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # Handle timeouts
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }

    # Optional: Debug logging
    error_log /var/log/nginx/error.log debug;
}
EOL
    echo "Created global Nginx proxy config."
fi

# Create Global Docker Compose configuration
if [ ! -f "$GLOBAL_NGINX_COMPOSE" ]; then
    echo "Global Docker Compose configuration not found. Creating..."
    cat > "$GLOBAL_NGINX_COMPOSE" <<EOL
services:
  nginx:
    image: nginx:latest
    container_name: nginx_proxy
    ports:
      - "80:80"
    volumes:
      - ./nginx/_proxy.conf:/etc/nginx/conf.d/_proxy.conf
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
    networks:
      - global_network

  mariadb:
    image: mariadb:latest
    container_name: mariadb
    environment:
      MYSQL_ROOT_PASSWORD: root
    networks:
      - global_network

  phpmyadmin:
    image: phpmyadmin/phpmyadmin:latest
    container_name: phpmyadmin
    environment:
      PMA_HOST: mariadb
      PMA_PORT: 3306
      MYSQL_ROOT_PASSWORD: root
      PMA_ABSOLUTE_URI: "/phpmyadmin/"
    ports:
      - "8081:80"
    networks:
      - global_network

  redis:
    image: redis:alpine
    container_name: redis
    ports:
      - "6379:6379"
    networks:
      - global_network
    command: ["redis-server", "--requirepass", "root"]

networks:
  global_network:
    external: true
EOL
    echo "Created global Docker Compose configuration."
fi

# Bring up the global proxy if not already running
if ! docker ps | grep -q nginx_proxy; then
    echo "Starting global Nginx reverse proxy..."
    docker-compose -f "$GLOBAL_NGINX_COMPOSE" up -d
else
    echo "Global Nginx reverse proxy is already running."
fi

# Project creation begins here
echo "----------------------------------------------------"
echo "Do you want to create a new project? (y/n):"

# shellcheck disable=SC2162
read CREATE_PROJECT

if [[ ! "$CREATE_PROJECT" =~ ^(yes|y|Y)$ ]]; then
    echo "Project creation canceled. Exiting."
    exit 0
fi

# Prompt for project name
echo "Enter the project name (e.g., 'my-app'):"

# shellcheck disable=SC2162
read PROJECT_NAME

if [ -z "$PROJECT_NAME" ]; then
    echo "Project name cannot be empty."
    exit 1
fi

# Define project directory
PROJECT_DIR="$BASE_DIR/www/$PROJECT_NAME"

if [ -d "$PROJECT_DIR" ]; then
    echo "Project '$PROJECT_NAME' already exists. Please choose a different name."
    exit 1
fi

# Prompt for technology choice
echo "Which technology do you want to use? (php/asp):"
# shellcheck disable=SC2162
read TECH_CHOICE

# --- PHP Project Setup ---
if [[ "$TECH_CHOICE" == "php" ]]; then
    echo "Creating PHP project structure for $PROJECT_NAME..."
    mkdir -p "$PROJECT_DIR/nginx" "$PROJECT_DIR/public" "$PROJECT_DIR/logs"

    # <<< UPDATED index.php for PHP with full HTML structure >>>
    cat > "$PROJECT_DIR/public/index.php" <<EOL
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$PROJECT_NAME</title>
</head>
<body>
    <h1>Welcome to $PROJECT_NAME! (PHP)</h1>

    <h2>Redis Connection Test</h2>
    <?php
    try
    {
        \$redis = new Redis();
        \$redis->connect('redis', 6379);
        \$redis->auth('root');
        \$redis->set("test_key", "Redis is working!");
        \$value = \$redis->get("test_key");
        echo "<p style='color: green;'>Redis Connection Successful: <strong>\$value</strong></p>";
    }
    catch (Exception \$e)
    {
        echo "<p style='color: red;'>Redis Connection Failed: " . \$e->getMessage() . "</p>";
    }
    ?>

    <h2>MariaDB Connection Test</h2>
    <?php
    \$mysqli = new mysqli('mariadb', 'root', 'root');
    if (\$mysqli->connect_error)
    {
        echo "<p style='color: red;'>MariaDB Connection Failed: " . \$mysqli->connect_error . "</p>";
    }
    else
    {
        echo "<p style='color: green;'>MariaDB Connection Successful: Connected to MySQL server version " . \$mysqli->server_info . "</p>";
        \$mysqli->close();
    }
    ?>
    <p>Access phpMyAdmin <a href="/phpmyadmin/" target="_blank">here</a>.</p>
</body>
</html>
EOL
    echo "Created index.php file."

    # Create Nginx configuration for PHP
    cat > "$PROJECT_DIR/nginx/site.conf" <<EOL
server {
    listen                  80;
    server_name             $PROJECT_NAME.localhost;
    set                     \$base /var/www/${PROJECT_NAME};
    root                    \$base/public;
    index                   index.php;
    access_log              /var/www/${PROJECT_NAME}/logs/access.log;
    error_log               /var/www/${PROJECT_NAME}/logs/error.log;

    location / {
      try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
      fastcgi_pass php_${PROJECT_NAME}:9000;
      include      fastcgi_params;
      fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOL
    echo "Created Nginx config for PHP."

    # Create Dockerfile for PHP
    cat > "$PROJECT_DIR/Dockerfile" <<EOL
FROM php:8.4-fpm
RUN docker-php-ext-install pdo pdo_mysql mysqli && docker-php-ext-enable mysqli
RUN pecl install redis && docker-php-ext-enable redis
COPY . /var/www/${PROJECT_NAME}
EXPOSE 9000
CMD ["php-fpm"]
EOL
    echo "Created Dockerfile for PHP."

    # Create Docker Compose file for PHP
    cat > "$PROJECT_DIR/docker-compose.yml" <<EOL
services:
  php:
    build:
      context: .
    container_name: php_${PROJECT_NAME}
    expose:
      - "9000"
    volumes:
      - ./:/var/www/${PROJECT_NAME}
    networks:
      - global_network

  nginx:
    image: nginx:latest
    container_name: ${PROJECT_NAME}
    volumes:
      - ./nginx/site.conf:/etc/nginx/conf.d/${PROJECT_NAME}.conf
      - ./logs:/var/www/${PROJECT_NAME}/logs
      - ./public:/var/www/${PROJECT_NAME}/public
    networks:
      - global_network

networks:
  global_network:
    external: true
EOL
    echo "Created Docker Compose file for PHP."

# --- ASP.NET Project Setup ---
elif [[ "$TECH_CHOICE" == "asp" ]]; then
    echo "Creating ASP.NET project structure for $PROJECT_NAME..."
    mkdir -p "$PROJECT_DIR/source" "$PROJECT_DIR/nginx"

    # Create Program.cs
    cat > "$PROJECT_DIR/source/Program.cs" <<EOL
using System.Text;
using MySql.Data.MySqlClient;
using StackExchange.Redis;
using Microsoft.AspNetCore.Mvc;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
var app = builder.Build();

app.MapGet("/", async (HttpContext context) => {
    var html = new StringBuilder();
    html.Append("<!DOCTYPE html><html lang=\"en\"><head><title>$PROJECT_NAME</title></head><body>");
    html.Append("<h1>Welcome to $PROJECT_NAME! (ASP.NET)</h1>");

    // Redis
    html.Append("<h2>Redis Connection Test</h2>");
    try
    {
        using var redis = await ConnectionMultiplexer.ConnectAsync("redis,password=root");
        var db = redis.GetDatabase();
        await db.StringSetAsync("test_key", "Redis is working!");
        var value = await db.StringGetAsync("test_key");
        html.Append($"<p style='color: green;'>Redis Connection Successful: <strong>{value}</strong></p>");
    }
    catch (Exception e) { html.Append($"<p style='color: red;'>Redis Connection Failed: {e.Message}</p>"); }

    // MariaDB
    html.Append("<h2>MariaDB Connection Test</h2>");
    try
    {
        await using var connection = new MySqlConnection("Server=mariadb;User=root;Password=root;");
        await connection.OpenAsync();
        html.Append($"<p style='color: green;'>MariaDB Connection Successful: Connected to MySQL server version {connection.ServerVersion}</p>");
    }
    catch (Exception e) { html.Append($"<p style='color: red;'>MariaDB Connection Failed: {e.Message}</p>"); }

    html.Append("<p>Access phpMyAdmin <a href=\"/phpmyadmin/\" target=\"_blank\">here</a>.</p>");
    html.Append("</body></html>");
    context.Response.ContentType = "text/html";
    await context.Response.WriteAsync(html.ToString());
});

app.MapControllers();
app.Run();
EOL
    echo "Created Program.cs file."

    # Create .csproj
    cat > "$PROJECT_DIR/source/$PROJECT_NAME.csproj" <<EOL
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
EOL
    echo "Created ${PROJECT_NAME}.csproj file."

    # <<< UPDATED Nginx conf for ASP.NET with resilient proxy_pass >>>
    cat > "$PROJECT_DIR/nginx/site.conf" <<EOL
server {
    listen 80;
    resolver 127.0.0.11 valid=30s;
    location / {
        set \$upstream_app http://app:8080;
        proxy_pass \$upstream_app;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL
    echo "Created Nginx config for ASP.NET."

    # Create Dockerfile
    cat > "$PROJECT_DIR/Dockerfile" <<EOL
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS base
WORKDIR /source
EXPOSE 8080

FROM base AS build
COPY ["source/${PROJECT_NAME}.csproj", "source/"]
RUN dotnet restore "source/${PROJECT_NAME}.csproj"
COPY ["source/", "source/"]
RUN dotnet publish "source/${PROJECT_NAME}.csproj" -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "${PROJECT_NAME}.dll"]
EOL
    echo "Created Dockerfile for ASP.NET."

    # <<< UPDATED base docker-compose.yml for ASP.NET with restart policy >>>
    cat > "$PROJECT_DIR/docker-compose.yml" <<EOL
services:
  app:
    container_name: ${PROJECT_NAME}_app
    build:
      context: .
      dockerfile: Dockerfile
      target: final
    networks:
      - global_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/"]
      interval: 10s
      timeout: 10s
      retries: 5
      start_period: 10s

  nginx:
    image: nginx:latest
    container_name: ${PROJECT_NAME}
    restart: unless-stopped
    volumes:
      - ./nginx/site.conf:/etc/nginx/conf.d/default.conf
    networks:
      - global_network
    depends_on:
      app:
        condition: service_healthy

networks:
  global_network:
    external: true
EOL
    echo "Created base Docker Compose file for ASP.NET."

    # Create override file
    cat > "$PROJECT_DIR/docker-compose.override.yml" <<EOL
services:
  app:
    build:
      target: base
    volumes:
      - ./source:/source
    command: dotnet watch run --urls "http://+:8080"
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
EOL
    echo "Created Docker Compose override file for ASP.NET development."

else
    echo "Invalid technology choice. Please enter 'php' or 'asp'."
    exit 1
fi

# Bring up the project
if ! docker ps | grep -q "$PROJECT_NAME"; then
    echo "Starting $PROJECT_NAME..."
    (cd "$PROJECT_DIR" && docker-compose up -d --build)
else
    echo "$PROJECT_NAME is already running."
fi

# Disable 'exit on error' to ensure the final message and pause always run
set +e

# Print success message
echo "----------------------------------------------------"
echo "✅ Project '$PROJECT_NAME' setup is complete!"
echo "Access your project at: http://${PROJECT_NAME}.localhost"
echo "----------------------------------------------------"

# Pause the script until the user presses Enter
read -p "Press [Enter] to exit..."