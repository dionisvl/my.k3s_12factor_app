# Nginx Hello World Kubernetes Project

![CI/CD](https://github.com/username/nginx-hello-world/workflows/CI/CD%20Pipeline/badge.svg)
![Version](https://img.shields.io/badge/version-v1.0.2-blue)
![License](https://img.shields.io/badge/license-MIT-green)

Production-ready nginx application with Kubernetes deployment and CI/CD.

## Features

- Static HTML serving with `/health` endpoint
- Multi-replica Kubernetes deployment with load balancing
- Environment-based configuration (local/production)
- CI/CD pipeline with testing and security scanning
- Build automation with Makefile

### Configuration

| Variable                   | Local                            | Production                                    |
|----------------------------|----------------------------------|-----------------------------------------------|
| `NGINX_SERVER_NAME`        | `localhost site.local app.local` | `example.com www.example.com api.example.com` |
| `NGINX_WORKER_CONNECTIONS` | `1024`                           | `2048`                                        |

```bash
# .env (local)
NGINX_SERVER_NAME=localhost site.local app.local
NGINX_WORKER_CONNECTIONS=1024

# .env.prod (production)  
NGINX_SERVER_NAME=example.com www.example.com api.example.com
NGINX_WORKER_CONNECTIONS=2048
```

## Quick Start

### Prerequisites
Docker Desktop, Make, Kind

### Development
```bash
make dev                  # Start local environment
make test                 # Run tests
```

### Kubernetes
```bash
make k8s-cluster          # Create kind cluster
make k8s-deploy           # Deploy application
make k8s-config-prod      # Switch to production config
```

### Manual Docker
```bash
docker compose up -d
curl http://localhost
```

### Manual Kubernetes
```bash
kind create cluster --name hello-cluster
docker build -t nginx_hello-nginx:latest .
kind load docker-image nginx_hello-nginx:latest --name hello-cluster
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/k8s-deployment.yaml
kubectl wait --for=condition=ready pod -l app=nginx-hello
```

## Endpoints

- `/` - Main page
- `/health` - Health check (returns "OK")

## CI/CD

- **Test**: Build, runtime, Kubernetes deployment
- **Security**: Trivy vulnerability scanning

```bash
make ci-test              # Run CI tests locally
```

## Common Commands

```bash
# Development
make dev / make dev-stop
make test / make clean

# Kubernetes  
make k8s-status
kubectl get pods -l app=nginx-hello
kubectl scale deployment nginx-hello --replicas=3

# Configuration
make k8s-config-local     # localhost domains
make k8s-config-prod      # production domains
```

## Troubleshooting

- **Port busy**: `make clean`
- **Pod not ready**: `make k8s-status`  
- **Image not found**: `make k8s-load`

## Architecture

See `docs/k8s-sequence.puml` for complete flow diagram.

