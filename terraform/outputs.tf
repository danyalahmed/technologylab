# ============================================================================
# INFRASTRUCTURE OUTPUTS
# ============================================================================

output "controlplane_vms" {
  description = "Proxmox control plane VM details"
  value = {
    for name, vm in module.kubernetes_controlplane_vms : name => {
      ip    = vm.ip
      vm_id = vm.vm_vmid
      node  = vm.node
      name  = vm.name
    }
  }
}

output "controlplane_ips" {
  description = "All control plane IP addresses (VMs + physical servers)"
  value       = local.controlplane_ips
}

output "worker_ips" {
  description = "All worker node IP addresses"
  value       = var.physical_worker_ips
}

# ============================================================================
# ANSIBLE CONFIGURATION
# ============================================================================

output "ansible_inventory_path" {
  description = "Path to generated Ansible inventory file"
  value       = local_file.ansible_inventory.filename
}
