# Kubernetes on Proxmox - Infrastructure as Code

Fully automated Kubernetes cluster deployment combining Proxmox VMs and physical machines using Terraform, Ansible, and ArgoCD for GitOps.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Infrastructure Layer                      │
│  Terraform creates VMs on Proxmox + manages physical nodes  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                  Configuration Layer                         │
│  Ansible configures nodes and initializes Kubernetes        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                   Application Layer                          │
│  ArgoCD manages cluster applications via GitOps             │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
technologylab/
├── terraform/              # Infrastructure as Code
│   ├── main.tf            # Main entry point (documentation)
│   ├── locals.tf          # Local values and computed data
│   ├── compute.tf         # Proxmox VM resources
│   ├── ansible.tf         # Ansible configuration generation
│   ├── provisioning.tf    # Ansible playbook orchestration
│   ├── variables.tf       # Input variables with validation
│   ├── outputs.tf         # Output values
│   ├── providers.tf       # Provider configuration
│   ├── versions.tf        # Version constraints
│   └── modules/
│       └── proxmox_vm/    # Reusable VM module
├── ansible/               # Configuration Management
│   ├── playbooks/         # Ordered execution playbooks
│   ├── roles/             # Reusable roles
│   ├── templates/         # Jinja2 templates
│   └── group_vars/        # Variables (auto-generated)
└── argocd/                # GitOps Applications
    ├── bootstrap/         # App-of-apps pattern
    ├── apps/              # Application definitions
    ├── infrastructure/    # Infrastructure manifests
    └── projects/          # ArgoCD projects
```

## 🚀 Quick Start

### 1. Configure Terraform

```bash
cd terraform
cp terraform.auto.tfvars.example terraform.auto.tfvars
```

Edit `terraform.auto.tfvars`:
```hcl
proxmox_api_url = "https://proxmox.example.com:8006/api2/json"

proxmox_vm_config = {
  k8s-cp-01 = {
    cpu_cores = 4
    memory_mb = 8192
    ipconfig0 = "ip=192.168.1.10/24,gw=192.168.1.1"
  }
}

physical_worker_ips = ["192.168.1.20", "192.168.1.21"]

auto_run_ansible = true  # Set false for manual Ansible execution
```

### 2. Deploy Infrastructure

```bash
# Initialize Terraform
make init

# Review planned changes
make plan

# Deploy everything
make apply
```

**With `auto_run_ansible = true`**, this command:
1. ✅ Creates VMs on Proxmox
2. ✅ Generates Ansible inventory and variables
3. ✅ Installs dependencies on nodes
4. ✅ Prepares nodes (firewall, containerd, k8s)
5. ✅ Initializes control plane
6. ✅ Joins worker nodes
7. ✅ Bootstraps ArgoCD

### 3. Verify Deployment

```bash
# Get cluster information
make cluster-info

# Get ArgoCD password
make argocd-password

# Fetch kubeconfig
make kubeconfig
```

## 🛠️ Available Make Commands

```bash
make help                 # Show all available commands

# Terraform
make init                 # Initialize Terraform
make validate             # Validate configuration
make plan                 # Show execution plan
make apply                # Apply changes
make destroy              # Destroy infrastructure
make fmt                  # Format Terraform files

# Ansible
make ansible-check        # Check playbook syntax
make ansible-lint         # Lint playbooks
make ansible-all          # Run all playbooks manually

# Cluster
make kubeconfig           # Fetch kubeconfig from control plane
make cluster-info         # Display cluster information
make argocd-password      # Get ArgoCD admin password
```

## 📝 Component Versions

All versions are centrally managed in [terraform/locals.tf](terraform/locals.tf):
- Kubernetes: v1.35.0
- Calico CNI: v3.31.3
- ArgoCD: v3.2.3
- MetalLB: v0.14.8
- Ubuntu Template: ubuntu-server-25.10

**To upgrade**, edit `terraform/locals.tf` and run `terraform apply`.

## 🔧 Configuration

### Terraform Variables

See [terraform/variables.tf](terraform/variables.tf) for all available options:
- Proxmox connection settings
- VM configurations (CPU, memory, network)
- Physical node IPs
- Ansible automation settings
- Kubernetes network configuration
- MetalLB IP ranges

### Ansible Roles

Modular roles in [ansible/roles/](ansible/roles/):
- **firewall**: UFW configuration for Kubernetes
- **system-prep**: Kernel modules, sysctl, swap
- **container-runtime**: Containerd installation
- **kubernetes**: Kubeadm, kubelet, kubectl
- **networking**: Network fixes for Calico

### ArgoCD Applications

GitOps-managed applications with sync waves:
1. **Wave 1**: Gateway API (CRDs)
2. **Wave 2**: Istio Base
3. **Wave 3**: Istio Istiod & CNI
4. **Wave 4**: Istio Ztunnel
5. **Wave 5**: Metrics Server
6. **Wave 6**: Kubernetes Dashboard

## 🔐 Security

### Secrets Management

1. Use Ansible Vault for sensitive data:
```bash
cp ansible/group_vars/vault.yml.example ansible/group_vars/vault.yml
ansible-vault edit ansible/group_vars/vault.yml
```

2. Use Terraform sensitive variables:
```hcl
variable "sudo_password" {
  type      = string
  sensitive = true
}
```

### Best Practices

- ✅ SSH keys instead of passwords
- ✅ Firewall rules configured automatically
- ✅ Secrets stored in Ansible Vault
- ✅ Infrastructure state in Terraform
- ✅ GitOps for application management

## 📊 Accessing Services

### Kubernetes Dashboard (Headlamp)

```bash
# Create service account
kubectl -n kubernetes-dashboard create serviceaccount headlamp-admin
kubectl create clusterrolebinding headlamp-admin-binding \
  --clusterrole=cluster-admin \
  --serviceaccount=kubernetes-dashboard:headlamp-admin

# Get token
kubectl -n kubernetes-dashboard create token headlamp-admin

# Port forward
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-headlamp 8080:80
# Open: http://localhost:8080
```

### ArgoCD UI

```bash
# Get admin password
make argocd-password

# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open: https://localhost:8080
# Username: admin
```

## 🔄 Common Operations

### Manual Ansible Execution

If `auto_run_ansible = false`:
```bash
make ansible-python        # Install Python deps
make ansible-prepare       # Prepare nodes
make ansible-init          # Initialize control plane
make ansible-join          # Join workers
make ansible-argocd        # Bootstrap ArgoCD
```

### Upgrade Kubernetes

1. Edit `terraform/locals.tf`:
```hcl
kubernetes_version = "v1.36.0"
```

2. Apply changes:
```bash
terraform apply
```

### Add Worker Nodes

1. Edit `terraform.auto.tfvars`:
```hcl
physical_worker_ips = ["192.168.1.20", "192.168.1.21", "192.168.1.22"]
```

2. Apply:
```bash
terraform apply
```

## 🐛 Troubleshooting

### Check Terraform State
```bash
terraform show
terraform state list
```

### Verify Ansible Connectivity
```bash
ansible all -i ansible/hosts.ini -m ping
```

### View Logs
```bash
tail -f ansible/ansible.log
```

### Debug Mode
```bash
cd ansible
ansible-playbook -i hosts.ini playbooks/01-prepare-nodes.yml -vvv
```

## 📚 Documentation

- [Terraform README](terraform/) - Infrastructure documentation
- [Ansible README](ansible/README.md) - Configuration management guide
- [ArgoCD README](argocd/README.md) - GitOps applications guide
- [Proxmox VM Module](terraform/modules/proxmox_vm/README.md) - Module documentation

## 🔨 Development

### Pre-commit Hooks

Install pre-commit hooks for validation:
```bash
pre-commit install
pre-commit run --all-files
```

Hooks include:
- Terraform fmt, validate, docs
- Ansible lint
- YAML syntax check
- Markdown lint

## ⚠️ Requirements

- **Terraform** >= 1.14
- **Ansible** >= 2.9
- **Proxmox VE** (tested on 8.x)
- **SSH access** to all nodes
- **Python 3** on control node

## 📄 License

This project is licensed under the MIT License.
