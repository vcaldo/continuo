# terraform/modules/docker-host/outputs.tf
# Output values from Docker host module

output "instance_ip" {
  description = "Public IP address of the Docker host"
  value       = linode_instance.docker_host.ip_address
}

output "instance_id" {
  description = "Linode instance ID"
  value       = linode_instance.docker_host.id
}

output "hostname" {
  description = "Hostname of the instance"
  value       = var.hostname
}

output "ssh_connection_string" {
  description = "SSH connection command"
  value       = "ssh -i ${var.ssh_private_key_path} ${var.admin_username}@${linode_instance.docker_host.ip_address}"
}

output "admin_username" {
  description = "Admin username"
  value       = var.admin_username
}

output "docker_compose_path" {
  description = "Path to docker-compose files on the host"
  value       = "/opt/continuo/docker"
}

output "backups_path" {
  description = "Path to backups directory on the host"
  value       = "/opt/continuo/backups"
}

output "data_path" {
  description = "Path to persistent data directory on the host"
  value       = "/opt/continuo/data"
}
