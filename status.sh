#!/bin/bash

# Color codes
RED='\033[0;31m'
AMBER='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}System Status Report${NC}"
echo "------------------------"

# System Resources (CPU, RAM, Disk)
echo -e "\n${GREEN}System Resources:${NC}"

# CPU Usage
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | grep -Po '[0-9.]+ id' | grep -Po '[0-9.]+')
CPU_USAGE=$(echo "scale=2; 100 - $CPU_IDLE" | bc)

if (( $(echo "$CPU_USAGE < 70" | bc -l) )); then
    CPU_COLOR=$GREEN
elif (( $(echo "$CPU_USAGE < 90" | bc -l) )); then
    CPU_COLOR=$AMBER
else
    CPU_COLOR=$RED
fi

echo -e "CPU Usage: ${CPU_COLOR}${CPU_USAGE}%${NC}"

# Memory Usage
MEM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
MEM_USED=$(free -m | awk '/^Mem:/{print $3}')
MEM_USAGE=$(echo "scale=2; $MEM_USED/$MEM_TOTAL*100" | bc)

if (( $(echo "$MEM_USAGE < 70" | bc -l) )); then
    MEM_COLOR=$GREEN
elif (( $(echo "$MEM_USAGE < 90" | bc -l) )); then
    MEM_COLOR=$AMBER
else
    MEM_COLOR=$RED
fi

echo -e "Memory Usage: ${MEM_COLOR}${MEM_USAGE}%${NC}"

# Disk Usage
DISK_USAGE=$(df -h / | awk 'NR==2{print $5}' | sed 's/%//')

if (( $DISK_USAGE < 70 )); then
    DISK_COLOR=$GREEN
elif (( $DISK_USAGE < 90 )); then
    DISK_COLOR=$AMBER
else
    DISK_COLOR=$RED
fi

echo -e "Disk Usage (/): ${DISK_COLOR}${DISK_USAGE}%${NC}"

# Failed Login Attempts
echo -e "\n${GREEN}Failed Login Attempts:${NC}"

TODAY=$(date +"%b %_d")
FAILED_LOGINS=$(grep "$TODAY" /var/log/auth.log | grep "Failed password" | wc -l)

if (( $FAILED_LOGINS == 0 )); then
    LOGIN_COLOR=$GREEN
elif (( $FAILED_LOGINS < 5 )); then
    LOGIN_COLOR=$AMBER
else
    LOGIN_COLOR=$RED
fi

echo -e "Failed Login Attempts Today: ${LOGIN_COLOR}${FAILED_LOGINS}${NC}"

# Service Status
echo -e "\n${GREEN}Service Status:${NC}"

# Find PHP-FPM service
PHP_FPM_SERVICE=$(systemctl list-units --type=service | grep -E 'php.*-fpm.service' | awk '{print $1}' | head -n1)
if [ -z "$PHP_FPM_SERVICE" ]; then
    PHP_FPM_SERVICE="php-fpm"
fi

SERVICES=("nginx" "mysql" "$PHP_FPM_SERVICE")

for SERVICE in "${SERVICES[@]}"; do
    STATUS=$(systemctl is-active $SERVICE 2>/dev/null)
    if [ "$STATUS" == "active" ]; then
        SERVICE_COLOR=$GREEN
    else
        SERVICE_COLOR=$RED
    fi
    echo -e "  $SERVICE: ${SERVICE_COLOR}$STATUS${NC}"
done

# Network Connections
echo -e "\n${GREEN}Network Connections (listening ports):${NC}"

ss -tuln | awk 'NR>1{print $1,$5}' | while read PROTO ADDRESS; do
    echo "  $PROTO $ADDRESS"
done

# Web Server Logs
echo -e "\n${GREEN}Web Server Errors (last 5 entries):${NC}"
tail -n 5 /var/log/nginx/error.log

# Database Size
echo -e "\n${GREEN}Database Sizes:${NC}"
sudo mysql -e "SELECT table_schema AS 'Database', ROUND(SUM(data_length + index_length)/1024/1024,2) AS 'Size_MB' FROM information_schema.TABLES GROUP BY table_schema;" 2>/dev/null

# System Updates
echo -e "\n${GREEN}System Updates:${NC}"

UPDATES=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l)
if (( $UPDATES == 0 )); then
    UPDATES_COLOR=$GREEN
    echo -e "  Updates available: ${UPDATES_COLOR}No updates available${NC}"
else
    UPDATES_COLOR=$RED
    echo -e "  Updates available: ${UPDATES_COLOR}$UPDATES packages can be upgraded${NC}"
fi

# Disk Activity
echo -e "\n${GREEN}Disk Activity:${NC}"

IO_WAIT=$(top -bn1 | grep "Cpu(s)" | grep -Po '[0-9.]+ wa' | grep -Po '[0-9.]+')

if (( $(echo "$IO_WAIT < 5" | bc -l) )); then
    IO_COLOR=$GREEN
elif (( $(echo "$IO_WAIT < 10" | bc -l) )); then
    IO_COLOR=$AMBER
else
    IO_COLOR=$RED
fi

echo -e "Disk I/O Wait: ${IO_COLOR}${IO_WAIT}%${NC}"

# PHP Error Logs
echo -e "\n${GREEN}PHP Error Log (last 5 entries):${NC}"
PHP_LOG=$(find /var/log -name "php*-fpm.log" | head -n1)
if [ -z "$PHP_LOG" ]; then
    echo "PHP error log not found."
else
    tail -n 5 $PHP_LOG
fi

# Backup Status
echo -e "\n${GREEN}Backup Status:${NC}"

BACKUP_DIR="/var/backups"
LATEST_BACKUP=$(ls -t $BACKUP_DIR 2>/dev/null | head -n1)

if [ -z "$LATEST_BACKUP" ]; then
    BACKUP_COLOR=$RED
    echo -e "  ${BACKUP_COLOR}No backups found in $BACKUP_DIR${NC}"
else
    BACKUP_TIME=$(stat -c %Y "$BACKUP_DIR/$LATEST_BACKUP")
    CURRENT_TIME=$(date +%s)
    TIME_DIFF=$(( (CURRENT_TIME - BACKUP_TIME) / 86400 ))

    if (( $TIME_DIFF < 1 )); then
        BACKUP_COLOR=$GREEN
    elif (( $TIME_DIFF < 7 )); then
        BACKUP_COLOR=$AMBER
    else
        BACKUP_COLOR=$RED
    fi

    echo -e "  Latest backup $LATEST_BACKUP is ${BACKUP_COLOR}$TIME_DIFF days old${NC}"
fi
