# ============================================================================
# PROXMOX PROVIDER CONFIGURATION
# ============================================================================

variable "proxmox_api_url" {
  description = "Proxmox API endpoint URL (e.g., https://proxmox.example.com:8006/api2/json)"
  type        = string

  validation {
    condition     = can(regex("^https?://", var.proxmox_api_url)) || var.proxmox_api_url == ""
    error_message = "proxmox_api_url must be a valid HTTP/HTTPS URL or empty string"
  }
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS certificate verification for Proxmox API (set false in production)"
  type        = bool
  default     = true
}

# ============================================================================
# VIRTUAL MACHINE CONFIGURATION
# ============================================================================

variable "proxmox_vm_config" {
  description = "Map of Proxmox VM configurations for control plane nodes. Key is the VM name."
  type = map(object({
    cpu_cores = number
    memory_mb = number
    ipconfig0 = string
  }))

  validation {
    condition     = alltrue([for k, v in var.proxmox_vm_config : v.cpu_cores >= 2])
    error_message = "All VMs must have at least 2 CPU cores for Kubernetes"
  }

  validation {
    condition     = alltrue([for k, v in var.proxmox_vm_config : v.memory_mb >= 2048])
    error_message = "All VMs must have at least 2048 MB RAM for Kubernetes"
  }
}

# ============================================================================
# PHYSICAL NODE CONFIGURATION
# ============================================================================

variable "physical_controlplane_ips" {
  description = "IP addresses of physical (bare metal) control plane nodes"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for ip in var.physical_controlplane_ips : can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", ip))])
    error_message = "All control plane IPs must be valid IPv4 addresses"
  }
}

variable "physical_worker_ips" {
  description = "IP addresses of physical (bare metal) worker nodes"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for ip in var.physical_worker_ips : can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", ip))])
    error_message = "All worker IPs must be valid IPv4 addresses"
  }
}

