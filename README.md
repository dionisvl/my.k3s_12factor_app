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

| Variable                   | Local                            | Production                                    |
|----------------------------|----------------------------------|-----------------------------------------------|
| `NGINX_PORT`               | `8080`                           | `8080`                                        |
| `NGINX_WORKER_CONNECTIONS` | `1024`                           | `2048`                                        |
| `DOMAIN_1`                 | `localhost`                      | `example.com`                                |
| `DOMAIN_2`                 | `site-r1.local`                  | `www.example.com`                            |
| `DOMAIN_3`                 | `site-r2.local`                  | `api.example.com` (optional)                |
| `ENVIRONMENT`              | `local`                          | `production`                                  |

### Environment Files

```bash
# .env (local development)
NGINX_PORT=8080
NGINX_WORKER_CONNECTIONS=1024
NGINX_APP_VERSION=v1.0.2
ENVIRONMENT=local

# Simple domain configuration
DOMAIN_1=localhost
DOMAIN_2=site-r1.local
DOMAIN_3=site-r2.local

# .env.prod (production)  
NGINX_PORT=8080
NGINX_WORKER_CONNECTIONS=2048
NGINX_APP_VERSION=v1.0.2
ENVIRONMENT=production

# Simple domain configuration
DOMAIN_1=example.com
DOMAIN_2=www.example.com
```

### Customizing Domains

To customize domains for your deployment:

**For Docker Compose:**
```bash
# Local development
DOMAIN_1=my-local.dev DOMAIN_2=api-local.dev make dev

# Production
cp .env.prod.example .env.prod
# Edit .env.prod with your domains
make dev-prod
```

**For Kubernetes:**
```bash
# Using environment variables
export DOMAIN_1="my-app.com" DOMAIN_2="www.my-app.com"
make k8s-deploy

# Using Helm with custom values
helm upgrade --install nginx-hello helm/nginx-hello/ \
  --set domain1=my-app.com \
  --set domain2=www.my-app.com
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

### Access Methods

**Via Ingress (recommended):**
```bash
# Local development
curl -H "Host: site-r1.local" http://localhost/
curl -H "Host: site-r2.local" http://localhost/

# Production  
curl https://example.com/
```

**Via NodePort (testing only):**
```bash
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
make dev / make dev-stop         # Local development environment  
make dev-prod / make dev-prod-stop # Production-like environment
make test / make clean

# Kubernetes  
make k8s-status           # Show pods, service, ingress
kubectl get pods -l app=nginx-hello
kubectl get ingress nginx-hello-ingress
kubectl scale deployment nginx-hello --replicas=3

# Helm
make helm-deploy          # Deploy with Helm (local)
make helm-deploy-prod     # Deploy with Helm (production)
make helm-status          # Show Helm deployment status
make helm-destroy         # Uninstall Helm deployment

# Configuration
make k8s-config-local     # localhost domains
make k8s-config-prod      # production domains

# Testing Ingress
curl -H "Host: site-r1.local" http://localhost/
curl -H "Host: site-r2.local" http://localhost/health
```

## Troubleshooting

- **Port busy**: `make clean`
- **Pod not ready**: `make k8s-status`  
- **Image not found**: `make k8s-load`
- **Ingress not working**: Check `kubectl get ingress` and ensure nginx-ingress controller is running
- **502 Bad Gateway**: Verify service endpoints with `kubectl get endpoints nginx-hello-service`

## Architecture

See `docs/k8s-sequence.puml` for complete flow diagram.

