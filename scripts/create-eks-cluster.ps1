# Create EKS cluster for Telegram moderator (PowerShell)
# Usage: .\create-eks-cluster.ps1 <REGION> [-Profile <AWS_PROFILE>]

param(
    [Parameter(Mandatory=$true)]
    [string]$Region,
    [Parameter(Mandatory=$false)]
    [string]$Profile = "default"
)

$ErrorActionPreference = "Stop"

Write-Host "Using AWS Profile: $Profile" -ForegroundColor Cyan
Write-Host "Creating EKS cluster 'tg-moderator' in region $Region..."
eksctl create cluster `
  --name tg-moderator `
  --region $Region `
  --nodes 2 `
  --node-type t3.large `
  --managed `
  --profile $Profile

Write-Host "EKS cluster created successfully!" -ForegroundColor Green
Write-Host "Run the following to configure kubectl:"
Write-Host "  aws eks update-kubeconfig --region $Region --name tg-moderator" -ForegroundColor Cyan
