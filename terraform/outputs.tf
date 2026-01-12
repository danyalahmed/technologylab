# ============================================================================
# INFRASTRUCTURE OUTPUTS
# ============================================================================

output "controlplane_vms" {
  description = "Control plane VM details"
  value = {
    for name, vm in module.kubernetes_controlplane_vms : name => {
      ip    = vm.ip
      vm_id = vm.vm_vmid
      node  = vm.node
      name  = vm.name
    }
  }
}

output "all_controlplane_ips" {
  description = "All control plane IPs (Proxmox VMs + physical servers)"
  value = [
    for ip in concat(
      [for _, m in module.kubernetes_controlplane_vms : m.ip],
      var.physical_controlplane_ips
    ) : ip if ip != null
  ]
}

output "worker_ips" {
  description = "All worker node IPs"
  value       = var.physical_worker_ips
}

# ============================================================================
# VERSION INFORMATION
# ============================================================================

output "versions" {
  description = "Deployed component versions"
  value = {
    kubernetes      = local.kubernetes_version
    calico          = local.calico_version
    ubuntu_template = local.ubuntu_template_name
    pod_cidr        = local.pod_network_cidr
  }
}

# ============================================================================
# ANSIBLE CONFIGURATION
# ============================================================================

output "ansible_inventory_path" {
  description = "Path to generated Ansible inventory file"
  value       = local_file.ansible_inventory.filename
}

output "ansible_vars_path" {
  description = "Path to generated Ansible variables file"
  value       = local_file.ansible_vars.filename
}

output "ansible_automation" {
  description = "Ansible automation status"
  value = {
    auto_run_enabled = var.auto_run_ansible
    prepare_nodes    = var.auto_run_ansible ? "Completed automatically" : "Run manually: cd ../ansible && ansible-playbook -i hosts.ini playbooks/prepare-nodes.yml"
    init_cluster     = var.auto_run_ansible ? "Completed automatically" : "Run manually: cd ../ansible && ansible-playbook -i hosts.ini playbooks/kubeadm-init.yml"
  }
}

# ============================================================================
# NEXT STEPS
# ============================================================================

locals {
  next_steps_auto = <<-EOT
    ✅ Infrastructure and Kubernetes cluster deployed successfully!

    Next steps:
    1. Verify cluster: kubectl get nodes
    2. Check pods: kubectl get pods --all-namespaces
    3. Access cluster: Use kubeconfig from control plane at ~/.kube/config

    Control Plane IPs: ${join(", ", [for ip in concat([for _, m in module.kubernetes_controlplane_vms : m.ip], var.physical_controlplane_ips) : ip if ip != null])}
    Worker IPs: ${join(", ", var.physical_worker_ips)}

    Versions deployed:
    - Kubernetes: ${local.kubernetes_version}
    - Calico CNI: ${local.calico_version}

    To upgrade versions, edit terraform/versions.tf and run 'terraform apply'
  EOT

  next_steps_manual = <<-EOT
    ✅ Infrastructure deployed successfully!

    Next steps (Ansible automation is disabled):
    1. Prepare nodes: cd ../ansible && ansible-playbook -i hosts.ini playbooks/prepare-nodes.yml --ask-become-pass
    2. Initialize cluster: cd ../ansible && ansible-playbook -i hosts.ini playbooks/kubeadm-init.yml --ask-become-pass
    3. Verify cluster: kubectl get nodes

    Control Plane IPs: ${join(", ", [for ip in concat([for _, m in module.kubernetes_controlplane_vms : m.ip], var.physical_controlplane_ips) : ip if ip != null])}
    Worker IPs: ${join(", ", var.physical_worker_ips)}

    To enable automatic Ansible execution, set 'auto_run_ansible = true' in terraform.auto.tfvars
  EOT
}

output "next_steps" {
  description = "What to do next"
  value       = var.auto_run_ansible ? local.next_steps_auto : local.next_steps_manual
}
