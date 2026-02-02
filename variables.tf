variable "linode_token" {
  description = "Linode API token"
  type        = string
  sensitive   = true
}

variable "ssh_public_keys" {
  description = "List of SSH public keys for admin access"
  type        = list(string)
}

variable "admin_username" {
  description = "Username for the admin account"
  type        = string
  default     = "admin"
}
