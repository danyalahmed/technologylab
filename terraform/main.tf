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

locals {
  controlplane_ips = [
    for ip in concat(
      [for _, m in module.kubernetes_controlplane_vms : m.ip],
      var.physical_controlplane_ips
    ) : ip if ip != null
  ]
}

# Generate Ansible inventory file from VM outputs
resource "local_file" "ansible_inventory" {
  depends_on = [module.kubernetes_controlplane_vms]

  content = templatefile("${path.module}/../ansible/templates/inventory.tftpl", {
    controlplane_ips = local.controlplane_ips
    worker_ips       = var.physical_worker_ips
  })

  filename = "${path.module}/../ansible/hosts.ini"
}

# Auto-generate Ansible variables from Terraform versions
resource "local_file" "ansible_vars" {
  content = yamlencode({
    kubernetes_version           = local.kubernetes_version
    kubernetes_version_short     = local.kubernetes_version_short
    calico_version               = local.calico_version
    pod_network_cidr             = local.pod_network_cidr
    ansible_user                 = var.ansible_user
    ansible_ssh_private_key_file = var.ansible_ssh_key_path
    argocd_version               = local.argocd_version
    kubelet_csr_ip_prefixes      = var.kubelet_csr_ip_prefixes
    desired_dns_servers          = join(" ", var.desired_dns_servers)
    kubelet_csr_regex            = "^(${join("|", concat(local.controlplane_ips, var.physical_worker_ips))})$"
    metallb_version              = var.metallb_version
    metallb_ip_range             = var.metallb_ip_range
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
      ANSIBLE_HOST_KEY_CHECKING=False ansible all -i ${path.module}/../ansible/hosts.ini -m ping --private-key=${var.ansible_ssh_key_path} -o
    EOT
  }
}

# Run Ansible playbook to install python dependencies
resource "null_resource" "ansible_install_python" {
  count = var.auto_run_ansible ? 1 : 0

  depends_on = [null_resource.wait_for_vms]

  triggers = {
    inventory_hash = local_file.ansible_inventory.content
  }

  provisioner "local-exec" {
    command = <<-EOT
        cd ${path.module}/../ansible
        echo "\n=== Installing Python dependencies on all nodes ==="
        ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini playbooks/00-install-python-deps.yml \
            --private-key=${var.ansible_ssh_key_path} \
            ${var.sudo_password != "" ? "-e ansible_become_password=${var.sudo_password}" : ""}
        EOT
  }

}

# Run Ansible playbook to prepare nodes
resource "null_resource" "ansible_prepare_nodes" {
  count = var.auto_run_ansible ? 1 : 0

  depends_on = [null_resource.ansible_install_python]

  triggers = {
    kubernetes_version = local.kubernetes_version
    calico_version     = local.calico_version
    inventory_hash     = local_file.ansible_inventory.content
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/../ansible
      echo "\n=== Preparing Kubernetes nodes ==="
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini playbooks/01-prepare-nodes.yml \
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
    calico_version     = local.calico_version
    prepare_nodes_id   = null_resource.ansible_prepare_nodes[0].id
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/../ansible
      echo "\n=== Initializing Kubernetes cluster ==="
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini playbooks/02-init-controlplane.yml \
        --private-key=${var.ansible_ssh_key_path} \
        ${var.sudo_password != "" ? "-e ansible_become_password=${var.sudo_password}" : ""}
    EOT
  }
}


# Run Ansible playbook to join worker nodes
resource "null_resource" "ansible_join_workers" {
  count = var.auto_run_ansible ? 1 : 0

  depends_on = [null_resource.ansible_init_cluster]

  triggers = {
    kubernetes_version = local.kubernetes_version
    init_cluster_id    = null_resource.ansible_init_cluster[0].id
  }

  provisioner "local-exec" {
    command = <<-EOT
        cd ${path.module}/../ansible
        echo "\n=== Joining worker nodes to Kubernetes cluster ==="
        ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini playbooks/03-join-workers.yml \
            --private-key=${var.ansible_ssh_key_path} \
            ${var.sudo_password != "" ? "-e ansible_become_password=${var.sudo_password}" : ""}
        EOT
  }
}

# Run Ansible playbook setup ArgoCD
resource "null_resource" "ansible_setup_argocd" {
  count = var.auto_run_ansible ? 1 : 0

  depends_on = [null_resource.ansible_init_cluster]

  triggers = {
    kubernetes_version = local.kubernetes_version
    init_cluster_id    = null_resource.ansible_init_cluster[0].id
    argocd_version     = local.argocd_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/../ansible
      echo "\n=== Setting up ArgoCD ==="
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini playbooks/04-bootstrap-argocd.yml \
        --private-key=${var.ansible_ssh_key_path} \
        ${var.sudo_password != "" ? "-e ansible_become_password=${var.sudo_password}" : ""}
    EOT
  }
}
