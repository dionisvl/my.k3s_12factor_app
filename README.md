# Nginx Hello World Kubernetes Project

![CI/CD](https://github.com/dionisvl/my.k8s_12factor_app/workflows/CI/badge.svg)
![Version](https://img.shields.io/badge/version-v1.0.2-blue)
![License](https://img.shields.io/badge/license-MIT-green)

Production-ready nginx application with Kubernetes deployment and CI/CD.

## Features

- Static HTML serving with `/health` endpoint
- Multi-replica Kubernetes deployment with Ingress load balancing
- Environment-based configuration (local/production)
- CI/CD pipeline with testing and security scanning
- Build automation with Makefile

## Configuration

```bash
NGINX_PORT=8080
NGINX_WORKER_CONNECTIONS=1024
NGINX_APP_VERSION=v1.0.2
ENVIRONMENT=local

DOMAIN_1=localhost
DOMAIN_2=site-r1.local
DOMAIN_3=site-r2.local
```

### Custom Domains

```bash
# Docker Compose
DOMAIN_1=my-app.com DOMAIN_2=www.my-app.com make dev

# Kubernetes
export DOMAIN_1="my-app.com" DOMAIN_2="www.my-app.com"
make k8s-deploy

# Helm  
helm upgrade --install nginx-hello helm/nginx-hello/ \
  --set domain1=my-app.com --set domain2=www.my-app.com
```

## Quick Start

### Prerequisites
Docker Desktop, Make, Kind, Helm

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

### Helm Deployment (Recommended)
```bash
make k8s-cluster          # Create kind cluster
make helm-deploy          # Deploy with Helm (local)
make helm-deploy-prod     # Deploy with Helm (production)
make helm-status          # Check deployment status
```

### Manual Docker
```bash
docker compose up -d
curl http://localhost:8080
```

### Access

```bash
# Ingress
curl -H "Host: site-r1.local" http://localhost/

# NodePort  
curl http://localhost:30080/
```

### Manual Kubernetes
```bash
kind create cluster --name hello-cluster
# Install nginx-ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s

# Deploy application
docker build -t nginx_hello-nginx:latest .
kind load docker-image nginx_hello-nginx:latest --name hello-cluster
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/k8s-deployment.yaml
kubectl apply -f k8s/ingress.yaml
kubectl wait --for=condition=ready pod -l app=nginx-hello --timeout=60s
```

## Endpoints

- `/` - Main page
- `/health` - Health check (returns "OK")



## Common Commands

```bash
# Development
make dev / make dev-stop
make dev-prod / make dev-prod-stop  
make test / make clean

# Kubernetes
make k8s-status
kubectl get pods -l app=nginx-hello
kubectl scale deployment nginx-hello --replicas=3

# Helm
make helm-deploy / make helm-deploy-prod
make helm-status / make helm-destroy

# Configuration  
make k8s-config-local / make k8s-config-prod

# Testing
curl -H "Host: site-r1.local" http://localhost/
curl -H "Host: site-r1.local" http://localhost/health
```

## Troubleshooting

- **Port busy**: `make clean`
- **Pod not ready**: `make k8s-status`  
- **Image not found**: `make k8s-load`
- **Ingress not working**: Check `kubectl get ingress` and ensure nginx-ingress controller is running
- **502 Bad Gateway**: Verify service endpoints with `kubectl get endpoints nginx-hello-service`

## Architecture

See `docs/k8s-sequence.puml` for complete flow diagram.

