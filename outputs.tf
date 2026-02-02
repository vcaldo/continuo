output "instance_ip" {
  description = "Public IP address of the Linode instance"
  value       = tolist(linode_instance.continuo.ipv4)[0]
}

output "ssh_connection_string" {
  description = "Ready-to-use SSH connection command"
  value       = "ssh ${var.admin_username}@${tolist(linode_instance.continuo.ipv4)[0]}"
}

output "admin_username" {
  description = "The configured admin username"
  value       = var.admin_username
}
