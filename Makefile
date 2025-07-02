.PHONY: help dev test clean deploy

IMAGE_NAME ?= nginx_hello-nginx
IMAGE_TAG ?= latest

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

test: test-build test-run

test-build: ## Test Docker build
	@echo "$(GREEN)Testing build...$(RESET)"
	docker build -t $(IMAGE_NAME):test .

test-run: ## Test application runtime
	@echo "$(GREEN)Testing runtime...$(RESET)"
	@docker rm -f nginx-test 2>/dev/null || true
	@docker run -d --name nginx-test -p 8081:8080 $(IMAGE_NAME):$(IMAGE_TAG)
	@sleep 5
	@curl -f http://localhost:8081/ | grep -q "Hello World" && echo "$(GREEN)✅ Main page OK$(RESET)"
	@curl -f http://localhost:8081/health | grep -q "OK" && echo "$(GREEN)✅ Health check OK$(RESET)"
	@docker stop nginx-test && docker rm nginx-test

test-custom-config: ## Test custom configuration
	@echo "$(GREEN)Testing custom config...$(RESET)"
	@docker rm -f nginx-test-custom 2>/dev/null || true
	docker run -d --name nginx-test-custom -p 8081:8081 \
		-e NGINX_PORT=8081 -e NGINX_SERVER_NAME="test.example.com" \
		$(IMAGE_NAME):$(IMAGE_TAG)
	@sleep 3
	@curl -f http://localhost:8081/ | grep -q "Hello World" && echo "$(GREEN)✅ Custom config OK$(RESET)"
	@docker stop nginx-test-custom && docker rm nginx-test-custom

# k3d (Recommended - Isolated)
k3d-cluster-isolated: ## Create isolated k3d cluster for this project
	@echo "$(GREEN)Creating isolated k3d cluster...$(RESET)"
	k3d cluster create hello-world-cluster --api-port 127.0.0.1:6443 --servers 1 --agents 0 --port 8080:80@loadbalancer --k3s-arg '--tls-san=127.0.0.1@server:*' --k3s-arg '--tls-san=localhost@server:*' --kubeconfig-update-default=false --kubeconfig-switch-context=false
	@k3d kubeconfig get hello-world-cluster > kubeconfig-hello-world.yaml
	@echo "$(GREEN)Isolated cluster created!$(RESET)"
	@echo "$(BLUE)To use: source scripts/k8s-env.sh$(RESET)"

k3d-load-isolated: build ## Load Docker image into isolated cluster
	k3d image import $(IMAGE_NAME):$(IMAGE_TAG) -c hello-world-cluster

k3d-deploy-isolated: k3d-load-isolated ## Deploy to isolated cluster
	@echo "$(GREEN)Deploying to isolated k3d cluster...$(RESET)"
	DOMAIN_1="localhost" DOMAIN_2="site-r1.local" DOMAIN_3="site-r2.local" envsubst < k3s/configmap.yaml | kubectl --kubeconfig=./kubeconfig-hello-world.yaml apply -f -
	kubectl --kubeconfig=./kubeconfig-hello-world.yaml apply -f k3s/k8s-deployment.yaml
	DOMAIN_1="localhost" DOMAIN_2="site-r1.local" DOMAIN_3="site-r2.local" envsubst < k3s/ingress.yaml | kubectl --kubeconfig=./kubeconfig-hello-world.yaml apply -f -

k3d-test-isolated: ## Test isolated cluster deployment
	kubectl --kubeconfig=./kubeconfig-hello-world.yaml wait --for=condition=ready pod -l app=nginx-hello --timeout=60s
	@echo "$(GREEN)Testing LoadBalancer at http://localhost:8080$(RESET)"
	@curl -f http://localhost:8080/ | grep -q "Hello World" && echo "$(GREEN)✅ LoadBalancer test OK$(RESET)"
	@curl -f http://localhost:8080/health | grep -q "OK" && echo "$(GREEN)✅ Health check OK$(RESET)"

k3d-status-isolated: ## Show isolated cluster status
	kubectl --kubeconfig=./kubeconfig-hello-world.yaml get pods -l app=nginx-hello
	kubectl --kubeconfig=./kubeconfig-hello-world.yaml get svc nginx-hello-service
	kubectl --kubeconfig=./kubeconfig-hello-world.yaml get ingress

k3d-destroy-isolated: ## Destroy isolated cluster and clean up
	@echo "$(GREEN)Destroying isolated cluster...$(RESET)"
	k3d cluster delete hello-world-cluster 2>/dev/null || true
	@rm -f kubeconfig-hello-world.yaml
	@echo "$(GREEN)Cleanup complete!$(RESET)"

# k3d (Legacy - Uses system kubeconfig)
k3d-cluster: ## Create k3d cluster (uses system kubeconfig)
	@echo "$(GREEN)Creating k3d cluster...$(RESET)"
	k3d cluster create hello-cluster --api-port 127.0.0.1:6443 --servers 1 --agents 0 --port 8080:80@loadbalancer --k3s-arg '--tls-san=127.0.0.1@server:*' --k3s-arg '--tls-san=localhost@server:*'
	@echo "$(GREEN)Waiting for cluster to be ready...$(RESET)"
	kubectl wait --for=condition=ready nodes --all --timeout=60s
	@echo "$(GREEN)Cluster ready! Traefik ingress is enabled by default.$(RESET)"

k3d-load: build ## Load Docker image into k3d cluster
	k3d image import $(IMAGE_NAME):$(IMAGE_TAG) -c hello-cluster

k3d-deploy: k3d-load ## Deploy to k3d cluster
	@echo "$(GREEN)Deploying to k3d...$(RESET)"
	DOMAIN_1="localhost" DOMAIN_2="site-r1.local" DOMAIN_3="site-r2.local" envsubst < k3s/configmap.yaml | kubectl apply -f -
	kubectl apply -f k3s/k8s-deployment.yaml
	DOMAIN_1="localhost" DOMAIN_2="site-r1.local" DOMAIN_3="site-r2.local" envsubst < k3s/ingress.yaml | kubectl apply -f -

k3d-destroy: ## Destroy k3d cluster
	@echo "$(GREEN)Destroying k3d cluster...$(RESET)"
	k3d cluster delete hello-cluster 2>/dev/null || true

# Helm
helm-deploy-isolated: k3d-load-isolated ## Deploy using Helm to isolated cluster
	@echo "$(GREEN)Deploying with Helm to isolated cluster...$(RESET)"
	helm --kubeconfig=./kubeconfig-hello-world.yaml upgrade --install nginx-hello helm/nginx-hello/ --create-namespace --namespace default

helm-deploy: k3d-load ## Deploy using Helm (legacy)
	@echo "$(GREEN)Deploying with Helm...$(RESET)"
	helm upgrade --install nginx-hello helm/nginx-hello/ --create-namespace --namespace default

helm-deploy-prod: k3d-load ## Deploy using Helm (production)
	@echo "$(GREEN)Deploying with Helm (production)...$(RESET)"
	helm upgrade --install nginx-hello helm/nginx-hello/ -f helm/nginx-hello/values-prod.yaml --create-namespace --namespace default

helm-destroy: ## Uninstall Helm deployment
	@echo "$(GREEN)Uninstalling Helm deployment...$(RESET)"
	helm uninstall nginx-hello 2>/dev/null || true

helm-status: ## Show Helm deployment status
	@echo "$(GREEN)Helm status:$(RESET)"
	helm status nginx-hello 2>/dev/null || echo "No Helm deployment found"
	@echo "$(GREEN)Kubernetes resources:$(RESET)"
	kubectl get pods,svc,ingress -l app.kubernetes.io/name=nginx-hello 2>/dev/null || echo "No resources found"

# Cleanup
clean: ## Clean up Docker containers and images
	@docker rm -f nginx-test nginx-test-custom 2>/dev/null || true
	@docker rmi $(IMAGE_NAME):$(IMAGE_TAG) $(IMAGE_NAME):test 2>/dev/null || true

# Quick workflows
deploy-isolated: k3d-cluster-isolated k3d-deploy-isolated k3d-test-isolated ## Full isolated deployment workflow
deploy-legacy: k3d-cluster k3d-deploy ## Legacy deployment workflow
