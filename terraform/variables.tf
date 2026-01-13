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

# ============================================================================
# ANSIBLE CONFIGURATION
# ============================================================================

variable "ansible_user" {
  description = "SSH username for Ansible to connect to nodes"
  type        = string
  default     = "danny"

  validation {
    condition     = length(var.ansible_user) > 0
    error_message = "ansible_user must not be empty"
  }
}

variable "ansible_ssh_key_path" {
  description = "Path to SSH private key for Ansible authentication"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "sudo_password" {
  description = "Sudo password for privilege escalation (consider using Ansible Vault instead)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "auto_run_ansible" {
  description = "Automatically execute Ansible playbooks after infrastructure provisioning"
  type        = bool
  default     = false
}

# ============================================================================
# KUBERNETES NETWORK CONFIGURATION
# ============================================================================

variable "kubelet_csr_ip_prefixes" {
  description = "IP prefixes for kubelet CSR (Certificate Signing Request) SANs"
  type        = string
  default     = ""
}

variable "desired_dns_servers" {
  description = "DNS servers for cluster nodes (e.g., ['8.8.8.8', '1.1.1.1'])"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for ip in var.desired_dns_servers : can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", ip))])
    error_message = "All DNS server addresses must be valid IPv4 addresses"
  }
}

# ============================================================================
# METALLB LOAD BALANCER CONFIGURATION
# ============================================================================

variable "metallb_version" {
  description = "MetalLB version to deploy (e.g., v0.14.8)"
  type        = string
  default     = "v0.14.8"

  validation {
    condition     = can(regex("^v\\d+\\.\\d+\\.\\d+$", var.metallb_version)) || var.metallb_version == ""
    error_message = "metallb_version must be in format 'vX.Y.Z' or empty string"
  }
}

variable "metallb_ip_range" {
  description = "IP address range for MetalLB to allocate LoadBalancer IPs (e.g., 192.168.1.50-192.168.1.60)"
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}-\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", var.metallb_ip_range)) || var.metallb_ip_range == ""
    error_message = "metallb_ip_range must be in format 'IP-IP' (e.g., 192.168.1.50-192.168.1.60) or empty string"
  }
}
