#!/bin/bash

# ============================================================================
# SCRIPT INITIALIZATION
# ============================================================================

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

ADMIN_USER="$ADMIN_USERNAME"
SERVER_HOSTNAME="$HOSTNAME"

# ============================================================================
# SYSTEM CONFIGURATION
# ============================================================================

echo "Configuring hostname..."
hostnamectl set-hostname "$SERVER_HOSTNAME"
echo "127.0.1.1 $SERVER_HOSTNAME" >> /etc/hosts
echo "Hostname configured successfully"

echo "Creating admin user..."
useradd -m -s /bin/bash "$ADMIN_USER"
echo "Admin user created successfully"

echo "Configuring SSH..."
mkdir -p /home/"$ADMIN_USER"/.ssh
chmod 700 /home/"$ADMIN_USER"/.ssh
echo "$SSH_KEYS" > /home/"$ADMIN_USER"/.ssh/authorized_keys
chmod 600 /home/"$ADMIN_USER"/.ssh/authorized_keys
chown -R "$ADMIN_USER":"$ADMIN_USER" /home/"$ADMIN_USER"/.ssh
echo "$ADMIN_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$ADMIN_USER"
chmod 440 /etc/sudoers.d/"$ADMIN_USER"
echo "SSH configured successfully"

echo "Hardening SSH configuration..."
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
echo "AllowUsers $ADMIN_USER" >> /etc/ssh/sshd_config
systemctl restart ssh || true
echo "SSH hardening configured successfully"

# ============================================================================
# SYSTEM PACKAGES
# ============================================================================

echo "Updating system packages..."
apt -qqy update
apt -qqy full-upgrade
echo "System packages updated successfully"

echo "Installing essential packages..."
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
    unzip \
    vim \
    zip \
    yq
echo "Essential packages installed successfully"

echo "Configuring unattended-upgrades..."
dpkg-reconfigure -f noninteractive unattended-upgrades
echo "Unattended-upgrades configured successfully"

# ============================================================================
# MONITORING (OPTIONAL)
# ============================================================================

if [ -n "${NEW_RELIC_LICENSE_KEY}" ]; then
  echo "Installing New Relic Infrastructure Agent..."
  curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && \
    NEW_RELIC_API_KEY="${NEW_RELIC_LICENSE_KEY}" \
    NEW_RELIC_ACCOUNT_ID="${NEW_RELIC_ACCOUNT_ID}" \
    NEW_RELIC_REGION="${NEW_RELIC_REGION}" \
    /usr/local/bin/newrelic install -y \
      -n infrastructure-agent-installer \
      -n docker-open-source-integration

  systemctl restart newrelic-infra
  echo "New Relic Infrastructure Agent installed successfully"
fi

# ============================================================================
# DOCKER INSTALLATION
# ============================================================================

echo "Installing Docker..."
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sh /tmp/get-docker.sh
systemctl enable docker
systemctl start docker
usermod -aG docker "$ADMIN_USER"
echo "Docker installed successfully"

# ============================================================================
# DEVELOPMENT TOOLS
# ============================================================================

echo "Installing Python..."
apt-get install -y python3 python3-pip python3-venv
echo "Python installed successfully"

echo "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs
echo "Node.js installed successfully"

echo "Installing PNPM..."
su - "$ADMIN_USER" -c 'curl -fsSL https://get.pnpm.io/install.sh | sh -'

# Set PNPM_HOME for all users
PNPM_HOME="/home/$ADMIN_USER/.local/share/pnpm"
cat > /etc/profile.d/pnpm.sh <<EOF
export PNPM_HOME="$PNPM_HOME"
export PATH="\$PNPM_HOME:\$PATH"
EOF
chmod +x /etc/profile.d/pnpm.sh
echo "PNPM installed successfully"

# ============================================================================
# HOMEBREW & UTILITIES
# ============================================================================

echo "Installing Homebrew..."
su - "$ADMIN_USER" -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/"$ADMIN_USER"/.bashrc
echo "Homebrew installed successfully"

echo "Installing LazyDocker..."
su - "$ADMIN_USER" -c '/home/linuxbrew/.linuxbrew/bin/brew install jesseduffield/lazydocker/lazydocker'
echo "LazyDocker installed successfully"

# ============================================================================
# OPENCLAW INSTALLATION AND CONFIGURATION
# ============================================================================

echo "Installing OpenClaw..."

# Install OpenClaw CLI globally using pnpm
PNPM_HOME="/home/$ADMIN_USER/.local/share/pnpm"
PNPM_BIN="$PNPM_HOME/pnpm"

su - "$ADMIN_USER" -c "PNPM_HOME=$PNPM_HOME PATH=$PNPM_HOME:\$PATH $PNPM_BIN add -g openclaw@latest"

# Set up workspace directory and OpenClaw config
OPENCLAW_BIN="$PNPM_HOME/openclaw"
su - "$ADMIN_USER" -c "mkdir -p ~/.openclaw/workspace"

# Create OpenClaw config with local gateway mode and generated token
GATEWAY_TOKEN=$(openssl rand -hex 32)
jq -n --arg token "$GATEWAY_TOKEN" '{gateway: {mode: "local", auth: {token: $token}}}' > /home/$ADMIN_USER/.openclaw/openclaw.json
chown $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.openclaw/openclaw.json

# Verify OpenClaw installation
echo "Verifying OpenClaw installation..."
if ! su - "$ADMIN_USER" -c "$OPENCLAW_BIN --version"; then
  echo "ERROR: openclaw command not found or failed to execute"
  exit 1
fi

# Install and start the gateway daemon
echo "Setting up OpenClaw gateway service..."
if ! su - "$ADMIN_USER" -c "$OPENCLAW_BIN gateway install"; then
  echo "ERROR: Failed to install OpenClaw gateway"
  exit 1
fi

# Start the gateway daemon
if ! su - "$ADMIN_USER" -c "$OPENCLAW_BIN gateway start"; then
  echo "ERROR: Failed to start OpenClaw gateway"
  exit 1
fi

# Wait for gateway to start and verify
echo "Waiting for gateway to start..."
sleep 10

if ! su - "$ADMIN_USER" -c "$OPENCLAW_BIN gateway status" >/dev/null 2>&1; then
  echo "ERROR: Gateway failed to start"
  exit 1
fi

echo "OpenClaw installed successfully"

# ============================================================================
# FINALIZATION
# ============================================================================

# Reboot if required (use nohup to allow script to exit cleanly)
if [ -f /var/run/reboot-required ]; then
    echo "Reboot required, scheduling reboot..."
    nohup sh -c 'sleep 30 && reboot' &>/dev/null &
fi
