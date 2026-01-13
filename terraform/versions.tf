terraform {
  required_version = ">= 1.14"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc07"
    }

    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }

    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
  }
}

