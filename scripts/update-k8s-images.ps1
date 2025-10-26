# Update Kubernetes manifests with your ECR images (PowerShell)
# Usage: .\update-k8s-images.ps1 <ACCOUNT_ID> <REGION>

param(
    [Parameter(Mandatory=$true)]
    [string]$AccountId,
    [Parameter(Mandatory=$true)]
    [string]$Region
)

$ErrorActionPreference = "Stop"

Write-Host "Updating Kubernetes manifests with ECR image URIs..."

# Update toxicity-svc deployment
(Get-Content k8s/10-toxicity.yaml) `
    -replace '<ACCOUNT_ID>', $AccountId `
    -replace '<REGION>', $Region | Set-Content k8s/10-toxicity.yaml

# Update telegram-bot-svc deployment
(Get-Content k8s/20-telegram-bot.yaml) `
    -replace '<ACCOUNT_ID>', $AccountId `
    -replace '<REGION>', $Region | Set-Content k8s/20-telegram-bot.yaml

Write-Host "Kubernetes manifests updated!" -ForegroundColor Green
Write-Host "Remember to update k8s/01-config-secrets.yaml with your BOT_TOKEN and MOD_CHAT_ID" -ForegroundColor Yellow
