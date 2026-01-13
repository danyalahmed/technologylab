# ============================================================================
# ANSIBLE PLAYBOOK ORCHESTRATION
# ============================================================================

# Wait for VMs to be SSH accessible
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

# ============================================================================
# ANSIBLE PLAYBOOK EXECUTION
# ============================================================================

# Prerequisites playbook
resource "null_resource" "ansible_prerequisites" {
  count = var.auto_run_ansible ? 1 : 0

  depends_on = [null_resource.wait_for_vms]

  triggers = {
    inventory_hash = local_file.ansible_inventory.content
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/../ansible
      echo "\n=== Installing Python dependencies on all nodes ==="
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini playbooks/prerequisites.yml \
        --private-key=${var.ansible_ssh_key_path} \
        ${var.sudo_password != "" ? "-e ansible_become_password=${var.sudo_password}" : ""}
    EOT
  }
}

# Configure nodes playbook
resource "null_resource" "ansible_configure_nodes" {
  count = var.auto_run_ansible ? 1 : 0

  depends_on = [null_resource.ansible_prerequisites]

  triggers = {
    kubernetes_version = local.kubernetes_version
    calico_version     = local.calico_version
    inventory_hash     = local_file.ansible_inventory.content
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/../ansible
      echo "\n=== Preparing Kubernetes nodes ==="
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini playbooks/configure-nodes.yml \
        --private-key=${var.ansible_ssh_key_path} \
        ${var.sudo_password != "" ? "-e ansible_become_password=${var.sudo_password}" : ""}
    EOT
  }
}

# Initialize control plane playbook
resource "null_resource" "ansible_initialize_control_plane" {
  count = var.auto_run_ansible ? 1 : 0

  depends_on = [null_resource.ansible_configure_nodes]

  triggers = {
    kubernetes_version = local.kubernetes_version
    calico_version     = local.calico_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/../ansible
      echo "\n=== Initializing Kubernetes control plane ==="
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini playbooks/initialize-control-plane.yml \
        --private-key=${var.ansible_ssh_key_path} \
        ${var.sudo_password != "" ? "-e ansible_become_password=${var.sudo_password}" : ""}
    EOT
  }
}

# Join worker nodes playbook
resource "null_resource" "ansible_join_worker_nodes" {
  count = var.auto_run_ansible ? 1 : 0

  depends_on = [null_resource.ansible_initialize_control_plane]

  triggers = {
    kubernetes_version = local.kubernetes_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/../ansible
      echo "\n=== Joining worker nodes to Kubernetes cluster ==="
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini playbooks/join-worker-nodes.yml \
        --private-key=${var.ansible_ssh_key_path} \
        ${var.sudo_password != "" ? "-e ansible_become_password=${var.sudo_password}" : ""}
    EOT
  }
}

# Deploy MetalLB playbook
resource "null_resource" "ansible_deploy_metallb" {
  count = var.auto_run_ansible ? 1 : 0

  depends_on = [null_resource.ansible_join_worker_nodes]

  triggers = {
    kubernetes_version = local.kubernetes_version
    metallb_version    = var.metallb_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/../ansible
      echo "\n=== Bootstrapping MetalLB ==="
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini playbooks/deploy-metallb.yml \
        --private-key=${var.ansible_ssh_key_path} \
        ${var.sudo_password != "" ? "-e ansible_become_password=${var.sudo_password}" : ""}
    EOT
  }
}

# Deploy ArgoCD playbook
resource "null_resource" "ansible_deploy_argocd" {
  count = var.auto_run_ansible ? 1 : 0

  depends_on = [null_resource.ansible_deploy_metallb]

  triggers = {
    kubernetes_version = local.kubernetes_version
    argocd_version     = local.argocd_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/../ansible
      echo "\n=== Bootstrapping ArgoCD ==="
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini playbooks/deploy-argocd.yml \
        --private-key=${var.ansible_ssh_key_path} \
        ${var.sudo_password != "" ? "-e ansible_become_password=${var.sudo_password}" : ""}
    EOT
  }
}
