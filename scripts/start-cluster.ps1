#!/usr/bin/env pwsh
# Start the EKS node group back up

Write-Host "`n🚀 Starting EKS Node Group...`n" -ForegroundColor Green
Write-Host "This will take 2-3 minutes`n" -ForegroundColor Cyan

$env:AWS_PROFILE='har5ha'

aws eks update-nodegroup-config `
  --cluster-name tg-moderator `
  --nodegroup-name ng-t3medium-v2 `
  --scaling-config minSize=1,maxSize=1,desiredSize=1 `
  --region us-east-2

Write-Host "`n⏳ Waiting for node to start (2 minutes)...`n" -ForegroundColor Cyan
Start-Sleep -Seconds 120

kubectl get nodes
kubectl get pods -n telegram

Write-Host "`n✅ Cluster is running!" -ForegroundColor Green
Write-Host "`nWebhook URL: https://bot.har5ha.in/webhook" -ForegroundColor Cyan
Write-Host "Bot should be ready in ~1 minute`n" -ForegroundColor Gray
