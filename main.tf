# create control plane VMs
module "kubernetes_controlplanes_vms" {
  source   = "./modules/proxmox_vm"
  for_each = var.proxmox_vm_config

  name                = each.key
  cpu_cores           = each.value.cpu_cores
  memory              = each.value.memory_mb
  balloon             = each.value.memory_mb
  clone_from_template = true
  template_name       = "ubuntu-server-25.10"
  ipconfig0           = each.value.ipconfig0
}


resource "local_file" "ansible_inventory" {
  depends_on = [module.kubernetes_controlplanes_vms]

  content = templatefile("${path.module}/inventory.tftpl", {
    controlplane_ips = [for ip in concat([for _, m in module.kubernetes_controlplanes_vms : m.ip], var.physical_controlplane_ip) : ip if ip != null]
    worker_ips       = var.physical_workers_ip
    sudo_password    = var.sudo_password
  })

  filename = "${path.module}/hosts.ini"
}
