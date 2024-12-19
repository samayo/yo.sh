#!/bin/bash
# This script assumes Debian-based system and requires user-defined variables
# Replace the following before running:
#   - YOUR_USERNAME
#   - YOUR_EMAIL@example.com
#   - SSH_PORT (e.g., 2222)
#
# Usage: Edit the script to set the above variables, then run as root.
# Make sure your VPS provider allows custom SSH ports if you change the default.

set -euo pipefail

YOUR_USERNAME="${YOUR_USERNAME:-default_user}" 
YOUR_EMAIL="${YOUR_EMAIL:-default@example.com}"
SSH_PORT="${SSH_PORT:-22}" 

# 1. Update and Upgrade System
apt update
apt full-upgrade -y
apt autoremove -y

# 2. Install Essential Packages
apt install -y ufw \
    fail2ban \
    unattended-upgrades \
    systemd-timesyncd \
    htop \
    curl \
    wget \
    git \
    nano \
    software-properties-common \
    logwatch \
    rkhunter

# 3. Create New User with Sudo Privileges
# Make sure this user does not exist. If it does, skip this step.
if ! id -u "$YOUR_USERNAME" >/dev/null 2>&1; then
    adduser "$YOUR_USERNAME"
    usermod -aG sudo "$YOUR_USERNAME"
fi

# 4. Configure SSH
# Backup original config
if [ ! -f /etc/ssh/sshd_config.bak ]; then
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
fi

cat > /etc/ssh/sshd_config << EOL
Port $SSH_PORT
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
UsePrivilegeSeparation yes
KeyRegenerationInterval 3600
ServerKeyBits 2048
SyslogFacility AUTH
LogLevel INFO
LoginGraceTime 60
PermitRootLogin no
StrictModes yes
PubkeyAuthentication yes
IgnoreRhosts yes
RhostsRSAAuthentication no
HostbasedAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
PasswordAuthentication yes
X11Forwarding no
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
UsePAM yes
AllowUsers $YOUR_USERNAME
EOL

systemctl restart sshd

# 5. Configure UFW Firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow "$SSH_PORT"/tcp  # SSH
ufw allow 80/tcp           # HTTP
ufw allow 443/tcp          # HTTPS
ufw --force enable

# 6. Configure fail2ban
# Avoid interactive edits; just overwrite jail.local
cat > /etc/fail2ban/jail.local << EOL
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = $YOUR_EMAIL
sendername = fail2ban
mta = sendmail

[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOL

systemctl restart fail2ban

# 7. Configure Automatic Updates (Unattended-Upgrades)
# Enable unattended-upgrades without prompting:
cat > /etc/apt/apt.conf.d/20auto-upgrades << EOL
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOL

# 8. System Optimization
echo 'vm.swappiness=10' | tee -a /etc/sysctl.conf
sysctl -p

# 9. Setup Time Synchronization
# Stop and disable NTP if installed
systemctl stop ntp || true
systemctl disable ntp || true

# Enable and start systemd-timesyncd
systemctl enable systemd-timesyncd
systemctl start systemd-timesyncd
timedatectl set-ntp true

# 10. Configure and Update RKHunter
rkhunter --update
rkhunter --propupd

# 11. Configure Logwatch
cat > /etc/cron.daily/00logwatch << EOL
#!/bin/bash
/usr/sbin/logwatch --output mail --mailto $YOUR_EMAIL --detail high
EOL
chmod +x /etc/cron.daily/00logwatch

# 12. Optional: Disable IPv6 if not required
# Note: Only do this if you don't need IPv6. Otherwise, comment out these lines.
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p

# 13. Verify Services (non-blocking status checks)
echo "Checking service statuses..."
systemctl status ufw || true
systemctl status fail2ban || true
systemctl status unattended-upgrades || true
systemctl status systemd-timesyncd || true

# 14. Final Security Checks
echo "Running final security checks..."
if ! grep -q "^AllowUsers $YOUR_USERNAME" /etc/ssh/sshd_config; then
    echo "WARNING: SSH AllowUsers configuration may not be correct!"
fi

if ! grep -q "^Port $SSH_PORT" /etc/ssh/sshd_config; then
    echo "WARNING: SSH port configuration may not be correct!"
fi

# 15. Final Instructions
echo "================================================================"
echo "Initial server setup complete. IMPORTANT NEXT STEPS:"
echo "1. BEFORE LOGGING OUT: Open a new terminal and verify you can log in as"
echo "   $YOUR_USERNAME via SSH on port $SSH_PORT"
echo "2. Command to connect: ssh -p $SSH_PORT $YOUR_USERNAME@your-server-ip"
echo "3. Test sudo access with: sudo whoami"
echo "4. Verify time synchronization: timedatectl status"
echo "5. Check firewall status: sudo ufw status"
echo "6. A system reboot is recommended after verifying SSH access"
echo "================================================================"root@srv670393:/# 
