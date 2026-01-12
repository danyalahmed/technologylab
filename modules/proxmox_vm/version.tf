terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = ">= 3.0.0, < 4.0.0"
    }
  }
}