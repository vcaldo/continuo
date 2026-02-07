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
    null = {
      source  = "hashicorp/null"
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
  label       = "${var.hostname}-setup"
  description = "Setup script for ${var.hostname} instance"
  images      = ["linode/ubuntu24.04"]
  script      = file("${path.module}/scripts/stackscript.sh")
}

resource "linode_instance" "continuo" {
  label           = var.hostname
  region          = var.region
  type            = var.instance_type
  image           = "linode/ubuntu24.04"
  root_pass       = random_password.root_password.result
  authorized_keys = var.ssh_public_keys
  stackscript_id  = linode_stackscript.continuo_setup.id

  stackscript_data = {
    admin_username        = var.admin_username
    ssh_keys              = join("\n", var.ssh_public_keys)
    hostname              = var.hostname
    new_relic_license_key = var.new_relic_license_key
    new_relic_account_id  = var.new_relic_account_id
    new_relic_region      = var.new_relic_region
  }

  # Wait for SSH and StackScript to complete
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for StackScript to complete...'",
      "while ! sudo grep -q 'OpenClaw installed' /var/log/stackscript-debug.log 2>/dev/null; do echo 'Still waiting...'; sleep 10; done",
      "echo 'StackScript completed!'"
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

resource "linode_firewall" "continuo" {
  label = "${var.hostname}-firewall"

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
