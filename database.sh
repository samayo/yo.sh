#!/bin/bash

# Function to show all databases
show_databases() {
    echo "Enter MySQL username:"
    read -r username
    echo "Enter MySQL password:"
    read -rs password
    echo

    mysql -u "$username" -p"$password" -e "SHOW DATABASES;" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "Error: Unable to connect to MySQL. Please check your credentials."
        exit 1
    fi
}

# Function to export a database
export_database() {
    if [ -z "$1" ]; then
        echo "Error: Please provide a database name to export."
        exit 1
    fi

    echo "Enter MySQL username:"
    read -r username
    echo "Enter MySQL password:"
    read -rs password
    echo

    dbname=$1
    filename="${dbname}.$(date +%Y.%m.%d.%H.%M).sql"

    mysqldump -u "$username" -p"$password" "$dbname" > "$filename" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "Database '$dbname' exported successfully to $filename"
    else
        echo "Error: Unable to export database. Please check your credentials and database name."
        exit 1
    fi
}

# Main script logic
if [ "$1" = "export" ]; then
    export_database "$2"
else
    show_databases
fi
