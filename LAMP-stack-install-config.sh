#!/bin/bash
# This script installs and configures Nginx, PHP-FPM, and MariaDB on a Debian-based system.
# It assumes your server is already secured and updated via a separate initial setup script.

# Exit on error, undefined variables, and prevent pipeline errors
set -euo pipefail
IFS=$'\n\t'

# Define variables
PHP_VERSION="8.2"  # Updated to latest stable PHP version
NGINX_USER="www-data"
DEBIAN_FRONTEND=noninteractive  # Prevent interactive prompts

# Function to log installation steps
log_msg() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root" >&2
        exit 1
    fi
}

# Function to install packages
install_packages() {
    log_msg "Installing $1..."
    apt-get install -y $2
}

# Main installation
main() {
    check_root
    
    # Update package lists
    log_msg "Updating package lists..."
    apt-get update
    
    # 1. Install Nginx
    install_packages "Nginx" "nginx"
    systemctl enable nginx
    systemctl start nginx
    
    # 2. Install MariaDB
    install_packages "MariaDB" "mariadb-server"
    systemctl enable mariadb
    systemctl start mariadb

    # Configure MariaDB root to use unix socket authentication
    log_msg "Configuring MariaDB root authentication..."
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED VIA unix_socket;"
    mysql -e "DELETE FROM mysql.global_priv WHERE User='';"
    mysql -e "DELETE FROM mysql.global_priv WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    mysql -e "FLUSH PRIVILEGES;"
    
    # 3. Install PHP-FPM and common extensions
    log_msg "Installing PHP and extensions..."
    install_packages "PHP and extensions" "php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql php${PHP_VERSION}-curl php${PHP_VERSION}-gd php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-intl"
    
    systemctl enable php${PHP_VERSION}-fpm
    systemctl start php${PHP_VERSION}-fpm
    
    # 4. Configure PHP-FPM for better security
    sed -i "s/upload_max_filesize = .*/upload_max_filesize = 10M/" /etc/php/${PHP_VERSION}/fpm/php.ini
    sed -i "s/post_max_size = .*/post_max_size = 10M/" /etc/php/${PHP_VERSION}/fpm/php.ini
    sed -i "s/expose_php = .*/expose_php = Off/" /etc/php/${PHP_VERSION}/fpm/php.ini
    
    # 5. Configure Nginx with optimized settings
    cat > /etc/nginx/sites-available/default << 'EOL'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/html;
    index index.php index.html index.htm;

    # Access and error logs
    access_log /var/log/nginx/access.log combined buffer=512k flush=1m;
    error_log /var/log/nginx/error.log warn;

    # Optimize file serving
    location ~* \.(jpg|jpeg|gif|png|css|js|ico|xml)$ {
        access_log off;
        log_not_found off;
        expires 30d;
    }

    # Main location block
    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    # Process PHP files
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        
        # Security headers
        fastcgi_hide_header X-Powered-By;
        add_header X-Frame-Options "SAMEORIGIN";
        add_header X-Content-Type-Options "nosniff";
        add_header X-XSS-Protection "1; mode=block";
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOL
    
    # Test Nginx configuration
    nginx -t
    systemctl reload nginx
    
    # Create info.php file for testing
    echo "<?php phpinfo(); ?>" > /var/www/html/info.php
    
    # Set proper permissions
    chown -R ${NGINX_USER}:${NGINX_USER} /var/www/html
    
    # Output completion message
    log_msg "Installation complete!"
    echo "-----------------------------------"
    echo "PHP Version: $PHP_VERSION"
    echo "Test PHP at: http://your-ip/info.php"
    echo "Remember to delete info.php after testing!"
    echo "-----------------------------------"
}

# Run main function
main
