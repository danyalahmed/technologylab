output "controlplanes" {
  description = "Map of control plane instances and their useful attributes. Keyed by instance name."
  value = {
    for name, m in module.kubernetes_controlplanes_vms : name => {
      vm_id   = m.vm_id
      vm_vmid = m.vm_vmid
      name    = m.name
      ip      = m.ip
      node    = m.node
    }
  }
}
