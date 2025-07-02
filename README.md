# K3s Nginx Hello World Project

![CI/CD](https://github.com/dionisvl/my.k8s_12factor_app/workflows/CI/badge.svg)
![Version](https://img.shields.io/badge/version-v1.0.2-blue)
![License](https://img.shields.io/badge/license-MIT-green)

Production-ready nginx application with isolated k3d deployment.

## Features

- Static HTML serving with `/health` endpoint
- Multi-replica Kubernetes deployment with Ingress load balancing
- Environment-based configuration (local/production)
- CI/CD pipeline with testing and security scanning
- Build automation with Makefile

## Quick Start

```bash
# Development
make up                    # Start Docker Compose
make test                  # Run tests

# Kubernetes (Recommended)
make k3d-cluster-isolated  # Create isolated cluster
source scripts/k8s-env.sh  # Activate environment
make k3d-deploy-isolated   # Deploy application
curl http://localhost:8080 # Test

# Cleanup
make k3d-destroy-isolated  # Clean everything
```

## Prerequisites

- Docker Desktop
- k3d: `brew install k3d`
- kubectl, helm, make

## Project Isolation

Each project gets its own kubeconfig to prevent conflicts:

```bash
source scripts/k8s-env.sh   # Isolate environment
kubectl config get-contexts # Shows only this project
```

## Available Commands

Run `make help` to see all commands.

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