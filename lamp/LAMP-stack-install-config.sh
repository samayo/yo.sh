#!/bin/bash
# v2
# This script installs and configures Nginx, PHP-FPM, and MariaDB on a Debian-based system.
# It assumes your server is already secured and updated via a separate initial setup script.

set -euo pipefail
IFS=$'\n\t'

PHP_VERSION="8.2"
NGINX_USER="www-data"
DEBIAN_FRONTEND=noninteractive

log_msg() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root" >&2
        exit 1
    fi
}

install_packages() {
    log_msg "Installing $1..."
    apt-get install -y -qq $2
}

add_php_repository() {
    log_msg "Adding Ondrej PHP repository..."
    apt-get update -qq
    apt-get install -y -qq ca-certificates apt-transport-https software-properties-common lsb-release
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/sury-php.list
    wget -qO - https://packages.sury.org/php/apt.gpg | apt-key add -
    apt-get update -qq
}

main() {
    check_root

    log_msg "Updating system packages..."
    apt-get update -qq
    apt-get upgrade -y -qq

    install_packages "Nginx" "nginx"
    systemctl enable nginx
    systemctl start nginx
    if ! systemctl is-active --quiet nginx; then
        log_msg "ERROR: Nginx failed to start. Check logs for details."
        exit 1
    fi

    install_packages "MariaDB" "mariadb-server"
    systemctl enable mariadb
    systemctl start mariadb
    if ! systemctl is-active --quiet mariadb; then
        log_msg "ERROR: MariaDB failed to start. Check logs for details."
        exit 1
    fi

    log_msg "Securing MariaDB..."
    MYSQL_ROOT_PASSWORD=$(openssl rand -base64 20)

    # Use mysqladmin to set initial root password
    mysqladmin -u root password "${MYSQL_ROOT_PASSWORD}"

    # Now use mysql with the password to perform remaining security operations
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<EOF
    DELETE FROM mysql.user WHERE User='';
    DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
    DROP DATABASE IF EXISTS test;
    DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
    FLUSH PRIVILEGES;
    EOF

    log_msg "MariaDB root password set to: ${MYSQL_ROOT_PASSWORD}"
    echo "MariaDB root password: ${MYSQL_ROOT_PASSWORD}" >> /root/mysql_root_password.txt
    chmod 600 /root/mysql_root_password.txt

    # Add Ondrej Sury's PPA for PHP 8.2
    add_php_repository

    log_msg "Installing PHP and extensions..."
    install_packages "PHP and extensions" \
        "php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql php${PHP_VERSION}-curl php${PHP_VERSION}-gd php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-intl"
    
    systemctl enable php${PHP_VERSION}-fpm
    systemctl start php${PHP_VERSION}-fpm
    if ! systemctl is-active --quiet php${PHP_VERSION}-fpm; then
        log_msg "ERROR: PHP-FPM failed to start. Check logs for details."
        exit 1
    fi

    log_msg "Configuring PHP-FPM..."
    
    # Update PHP configuration settings using sed 
    sed -i "s/upload_max_filesize = .*/upload_max_filesize = 10M/" /etc/php/${PHP_VERSION}/fpm/php.ini
    sed -i "s/post_max_size = .*/post_max_size = 10M/" /etc/php/${PHP_VERSION}/fpm/php.ini
    sed -i "s/expose_php = .*/expose_php = Off/" /etc/php/${PHP_VERSION}/fpm/php.ini
    sed -i "s/display_errors = .*/display_errors = Off/" /etc/php/${PHP_VERSION}/fpm/php.ini
    sed -i "s/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/" /etc/php/${PHP_VERSION}/fpm/php.ini
    sed -i "s/;max_execution_time = .*/max_execution_time = 300/" /etc/php/${PHP_VERSION}/fpm/php.ini
    sed -i "s/;max_input_time = .*/max_input_time = 60/" /etc/php/${PHP_VERSION}/fpm/php.ini
    sed -i "s/;memory_limit = .*/memory_limit = 256M/" /etc/php/${PHP_VERSION}/fpm/php.ini
    sed -i "s/;date.timezone =.*/date.timezone = UTC/" /etc/php/${PHP_VERSION}/fpm/php.ini

    log_msg "Configuring Nginx..."
    
cat > /etc/nginx/sites-available/default <<EOL
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/html;
    index index.php index.html index.htm;

    access_log /var/log/nginx/access.log combined buffer=512k flush=1m;
    error_log /var/log/nginx/error.log warn;

    location ~* \.(jpg|jpeg|gif|png|css|js|ico|xml)$ {
        access_log off;
        log_not_found off;
        expires 30d;
    }

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;

        fastcgi_hide_header X-Powered-By;
        add_header X-Frame-Options "SAMEORIGIN";
        add_header X-Content-Type-Options "nosniff";
        add_header X-XSS-Protection "1; mode=block";
        add_header Referrer-Policy "no-referrer-when-downgrade";
        add_header Content-Security-Policy "default-src 'self';";
    }

    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOL

    nginx -t || { 
        log_msg "Error: Nginx configuration test failed. Please check the configuration."; 
        exit 1; 
      }

    systemctl restart nginx

    echo "<?php phpinfo(); ?>" > /var/www/html/info.php
    chown -R ${NGINX_USER}:${NGINX_USER} /var/www/html

    log_msg "Installation complete!"
    echo "-----------------------------------"
    echo "PHP Version: $PHP_VERSION"
    echo "Test PHP at: http://your-server-ip/info.php"
    echo "Remember to delete info.php after testing!"
    
	if [ -f /root/mysql_root_password.txt ]; then
	    echo "MariaDB root password has been saved to /root/mysql_root_password.txt"
	fi
	
	echo "IMPORTANT: If your server is using DHCP, your IP address may change. Consider setting a static IP."
	echo "-----------------------------------"
}

main "$@"
