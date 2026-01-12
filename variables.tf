# Proxmox variable definitions
variable "proxmox_api_url" {
  description = "The URL of the Proxmox API endpoint."
  type        = string
  default     = ""
}

variable "proxmox_tls_insecure" {
  description = "Whether to skip TLS verification for Proxmox API."
  type        = bool
  default     = true
}

# Proxmox VM configuration: shared base + per-node overrides
variable "proxmox_vm_config" {
  description = "Proxmox vm configuration"
  type = map(object({
    cpu_cores = number
    memory_mb = number
    ipconfig0 = string
  }))
}

# kubernetes nodes on bare metal
variable "physical_controlplane_ip" {
  description = "List of physical control plane node IPs"
  type        = list(string)
  default     = []
}

variable "physical_workers_ip" {
  description = "List of physical worker node IPs"
  type        = list(string)
  default     = []
}

variable "sudo_password" {
  description = "Sudo password for the servers"
  type        = string
  default     = ""
}