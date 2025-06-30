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

dev:
	@echo "$(GREEN)Starting development...$(RESET)"
	docker compose up -d

dev-stop:
	docker compose down

dev-logs:
	docker compose logs -f

build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

test: test-build test-run

test-build:
	@echo "$(GREEN)Testing build...$(RESET)"
	docker build -t $(IMAGE_NAME):test .

test-run:
	@echo "$(GREEN)Testing runtime...$(RESET)"
	@docker rm -f nginx-test 2>/dev/null || true
	@docker run -d --name nginx-test -p 8080:8080 $(IMAGE_NAME):$(IMAGE_TAG)
	@sleep 5
	@curl -f http://localhost:8080/ | grep -q "Hello World" && echo "$(GREEN)✅ Main page OK$(RESET)"
	@curl -f http://localhost:8080/health | grep -q "OK" && echo "$(GREEN)✅ Health check OK$(RESET)"
	@docker stop nginx-test && docker rm nginx-test

test-custom-config:
	@echo "$(GREEN)Testing custom config...$(RESET)"
	@docker rm -f nginx-test-custom 2>/dev/null || true
	docker run -d --name nginx-test-custom -p 8081:8081 \
		-e NGINX_PORT=8081 -e NGINX_SERVER_NAME="test.example.com" \
		$(IMAGE_NAME):$(IMAGE_TAG)
	@sleep 3
	@curl -f http://localhost:8081/ | grep -q "Hello World" && echo "$(GREEN)✅ Custom config OK$(RESET)"
	@docker stop nginx-test-custom && docker rm nginx-test-custom

k8s-cluster: ## Create Kind cluster and install ingress controller
	@kind get clusters | grep -q $(CLUSTER_NAME) || kind create cluster --name $(CLUSTER_NAME)
	@echo "$(GREEN)Installing nginx-ingress controller...$(RESET)"
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	@echo "$(GREEN)Waiting for ingress controller to be ready...$(RESET)"
	@kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s

k8s-load: build
	kind load docker-image $(IMAGE_NAME):$(IMAGE_TAG) --name $(CLUSTER_NAME)

k8s-deploy: k8s-load
	@echo "$(GREEN)Deploying to Kubernetes...$(RESET)"
	kubectl apply -f k8s/configmap.yaml
	kubectl apply -f k8s/k8s-deployment.yaml
	kubectl apply -f k8s/ingress.yaml

helm-deploy: k8s-load ## Deploy using Helm (local environment)
	@echo "$(GREEN)Deploying with Helm (local)...$(RESET)"
	helm upgrade --install nginx-hello helm/nginx-hello/ --create-namespace --namespace default

helm-deploy-prod: k8s-load ## Deploy using Helm (production environment)
	@echo "$(GREEN)Deploying with Helm (production)...$(RESET)"
	helm upgrade --install nginx-hello helm/nginx-hello/ -f helm/nginx-hello/values-prod.yaml --create-namespace --namespace default

k8s-config-local:
	kubectl apply -f k8s/configmap.yaml
	kubectl rollout restart deployment nginx-hello

k8s-config-prod:
	kubectl apply -f k8s/configmap-prod.yaml
	kubectl rollout restart deployment nginx-hello

k8s-test:
	kubectl wait --for=condition=ready pod -l app=nginx-hello --timeout=60s
	@echo "Testing via Ingress at http://site-r1.local"
	@curl -H "Host: site-r1.local" http://localhost:80/ | grep -q "Hello World" && echo "$(GREEN)✅ Ingress test OK$(RESET)" || echo "$(GREEN)ℹ️  Ingress not ready, testing via port-forward$(RESET)"
	@kubectl port-forward svc/nginx-hello-service 8082:8080 & sleep 3; curl -f http://localhost:8082/ | grep -q "Hello World" && echo "$(GREEN)✅ Service test OK$(RESET)"; pkill -f "kubectl port-forward" || true

k8s-status:
	kubectl get pods -l app=nginx-hello
	kubectl get svc nginx-hello-service
	kubectl get ingress nginx-hello-ingress

k8s-destroy:
	kubectl delete -f k8s/ingress.yaml 2>/dev/null || true
	kubectl delete -f k8s/k8s-deployment.yaml 2>/dev/null || true
	kubectl delete -f k8s/configmap.yaml 2>/dev/null || true
	kind delete cluster --name $(CLUSTER_NAME) 2>/dev/null || true

helm-destroy:
	@echo "$(GREEN)Uninstalling Helm deployment...$(RESET)"
	helm uninstall nginx-hello 2>/dev/null || true

helm-status:
	@echo "$(GREEN)Helm status:$(RESET)"
	helm status nginx-hello 2>/dev/null || echo "No Helm deployment found"
	@echo "$(GREEN)Kubernetes resources:$(RESET)"
	kubectl get pods,svc,ingress -l app.kubernetes.io/name=nginx-hello 2>/dev/null || echo "No resources found"


clean:
	@docker rm -f nginx-test nginx-test-custom 2>/dev/null || true
	@docker rmi $(IMAGE_NAME):$(IMAGE_TAG) $(IMAGE_NAME):test 2>/dev/null || true

deploy: k8s-cluster k8s-deploy k8s-test

up: dev
down: dev-stop
status: k8s-status