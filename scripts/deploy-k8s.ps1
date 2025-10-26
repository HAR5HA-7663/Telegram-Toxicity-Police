# Deploy Kubernetes manifests to EKS (PowerShell)
# Usage: .\deploy-k8s.ps1 [-Profile <AWS_PROFILE>]

param(
    [Parameter(Mandatory=$false)]
    [string]$Profile = "default"
)

$ErrorActionPreference = "Stop"

# Note: kubectl uses the current context set by aws eks update-kubeconfig
# Make sure you've run: aws eks update-kubeconfig --region <REGION> --name tg-moderator --profile $Profile

Write-Host "Applying Kubernetes manifests..."
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-config-secrets.yaml
kubectl apply -f k8s/10-toxicity.yaml
kubectl apply -f k8s/20-telegram-bot.yaml
kubectl apply -f k8s/30-ingress.yaml
kubectl apply -f k8s/40-autoscaling.yaml

Write-Host ""
Write-Host "All manifests applied successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Check deployment status:" -ForegroundColor Cyan
Write-Host "  kubectl get pods -n telegram"
Write-Host ""
Write-Host "Get ingress URL:" -ForegroundColor Cyan
Write-Host "  kubectl get ingress telegram-ingress -n telegram"
