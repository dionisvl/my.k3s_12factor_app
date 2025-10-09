#!/bin/bash
# Isolate kubectl to project-specific kubeconfig
# Usage: source scripts/k8s-env.sh

PROJECT_NAME="hello-world"
PROJECT_KUBECONFIG="$PWD/kubeconfig-${PROJECT_NAME}.yaml"
export KUBECONFIG="$PROJECT_KUBECONFIG"

# Quick status check
k8s_status() {
    echo "Current kubeconfig: $KUBECONFIG"
    kubectl config get-contexts 2>/dev/null || echo "No contexts available"
}

# Reset to system kubeconfig
k8s_reset() {
    unset KUBECONFIG
    echo "🔄 Reset to system kubeconfig (~/.kube/config)"
}

export -f k8s_status k8s_reset

echo "🚀 Kubernetes environment activated: $PROJECT_NAME"
echo "📁 Using kubeconfig: $PROJECT_KUBECONFIG"
echo "🔧 Context: $(kubectl config current-context 2>/dev/null || echo 'none')"