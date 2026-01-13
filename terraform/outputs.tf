# ============================================================================
# INFRASTRUCTURE OUTPUTS
# ============================================================================

output "controlplane_vms" {
  description = "Proxmox control plane VM details"
  value = {
    for name, vm in module.kubernetes_controlplane_vms : name => {
      ip    = vm.ip
      vm_id = vm.vm_vmid
      node  = vm.node
      name  = vm.name
    }
  }
}

output "controlplane_ips" {
  description = "All control plane IP addresses (VMs + physical servers)"
  value       = local.controlplane_ips
}

output "worker_ips" {
  description = "All worker node IP addresses"
  value       = var.physical_worker_ips
}

# ============================================================================
# COMPONENT VERSIONS
# ============================================================================

output "component_versions" {
  description = "Deployed component versions"
  value = {
    kubernetes       = local.kubernetes_version
    calico_cni       = local.calico_version
    argocd           = local.argocd_version
    metallb          = var.metallb_version
    ubuntu_template  = local.ubuntu_template_name
    pod_network_cidr = local.pod_network_cidr
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

output "ansible_automation_status" {
  description = "Ansible automation configuration status"
  value = {
    enabled             = var.auto_run_ansible
    manual_instructions = var.auto_run_ansible ? null : "Run playbooks manually: cd ../ansible && ansible-playbook -i hosts.ini playbooks/<playbook-name>.yml"
  }
}

# ============================================================================
# NEXT STEPS
# ============================================================================

output "next_steps" {
  description = "Post-deployment instructions"
  value = var.auto_run_ansible ? local.next_steps_automated : local.next_steps_manual
}

locals {
  next_steps_automated = <<-EOT
    ✅ Infrastructure and Kubernetes cluster deployed successfully!

    Cluster Information:
    - Control Plane IPs: ${join(", ", local.controlplane_ips)}
    - Worker IPs: ${join(", ", var.physical_worker_ips)}

    Component Versions:
    - Kubernetes: ${local.kubernetes_version}
    - Calico CNI: ${local.calico_version}
    - ArgoCD: ${local.argocd_version}
    - MetalLB: ${var.metallb_version}

    Next Steps:
    1. Verify cluster health:
       kubectl get nodes
       kubectl get pods --all-namespaces

    2. Access ArgoCD UI:
       kubectl port-forward svc/argocd-server -n argocd 8080:443
       Username: admin
       Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

    3. Copy kubeconfig from control plane:
       scp ${element(local.controlplane_ips, 0)}:~/.kube/config ~/.kube/config

    To upgrade versions, edit terraform/locals.tf and run 'terraform apply'
  EOT

  next_steps_manual = <<-EOT
    ✅ Infrastructure deployed successfully!

    Cluster Information:
    - Control Plane IPs: ${join(", ", local.controlplane_ips)}
    - Worker IPs: ${join(", ", var.physical_worker_ips)}

    Next Steps (Manual Ansible execution required):
    1. Install Python dependencies:
       cd ../ansible && ansible-playbook -i hosts.ini playbooks/00-install-python-deps.yml

    2. Prepare nodes:
       ansible-playbook -i hosts.ini playbooks/01-prepare-nodes.yml

    3. Initialize control plane:
       ansible-playbook -i hosts.ini playbooks/02-init-controlplane.yml

    4. Join worker nodes:
       ansible-playbook -i hosts.ini playbooks/03-join-workers.yml

    5. Bootstrap ArgoCD:
       ansible-playbook -i hosts.ini playbooks/04-bootstrap-argocd.yml

    6. Verify cluster:
       kubectl get nodes

    To enable automatic Ansible execution, set auto_run_ansible = true in terraform.auto.tfvars
  EOT
}

    Worker IPs: ${join(", ", var.physical_worker_ips)}

    To enable automatic Ansible execution, set 'auto_run_ansible = true' in terraform.auto.tfvars
  EOT
}

output "next_steps" {
  description = "What to do next"
  value       = var.auto_run_ansible ? local.next_steps_auto : local.next_steps_manual
}
