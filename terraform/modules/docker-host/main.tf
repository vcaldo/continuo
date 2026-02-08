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

provider "linode" {
  token = var.linode_token
}

# =============================================================================
# STACKSCRIPT
# =============================================================================

resource "linode_stackscript" "docker_host" {
  label       = "docker-host-${var.hostname}"
  description = "Docker host setup for multi-bot OpenClaw deployment"
  images      = ["linode/ubuntu24.04"]
  is_public   = false

  script = file("${path.module}/scripts/stackscript.sh")
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
      "echo 'Waiting for StackScript to complete...'",
      "while ! sudo grep -q 'Docker Host Setup Complete' /var/log/stackscript.log 2>/dev/null; do echo 'Still waiting...'; sleep 10; done",
      "echo 'Setup complete!'"
    ]

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = file(var.ssh_private_key_path)
      host        = tolist(self.ipv4)[0]
      timeout     = "30m"
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
      host        = tolist(linode_instance.docker_host.ipv4)[0]
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
      host        = tolist(linode_instance.docker_host.ipv4)[0]
    }
  }
}
