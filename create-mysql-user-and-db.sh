#!/usr/bin/env bash

# Ask for database name
read -p "Enter database name: " dbname

# Ask for username
while true; do
	read -p "Enter username (alphanumeric and underscore only): " username
	if [[ $username =~ ^[a-zA-Z0-9_]+$ ]]; then
		break
	else
		echo "Invalid username. Use only letters, numbers, and underscores."
	fi
done

# Ask for password (hidden input)
read -s -p "Enter password: " userpass
echo # Add a newline after password input

mysql -u root -p <<EOF
CREATE DATABASE IF NOT EXISTS \`${dbname}\`;
CREATE USER IF NOT EXISTS \`${username}\`@'localhost' IDENTIFIED BY '${userpass}';
GRANT ALL PRIVILEGES ON \`${dbname}\`.* TO \`${username}\`@'localhost';
FLUSH PRIVILEGES;
EOF

# show users
# mysql -u root -p -e "SELECT User, Host FROM mysql.user;"
# drop user 
# mysql -u root -p -e "DROP USER 'username'@'localhost';"