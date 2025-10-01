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

# Kubernetes (Recommended)
make k3d-cluster-isolated  # Create isolated cluster
source scripts/k8s-env.sh  # Activate environment (bash/zsh/fish)
make k3d-deploy-isolated   # Deploy application
make k3d-test-isolated     # Test (automated)

# Cleanup
make k3d-destroy-isolated  # Clean everything
```

## Testing & Verification

### Docker Compose
```bash
make build && docker compose up -d
docker ps | grep healthy              # Container health status
curl localhost:8080                   # Main page
curl localhost:8080/health            # Health endpoint
docker logs nginx_hello               # Check logs
```

### Kubernetes (k3s)
```bash
# Deploy
make k3d-cluster-isolated && source scripts/k8s-env.sh  # bash/zsh/fish
make k3d-deploy-isolated

# Verify deployment
kubectl get pods -o wide              # Check READY 1/1 status
kubectl get svc,ingress               # Check services
kubectl logs -l app=nginx-hello       # Check application logs

# Test application (automated)
make k3d-test-isolated               # Runs health checks inside pods

# Health checks verification
kubectl describe pod -l app=nginx-hello | grep -A5 "Liveness\|Readiness"
```

### Helm Deployment
```bash
# Deploy with Helm
make helm-deploy-isolated

# Or with custom values
helm upgrade --install nginx-hello helm/nginx-hello/ \
  --set config.domains='{example.com,www.example.com}' \
  --set image.tag=$(git rev-parse --short HEAD) \
  --set image.pullPolicy=Never
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