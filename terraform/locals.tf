# Local values for computed data and common expressions
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

  # Computed control plane IPs (VMs + physical servers)
  controlplane_ips = [
    for ip in concat(
      [for _, m in module.kubernetes_controlplane_vms : m.ip],
      var.physical_controlplane_ips
    ) : ip if ip != null
  ]

  # Common tags for resources
  common_tags = {
    managed_by  = "terraform"
    environment = "production"
    project     = "kubernetes-cluster"
  }
}
