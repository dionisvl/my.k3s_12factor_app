# K3s Nginx Hello World Project

![CI/CD](https://github.com/dionisvl/my.k8s_12factor_app/workflows/CI/badge.svg)
![Version](https://img.shields.io/badge/version-v1.0.2-blue)
![License](https://img.shields.io/badge/license-MIT-green)

Production-ready nginx application with isolated k3d deployment.

## Features

- Static HTML serving with `/health` endpoint
- Multi-replica Kubernetes deployment with Ingress load balancing
- Environment-based configuration (local/production)
- Helm charts for production deployments
- Configurable k3d ports for parallel development
- Automated testing with pod-level health checks
- CI/CD pipeline with testing and security scanning
- Build automation with Makefile


## Prerequisites

- Docker Desktop
- k3d: `brew install k3d`
- kubectl, helm, make

## Quick Start

```bash
# Development
make up                    # Start Docker Compose
make test                  # Run tests

# Kubernetes with Helm (Recommended)
make k3d-cluster-isolated  # Create isolated cluster
source scripts/k8s-env.sh  # Activate environment (bash/zsh/fish)
make k3d-deploy-isolated   # Deploy with Helm (uses values.yaml + values.dev.yaml)
make k3d-test-isolated     # Test (automated)
make k3d-local-access      # Open http://localhost:8080 via port-forward

# Cleanup
make k3d-destroy-isolated  # Clean everything
```

## Testing & Verification

### Docker Compose
```bash
# Works without .env files (uses defaults)
make up                               # Start with defaults (port 8080, 1024 connections)
docker ps | grep healthy              # Container health status
curl localhost:8080                   # Main page
curl localhost:8080/health            # Health endpoint
docker logs nginx_hello               # Check logs

# Optional: override with environment variables or .env file
# NGINX_PORT=8081 docker compose up -d  # Custom port
# or create .env file (in .gitignore):
# NGINX_PORT=8081
# NGINX_WORKER_CONNECTIONS=2048
```

### Kubernetes (k3s)
```bash
# Deploy
make k3d-cluster-isolated && source scripts/k8s-env.sh  # bash/zsh/fish
make k3d-deploy-isolated

# Local access (recommended for dev)
make k3d-local-access                # Port-forward to http://localhost:8080 (instant)

# Verify deployment
kubectl get pods -o wide              # Check READY 1/1 status
kubectl get svc,ingress               # Check services
kubectl logs -l app=nginx-hello       # Check application logs

# Test application (automated)
make k3d-test-isolated               # Runs health checks inside pods
```

**Local vs Ingress access:**
- `make k3d-local-access` - Direct port-forward, instant, for dev
- `http://localhost:8080/` - Through Traefik Ingress, production-like, requires Traefik to be running

### Helm Configuration (Like .env files)

Configuration uses layered values files (similar to .env pattern):

```bash
helm/nginx-hello/
├── values.yaml              # Base config (in Git)
├── values.dev.yaml          # Dev environment (in Git)
├── values.prod.yaml         # Production (in Git)
├── values.local.yaml        # Your personal overrides (in .gitignore)
└── values.local.yaml.example # Template for local config
```

**Local Development:**
```bash
# 1. Create your personal config (optional)
cp helm/nginx-hello/values.local.yaml.example helm/nginx-hello/values.local.yaml

# 2. Edit your overrides
# values.local.yaml:
# config:
#   domains:
#     - "myapp.local"

# 3. Deploy (automatically uses values.local.yaml if exists)
make helm-deploy-isolated

# Helm loads in order: base → dev/prod → local
```

**Deploy to different environments:**
```bash
make helm-deploy-isolated  # Dev (values.yaml + values.dev.yaml + values.local.yaml)
make helm-deploy-prod      # Prod (values.yaml + values.prod.yaml + values.local.yaml)
```

### Custom Ports (Avoid Conflicts)
```bash
# Use different ports for parallel projects
K3D_API_PORT=6444 K3D_LB_PORT=8081 make k3d-cluster-isolated
```

## Project Isolation

Each project gets its own kubeconfig to prevent conflicts:

```bash
source scripts/k8s-env.sh   # Isolate environment
kubectl config get-contexts # Shows only this project
```

## Endpoints

- `/` - Hello World page
- `/health` - Health check

## Troubleshooting

```bash
# kubectl not working?
make k3d-destroy-isolated && make k3d-cluster-isolated
source scripts/k8s-env.sh

# Wrong context?
echo $KUBECONFIG  # Should show project kubeconfig
```