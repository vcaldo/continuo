terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "linode" {
  token = var.linode_token
}

resource "random_password" "root_password" {
  length  = 32
  special = true
}

resource "linode_stackscript" "continuo_setup" {
  label       = "continuo-setup"
  description = "Setup script for continuo instance"
  images      = ["linode/ubuntu24.04"]
  script      = <<-EOF
    #!/bin/bash
    set -euo pipefail

    # UDF variables from StackScript
    # <UDF name="admin_username" label="Admin username" />
    # <UDF name="ssh_keys" label="SSH public keys (newline separated)" />

    ADMIN_USER="$ADMIN_USERNAME"

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
    systemctl restart sshd

    # Install Docker (official method)
    apt-get update
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Add admin user to docker group
    usermod -aG docker "$ADMIN_USER"

    # Enable and start Docker
    systemctl enable docker
    systemctl start docker

    # Install Python 3 with pip and venv
    apt-get install -y python3 python3-pip python3-venv

    # Upgrade pip
    python3 -m pip install --upgrade pip

    # Reboot if required
    if [ -f /var/run/reboot-required ]; then
        reboot
    fi
  EOF
}

resource "linode_instance" "continuo" {
  label           = "continuo"
  region          = "us-ord"
  type            = "g6-standard-2"
  image           = "linode/ubuntu24.04"
  root_pass       = random_password.root_password.result
  authorized_keys = var.ssh_public_keys
  stackscript_id  = linode_stackscript.continuo_setup.id

  stackscript_data = {
    admin_username = var.admin_username
    ssh_keys       = join("\n", var.ssh_public_keys)
  }
}

resource "linode_firewall" "continuo" {
  label = "continuo-firewall"

  inbound {
    label    = "allow-ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  linodes = [linode_instance.continuo.id]
}
