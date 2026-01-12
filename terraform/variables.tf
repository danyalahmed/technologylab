# Proxmox Configuration Variables
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

# Proxmox VM Configuration
variable "proxmox_vm_config" {
  description = "Map of Proxmox VM configurations. Key is the VM name."
  type = map(object({
    cpu_cores = number
    memory_mb = number
    ipconfig0 = string
  }))
}

# Physical Kubernetes Nodes Configuration
variable "physical_controlplane_ips" {
  description = "List of physical control plane node IPs (bare metal servers)"
  type        = list(string)
  default     = []
}

variable "physical_worker_ips" {
  description = "List of physical worker node IPs (bare metal servers)"
  type        = list(string)
  default     = []
}

# Ansible Configuration
variable "ansible_user" {
  description = "SSH user for Ansible connections"
  type        = string
  default     = "danny"
}

variable "sudo_password" {
  description = "Sudo password for the servers (consider using Ansible vault instead)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "auto_run_ansible" {
  description = "Automatically run Ansible playbooks after infrastructure is created"
  type        = bool
  default     = true
}

variable "ansible_ssh_key_path" {
  description = "Path to SSH private key for Ansible connections"
  type        = string
  default     = "~/.ssh/id_rsa"
}
