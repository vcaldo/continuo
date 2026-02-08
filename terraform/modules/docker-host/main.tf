# terraform/modules/docker-host/main.tf
# Linode instance configured for Docker multi-bot deployment

terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 2.0"
    }
  }
}

# =============================================================================
# STACKSCRIPT
# =============================================================================

resource "linode_stackscript" "docker_host" {
  label       = "docker-host-${var.hostname}"
  description = "Docker host setup for multi-bot OpenClaw deployment"
  images      = ["linode/ubuntu24.04"]
  is_public   = false

  script = <<-SCRIPT
#!/bin/bash
# StackScript for Docker host setup
# <UDF name="admin_username" label="Admin Username" default="admin" />
# <UDF name="ssh_public_keys" label="SSH Public Keys (newline-separated)" />
# <UDF name="new_relic_license_key" label="New Relic License Key" default="" />
# <UDF name="new_relic_account_id" label="New Relic Account ID" default="" />
# <UDF name="new_relic_region" label="New Relic Region" default="US" />

set -euo pipefail
exec > >(tee /var/log/stackscript.log) 2>&1

echo "=== Docker Host Setup Started ==="
echo "Timestamp: $(date -Iseconds)"

# Update system
apt-get update && apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | bash

# Install Docker Compose plugin
apt-get install -y docker-compose-plugin

# Create admin user
ADMIN_USER="$${ADMIN_USERNAME:-admin}"
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
sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

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
if [[ -n "$${NEW_RELIC_LICENSE_KEY:-}" && -n "$${NEW_RELIC_ACCOUNT_ID:-}" ]]; then
    echo "Installing New Relic infrastructure agent..."
    curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | \
        bash && \
        NEW_RELIC_API_KEY="$NEW_RELIC_LICENSE_KEY" \
        NEW_RELIC_ACCOUNT_ID="$NEW_RELIC_ACCOUNT_ID" \
        NEW_RELIC_REGION="$${NEW_RELIC_REGION:-US}" \
        /usr/local/bin/newrelic install -y --tag "role:docker-host" --tag "app:continuo" || \
        echo "New Relic installation failed (non-fatal)"
fi

# Set up automatic security updates
apt-get install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# Install useful tools
apt-get install -y htop iotop ncdu tmux jq

echo "=== Docker Host Setup Complete ==="
echo "Docker version: $(docker --version)"
echo "Docker Compose version: $(docker compose version)"
SCRIPT
}

# =============================================================================
# LINODE INSTANCE
# =============================================================================

resource "linode_instance" "docker_host" {
  label           = var.hostname
  region          = var.region
  type            = var.instance_type
  image           = "linode/ubuntu24.04"
  authorized_keys = var.ssh_public_keys
  stackscript_id  = linode_stackscript.docker_host.id
  
  stackscript_data = {
    admin_username       = var.admin_username
    ssh_public_keys      = join(",", var.ssh_public_keys)
    new_relic_license_key = var.new_relic_license_key
    new_relic_account_id  = var.new_relic_account_id
    new_relic_region      = var.new_relic_region
  }

  tags = concat(["continuo", "docker-host"], var.tags)

  # Wait for StackScript to complete
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init and StackScript to complete...'",
      "cloud-init status --wait || true",
      "while [ ! -f /var/log/stackscript.log ] || ! grep -q 'Docker Host Setup Complete' /var/log/stackscript.log; do sleep 5; done",
      "echo 'Setup complete!'"
    ]

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = file(var.ssh_private_key_path)
      host        = self.ip_address
      timeout     = "10m"
    }
  }
}

# =============================================================================
# FIREWALL
# =============================================================================

resource "linode_firewall" "docker_host" {
  label = "${var.hostname}-firewall"

  # Inbound: SSH only
  inbound {
    label    = "allow-ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  # Additional inbound ports (if any exposed services)
  dynamic "inbound" {
    for_each = var.exposed_ports
    content {
      label    = "allow-port-${inbound.value}"
      action   = "ACCEPT"
      protocol = "TCP"
      ports    = tostring(inbound.value)
      ipv4     = ["0.0.0.0/0"]
      ipv6     = ["::/0"]
    }
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  linodes = [linode_instance.docker_host.id]
}

# =============================================================================
# FILE PROVISIONER - Deploy Docker files
# =============================================================================

resource "null_resource" "deploy_docker_files" {
  depends_on = [linode_instance.docker_host]

  triggers = {
    instance_id = linode_instance.docker_host.id
    # Re-deploy if compose template changes
    compose_hash = filemd5("${path.module}/../../../docker/docker-compose.yml.template")
  }

  # Copy Docker files to host
  provisioner "file" {
    source      = "${path.module}/../../../docker/"
    destination = "/opt/continuo/docker"

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = file(var.ssh_private_key_path)
      host        = linode_instance.docker_host.ip_address
    }
  }

  # Build the base image
  provisioner "remote-exec" {
    inline = [
      "cd /opt/continuo/docker",
      "docker build -t openclaw-base:latest -f Dockerfile .",
      "echo 'Docker base image built successfully'"
    ]

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = file(var.ssh_private_key_path)
      host        = linode_instance.docker_host.ip_address
    }
  }
}
