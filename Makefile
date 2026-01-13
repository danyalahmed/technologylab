.PHONY: help init validate plan apply destroy fmt clean check ansible-check

# Default target
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

# ============================================================================
# TERRAFORM COMMANDS
# ============================================================================

init: ## Initialize Terraform working directory
	cd terraform && terraform init

validate: ## Validate Terraform configuration files
	cd terraform && terraform validate

fmt: ## Format Terraform configuration files
	cd terraform && terraform fmt -recursive

plan: ## Show Terraform execution plan
	cd terraform && terraform plan

apply: ## Apply Terraform configuration
	cd terraform && terraform apply

destroy: ## Destroy Terraform-managed infrastructure
	cd terraform && terraform destroy

clean: ## Clean Terraform generated files
	cd terraform && rm -rf .terraform .terraform.lock.hcl terraform.tfstate* ansible/hosts.ini ansible/group_vars/all.yml

# ============================================================================
# VALIDATION AND CHECKS
# ============================================================================

check: fmt validate ## Run formatting and validation

terraform-docs: ## Generate Terraform documentation
	cd terraform && terraform-docs markdown table --output-file TERRAFORM.md .

# ============================================================================
# ANSIBLE COMMANDS
# ============================================================================

ansible-check: ## Check Ansible syntax
	cd ansible && ansible-playbook --syntax-check playbooks/*.yml

ansible-lint: ## Run ansible-lint on playbooks
	cd ansible && ansible-lint playbooks/

ansible-inventory: ## Display generated Ansible inventory
	cd ansible && cat hosts.ini

# ============================================================================
# MANUAL ANSIBLE PLAYBOOK EXECUTION
# ============================================================================

ansible-prerequisites: ## Install Python dependencies on nodes
	cd ansible && ansible-playbook -i hosts.ini playbooks/prerequisites.yml

ansible-configure: ## Configure Kubernetes nodes
	cd ansible && ansible-playbook -i hosts.ini playbooks/configure-nodes.yml

ansible-init: ## Initialize Kubernetes control plane
	cd ansible && ansible-playbook -i hosts.ini playbooks/initialize-control-plane.yml

ansible-join: ## Join worker nodes to cluster
	cd ansible && ansible-playbook -i hosts.ini playbooks/join-worker-nodes.yml

ansible-metallb: ## Deploy MetalLB
	cd ansible && ansible-playbook -i hosts.ini playbooks/deploy-metallb.yml

ansible-argocd: ## Deploy ArgoCD
	cd ansible && ansible-playbook -i hosts.ini playbooks/deploy-argocd.yml

ansible-all: ansible-prerequisites ansible-configure ansible-init ansible-join ansible-metallb ansible-argocd ## Run all Ansible playbooks in sequence

# ============================================================================
# CLUSTER OPERATIONS
# ============================================================================

kubeconfig: ## Fetch kubeconfig from control plane
	@echo "Fetching kubeconfig from control plane..."
	@cd ansible && ansible controlplane[0] -i hosts.ini -m fetch -a "src=~/.kube/config dest=./kubeconfig flat=yes" -b

cluster-info: ## Display cluster information
	kubectl cluster-info
	kubectl get nodes
	kubectl get pods --all-namespaces

argocd-password: ## Get ArgoCD admin password
	kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
