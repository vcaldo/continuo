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

# Determine if this is first run or post-reboot run
PHASE_FILE="/var/lib/cloud/instance/stackscript-phase"
PHASE=$(cat "$PHASE_FILE" 2>/dev/null || echo "initial")
echo "StackScript phase: $PHASE"

# Run installation steps only on initial phase
if [ "$PHASE" = "initial" ]; then

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
# Note: SSH restart is deferred to avoid dropping Terraform's connection
# It will restart on reboot, or we'll restart it at the very end

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

# Install lazydocker (optional, non-fatal)
echo "Installing lazydocker..."
if LAZYDOCKER_VERSION=$(curl -s https://api.github.com/repos/jesseduffield/lazydocker/releases/latest | jq -r '.tag_name' | sed 's/^v//'); then
    if [ -n "$LAZYDOCKER_VERSION" ]; then
        curl -fsSL "https://github.com/jesseduffield/lazydocker/releases/download/v${LAZYDOCKER_VERSION}/lazydocker_${LAZYDOCKER_VERSION}_Linux_x86_64.tar.gz" | tar xz -C /usr/local/bin lazydocker && \
        chmod +x /usr/local/bin/lazydocker && \
        echo "Lazydocker ${LAZYDOCKER_VERSION} installed successfully" || \
        echo "Lazydocker installation failed (non-fatal)"
    else
        echo "Could not determine lazydocker version (non-fatal)"
    fi
else
    echo "Lazydocker installation skipped (GitHub API error)"
fi

    # Set up post-reboot completion service
    echo "Creating post-reboot completion service..."
    cat > /etc/systemd/system/stackscript-completion.service << 'SYSTEMD_EOF'
[Unit]
Description=Complete StackScript setup after reboot
After=network.target docker.service cloud-init.service

[Service]
Type=oneshot
ExecStart=/var/lib/cloud/instance/scripts/part-001
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF

    systemctl daemon-reload
    systemctl enable stackscript-completion.service

    # Mark initial phase complete
    echo "pre-reboot" > "$PHASE_FILE"
    echo "Initial setup phase complete"
fi

# If we're in post-reboot phase, verify services
if [ "$PHASE" = "post-reboot" ]; then
    echo "Post-reboot verification..."
    systemctl is-active --quiet docker || systemctl start docker
    docker --version
fi

# Check for reboot BEFORE writing completion marker
if [ -f /var/run/reboot-required ] && [ "$PHASE" != "post-reboot" ]; then
    echo "Reboot required, rebooting now..."
    echo "post-reboot" > "$PHASE_FILE"
    # Allow script to exit cleanly before reboot
    nohup sh -c 'sleep 2 && systemctl reboot' > /dev/null 2>&1 &
    exit 0
fi

# Write completion marker only after reboot (or if no reboot needed)
echo "=== Docker Host Setup Complete ==="
echo "Docker version: $(docker --version)"
echo "Docker Compose version: $(docker compose version)"
echo "completed" > "$PHASE_FILE"

# Restart SSH to apply security configuration (done after completion marker)
# This allows Terraform to see completion before the connection is dropped
if [ "$PHASE" = "initial" ]; then
    echo "Restarting SSH service to apply security configuration..."
    sleep 2  # Give Terraform time to read the completion marker
    systemctl restart ssh || true
fi
