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
  label       = "continuo-setup"
  description = "Setup script for continuo instance"
  images      = ["linode/ubuntu24.04"]
  script      = file("${path.module}/scripts/stackscript.sh")
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
    admin_username        = var.admin_username
    ssh_keys              = join("\n", var.ssh_public_keys)
    hostname              = "continuo"
    new_relic_license_key = var.new_relic_license_key
    new_relic_account_id  = var.new_relic_account_id
    new_relic_region      = var.new_relic_region
    restore_backup        = var.restore_from_backup ? "true" : "false"
  }

  # Wait for SSH to be available
  provisioner "remote-exec" {
    inline = ["echo 'SSH is ready'"]

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = file(var.ssh_private_key_path)
      host        = tolist(self.ipv4)[0]
      timeout     = "5m"
    }
  }

  # Upload restore script
  provisioner "file" {
    source      = "${path.module}/scripts/restore.sh"
    destination = "/tmp/restore.sh"

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = file(var.ssh_private_key_path)
      host        = tolist(self.ipv4)[0]
    }
  }
}

# Upload backup files when restore mode is enabled
resource "null_resource" "backup_upload" {
  count = var.restore_from_backup ? 1 : 0

  depends_on = [linode_instance.continuo]

  # Re-run when backup changes
  triggers = {
    instance_id = linode_instance.continuo.id
    backup_hash = var.restore_from_backup ? filemd5("${path.module}/backup/latest/manifest.json") : "none"
  }

  # Create restore directory
  provisioner "remote-exec" {
    inline = ["mkdir -p /home/${var.admin_username}/.restore"]

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = file(var.ssh_private_key_path)
      host        = tolist(linode_instance.continuo.ipv4)[0]
    }
  }

  # Upload backup directory contents
  provisioner "file" {
    source      = "${path.module}/backup/latest/"
    destination = "/home/${var.admin_username}/.restore"

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = file(var.ssh_private_key_path)
      host        = tolist(linode_instance.continuo.ipv4)[0]
    }
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
