#!/bin/bash
# Undo script for LAMP stack installation

set -euo pipefail
IFS=$'\n\t'

log_msg() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

remove_packages() {
    if dpkg -l | grep -q "^ii  $2"; then
        log_msg "Removing $1..."
        apt-get purge -y $2
    else
        log_msg "$1 is not installed, skipping removal."
    fi
}

remove_nginx() {
    remove_packages "Nginx" "nginx"
    log_msg "Removing Nginx configuration files..."
    rm -rf /etc/nginx
}

remove_mariadb() {
    remove_packages "MariaDB" "mariadb-server"
    remove_packages "MariaDB client" "mariadb-client"
    
    log_msg "Removing MariaDB data directory..."
    rm -rf /var/lib/mysql
    log_msg "Removing MariaDB configuration files..."
    rm -rf /etc/mysql
}

remove_php() {
    remove_packages "PHP" "php*"
}

main() {
    log_msg "Starting undo process..."

    # Remove Nginx
    remove_nginx

    # Remove MariaDB
    remove_mariadb

    # Remove PHP
    remove_php

    log_msg "Cleaning up any remaining dependencies..."
    apt-get autoremove -y

    log_msg "Undo process complete!"
}

main "$@"
