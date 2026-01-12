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

# Generate Ansible inventory file from VM outputs
resource "local_file" "ansible_inventory" {
  depends_on = [module.kubernetes_controlplane_vms]

  content = templatefile("${path.module}/../ansible/templates/inventory.tftpl", {
    controlplane_ips = [
      for ip in concat(
        [for _, m in module.kubernetes_controlplane_vms : m.ip],
        var.physical_controlplane_ips
      ) : ip if ip != null
    ]
    worker_ips    = var.physical_worker_ips
    ansible_user  = var.ansible_user
  })

  filename = "${path.module}/../ansible/hosts.ini"
}

# Auto-generate Ansible variables from Terraform versions
resource "local_file" "ansible_vars" {
  content = yamlencode({
    kubernetes_version       = local.kubernetes_version
    kubernetes_minor_version = local.kubernetes_minor_version
    calico_version          = local.calico_version
    pod_network_cidr        = local.pod_network_cidr
    ansible_user            = var.ansible_user
    ansible_ssh_private_key_file = var.ansible_ssh_key_path
  })

  filename = "${path.module}/../ansible/group_vars/all.yml"
}

# Wait for VMs to be ready (SSH accessible)
resource "null_resource" "wait_for_vms" {
  count = var.auto_run_ansible ? 1 : 0

  depends_on = [
    module.kubernetes_controlplane_vms,
    local_file.ansible_inventory,
    local_file.ansible_vars
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for VMs to be ready..."
      sleep 30
      ansible all -i ${path.module}/../ansible/hosts.ini -m ping --private-key=${var.ansible_ssh_key_path} -o
    EOT
  }
}

# Run Ansible playbook to prepare nodes
resource "null_resource" "ansible_prepare_nodes" {
  count = var.auto_run_ansible ? 1 : 0

  depends_on = [null_resource.wait_for_vms]

  triggers = {
    kubernetes_version = local.kubernetes_version
    calico_version    = local.calico_version
    inventory_hash    = local_file.ansible_inventory.content
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/../ansible
      echo "\n=== Preparing Kubernetes nodes ==="
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini playbooks/prepare-nodes.yml \
        --private-key=${var.ansible_ssh_key_path} \
        ${var.sudo_password != "" ? "-e ansible_become_password=${var.sudo_password}" : ""}
    EOT
  }
}

# Run Ansible playbook to initialize Kubernetes cluster
resource "null_resource" "ansible_init_cluster" {
  count = var.auto_run_ansible ? 1 : 0

  depends_on = [null_resource.ansible_prepare_nodes]

  triggers = {
    kubernetes_version = local.kubernetes_version
    calico_version    = local.calico_version
    prepare_nodes_id  = null_resource.ansible_prepare_nodes[0].id
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/../ansible
      echo "\n=== Initializing Kubernetes cluster ==="
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini playbooks/kubeadm-init.yml \
        --private-key=${var.ansible_ssh_key_path} \
        ${var.sudo_password != "" ? "-e ansible_become_password=${var.sudo_password}" : ""}
    EOT
  }
}
