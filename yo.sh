#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting system cleanup...${NC}"

# Function to print status
print_status() {
    echo -e "${GREEN}[*]${NC} $1"
}

# Function to safely execute commands
safe_execute() {
    if ! eval "$1" > /dev/null 2>&1; then
        echo "Warning: Failed to execute: $1"
    fi
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# Start cleanup processes
print_status "Cleaning apt cache..."
safe_execute "apt-get clean"
safe_execute "apt-get autoremove -y"

print_status "Cleaning temporary files..."
# Clean /tmp files older than 10 days
safe_execute "find /tmp -type f -atime +10 -delete"
safe_execute "find /var/tmp -type f -atime +10 -delete"

print_status "Cleaning journal logs..."
safe_execute "journalctl --vacuum-time=3d"

print_status "Cleaning thumbnail cache..."
safe_execute "rm -rf /home/*/.cache/thumbnails/*"

print_status "Cleaning MariaDB temporary files..."
if systemctl is-active --quiet mariadb; then
    safe_execute "rm -f /tmp/#sql*"
fi

# Print disk usage before and after
print_status "Disk usage before cleanup:"
df -h /

print_status "Cleaning package cache..."
safe_execute "apt-get autoclean"

print_status "Final disk usage:"
df -h /

echo -e "${BLUE}Cleanup completed!${NC}"

# Print memory status
print_status "Memory status:"
free -h

# Print largest directories (optional)
print_status "Largest directories in /var:"
du -h /var/ --max-depth=1 2>/dev/null | sort -rh | head -n 5
