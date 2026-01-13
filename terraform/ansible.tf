# ============================================================================
# ANSIBLE CONFIGURATION GENERATION
# ============================================================================

# Generate Ansible inventory file from VM outputs
resource "local_file" "ansible_inventory" {
  depends_on = [module.kubernetes_controlplane_vms]

  content = templatefile("${path.module}/../ansible/playbooks/templates/inventory.tftpl", {
    controlplane_ips = local.controlplane_ips
    worker_ips       = var.physical_worker_ips
  })

  filename = "${path.module}/../ansible/hosts.ini"
}

# Auto-generate Ansible variables from Terraform
resource "local_file" "ansible_vars" {
  content = yamlencode({
    # Kubernetes configuration
    kubernetes_version       = local.kubernetes_version
    kubernetes_version_short = local.kubernetes_version_short
    calico_version           = local.calico_version
    pod_network_cidr         = local.pod_network_cidr
    argocd_version           = local.argocd_version

    # Ansible configuration
    ansible_user                 = var.ansible_user
    ansible_ssh_private_key_file = var.ansible_ssh_key_path

    # Network configuration
    desired_dns_servers     = join(" ", var.desired_dns_servers)
    kubelet_csr_ip_prefixes = var.kubelet_csr_ip_prefixes
    kubelet_csr_regex       = "^(${join("|", concat(local.controlplane_ips, var.physical_worker_ips))})$"

    # LoadBalancer configuration
    metallb_version  = var.metallb_version
    metallb_ip_range = var.metallb_ip_range
  })

  filename = "${path.module}/../ansible/group_vars/all.yml"
}
