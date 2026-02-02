#!/bin/bash
exec > >(tee /var/log/stackscript-debug.log | logger -t stackscript -s 2>/dev/console) 2>&1
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# UDF variables from StackScript
# <UDF name="admin_username" label="Admin username" />
# <UDF name="ssh_keys" label="SSH public keys (newline separated)" />
# <UDF name="hostname" label="Hostname for the server" default="continuo" />

ADMIN_USER="$ADMIN_USERNAME"
SERVER_HOSTNAME="$HOSTNAME"

# Set hostname
hostnamectl set-hostname "$SERVER_HOSTNAME"

# Update /etc/hosts
echo "127.0.1.1 $SERVER_HOSTNAME" >> /etc/hosts

# Create admin user
useradd -m -s /bin/bash "$ADMIN_USER"

# Setup SSH directory and authorized_keys
mkdir -p /home/"$ADMIN_USER"/.ssh
chmod 700 /home/"$ADMIN_USER"/.ssh

# Add SSH keys (newline separated)
echo "$SSH_KEYS" > /home/"$ADMIN_USER"/.ssh/authorized_keys
chmod 600 /home/"$ADMIN_USER"/.ssh/authorized_keys
chown -R "$ADMIN_USER":"$ADMIN_USER" /home/"$ADMIN_USER"/.ssh

# Configure passwordless sudo
echo "$ADMIN_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$ADMIN_USER"
chmod 440 /etc/sudoers.d/"$ADMIN_USER"

# Harden SSH configuration
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
echo "AllowUsers $ADMIN_USER" >> /etc/ssh/sshd_config
systemctl restart ssh || true

# System update and essential packages installation
echo "Updating system packages..."
apt -qqy update
apt -qqy full-upgrade
apt -qqy install \
    apt-transport-https \
    build-essential \
    ca-certificates \
    curl \
    dnsutils \
    fail2ban \
    file \
    git \
    gnupg \
    jq \
    lsb-release \
    procps \
    software-properties-common \
    unattended-upgrades \
    ufw \
    vim \
    yq
dpkg-reconfigure -f noninteractive unattended-upgrades

# Docker installation
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sh /tmp/get-docker.sh
systemctl enable docker
systemctl start docker
usermod -aG docker "$ADMIN_USER" || true

# Install Python 3 with pip and venv
apt-get install -y python3 python3-pip python3-venv

# Install Node.js and npm via NodeSource
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs

# Install Homebrew (as admin user, not root)
su - "$ADMIN_USER" -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'

# Add Homebrew to PATH in .bashrc
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/"$ADMIN_USER"/.bashrc

# Install LazyDocker (using full path to brew)
su - "$ADMIN_USER" -c '/home/linuxbrew/.linuxbrew/bin/brew install jesseduffield/lazydocker/lazydocker'

# Reboot if required
if [ -f /var/run/reboot-required ]; then
    reboot
fi
