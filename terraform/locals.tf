# Local values for computed data and common expressions
locals {
  # OS/Template versions
  ubuntu_template_name = "ubuntu-server-25.10"

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
