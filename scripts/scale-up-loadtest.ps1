# Scale cluster for load testing (500-1500 RPS)
# WARNING: This will increase costs to ~$500/month while running
# Run this BEFORE load testing, then scale down after

Write-Host "`n🚀 Scaling cluster for LOAD TESTING (500-1500 RPS)...`n" -ForegroundColor Yellow
Write-Host "⚠️  WARNING: This will cost ~$500/month while active!`n" -ForegroundColor Red

# Switch to correct AWS profile
$env:AWS_PROFILE = 'har5ha'

# 1. Scale node group to 5 nodes (t3.medium)
Write-Host "📦 Scaling node group to 5 nodes (t3.medium)..." -ForegroundColor Cyan
aws eks update-nodegroup-config `
  --cluster-name tg-moderator `
  --nodegroup-name ng-t3medium-v2 `
  --region us-east-2 `
  --scaling-config minSize=5,maxSize=5,desiredSize=5 2>&1

Write-Host "`n⏳ Waiting 3 minutes for nodes to come up...`n" -ForegroundColor Cyan
Start-Sleep -Seconds 180

# 2. Scale bot deployments to 10 replicas each
Write-Host "`n📈 Scaling bot deployments to 10 replicas..." -ForegroundColor Cyan
kubectl scale deployment telegram-bot-svc --replicas=10 -n telegram
kubectl scale deployment toxicity-svc --replicas=10 -n telegram

Start-Sleep -Seconds 45

# 3. Show status
Write-Host "`n✅ CLUSTER STATUS:`n" -ForegroundColor Green
kubectl get nodes
Write-Host "`n"
kubectl get pods -n telegram

Write-Host "`n🎯 Cluster ready for load testing!`n" -ForegroundColor Green
Write-Host "Run: k6 run load-test.js`n" -ForegroundColor Cyan
Write-Host "Cost: ~$500/month while active" -ForegroundColor Yellow
Write-Host "After testing: Run .\scripts\scale-down.ps1`n" -ForegroundColor Yellow
