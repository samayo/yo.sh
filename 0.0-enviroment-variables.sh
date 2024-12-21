#!/bin/bash

# env.sh - Script to set environment variables interactively

# List of variables to set
variables=("USERNAME" "EMAIL" "SSH_PORT")

# Initialize an associative array to store values
declare -A values

# Loop through each variable
for var in "${variables[@]}"; do
  # Prompt the user for the value of the variable
  read -r -p "Enter value for $var: " value

  # Sanitize inputs
  case "$var" in
    "USERNAME")
      if [[ ! "$value" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Error: USERNAME can only contain alphanumeric characters, underscores, and hyphens."
        exit 1
      fi
      ;;
    "EMAIL")
      if [[ ! "$value" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "Error: Invalid EMAIL format."
        exit 1
      fi
      ;;
    "SSH_PORT")
      if [[ ! "$value" =~ ^[0-9]+$ ]] || (( value < 0 || value > 65535 )); then
        echo "Error: SSH_PORT must be a number between 0 and 65535."
        exit 1
      fi
      ;;
  esac

  # Store the value in the associative array
  values[$var]="$value"
done

# Export the variables
for var in "${variables[@]}"; do
  export "$var=${values[$var]}"
done

# Print a confirmation message
echo "Environment variables set successfully:"
for var in "${variables[@]}"; do
  echo "$var=${values[$var]}"
done