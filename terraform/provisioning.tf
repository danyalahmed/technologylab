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
# PLAYBOOK 1: Install Python Dependencies
# ============================================================================

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

# ============================================================================
# PLAYBOOK 2: Prepare Kubernetes Nodes
# ============================================================================

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

# ============================================================================
# PLAYBOOK 3: Initialize Control Plane
# ============================================================================

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
      echo "\n=== Initializing Kubernetes control plane ==="
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini playbooks/02-init-controlplane.yml \
        --private-key=${var.ansible_ssh_key_path} \
        ${var.sudo_password != "" ? "-e ansible_become_password=${var.sudo_password}" : ""}
    EOT
  }
}

# ============================================================================
# PLAYBOOK 4: Join Worker Nodes
# ============================================================================

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

# ============================================================================
# PLAYBOOK 5: Bootstrap ArgoCD
# ============================================================================

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
      echo "\n=== Bootstrapping ArgoCD ==="
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini playbooks/04-bootstrap-argocd.yml \
        --private-key=${var.ansible_ssh_key_path} \
        ${var.sudo_password != "" ? "-e ansible_become_password=${var.sudo_password}" : ""}
    EOT
  }
}
