A **dynamic *30-seconds* project setup script** for PHP, Nginx, MariaDB, Redis, and Docker-based environments. 

This script automates the process of creating a fully functional PHP project environment with Composer support and Docker integration. It is designed to streamline the development workflow by reducing manual configuration and setup time.

Similar to LEMP stack. (Nginx MariaDB PHP Redis)

![image](https://github.com/user-attachments/assets/212b0b58-ffe9-4669-9932-e9a19f551484)

---

## **Installation**

Get the `setup_nginx_project.sh` file and double click on Windows if you have git installed, or via terminal `./setup_nginx_project.sh`

The project name you type will be subdomain, for example if name of the project is skeleton, it will be accessible to `http://skeleton.localhost`

You can make as many as you want projects.

## **Features**

- **Deploy in less than 30 seconds:**
After downloading necessary docker images, it takes less than 30 seconds to deploy php ready environment with custom nginx server and php configuration which can be changed anytime.

- **Global Nginx Reverse Proxy:**  
  Uses global nginx proxy to handle all created containers to correct project location when accesssing via subdomain. eg. http://project1.localhost

- **Automated Directory Structure:**  
  ```plaintext
  environment/ - the folder you will make to hold the script file
  └── nginx/ # Location for global nginx config
      └── default.conf # Global nginx reverse proxy config
  └── www/ # Location for projects
      └── <project_name>/
          ├── public/
          │   └── index.php      # Default PHP entry point
          ├── nginx/
          │   └── site.conf      # Project-specific Nginx configuration
          ├── composer.json      # Composer initialization file
          ├── composer.lock      # Composer lock file
          └── docker-compose.yml # Docker Compose file for the project
  └── docker-compose.yml # Location for global nginx proxy docker compose file
  └── setup_nginx_project.sh # File we use to do all the magic
  ```

- **Composer-Ready Setup:**  
  Installs and initializes Composer in the project, enabling easy dependency management.

- **phpMyAdmin Integration:**  
  - Configures phpMyAdmin to be accessible at `/phpmyadmin/` in the browser and shares same mariadb server across all containers.
  - Accessible at `http://project_name.localhost/phpmyadmin/` via Username: root :: Password: root
 

## **Useful commands**

- **Access container as root:**
  In case you need to access container as root user for any reason you can do so by typing into terminal:
  
  `docker exec -it php_projectName /bin/bash`

   *By default, files inside your project folder are automatically linked with container volume, so any changes to your nginx/php files will be reflected without needing to access container as root*
   
   *Accessing root will let you also install packages to the container server or updating existing or changing server settings*
