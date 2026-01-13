# Ansible Roles

This directory contains reusable Ansible roles for Kubernetes cluster management.

## Available Roles

### firewall
Configures UFW firewall rules for Kubernetes nodes.

### system-prep
Prepares system for Kubernetes (swap, kernel modules, sysctl).

### container-runtime
Installs and configures containerd as the container runtime.

### kubernetes
Installs Kubernetes components (kubelet, kubeadm, kubectl).

### networking
Configures network fixes for Calico VXLAN.

## Usage

Roles are automatically applied by playbooks in the `playbooks/` directory.

To use a role independently:

```yaml
---
- name: Example playbook
  hosts: all
  roles:
    - firewall
    - system-prep
    - container-runtime
```
