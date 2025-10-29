#!/usr/bin/env pwsh
# Check cluster status and cost

$env:AWS_PROFILE='har5ha'

Write-Host "`n💰 Cluster Cost Status`n" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Gray

$status = aws eks describe-nodegroup `
  --cluster-name tg-moderator `
  --nodegroup-name ng-t3medium-v2 `
  --region us-east-2 `
  --query 'nodegroup.{desired:scalingConfig.desiredSize,status:status}' `
  --output json | ConvertFrom-Json

Write-Host "`nNode Group:" -ForegroundColor Yellow
Write-Host "  Desired Nodes: $($status.desired)" -ForegroundColor White
Write-Host "  Status: $($status.status)" -ForegroundColor White

if ($status.desired -eq 0) {
    Write-Host "`n✅ COST: `$0/month" -ForegroundColor Green
    Write-Host "`nTo start: .\scripts\start-cluster.ps1`n" -ForegroundColor Gray
} else {
    Write-Host "`n💰 COST: ~`$30/month (t3.medium)" -ForegroundColor Yellow
    
    kubectl get pods -n telegram 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n📊 Bot Status:" -ForegroundColor Cyan
        kubectl get pods -n telegram
    }
    
    Write-Host "`nTo stop: .\scripts\stop-cluster.ps1`n" -ForegroundColor Gray
}
