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
Automated Project Setup for PHP, Nginx, and Docker
-------------------------------------------------------------

Author: @RevertIT
License: MIT
Copyright (C) 2025 RevertIT
Description:
This script automates the creation of a PHP project environment
with Nginx, Composer, and Docker integration. It is tailored to
simplify development and minimize repetitive setup tasks.
EOF

# Exit immediately if a command exits with a non-zero status.
set -e

# Dynamically determine the current directory (environment folder)
BASE_DIR=$(pwd)

# Global Nginx setup
GLOBAL_NGINX_DIR="$BASE_DIR/nginx"
GLOBAL_NGINX_COMPOSE="$BASE_DIR/docker-compose.yml"
GLOBAL_NGINX_CONFIG="$GLOBAL_NGINX_DIR/default.conf"

# Ensure the global proxy exists and is running
echo "Checking global Nginx reverse proxy setup..."

if [ ! -d "$GLOBAL_NGINX_DIR" ]; then
    echo "Global Nginx directory not found. Creating..."
    mkdir -p "$GLOBAL_NGINX_DIR"
fi

# Create Global Nginx Configuration
if [ ! -f "$GLOBAL_NGINX_CONFIG" ]; then
    echo "Global Nginx configuration not found. Creating..."
    cat > "$GLOBAL_NGINX_CONFIG" <<EOL
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
        proxy_pass http://\$subdomain:80;

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
    echo "Created global Nginx configuration."
fi

# Create Global Docker Compose configuration
if [ ! -f "$GLOBAL_NGINX_COMPOSE" ]; then
    echo "Global Docker Compose configuration not found. Creating..."
    cat > "$GLOBAL_NGINX_COMPOSE" <<EOL
services:
  global_nginx:
    image: nginx:latest
    container_name: global_nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/proxy.conf
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
      - "8081:80"  # Exposing phpMyAdmin on port 8081 inside the container
    networks:
      - global_network

networks:
  global_network:
    external: true
EOL
    echo "Created global Docker Compose configuration."
fi

# Bring up the global proxy if not already running
if ! docker ps | grep -q global_nginx; then
    echo "Starting global Nginx reverse proxy..."
    docker-compose -f "$GLOBAL_NGINX_COMPOSE" up -d
else
    echo "Global Nginx reverse proxy is already running."
fi

# Project creation begins here

# Prompt to create a new project
echo "Do you want to create a new project? (y/n):"

# shellcheck disable=SC2162
read CREATE_PROJECT

# Check if the input is 'y' or 'yes', otherwise exit the script
if [[ ! "$CREATE_PROJECT" =~ ^(yes|y|Y)$ ]]; then
    echo "Project creation canceled. Exiting here."
    exit 0
fi

# Prompt for project name
echo "Enter the project name:"

# shellcheck disable=SC2162
read PROJECT_NAME

# Ensure project name is not empty
if [ -z "$PROJECT_NAME" ]; then
    echo "Project name cannot be empty."
    exit 1
fi

# Define project directory
PROJECT_DIR="$BASE_DIR/www/$PROJECT_NAME"

# Check if the project directory already exists
if [ -d "$PROJECT_DIR" ]; then
    echo "Project '$PROJECT_NAME' already exists. Please choose a different name."
    exit 1
fi

# Create project directory structure
echo "Creating project structure for $PROJECT_NAME..."

if ! mkdir -p "$PROJECT_DIR/nginx" "$PROJECT_DIR/public"; then
    echo "Failed to create directories for the project. Check file permissions."
    exit 1
fi

# Create logs folder
LOGS_DIR="$PROJECT_DIR/logs"

if [ -d "$LOGS_DIR" ]; then
    echo "Directory '$LOGS_DIR' already exists. Skipping creation."
else
    mkdir -p "$PROJECT_DIR/logs"
    echo "Created logs directory."
fi

# Create index.php
INDEX_PHP="$PROJECT_DIR/public/index.php"
if [ -f "$INDEX_PHP" ]; then
    echo "File '$INDEX_PHP' already exists. Skipping creation."
else
    cat > "$INDEX_PHP" <<EOL
<?php
echo "Welcome to $PROJECT_NAME! You can access phpMyAdmin by <a href=\"/phpmyadmin/\" target=\"_blank\">clicking here</a>";
?>
EOL
    echo "Created index.php file."
fi

# Create Nginx configuration
NGINX_CONF="$PROJECT_DIR/nginx/site.conf"
if [ -f "$NGINX_CONF" ]; then
    echo "Nginx config '$NGINX_CONF' already exists. Skipping creation."
else
    cat > "$NGINX_CONF" <<EOL
server {
    listen 80;
    server_name $PROJECT_NAME.localhost;

    # Access and error logs inside the project folder
    access_log /var/www/${PROJECT_NAME}/logs/access.log;
    error_log /var/www/${PROJECT_NAME}/logs/error.log;

    # Common security practices
    # Disable unwanted HTTP methods
    if (\$request_method !~ ^(GET|POST|HEAD)$) {
        return 405;
    }

    # Prevent accessing hidden files (starting with dot)
    location ~ /\.(?!well-known).* {
        deny all;
    }

    # Set security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header Content-Security-Policy "default-src 'self';" always;

    # PHP handling
    location ~ \.php$ {
        fastcgi_pass php_$PROJECT_NAME:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME /var/www/${PROJECT_NAME}/public\$fastcgi_script_name;
        include fastcgi_params;
    }

    # Main file serving
    location / {
        root /var/www/${PROJECT_NAME}/public;
        index index.php;
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # Disable .git or other source control access
    location ~ /\.git {
        deny all;
    }
}
EOL
    echo "Created Nginx config."
fi

# Create Dockerfile
DOCKERFILE="$PROJECT_DIR/Dockerfile"
if [ -f "$DOCKERFILE" ]; then
    echo "Dockerfile '$DOCKERFILE' already exists. Skipping creation."
else
    cat > "$DOCKERFILE" <<EOL
FROM php:8.4-fpm

# Install PHP extensions
RUN docker-php-ext-install pdo pdo_mysql

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Copy the project files to the container
COPY . /var/www/${PROJECT_NAME}

# Expose PHP-FPM port
EXPOSE 9000

# Start PHP-FPM
CMD ["php-fpm"]

EOL
    echo "Created Dockerfile."
fi

# Create Docker Compose file
DOCKER_COMPOSE="$PROJECT_DIR/docker-compose.yml"
if [ -f "$DOCKER_COMPOSE" ]; then
    echo "Docker Compose file '$DOCKER_COMPOSE' already exists. Skipping creation."
else
    cat > "$DOCKER_COMPOSE" <<EOL
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
      - ./nginx/site.conf:/etc/nginx/conf.d/${PROJECT_NAME}.conf # Mount config file
      - ./logs:/var/www/${PROJECT_NAME}/logs # Mount logs directory
    networks:
      - global_network

networks:
  global_network:
    external: true
EOL
    echo "Created Docker Compose file."
fi

# Bring up the global proxy if not already running
if ! docker ps | grep -q "$PROJECT_NAME"; then
    echo "Starting $PROJECT_NAME..."
    docker-compose -f "$PROJECT_DIR"/docker-compose.yml up -d
else
    echo "$PROJECT_NAME is already running."
fi

# Print success message
# We are automatically running this, no need
#echo "Project $PROJECT_NAME setup is complete!"
#echo "To start the project, run:"
#echo "docker-compose -f $PROJECT_DIR/docker-compose.yml up -d"
