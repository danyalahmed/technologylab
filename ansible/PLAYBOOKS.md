# Ansible Playbooks Documentation

This document provides detailed information about each Ansible playbook used to deploy and manage the Kubernetes cluster.

## Playbook Overview

| Playbook | Purpose | Target | Duration |
|----------|---------|--------|----------|
| `00-Prerequisites.yml` | Install Python dependencies | All nodes | ~2-3 minutes |
| `01-Configure-nodes.yml` | Configure nodes for Kubernetes | All nodes | ~5-7 minutes |
| `02-Initialize-control-plane.yml` | Initialize Kubernetes cluster | Control plane | ~3-5 minutes |
| `03-Join-worker-nodes.yml` | Join workers to cluster | Workers | ~2-3 minutes |
| `04-Ddeploy-infra.yml` | Deploy infrastructure services | Localhost | ~10-15 minutes |
| `999-Destroy.yml` | Clean cluster removal | All nodes | ~2-3 minutes |

## Execution Order

The playbooks **MUST** be executed in numerical order due to dependencies:

```bash
cd ansible

# Phase 1: Prerequisites
ansible-playbook playbooks/00-Prerequisites.yml

# Phase 2: Node Configuration
ansible-playbook playbooks/01-Configure-nodes.yml

# Phase 3: Cluster Initialization
ansible-playbook playbooks/02-Initialize-control-plane.yml

# Phase 4: Cluster Expansion
ansible-playbook playbooks/03-Join-worker-nodes.yml

# Phase 5: Infrastructure Deployment
ansible-playbook playbooks/04-Ddeploy-infra.yml

# Cleanup (when needed)
ansible-playbook playbooks/999-Destroy.yml
```

---

## 00-Prerequisites.yml

**Purpose:** Install Python dependencies required for Ansible Kubernetes modules.

**Target:** All nodes (controlplane + workers)

**Prerequisites:** None

**Duration:** ~2-3 minutes

### What it does:
- Updates APT package cache (with 1-hour cache validity)
- Installs Python runtime and tools:
  - `python3`, `python3-pip`, `python3-venv`
  - `python3-kubernetes` (Kubernetes Python client)
  - `python3-yaml` (YAML parsing)
  - `ethtool` (Network interface tools)
  - `nfs-common` (NFS client utilities)

### Optimization features:
- `strategy: free` - Parallel execution across nodes
- `cache_valid_time: 3600` - APT cache reuse

### Usage:
```bash
ansible-playbook -i hosts.ini playbooks/00-Prerequisites.yml
```

---

## 01-Configure-nodes.yml

**Purpose:** Prepare all nodes for Kubernetes cluster membership.

**Target:** All Kubernetes nodes (k8s_nodes group)

**Prerequisites:**
- Python dependencies installed (00-Prerequisites.yml)

**Duration:** ~5-7 minutes

### Roles applied (in order):
1. **firewall** - Configure UFW firewall rules
2. **system-prep** - System preparation for Kubernetes
3. **container-runtime** - Install and configure containerd
4. **kubernetes** - Install kubeadm, kubelet, kubectl
5. **networking** - Apply network fixes for Calico VXLAN

### Key configurations:
- **Firewall:** Opens ports for Kubernetes API, etcd, Calico networking, NodePort services
- **System:** Disables swap, loads kernel modules, configures sysctl for networking
- **Containerd:** Installs containerd with SystemdCgroup enabled
- **Kubernetes:** Installs v1.28+ components with package holding
- **Networking:** Fixes for Calico VXLAN TX checksum offload

### Optimization features:
- `strategy: free` - Parallel execution across all nodes
- `become: true` with sudo method

### Usage:
```bash
ansible-playbook -i hosts.ini playbooks/01-Configure-nodes.yml
```

---

## 02-Initialize-control-plane.yml

**Purpose:** Initialize the Kubernetes control plane and configure cluster networking.

**Target:** Control plane node (first master)

**Prerequisites:**
- All nodes configured (01-Configure-nodes.yml)

**Duration:** ~3-5 minutes

### Steps performed:
1. **Check existing installation** - Skip if already initialized
2. **Generate kubeadm config** - From template `kubeadm-config.yml.j2`
3. **Initialize cluster** - `kubeadm init` with custom configuration
4. **Configure kubectl** - Copy admin.conf to user's kube config
5. **Fix CoreDNS** - Update forwarders for custom DNS servers
6. **Install CNI** - Deploy Calico with Tigera operator
7. **CSR Approver** - Deploy automatic kubelet CSR approval
8. **Fetch kubeconfig** - Save to `temp_kubeconfig` for subsequent playbooks

### Key configurations:
- **Networking:** Calico VXLAN with custom pod CIDR
- **DNS:** CoreDNS configured with custom upstream servers
- **Security:** Automatic kubelet certificate approval
- **HA:** Single-node control plane (expandable to multi-master)

### Post-initialization:
- Kubeconfig available at `~/.kube/config` on control plane
- Kubeconfig copied to `ansible/playbooks/temp_kubeconfig`

### Usage:
```bash
ansible-playbook -i hosts.ini playbooks/02-Initialize-control-plane.yml
```

---

## 03-Join-worker-nodes.yml

**Purpose:** Join worker nodes to the established Kubernetes cluster.

**Target:** Control plane (to generate token) + Worker nodes (to join)

**Prerequisites:**
- Control plane initialized (02-Initialize-control-plane.yml)
- Worker nodes configured (01-Configure-nodes.yml)

**Duration:** ~2-3 minutes

### Process:
1. **Generate join command** - On control plane using `kubeadm token create --print-join-command`
2. **Distribute command** - Set as fact accessible to worker nodes
3. **Join workers** - Execute join command on each worker node
4. **Validation** - Check for existing `/etc/kubernetes/kubelet.conf`

### Safety features:
- Idempotent - skips nodes already joined
- Node naming - uses `inventory_hostname` for consistent naming
- Error handling - fails if join command unavailable

### Usage:
```bash
ansible-playbook -i hosts.ini playbooks/03-Join-worker-nodes.yml
```

---

## 04-Ddeploy-infra.yml

**Purpose:** Deploy infrastructure services and add-ons to the cluster.

**Target:** Localhost (kubectl commands)

**Prerequisites:**
- Cluster fully operational (03-Join-worker-nodes.yml completed)

**Duration:** ~10-15 minutes

### Deployment phases (sequential for dependencies):

#### Phase 1: Base Infrastructure (Parallel)
- **metric-server** - Cluster metrics collection
- **metallb** - LoadBalancer service support
- **cert-manager** - TLS certificate management

#### Phase 2: Gateway API CRDs
- **gateway-api** - Kubernetes Gateway API CRDs (required before Istio)

#### Phase 3: Service Mesh
- **istio** - Service mesh with ambient mode
- **default-gateways** - Istio ingress/egress gateways

#### Phase 4: Storage Provisioner
- **nfs-provisioner** - Dynamic NFS volume provisioning

#### Phase 5: Object Storage
- **seaweedfs** - S3-compatible object storage (uses NFS backend)

#### Phase 6: Secrets Management
- **vault** - HashiCorp Vault with SeaweedFS S3 backend

### Dependency chain:
```
Gateway API → Istio
NFS → SeaweedFS → Vault
```

### Usage:
```bash
ansible-playbook playbooks/04-Ddeploy-infra.yml
```

---

## 999-Destroy.yml

**Purpose:** Safely remove Kubernetes cluster and restore nodes to clean state.

**Target:** All nodes

**Prerequisites:** None (can run on any cluster state)

**Duration:** ~2-3 minutes

### Safe cleanup process:
1. **Graceful reset** - `kubeadm reset -f` on all nodes
2. **Stop services** - kubelet, containerd
3. **Unmount filesystems** - Only K8s/Calico/CSI mounts
4. **Clean network** - Remove CNI interfaces (cni0, tunl0, vxlan.calico, etc.)
5. **Reset firewall** - UFW reset while keeping SSH accessible
6. **Clean directories** - Remove `/etc/kubernetes`, `/var/lib/kubelet`, etc.
7. **Reboot** - Optional node restart for complete cleanup

### Safety features:
- **Selective unmounting** - Only targets K8s-related mounts
- **SSH preservation** - Firewall reset keeps SSH accessible
- **Failed_when: false** - Continues despite individual failures
- **Idempotent** - Safe to run multiple times

### Usage:
```bash
ansible-playbook -i hosts.ini playbooks/999-Destroy.yml
```

---

## Common Usage Patterns

### Full cluster deployment:
```bash
# Automated (via Terraform)
terraform apply  # Includes Ansible execution

# Manual execution
ansible-playbook playbooks/00-Prerequisites.yml
ansible-playbook playbooks/01-Configure-nodes.yml
ansible-playbook playbooks/02-Initialize-control-plane.yml
ansible-playbook playbooks/03-Join-worker-nodes.yml
ansible-playbook playbooks/04-Ddeploy-infra.yml
```

### Testing and debugging:
```bash
# Syntax check all playbooks
ansible-playbook playbooks/*.yml --syntax-check

# Dry run configuration
ansible-playbook playbooks/01-Configure-nodes.yml --check

# Debug with verbose output
ansible-playbook playbooks/01-Configure-nodes.yml -vvv

# Run specific tags
ansible-playbook playbooks/01-Configure-nodes.yml --tags firewall
```

### Troubleshooting:
```bash
# Test connectivity
ansible all -m ping

# Check inventory
ansible-inventory -i hosts.ini --list

# View Ansible logs
tail -f ansible.log
```

---

## Configuration Files

### Required files:
- `hosts.ini` - Ansible inventory (auto-generated by Terraform)
- `group_vars/all.yml` - Variables (auto-generated by Terraform)
- `ansible.cfg` - Ansible configuration with optimizations

### Templates:
- `templates/kubeadm-config.yml.j2` - Kubeadm initialization config
- `templates/inventory.tftpl` - Inventory template for Terraform
- `templates/s3-config.json.j2` - SeaweedFS S3 configuration

### Optional:
- `group_vars/vault.yml` - Encrypted secrets (use `ansible-vault`)

---

## Error Handling

### Common issues and solutions:

**SSH connectivity:**
```bash
# Test SSH access
ansible all -m ping --private-key ~/.ssh/id_rsa

# Add host keys
ssh-keyscan <node-ip> >> ~/.ssh/known_hosts
```

**Privilege escalation:**
```bash
# Use password authentication
ansible-playbook playbooks/01-Configure-nodes.yml --ask-become-pass
```

**Vault secrets:**
```bash
# Edit encrypted variables
ansible-vault edit group_vars/vault.yml

# Run with vault password
ansible-playbook playbooks/04-Ddeploy-infra.yml --ask-vault-pass
```

---

## Performance Optimizations

### Parallelization:
- `forks: 20` - Up to 20 concurrent operations
- `strategy: free` - Independent node execution
- Sequential phases where dependencies exist

### Caching:
- APT cache: 1-hour validity
- Fact caching: 24-hour TTL with JSON backend

### Network:
- SSH pipelining enabled
- ControlPersist for connection reuse
- Optimized timeouts and retry logic

---

## Monitoring and Logs

### Logs:
- Main log: `ansible.log`
- Per-playbook execution logs
- Task timing with `profile_tasks` callback

### Monitoring:
- Use `--profile` for task timing
- Check `ansible.log` for detailed execution
- Monitor cluster health with `kubectl get nodes,pods -A`