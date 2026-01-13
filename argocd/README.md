# ArgoCD GitOps Configuration

This directory contains ArgoCD application definitions for managing Kubernetes cluster infrastructure using GitOps principles.

## Directory Structure

```
argocd/
├── bootstrap/          # Bootstrap applications (app-of-apps pattern)
│   ├── apps.yml       # Root application deploying all apps
│   └── projects.yml   # ArgoCD projects
├── apps/              # Application definitions
│   ├── gateway-api.yml         # Kubernetes Gateway API (wave 1)
│   ├── istio.yml               # Istio service mesh (wave 2-4)
│   ├── metric-server.yml       # Metrics server (wave 5)
│   └── kubernetes-dashboard.yml # Dashboard (wave 6)
├── infrastructure/    # Infrastructure manifests
│   └── gateway-api/
└── projects/         # Project definitions
    └── infrastructure.yml
```

## Sync Waves

Applications are deployed in the following order using sync waves:

1. **Wave 1**: Gateway API CRDs
2. **Wave 2**: Istio Base (CRDs and base configuration)
3. **Wave 3**: Istio Istiod (control plane) & CNI
4. **Wave 4**: Istio Ztunnel (ambient mesh)
5. **Wave 5**: Metrics Server
6. **Wave 6**: Kubernetes Dashboard

## Bootstrap Process

The cluster is bootstrapped using the app-of-apps pattern:

1. ArgoCD is installed via Ansible playbook `deploy-argocd.yml`
2. Root application (`bootstrap/apps.yml`) is applied
3. Root app automatically deploys all applications in `apps/` directory
4. Applications sync in order based on their sync wave annotations

## Adding New Applications

1. Create application manifest in `apps/` directory
2. Add appropriate sync wave annotation
3. Configure sync policy (automated or manual)
4. Commit and push - ArgoCD will detect and sync automatically

Example:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "7"
spec:
  project: infrastructure
  source:
    repoURL: https://my-helm-repo.example.com
    chart: my-app
    targetRevision: 1.0.0
  destination:
    server: https://kubernetes.default.svc
    namespace: my-namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 3
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 2m
```

## Manual Sync

If automatic sync is disabled, manually sync applications:

```bash
# Sync specific application
argocd app sync <app-name>

# Sync all applications
argocd app sync -l app.kubernetes.io/instance=root-app

# View sync status
argocd app list
```

## Health Checks

ArgoCD automatically monitors application health. Check status:

```bash
# CLI
argocd app get <app-name>

# Web UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Visit https://localhost:8080
```

## Troubleshooting

### Application Out of Sync

```bash
argocd app sync <app-name> --force
```

### View Application Logs

```bash
argocd app logs <app-name>
```

### Refresh Application

```bash
argocd app get <app-name> --refresh
```
