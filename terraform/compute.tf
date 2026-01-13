# ============================================================================
# PROXMOX VIRTUAL MACHINES
# ============================================================================

# Create Kubernetes control plane VMs on Proxmox
module "kubernetes_controlplane_vms" {
  source   = "./modules/proxmox_vm"
  for_each = var.proxmox_vm_config

  name                = each.key
  cpu_cores           = each.value.cpu_cores
  memory              = each.value.memory_mb
  balloon             = each.value.memory_mb
  clone_from_template = true
  template_name       = local.ubuntu_template_name
  ipconfig0           = each.value.ipconfig0
}
