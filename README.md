A **dynamic **_**30-seconds**_** project setup script** for **PHP or ASP.NET**, Nginx, MariaDB, Redis, and Docker-based environments.

This script automates the process of creating a fully functional project environment with either PHP (with Composer) or ASP.NET Core (with live-reloading). It is designed to streamline the development workflow by reducing manual configuration and setup time.

Similar to a LEMP stack (Nginx MariaDB PHP Redis) or an ASP.NET Core stack.

![image](https://github.com/user-attachments/assets/212b0b58-ffe9-4669-9932-e9a19f551484)

## **Installation**

Get the `setup_nginx_project.sh` file and run it. On Windows, you can double-click it if you have Git Bash installed. On Linux/macOS, run it via the terminal: `./setup_nginx_project.sh`

The project name you type will become the subdomain. For example, if the name of the project is `skeleton`, it will be accessible at `http://skeleton.localhost`.

You can create as many projects as you want.

## **Features**

* **Deploy in less than 30 seconds:** After downloading the necessary Docker images for the first time, it takes less than 30 seconds to deploy a complete, ready-to-code environment.

* **Choice of Technology:** The script will prompt you to choose between a classic PHP setup or a modern ASP.NET Core environment.

* **Global Nginx Reverse Proxy:** Uses a global Nginx proxy to handle all created containers, routing traffic to the correct project when you access it via its subdomain (e.g., `http://project1.localhost`).

* **Automated Directory Structure:** The script generates a clean, logical structure for your chosen technology.

  **PHP Structure:**

  ```
  www/
  └── <project_name>/
      ├── public/
      │   └── index.php
      ├── nginx/
      │   └── site.conf
      ├── logs/
      ├── Dockerfile
      └── docker-compose.yml

  ```

  **ASP.NET Structure:**

  ```
  www/
  └── <project_name>/
      ├── source/
      │   ├── <project_name>.csproj
      │   └── Program.cs
      ├── nginx/
      │   └── site.conf
      ├── Dockerfile
      ├── docker-compose.yml
      └── docker-compose.override.yml

  ```

* **Ready-to-Code Setup:**

    * **PHP** projects come with `php-fpm`, `mysqli`, and `redis` extensions installed and ready to use.

    * **ASP.NET** projects are configured with `dotnet watch` for instant, live reloading of your code as you make changes.

* **phpMyAdmin Integration:**

    * A global phpMyAdmin container is configured to be accessible at `/phpmyadmin/` on any project URL.

    * Accessible at `http://project_name.localhost/phpmyadmin/` with Username: `root` and Password: `root`.

## **Useful commands**

* **Access container as root:** If you need to access a container's shell (e.g., to install new packages), you can use the `docker exec` command. The command differs slightly depending on the project type.

  **For a PHP project:**

  ```
  docker exec -it php_projectName /bin/bash

  ```

  **For an ASP.NET project:**

  ```
  docker exec -it projectName_app /bin/bash

  ```

  _(Replace `projectName` with the actual name of your project.)_

    **Note on Live Reloading:** By default, your local project folder is linked to the container volume. 
    * For **PHP**, any changes you make to `.php` files are reflected instantly. 
    * For **ASP.NET**, the `dotnet watch` command automatically detects changes, recompiles your application, and restarts the server for you.