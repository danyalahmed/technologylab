# Terraform Infrastructure Configuration

Infrastructure as Code for Kubernetes cluster on Proxmox using Terraform.

## Overview

This Terraform configuration manages:
- Proxmox virtual machines for Kubernetes control plane
- Integration with physical (bare metal) nodes
- Automatic Ansible inventory and variable generation
- Optional automatic Ansible playbook execution

## File Organization

```
terraform/
├── main.tf              # Main entry point (documentation)
├── locals.tf            # Local values and version management
├── compute.tf           # Proxmox VM resources
├── ansible.tf           # Ansible configuration generation
├── provisioning.tf      # Ansible playbook orchestration
├── variables.tf         # Input variables with validation
├── outputs.tf           # Output values
├── providers.tf         # Provider configuration
├── versions.tf          # Terraform version constraints
├── terraform.auto.tfvars.example  # Example configuration
└── modules/
    └── proxmox_vm/      # Reusable VM module
```

## Quick Start

### 1. Configure Variables

```bash
cp terraform.auto.tfvars.example terraform.auto.tfvars
```

Edit `terraform.auto.tfvars`:

```hcl
# Proxmox Configuration
proxmox_api_url = "https://proxmox.example.com:8006/api2/json"

# VM Configuration
proxmox_vm_config = {
  k8s-cp-01 = {
    cpu_cores = 4
    memory_mb = 8192
    ipconfig0 = "ip=192.168.1.10/24,gw=192.168.1.1"
  }
  k8s-cp-02 = {
    cpu_cores = 4
    memory_mb = 8192
    ipconfig0 = "ip=192.168.1.11/24,gw=192.168.1.1"
  }
}

# Physical Nodes
physical_worker_ips = ["192.168.1.20", "192.168.1.21"]

# Ansible Configuration
ansible_user         = "danny"
ansible_ssh_key_path = "~/.ssh/id_rsa"
auto_run_ansible     = true

# Network Configuration
desired_dns_servers = ["8.8.8.8", "1.1.1.1"]
metallb_ip_range    = "192.168.1.50-192.168.1.60"
```

### 2. Initialize and Apply

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan

# Apply changes
terraform apply
```

## Version Management

All component versions are centrally managed in `locals.tf`:

```hcl
locals {
  kubernetes_version       = "v1.35.0"
  kubernetes_version_short = "1.35"
  calico_version          = "v3.31.3"
  ubuntu_template_name    = "ubuntu-server-25.10"
  pod_network_cidr        = "10.240.0.0/16"
  argocd_version          = "v3.2.3"
}
```

To upgrade Kubernetes:
1. Edit `locals.tf`
2. Run `terraform apply`
3. Terraform will regenerate Ansible variables with new versions

## Input Variables

### Required Variables

- `proxmox_vm_config`: Map of VM configurations
- `proxmox_api_url`: Proxmox API endpoint

### Optional Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `auto_run_ansible` | bool | false | Auto-execute Ansible playbooks |
| `physical_controlplane_ips` | list(string) | [] | Physical control plane node IPs |
| `physical_worker_ips` | list(string) | [] | Physical worker node IPs |
| `ansible_user` | string | "danny" | SSH username for Ansible |
| `ansible_ssh_key_path` | string | "~/.ssh/id_rsa" | SSH private key path |
| `desired_dns_servers` | list(string) | [] | DNS servers for cluster nodes |
| `metallb_version` | string | "v0.14.8" | MetalLB version |
| `metallb_ip_range` | string | "" | MetalLB IP address range |

See [variables.tf](variables.tf) for complete documentation with validation rules.

## Outputs

After successful apply, Terraform outputs:

```
controlplane_ips        - All control plane IP addresses
worker_ips              - All worker node IP addresses
component_versions      - Deployed component versions
ansible_inventory_path  - Path to generated inventory file
ansible_vars_path       - Path to generated variables file
next_steps             - Post-deployment instructions
```

View outputs:
```bash
terraform output
terraform output -json
```

## Resource Organization

### compute.tf
Creates Proxmox VMs for Kubernetes control plane using the `proxmox_vm` module.

### ansible.tf
Generates two files automatically:
- `../ansible/hosts.ini` - Ansible inventory with all node IPs
- `../ansible/group_vars/all.yml` - Variables including versions

### provisioning.tf
Orchestrates Ansible playbook execution (when `auto_run_ansible = true`):
1. Wait for VMs to be SSH accessible
2. Install Python dependencies
3. Prepare nodes
4. Initialize control plane
5. Join worker nodes
6. Bootstrap ArgoCD

## Modules

### proxmox_vm

Reusable module for creating Proxmox VMs.

**Usage:**
```hcl
module "my_vm" {
  source = "./modules/proxmox_vm"
  
  name                = "my-vm"
  cpu_cores           = 2
  memory              = 4096
  clone_from_template = true
  template_name       = "ubuntu-server-25.10"
  ipconfig0           = "ip=192.168.1.100/24,gw=192.168.1.1"
}
```

See [modules/proxmox_vm/README.md](modules/proxmox_vm/README.md) for full documentation.

## Automation Modes

### Mode 1: Fully Automatic (Recommended)

```hcl
auto_run_ansible = true
```

Terraform handles everything:
- Creates VMs
- Generates Ansible files
- Runs all playbooks
- Deploys complete cluster

### Mode 2: Infrastructure Only

```hcl
auto_run_ansible = false
```

Terraform only:
- Creates VMs
- Generates Ansible files

You run Ansible manually:
```bash
cd ../ansible
ansible-playbook -i hosts.ini playbooks/01-prepare-nodes.yml
```

## State Management

### Local State (Development)
By default, state is stored locally in `terraform.tfstate`.

**⚠️ Warning**: Do not commit state files to Git!

### Remote State (Production)

Configure remote backend in `providers.tf`:

```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "kubernetes/terraform.tfstate"
    region = "us-east-1"
  }
}
```

Or use Terraform Cloud:
```hcl
terraform {
  cloud {
    organization = "my-org"
    workspaces {
      name = "kubernetes-cluster"
    }
  }
}
```

## Best Practices

### Version Pinning
- ✅ Pin provider versions in `versions.tf`
- ✅ Use `~>` for minor version flexibility
- ✅ Lock exact versions for production

### Variable Validation
All variables include validation rules:
```hcl
variable "proxmox_vm_config" {
  validation {
    condition     = alltrue([for k, v in var.proxmox_vm_config : v.cpu_cores >= 2])
    error_message = "All VMs must have at least 2 CPU cores for Kubernetes"
  }
}
```

### Sensitive Data
Mark sensitive variables:
```hcl
variable "sudo_password" {
  type      = string
  sensitive = true
}
```

### Idempotency
All resources are designed to be idempotent:
- VMs check for existing resources
- Ansible playbooks use proper `changed_when` conditions
- Triggers ensure playbooks only run when needed

## Troubleshooting

### Proxmox Connection Issues
```bash
# Test Proxmox API
curl -k https://proxmox.example.com:8006/api2/json

# Check provider configuration
terraform console
> var.proxmox_api_url
```

### Ansible Not Running
Check `null_resource` triggers:
```bash
terraform show | grep triggers
```

Force Ansible re-run:
```bash
terraform taint null_resource.ansible_prepare_nodes[0]
terraform apply
```

### VM Creation Failures
```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform apply

# Check Proxmox logs
tail -f /var/log/pve/tasks/active
```

### State Issues
```bash
# List resources in state
terraform state list

# Show specific resource
terraform state show module.kubernetes_controlplane_vms[\"k8s-cp-01\"]

# Remove problematic resource
terraform state rm module.kubernetes_controlplane_vms[\"k8s-cp-01\"]
```

## Common Operations

### Add Control Plane Node
```hcl
# In terraform.auto.tfvars
proxmox_vm_config = {
  k8s-cp-01 = { ... }
  k8s-cp-02 = { ... }
  k8s-cp-03 = { ... }  # New node
}
```

```bash
terraform apply
```

### Remove Worker Node
```hcl
# In terraform.auto.tfvars
physical_worker_ips = [
  "192.168.1.20",
  # "192.168.1.21"  # Commented out
]
```

```bash
terraform apply
```

### Upgrade Kubernetes
```hcl
# In locals.tf
kubernetes_version = "v1.36.0"
```

```bash
terraform apply
```

### Destroy Infrastructure
```bash
# Preview what will be destroyed
terraform plan -destroy

# Destroy everything
terraform destroy
```

## Formatting and Validation

```bash
# Format Terraform files
terraform fmt -recursive

# Validate configuration
terraform validate

# Check with tflint
tflint

# Generate documentation
terraform-docs markdown table . > TERRAFORM.md
```

## CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: Terraform

on:
  push:
    branches: [main]
  pull_request:

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.14
      
      - name: Terraform Init
        run: terraform init
        working-directory: terraform
      
      - name: Terraform Validate
        run: terraform validate
        working-directory: terraform
      
      - name: Terraform Plan
        run: terraform plan
        working-directory: terraform
        env:
          TF_VAR_proxmox_api_url: ${{ secrets.PROXMOX_API_URL }}
```

## Security

- 🔒 Never commit `terraform.tfvars` files
- 🔒 Use Terraform Cloud for sensitive state
- 🔒 Enable encryption at rest for state files
- 🔒 Use least privilege for Proxmox API tokens
- 🔒 Rotate SSH keys regularly

## Additional Resources

- [Terraform Proxmox Provider](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Ansible Documentation](../ansible/README.md)
