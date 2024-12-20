#!/bin/bash
# This script completely removes Nginx, PHP, and MariaDB from the system.

set -euo pipefail
IFS=$'\n\t'

log_msg() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

remove_nginx() {
    log_msg "Stopping Nginx service..."
    systemctl stop nginx || true
    log_msg "Removing Nginx packages..."
    apt-get purge -y nginx nginx-common nginx-core
    log_msg "Removing Nginx directories..."
    rm -rf /etc/nginx /var/log/nginx /var/cache/nginx /usr/share/nginx
}

remove_php() {
    log_msg "Removing PHP packages..."
    apt-get purge -y php* 
    log_msg "Removing PHP directories..."
    rm -rf /etc/php /var/lib/php /var/log/php
}

remove_mariadb() {
    log_msg "Stopping MariaDB service..."
    systemctl stop mariadb || true
    log_msg "Removing MariaDB packages..."
    apt-get purge -y mariadb-server mariadb-client
    log_msg "Removing MariaDB data and configuration..."
    rm -rf /etc/mysql /var/lib/mysql /var/log/mysql /var/lib/mysql-files
}

main() {
    log_msg "Starting complete removal..."

    remove_nginx
    remove_php
    remove_mariadb

    log_msg "Cleaning up residual dependencies..."
    apt-get autoremove -y
    apt-get autoclean -y

    log_msg "All traces removed!"
}

main "$@"
