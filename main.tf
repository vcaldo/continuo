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
    admin_username = var.admin_username
    ssh_keys       = join("\n", var.ssh_public_keys)
    hostname       = "continuo"
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
