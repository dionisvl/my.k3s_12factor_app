.PHONY: help dev test clean deploy

IMAGE_NAME ?= nginx_hello-nginx
GIT_COMMIT := $(shell git rev-parse --short HEAD)
IMAGE_TAG ?= $(GIT_COMMIT)

# K3d configuration
K3D_API_PORT ?= 6443
K3D_LB_PORT ?= 8080
K3S_VERSION ?= v1.31.5-k3s1

BLUE := \033[36m
GREEN := \033[32m
RESET := \033[0m

help: ## Show available commands
	@echo "$(BLUE)Available commands:$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BLUE)%-20s$(RESET) %s\n", $$1, $$2}'

up:
	docker compose up -d

down:
	docker compose down

build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

k3d-cluster-isolated: ## Create isolated k3d cluster for this project
	@echo "$(GREEN)Creating isolated k3d cluster...$(RESET)"
	k3d cluster create hello-world-cluster --image rancher/k3s:$(K3S_VERSION) --api-port 127.0.0.1:$(K3D_API_PORT) --servers 1 --agents 0 --port $(K3D_LB_PORT):80@loadbalancer --k3s-arg '--tls-san=127.0.0.1@server:*' --k3s-arg '--tls-san=localhost@server:*' --kubeconfig-update-default=false --kubeconfig-switch-context=false
	@k3d kubeconfig get hello-world-cluster > kubeconfig-hello-world.yaml
	@echo "$(GREEN)Isolated cluster created!$(RESET)"
	@echo "$(BLUE)To use: source scripts/k8s-env.sh$(RESET)"

k3d-load-isolated: build ## Load Docker image into isolated cluster
	k3d image import $(IMAGE_NAME):$(IMAGE_TAG) -c hello-world-cluster

k3d-test-isolated: ## Test isolated cluster deployment
	kubectl --kubeconfig=./kubeconfig-hello-world.yaml wait --for=condition=ready pod -l app=nginx-hello --timeout=60s
	@echo "$(GREEN)Testing pods directly...$(RESET)"
	@POD_NAME=$$(kubectl --kubeconfig=./kubeconfig-hello-world.yaml get pod -l app=nginx-hello -o jsonpath='{.items[0].metadata.name}'); \
	kubectl --kubeconfig=./kubeconfig-hello-world.yaml exec $$POD_NAME -- curl -f http://localhost:8080/ | grep -q "Hello World" && echo "$(GREEN)✅ Main page OK$(RESET)"
	@POD_NAME=$$(kubectl --kubeconfig=./kubeconfig-hello-world.yaml get pod -l app=nginx-hello -o jsonpath='{.items[0].metadata.name}'); \
	kubectl --kubeconfig=./kubeconfig-hello-world.yaml exec $$POD_NAME -- curl -f http://localhost:8080/health | grep -q "OK" && echo "$(GREEN)✅ Health check OK$(RESET)"

k3d-status-isolated: ## Show isolated cluster status
	kubectl --kubeconfig=./kubeconfig-hello-world.yaml get pods -l app=nginx-hello
	kubectl --kubeconfig=./kubeconfig-hello-world.yaml get svc nginx-hello-service
	kubectl --kubeconfig=./kubeconfig-hello-world.yaml get ingress

k3d-local-access: ## Open local access via port-forward (for dev)
	@echo "$(GREEN)Starting port-forward to nginx service...$(RESET)"
	@echo "$(BLUE)Open http://localhost:8080/ in browser$(RESET)"
	@echo "$(BLUE)Press Ctrl+C to stop$(RESET)"
	kubectl --kubeconfig=./kubeconfig-hello-world.yaml port-forward svc/nginx-hello-service 8080:8080

k3d-destroy-isolated: ## Destroy isolated cluster and clean up
	@echo "$(GREEN)Destroying isolated cluster...$(RESET)"
	k3d cluster delete hello-world-cluster 2>/dev/null || true
	@rm -f kubeconfig-hello-world.yaml
	@echo "$(GREEN)Cleanup complete!$(RESET)"

k3d-load: build ## Load Docker image into k3d cluster
	k3d image import $(IMAGE_NAME):$(IMAGE_TAG) -c hello-cluster

k3d-destroy: ## Destroy k3d cluster
	@echo "$(GREEN)Destroying k3d cluster...$(RESET)"
	k3d cluster delete hello-cluster 2>/dev/null || true

# Helm values file detection
HELM_VALUES_BASE := helm/nginx-hello/values.yaml
HELM_VALUES_DEV := helm/nginx-hello/values.dev.yaml
HELM_VALUES_PROD := helm/nginx-hello/values.prod.yaml
HELM_VALUES_LOCAL := helm/nginx-hello/values.local.yaml

# Build helm flags with local override if exists
define helm_flags
	-f $(HELM_VALUES_BASE) -f $(1) $(if $(wildcard $(HELM_VALUES_LOCAL)),-f $(HELM_VALUES_LOCAL),)
endef

# Helm
helm-deploy-isolated: k3d-load-isolated ## Deploy using Helm to isolated cluster (dev + local if exists)
	@echo "$(GREEN)Deploying with Helm to isolated cluster...$(RESET)"
	@if [ -f "$(HELM_VALUES_LOCAL)" ]; then echo "$(BLUE)Using local overrides from values.local.yaml$(RESET)"; fi
	helm --kubeconfig=./kubeconfig-hello-world.yaml upgrade --install nginx-hello helm/nginx-hello/ $(call helm_flags,$(HELM_VALUES_DEV)) --set image.tag=$(IMAGE_TAG) --create-namespace --namespace default

helm-deploy: k3d-load ## Deploy using Helm (dev + local if exists)
	@echo "$(GREEN)Deploying with Helm...$(RESET)"
	@if [ -f "$(HELM_VALUES_LOCAL)" ]; then echo "$(BLUE)Using local overrides from values.local.yaml$(RESET)"; fi
	helm upgrade --install nginx-hello helm/nginx-hello/ $(call helm_flags,$(HELM_VALUES_DEV)) --set image.tag=$(IMAGE_TAG) --create-namespace --namespace default

helm-deploy-prod: k3d-load ## Deploy using Helm (production + local if exists)
	@echo "$(GREEN)Deploying with Helm (production)...$(RESET)"
	@if [ -f "$(HELM_VALUES_LOCAL)" ]; then echo "$(BLUE)Using local overrides from values.local.yaml$(RESET)"; fi
	helm upgrade --install nginx-hello helm/nginx-hello/ $(call helm_flags,$(HELM_VALUES_PROD)) --set image.tag=$(IMAGE_TAG) --create-namespace --namespace default

helm-destroy: ## Uninstall Helm deployment
	@echo "$(GREEN)Uninstalling Helm deployment...$(RESET)"
	helm uninstall nginx-hello 2>/dev/null || true

helm-status: ## Show Helm deployment status
	@echo "$(GREEN)Helm status:$(RESET)"
	helm status nginx-hello 2>/dev/null || echo "No Helm deployment found"
	@echo "$(GREEN)Kubernetes resources:$(RESET)"
	kubectl get pods,svc,ingress -l app.kubernetes.io/name=nginx-hello 2>/dev/null || echo "No resources found"

clean: ## Clean up Docker containers and images
	@docker rm -f nginx-test nginx-test-custom 2>/dev/null || true
	@docker rmi $(IMAGE_NAME):$(IMAGE_TAG) $(IMAGE_NAME):test 2>/dev/null || true

# Quick workflows
deploy-isolated: k3d-cluster-isolated helm-deploy-isolated k3d-test-isolated ## Full isolated deployment workflow
