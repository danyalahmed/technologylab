resource "proxmox_vm_qemu" "vm" {
  name        = var.name
  target_node = var.target_node
  clone       = var.clone_from_template ? var.template_name : null

  # basic vm settings
  agent              = var.enable_agent ? 1 : 0
  os_type            = "cloud-init"
  memory             = var.memory
  balloon            = var.balloon
  scsihw             = var.scsihw
  boot               = var.boot
  bios               = var.enable_efi ? var.bios : null
  vm_state           = var.vm_state
  start_at_node_boot = var.start_at_node_boot

  cpu {
    sockets = var.cpu_sockets
    cores   = var.cpu_cores
  }

  disks {
    ide {
      ide2 {
        cloudinit {
          storage = var.cloudinit_storage
        }
      }
    }

    virtio {
      virtio0 {
        disk {
          size    = var.disk_size
          storage = var.disk_storage
          discard = var.disk_discard
          cache   = var.disk_cache
        }
      }
    }
  }

  dynamic "efidisk" {
    for_each = var.enable_efi ? [1] : []
    content {
      efitype = var.efidisk.efitype
      storage = var.efidisk.storage
    }
  }

  network {
    id     = 0
    model  = var.network_model
    bridge = var.network_bridge
  }
  ipconfig0 = var.ipconfig0

  skip_ipv6 = var.skip_ipv6

  dynamic "startup_shutdown" {
    # Always forward the configured values to the provider. Use -1 to explicitly pass the sentinel value when desired.
    for_each = [var.startup_shutdown]
    content {
      order            = startup_shutdown.value.order
      shutdown_timeout = startup_shutdown.value.shutdown_timeout
      startup_delay    = startup_shutdown.value.startup_delay
    }
  }

  lifecycle {
    # Adjust lifecycle rules here if you want to protect VMs from accidental destroy
    prevent_destroy = false
  }
}
