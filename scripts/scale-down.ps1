# Scale down after load testing
# Returns cluster to minimal state (1 node, 1 replica each)

Write-Host "`n⬇️  Scaling cluster back to minimal state...`n" -ForegroundColor Yellow

# Switch to correct AWS profile
$env:AWS_PROFILE = 'har5ha'

# 1. Scale deployments to 1 replica
Write-Host "📉 Scaling deployments to 1 replica..." -ForegroundColor Cyan
kubectl scale deployment telegram-bot-svc --replicas=1 -n telegram
kubectl scale deployment toxicity-svc --replicas=1 -n telegram

Start-Sleep -Seconds 15

# 2. Scale node group to 1 node
Write-Host "`n📦 Scaling node group to 1 node..." -ForegroundColor Cyan
aws eks update-nodegroup-config `
  --cluster-name tg-moderator `
  --nodegroup-name ng-t3medium-v2 `
  --region us-east-2 `
  --scaling-config minSize=0,maxSize=1,desiredSize=1 2>&1

Write-Host "`n⏳ Waiting 2 minutes for nodes to drain...`n" -ForegroundColor Cyan
Start-Sleep -Seconds 120

# 3. Show final status
Write-Host "`n✅ CLUSTER STATUS:`n" -ForegroundColor Green
kubectl get nodes
Write-Host "`n"
kubectl get pods -n telegram

Write-Host "`n💰 Cost reduced to ~$103/month`n" -ForegroundColor Green
