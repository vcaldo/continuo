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

variable "new_relic_license_key" {
  description = "New Relic license key for infrastructure monitoring"
  type        = string
  sensitive   = true
  default     = ""
}

variable "new_relic_account_id" {
  description = "New Relic account ID"
  type        = string
  default     = ""
}

variable "new_relic_region" {
  description = "New Relic region (US or EU)"
  type        = string
  default     = "US"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for provisioner connections"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "hostname" {
  description = "Hostname for the server instance"
  type        = string
  default     = "continuo"
}

variable "region" {
  description = "Linode region for the instance"
  type        = string
  default     = "us-ord"
}

variable "instance_type" {
  description = "Linode instance type (size)"
  type        = string
  default     = "g6-standard-2"
}
