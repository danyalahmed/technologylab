terraform {
  required_version = ">= 1.14"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc07"
    }

    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
  }
}

# Configure the Proxmox provider
provider "proxmox" {
  pm_api_url      = var.proxmox_api_url
  pm_tls_insecure = var.proxmox_tls_insecure
}