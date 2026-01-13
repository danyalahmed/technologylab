# ============================================================================
# MAIN TERRAFORM CONFIGURATION
# ============================================================================
# This file serves as the main entry point.
# Infrastructure components are organized in separate files:
#   - locals.tf: Local values and computed data
#   - compute.tf: Proxmox VM resources
#   - ansible.tf: Ansible configuration generation
#   - provisioning.tf: Ansible playbook orchestration
#   - outputs.tf: Output values
#   - variables.tf: Input variables
#   - providers.tf: Provider configuration
#   - versions.tf: Terraform and provider version constraints
