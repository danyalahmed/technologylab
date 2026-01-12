variable "name" {
  type        = string
  default     = "vm"
  description = "Base name for VM(s). If instance_count > 1, suffix '-<index>' will be appended."

  validation {
    condition     = length(trimspace(var.name)) > 0
    error_message = "name must not be empty"
  }
}

variable "target_node" {
  type        = string
  default     = "proxmox"
  description = "Proxmox target node to create the VM on."
}

variable "start_at_node_boot" {
  type    = bool
  default = true
}

variable "enable_agent" {
  type        = bool
  default     = true
  description = "Enable QEMU guest agent (set to true to enable)."
}

variable "memory" {
  type        = number
  default     = 4096
  description = "RAM (MB) for the VM."

  validation {
    condition     = var.memory > 0
    error_message = "memory must be greater than 0"
  }
}

variable "balloon" {
  type        = number
  default     = 0
  description = "Ballooning adjustment for VM memory (MB). Set to 0 to disable."
}

variable "cpu_sockets" {
  type        = number
  default     = 1
  description = "Number of CPU sockets for the VM."

  validation {
    condition     = var.cpu_sockets > 0
    error_message = "cpu_sockets must be greater than 0"
  }
}

variable "cpu_cores" {
  type        = number
  default     = 2
  description = "Number of CPU cores for the VM."

  validation {
    condition     = var.cpu_cores > 0
    error_message = "cpu_cores must be greater than 0"
  }
}

variable "vm_state" {
  type        = string
  default     = "started"
  description = "Whether to start the VM after creation."
}

variable "boot" {
  type        = string
  default     = "order=virtio0;ide2;net0"
  description = "Boot order for the VM. Adjust if no CD-ROM is attached."
}

variable "bios" {
  type        = string
  default     = "ovmf"
  description = "BIOS type for the VM (e.g., 'ovmf' for UEFI)."
}

variable "enable_efi" {
  type        = bool
  default     = false
  description = "Enable EFI disk for UEFI boot. When enabled, BIOS is set to 'ovmf'."
}

variable "efidisk" {
  description = "EFIDISK configuration object for UEFI boot."
  type = object({
    efitype = string
    storage = string
  })
  default = {
    efitype = "4m"
    storage = "local-lvm"
  }
}

variable "cloudinit_storage" {
  type        = string
  default     = "VM-Drives"
  description = "Storage pool for the Cloud-Init disk."
}

variable "scsihw" {
  description = "SCSI controller hardware type."
  type        = string
  default     = "virtio-scsi-pci"
}

variable "disk_size" {
  type        = string
  default     = "32G"
  description = "Size of the primary disk (e.g., '32G')."
}

variable "disk_storage" {
  type        = string
  default     = "local-lvm"
  description = "Storage pool for the primary disk."
}

variable "disk_discard" {
  type        = bool
  default     = true
  description = "Enable discard (TRIM) for the disk."
}

variable "disk_cache" {
  type        = string
  default     = "writethrough"
  description = "Cache mode for the disk."
}

variable "network_model" {
  type        = string
  default     = "virtio"
  description = "Network interface model (e.g., 'virtio', 'e1000')."
}

variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

variable "skip_ipv6" {
  type    = bool
  default = true
}

variable "startup_shutdown" {
  description = "Startup/shutdown configuration. Set values to -1 to omit a specific attribute (treated as null)."
  type = object({
    order            = number
    shutdown_timeout = number
    startup_delay    = number
  })
  default = {
    order            = -1
    shutdown_timeout = -1
    startup_delay    = -1
  }

  validation {
    condition     = var.startup_shutdown.order >= -1 && var.startup_shutdown.shutdown_timeout >= -1 && var.startup_shutdown.startup_delay >= -1
    error_message = "startup_shutdown values must be >= -1 (-1 means unset)"
  }
}


variable "clone_from_template" {
  type        = bool
  default     = false
  description = "Whether to clone the VM from a template."
}

variable "template_name" {
  type        = string
  default     = ""
  description = "Name of the template to clone from if clone_from_template is true."
  validation {
    condition     = !var.clone_from_template || (var.clone_from_template && length(trimspace(var.template_name)) > 0)
    error_message = "template_name must be provided when clone_from_template is true"
  }
}

variable "ipconfig0" {
  type        = string
  default     = ""
  description = "IP configuration for the primary network interface (net0)."
}