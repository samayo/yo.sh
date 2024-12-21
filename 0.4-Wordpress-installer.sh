#!/bin/bash

# Set webroot directory (change if necessary)
WEBROOT="/var/www/html/"

# Update package list and install wget
sudo apt update && sudo apt install wget -y

# Download latest WordPress
wget https://wordpress.org/latest.tar.gz

# Extract WordPress to webroot
sudo tar -xvzf latest.tar.gz -C "$WEBROOT"

# Rename the wordpress directory (optional)
# sudo mv "$WEBROOT/wordpress" "$WEBROOT/your_site_name"

# Set correct ownership
sudo chown -R www-data:www-data "$WEBROOT/wordpress/"

# Set correct permissions
sudo find "$WEBROOT/wordpress/" -type d -exec chmod 750 {} \;
sudo find "$WEBROOT/wordpress/" -type f -exec chmod 640 {} \;

echo "WordPress downloaded and extracted to $WEBROOT/wordpress/"
echo "Remember to:"
echo "1. Create a MySQL database for WordPress."
echo "2. Configure wp-config.php (use wp-config-sample.php as a template)."
echo "3. Complete the installation by visiting your website in a browser."