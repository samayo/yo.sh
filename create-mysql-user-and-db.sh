#!/usr/bin/env bash

# Ask for database name
read -p "Enter database name: " dbname

# Ask for username
read -p "Enter username: " username

# Ask for password (hidden input)
read -s -p "Enter password: " userpass
echo # Add a newline after password input

mysql -u root -p <<EOF
CREATE DATABASE IF NOT EXISTS \`${dbname}\`;
CREATE USER IF NOT EXISTS \`${username}\`@'localhost' IDENTIFIED BY '${userpass}';
GRANT ALL PRIVILEGES ON \`${dbname}\`.* TO \`${username}\`@'localhost';
FLUSH PRIVILEGES;
EOF