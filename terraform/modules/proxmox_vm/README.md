# Proxmox VM Module

Terraform module for creating and managing Proxmox virtual machines with cloud-init support.

## Features

- Clone from existing templates
- Cloud-init configuration
- UEFI boot support
- Flexible disk and network configuration
- VM lifecycle management

## Usage

```hcl
module "k8s_vm" {
  source = "./modules/proxmox_vm"

  name                = "kubernetes-node-01"
  cpu_cores           = 4
  memory              = 8192
  clone_from_template = true
  template_name       = "ubuntu-server-24.04"
  ipconfig0           = "ip=192.168.1.10/24,gw=192.168.1.1"
}
```

## Required Inputs

| Name | Description | Type |
|------|-------------|------|
| name | VM name | string |

## Optional Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| target_node | Proxmox node | string | "proxmox" |
| cpu_cores | CPU cores | number | 2 |
| memory | RAM in MB | number | 4096 |
| disk_size | Disk size | string | "32G" |
| template_name | Template to clone | string | "" |
| ipconfig0 | Network config | string | "" |

## Outputs

| Name | Description |
|------|-------------|
| vm_id | Proxmox VM ID |
| ip | VM IP address |
| name | VM name |
| node | Proxmox node |
