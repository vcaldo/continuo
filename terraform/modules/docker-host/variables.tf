# terraform/modules/docker-host/variables.tf
# Input variables for Docker host module

variable "linode_token" {
  description = "Linode API token"
  type        = string
  sensitive   = true
}

variable "hostname" {
  description = "Hostname/label for the Linode instance"
  type        = string
  default     = "continuo-docker"
}

variable "region" {
  description = "Linode region"
  type        = string
  default     = "us-ord"
}

variable "instance_type" {
  description = "Linode instance type (recommend g6-standard-4 for 4+ bots)"
  type        = string
  default     = "g6-standard-4"  # 4 vCPU, 8GB RAM
}

variable "admin_username" {
  description = "Admin username for SSH access"
  type        = string
  default     = "admin"
}

variable "ssh_public_keys" {
  description = "List of SSH public keys for access"
  type        = list(string)
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for provisioning"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "new_relic_license_key" {
  description = "New Relic license key (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "new_relic_account_id" {
  description = "New Relic account ID (optional)"
  type        = string
  default     = ""
}

variable "new_relic_region" {
  description = "New Relic region (US or EU)"
  type        = string
  default     = "US"
}

variable "tags" {
  description = "Additional tags for the instance"
  type        = list(string)
  default     = []
}

variable "exposed_ports" {
  description = "Additional ports to expose in firewall (besides SSH)"
  type        = list(number)
  default     = []
}

variable "bots" {
  description = "Map of bot configurations for Docker deployment"
  type = map(object({
    backup_path = optional(string, "")
    env_file    = optional(string, "")
    cpu_limit   = optional(string, "1.0")
    memory_limit = optional(string, "1536M")
  }))
  default = {}
}
