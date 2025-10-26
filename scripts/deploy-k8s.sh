#!/bin/bash
# Deploy Kubernetes manifests to EKS
# Usage: ./deploy-k8s.sh

set -e

echo "Applying Kubernetes manifests..."
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-config-secrets.yaml
kubectl apply -f k8s/10-toxicity.yaml
kubectl apply -f k8s/20-telegram-bot.yaml
kubectl apply -f k8s/30-ingress.yaml
kubectl apply -f k8s/40-autoscaling.yaml

echo ""
echo "All manifests applied successfully!"
echo ""
echo "Check deployment status:"
echo "  kubectl get pods -n telegram"
echo ""
echo "Get ingress URL:"
echo "  kubectl get ingress telegram-ingress -n telegram"
