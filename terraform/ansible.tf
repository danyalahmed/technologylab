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
