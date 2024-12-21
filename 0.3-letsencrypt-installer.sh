#!/bin/bash

# Update package list
echo "Updating package list..."
sudo apt update

# Install snapd
echo "Installing snapd..."
sudo apt install snapd -y

# Install and refresh core snap
echo "Installing and refreshing core snap..."
sudo snap install core
sudo snap refresh core

# Install certbot
echo "Installing certbot..."
sudo snap install --classic certbot

# Create symbolic link for certbot command
echo "Creating symbolic link for certbot..."
sudo ln -s /snap/bin/certbot /usr/bin/certbot

echo "Certbot installation complete!"