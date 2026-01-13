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

# Centralized version management
# Update these locals to upgrade your infrastructure
locals {
  # Kubernetes versions
  kubernetes_version       = "v1.35.0"
  kubernetes_version_short = "1.35"

  # Network plugin versions
  calico_version = "v3.31.3"

  # OS/Template versions
  ubuntu_template_name = "ubuntu-server-25.10"

  # Pod network CIDR
  pod_network_cidr = "10.240.0.0/16"

  # ArgoCD version
  argocd_version = "v3.2.3"
}
