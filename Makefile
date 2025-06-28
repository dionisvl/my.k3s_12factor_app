.PHONY: help dev test clean deploy

IMAGE_NAME ?= nginx_hello-nginx
IMAGE_TAG ?= latest
CLUSTER_NAME ?= hello-cluster

BLUE := \033[36m
GREEN := \033[32m
RESET := \033[0m

help:
	@echo "$(BLUE)Available commands:$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BLUE)%-15s$(RESET) %s\n", $$1, $$2}'

dev: ## Start development environment
	@echo "$(GREEN)Starting development...$(RESET)"
	docker compose up -d

dev-stop: ## Stop development environment
	docker compose down

dev-logs: ## Show logs
	docker compose logs -f

build: ## Build Docker image
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

test: test-build test-run ## Run all tests

test-build: ## Test build
	@echo "$(GREEN)Testing build...$(RESET)"
	docker build -t $(IMAGE_NAME):test .

test-run: ## Test runtime
	@echo "$(GREEN)Testing runtime...$(RESET)"
	@docker rm -f nginx-test 2>/dev/null || true
	docker run -d --name nginx-test -p 8080:8080 $(IMAGE_NAME):$(IMAGE_TAG)
	@sleep 3
	@curl -f http://localhost:8080/ | grep -q "Hello World" && echo "$(GREEN)✅ Main page OK$(RESET)"
	@curl -f http://localhost:8080/health | grep -q "OK" && echo "$(GREEN)✅ Health check OK$(RESET)"
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

k8s-cluster: ## Create Kind cluster
	@kind get clusters | grep -q $(CLUSTER_NAME) || kind create cluster --name $(CLUSTER_NAME)

k8s-load: build ## Load image to cluster
	kind load docker-image $(IMAGE_NAME):$(IMAGE_TAG) --name $(CLUSTER_NAME)

k8s-deploy: k8s-load ## Deploy to Kubernetes
	@echo "$(GREEN)Deploying to Kubernetes...$(RESET)"
	kubectl apply -f k8s/configmap.yaml
	kubectl apply -f k8s/k8s-deployment.yaml

k8s-config-local: ## Switch to local config
	kubectl apply -f k8s/configmap.yaml
	kubectl rollout restart deployment nginx-hello

k8s-config-prod: ## Switch to production config
	kubectl apply -f k8s/configmap-prod.yaml
	kubectl rollout restart deployment nginx-hello

k8s-test: ## Test Kubernetes deployment
	kubectl wait --for=condition=ready pod -l app=nginx-hello --timeout=60s
	kubectl port-forward svc/nginx-hello-service 8082:8080 &
	@sleep 5
	@curl -f http://localhost:8082/ | grep -q "Hello World" && echo "$(GREEN)✅ K8s test OK$(RESET)"
	@pkill -f "kubectl port-forward" || true

k8s-status: ## Show status
	kubectl get pods -l app=nginx-hello
	kubectl get svc nginx-hello-service

k8s-destroy: ## Destroy cluster
	kubectl delete -f k8s/k8s-deployment.yaml 2>/dev/null || true
	kubectl delete -f k8s/configmap.yaml 2>/dev/null || true
	kind delete cluster --name $(CLUSTER_NAME) 2>/dev/null || true


clean: ## Clean up containers and images
	@docker rm -f nginx-test nginx-test-custom 2>/dev/null || true
	@docker rmi $(IMAGE_NAME):$(IMAGE_TAG) $(IMAGE_NAME):test 2>/dev/null || true

ci-test: test ## Run CI tests locally

deploy: k8s-cluster k8s-deploy k8s-test ## Full deployment pipeline

up: dev
down: dev-stop
status: k8s-status