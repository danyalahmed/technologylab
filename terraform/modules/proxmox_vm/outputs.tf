output "vm_id" {
  description = "The Proxmox resource id for the VM (provider-specific)."
  value       = proxmox_vm_qemu.vm.id
}

output "vm_vmid" {
  description = "The numeric VMID assigned by Proxmox, if available (null if not exposed by provider)."
  value       = try(proxmox_vm_qemu.vm.vmid, null)
}

output "name" {
  description = "The name of the VM."
  value       = proxmox_vm_qemu.vm.name
}

output "ip" {
  description = "IP address assigned to the VM via QEMU Guest Agent, if available (null if not exposed by provider or agent not enabled)."
  value       = try(proxmox_vm_qemu.vm.default_ipv4_address, null)
}

output "node" {
  description = "Proxmox node the VM was created on (from module input)."
  value       = var.target_node
}
