#!/bin/bash
exec > >(tee /var/log/stackscript-debug.log | logger -t stackscript -s 2>/dev/console) 2>&1
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# UDF variables from StackScript
# <UDF name="admin_username" label="Admin username" />
# <UDF name="ssh_keys" label="SSH public keys (newline separated)" />
# <UDF name="hostname" label="Hostname for the server" default="continuo" />
# <UDF name="new_relic_license_key" label="New Relic License Key" default="" />
# <UDF name="new_relic_account_id" label="New Relic Account ID" default="" />
# <UDF name="new_relic_region" label="New Relic Region" default="US" />
# <UDF name="restore_backup" label="Restore from backup" default="false" />

ADMIN_USER="$ADMIN_USERNAME"
SERVER_HOSTNAME="$HOSTNAME"
RESTORE_MODE="${RESTORE_BACKUP:-false}"

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

# Install New Relic Infrastructure Agent (conditional, no log forwarding)
if [ -n "${NEW_RELIC_LICENSE_KEY}" ]; then
  echo "Installing New Relic Infrastructure Agent..."
  curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && \
    NEW_RELIC_API_KEY="${NEW_RELIC_LICENSE_KEY}" \
    NEW_RELIC_ACCOUNT_ID="${NEW_RELIC_ACCOUNT_ID}" \
    NEW_RELIC_REGION="${NEW_RELIC_REGION}" \
    /usr/local/bin/newrelic install -y

  # Disable log forwarding (correct nested structure: log.forward)
  yq -y '.log.forward = false' /etc/newrelic-infra.yml > /tmp/newrelic.yml && \
    mv /tmp/newrelic.yml /etc/newrelic-infra.yml

  systemctl restart newrelic-infra
fi

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

# Install pnpm
su - "$ADMIN_USER" -c 'curl -fsSL https://get.pnpm.io/install.sh | sh -'

# Install Homebrew (as admin user, not root)
su - "$ADMIN_USER" -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'

# Add Homebrew to PATH in .bashrc
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/"$ADMIN_USER"/.bashrc

# Install LazyDocker (using full path to brew)
su - "$ADMIN_USER" -c '/home/linuxbrew/.linuxbrew/bin/brew install jesseduffield/lazydocker/lazydocker'

# # Add brew function for root to run as admin user
# cat >> /root/.bashrc <<EOF

# # Run brew as admin user (brew refuses to run as root)
# brew() {
#   su - $ADMIN_USER -c "/home/linuxbrew/.linuxbrew/bin/brew \$*"
# }
# EOF

# ============================================================================
# OPENCLAW INSTALLATION AND CONFIGURATION
# ============================================================================

echo "Installing OpenClaw..."

# Install OpenClaw CLI globally using pnpm (pnpm is in user's PATH via .bashrc)
su - "$ADMIN_USER" -c 'source ~/.bashrc && pnpm add -g openclaw@latest'

# Check for backup restore
RESTORE_DIR="/home/$ADMIN_USER/.restore"
if [ "$RESTORE_MODE" = "true" ] && [ -d "$RESTORE_DIR" ] && [ -f "$RESTORE_DIR/manifest.json" ]; then
    echo "Backup detected - restoring configuration before daemon setup..."

    # Run restore script (provided via file provisioner)
    if [ -f "/tmp/restore.sh" ]; then
        chmod +x /tmp/restore.sh
        ADMIN_USER="$ADMIN_USER" /tmp/restore.sh
    else
        echo "WARNING: restore.sh not found, manual restoration needed"
    fi

    # Install daemon without running onboard wizard (config already exists)
    echo "Installing OpenClaw gateway..."
    su - "$ADMIN_USER" -c 'source ~/.bashrc && openclaw gateway install' || true
    su - "$ADMIN_USER" -c 'source ~/.bashrc && openclaw gateway start' || true

    echo "OpenClaw restored from backup and daemon started"
else
    echo "Fresh install - run 'openclaw onboard' to complete setup"

    # For fresh install, just set up the workspace directory
    # User will run 'openclaw onboard' manually to configure channels
    su - "$ADMIN_USER" -c 'source ~/.bashrc && mkdir -p ~/.openclaw/workspace'

    echo "OpenClaw installed - run 'openclaw onboard' to complete setup"
fi

# Verify OpenClaw installation
echo "Verifying OpenClaw installation..."
su - "$ADMIN_USER" -c 'source ~/.bashrc && openclaw --version' || echo "WARNING: openclaw command not found"

# Reboot if required
if [ -f /var/run/reboot-required ]; then
    reboot
fi
