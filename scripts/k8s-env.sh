#!/bin/bash

# Script for isolating Kubernetes environment per project
# Usage: source scripts/k8s-env.sh

PROJECT_NAME="hello-world"
PROJECT_KUBECONFIG="$PWD/kubeconfig-${PROJECT_NAME}.yaml"
export KUBECONFIG="$PROJECT_KUBECONFIG"

export DOMAIN_1="localhost"
export DOMAIN_2="site-r1.local"
export DOMAIN_3="site-r2.local"
export NGINX_PORT="8080"
export IMAGE_NAME="nginx_hello-nginx"
export IMAGE_TAG="latest"
export CLUSTER_NAME="${PROJECT_NAME}-cluster"

# Function for quick status check
k8s_status() {
    echo "Current kubeconfig: $KUBECONFIG"
    kubectl config get-contexts 2>/dev/null || echo "No contexts available"
}

k8s_reset() {
    unset KUBECONFIG
    echo "🔄 Reset to system kubeconfig (~/.kube/config)"
}

export -f k8s_status k8s_reset

echo "🚀 Kubernetes environment activated for project: $PROJECT_NAME"
echo "📁 Using kubeconfig: $PROJECT_KUBECONFIG"
echo "🔧 Current context: $(kubectl config current-context 2>/dev/null || echo 'none')"