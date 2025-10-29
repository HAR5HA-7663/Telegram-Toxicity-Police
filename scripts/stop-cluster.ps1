#!/usr/bin/env pwsh
# Stop the EKS node group completely (saves ~$30/month)

Write-Host "`n🛑 Stopping EKS Node Group...`n" -ForegroundColor Yellow
Write-Host "This will scale the node to 0 (saves ~`$30/month)" -ForegroundColor Cyan
Write-Host "Takes 2-3 minutes to start back up`n" -ForegroundColor Gray

$env:AWS_PROFILE='har5ha'

aws eks update-nodegroup-config `
  --cluster-name tg-moderator `
  --nodegroup-name ng-t3medium-v2 `
  --scaling-config minSize=0,maxSize=1,desiredSize=0 `
  --region us-east-2

Write-Host "`n✅ Node group scaling to 0..." -ForegroundColor Green
Write-Host "To start again: ./scripts/start-cluster.ps1`n" -ForegroundColor Gray
