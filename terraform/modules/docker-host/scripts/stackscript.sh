#!/bin/bash
# StackScript for Docker host setup
# <UDF name="admin_username" label="Admin Username" default="admin" />
# <UDF name="ssh_public_keys" label="SSH Public Keys (newline-separated)" />
# <UDF name="hostname" label="Hostname for the server" default="continuo" />
# <UDF name="new_relic_license_key" label="New Relic License Key" default="" />
# <UDF name="new_relic_account_id" label="New Relic Account ID" default="" />
# <UDF name="new_relic_region" label="New Relic Region" default="US" />

set -euo pipefail
exec > >(tee /var/log/stackscript.log) 2>&1
export DEBIAN_FRONTEND=noninteractive

echo "=== Docker Host Setup Started ==="
echo "Timestamp: $(date -Iseconds)"

# Configure hostname
hostnamectl set-hostname "$HOSTNAME"
echo "127.0.1.1 $HOSTNAME" >> /etc/hosts

# Update system
apt-get update && apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sh /tmp/get-docker.sh

# Install Docker Compose plugin
apt-get install -y docker-compose-plugin

# Create admin user
ADMIN_USER="${ADMIN_USERNAME:-admin}"
useradd -m -s /bin/bash -G docker,sudo "$ADMIN_USER" || true
echo "$ADMIN_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$ADMIN_USER"
chmod 440 "/etc/sudoers.d/$ADMIN_USER"

# Set up SSH keys
ADMIN_HOME="/home/$ADMIN_USER"
mkdir -p "$ADMIN_HOME/.ssh"
echo "$SSH_PUBLIC_KEYS" | tr ',' '\n' > "$ADMIN_HOME/.ssh/authorized_keys"
chmod 700 "$ADMIN_HOME/.ssh"
chmod 600 "$ADMIN_HOME/.ssh/authorized_keys"
chown -R "$ADMIN_USER:$ADMIN_USER" "$ADMIN_HOME/.ssh"

# Disable root login and password auth
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
echo "AllowUsers $ADMIN_USER" >> /etc/ssh/sshd_config
systemctl restart ssh || true

# Create directories for Docker deployment
mkdir -p /opt/continuo/{backups,env,data}
chown -R "$ADMIN_USER:$ADMIN_USER" /opt/continuo

# Enable Docker to start on boot
systemctl enable docker
systemctl start docker

# Configure Docker daemon for security
cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false
}
EOF
systemctl restart docker

# New Relic setup (optional)
if [[ -n "${NEW_RELIC_LICENSE_KEY:-}" && -n "${NEW_RELIC_ACCOUNT_ID:-}" ]]; then
    echo "Installing New Relic infrastructure agent..."
    curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | \
        bash && \
        NEW_RELIC_API_KEY="$NEW_RELIC_LICENSE_KEY" \
        NEW_RELIC_ACCOUNT_ID="$NEW_RELIC_ACCOUNT_ID" \
        NEW_RELIC_REGION="${NEW_RELIC_REGION:-US}" \
        /usr/local/bin/newrelic install -y --tag "role:docker-host" --tag "app:continuo" || \
        echo "New Relic installation failed (non-fatal)"
fi

# Set up automatic security updates
apt-get install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# Install useful tools
apt-get install -y ca-certificates curl fail2ban git htop iotop jq ncdu tmux zip

echo "=== Docker Host Setup Complete ==="
echo "Docker version: $(docker --version)"
echo "Docker Compose version: $(docker compose version)"

# Reboot if required
if [ -f /var/run/reboot-required ]; then
    echo "Reboot required, scheduling reboot..."
    systemctl reboot --no-block
fi
