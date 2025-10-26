<#
.SYNOPSIS
    Complete production deployment meeting ALL requirements
.DESCRIPTION
    Deploys with HPA, PDB, circuit breaking, timeouts, monitoring
#>

param(
    [string]$BotToken = $(Read-Host "Enter your Telegram Bot Token"),
    [string]$ModChatId = $(Read-Host "Enter your Moderator Chat ID"),
    [string]$Region = "us-east-2",
    [string]$Profile = "har5ha"
)

$accountId = (aws sts get-caller-identity --profile $Profile --query Account --output text)

Write-Host "=== COMPLETE PRODUCTION DEPLOYMENT ===" -ForegroundColor Cyan
Write-Host "Implementing ALL requirements:" -ForegroundColor White
Write-Host "  - HPA rules with multiple metrics" -ForegroundColor Green
Write-Host "  - Pod Disruption Budget" -ForegroundColor Green
Write-Host "  - Circuit breaking" -ForegroundColor Green
Write-Host "  - Timeouts (5s)" -ForegroundColor Green
Write-Host "  - Right-sizing (CPU/memory limits)" -ForegroundColor Green
Write-Host "  - Spot instances" -ForegroundColor Green
Write-Host "  - Prometheus monitoring" -ForegroundColor Green
Write-Host ""

# Step 1: Create cluster with spot instances (COST CONTROL)
Write-Host "[1/8] Creating EKS cluster with Spot instances..." -ForegroundColor Green
$clusterExists = aws eks describe-cluster --name tg-moderator --region $Region --profile $Profile 2>$null
if (-not $clusterExists) {
    eksctl create cluster `
        --name tg-moderator `
        --region $Region `
        --profile $Profile `
        --node-type t3.medium `
        --nodes 2 `
        --nodes-min 1 `
        --nodes-max 5 `
        --managed `
        --spot `
        --instance-types t3.medium,t3.large
} else {
    Write-Host "  Cluster already exists, skipping..." -ForegroundColor Yellow
}

aws eks update-kubeconfig --region $Region --name tg-moderator --profile $Profile

# Step 2: Install metrics-server (REQUIRED for HPA)
Write-Host "[2/8] Installing metrics-server..." -ForegroundColor Green
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Step 3: Install Prometheus (REQUIRED for monitoring)
Write-Host "[3/8] Installing Prometheus..." -ForegroundColor Green
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
$prometheusExists = helm list -n monitoring --filter prometheus -q 2>$null
if (-not $prometheusExists) {
    helm install prometheus prometheus-community/kube-prometheus-stack `
        -n monitoring `
        --create-namespace `
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
} else {
    Write-Host "  Prometheus already installed, skipping..." -ForegroundColor Yellow
}

# Step 4: Install ALB Controller
Write-Host "[4/8] Installing AWS Load Balancer Controller..." -ForegroundColor Green
if (-not (Test-Path "iam-policy.json")) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json" -OutFile "iam-policy.json"
}

aws iam create-policy `
  --policy-name AWSLoadBalancerControllerIAMPolicy `
  --policy-document file://iam-policy.json `
  --profile $Profile 2>$null

eksctl create iamserviceaccount `
  --cluster=tg-moderator `
  --namespace=kube-system `
  --name=aws-load-balancer-controller `
  --attach-policy-arn=arn:aws:iam::${accountId}:policy/AWSLoadBalancerControllerIAMPolicy `
  --override-existing-serviceaccounts `
  --region=$Region `
  --profile=$Profile `
  --approve 2>$null

helm repo add eks https://aws.github.io/eks-charts
helm repo update
$albExists = helm list -n kube-system --filter aws-load-balancer-controller -q 2>$null
if (-not $albExists) {
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller `
      -n kube-system `
      --set clusterName=tg-moderator `
      --set serviceAccount.create=false `
      --set serviceAccount.name=aws-load-balancer-controller
} else {
    Write-Host "  ALB Controller already installed, skipping..." -ForegroundColor Yellow
}

# Step 5: Update secrets
Write-Host "[5/8] Updating configuration..." -ForegroundColor Green
(Get-Content k8s/01-config-secrets.yaml) `
    -replace '<YOUR_TELEGRAM_BOT_TOKEN>', $BotToken `
    -replace '<YOUR_MODERATOR_CHAT_ID>', $ModChatId | Set-Content k8s/01-config-secrets.yaml

# Step 6: Build and push images
Write-Host "[6/8] Building and pushing Docker images..." -ForegroundColor Green
.\scripts\build-push-ecr.ps1 $accountId $Region -Profile $Profile

# Step 7: Deploy all Kubernetes resources
Write-Host "[7/8] Deploying to Kubernetes..." -ForegroundColor Green
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-config-secrets.yaml
kubectl apply -f k8s/10-toxicity.yaml
kubectl apply -f k8s/20-telegram-bot.yaml
kubectl apply -f k8s/30-ingress.yaml
kubectl apply -f k8s/40-autoscaling.yaml
kubectl apply -f k8s/50-monitoring.yaml

# Step 8: Wait for ALB and setup webhook
Write-Host "[8/8] Waiting for Load Balancer..." -ForegroundColor Green
$maxAttempts = 30
$attempt = 0
$albUrl = $null

while ($attempt -lt $maxAttempts) {
    $albUrl = kubectl get ingress telegram-ingress -n telegram -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null
    if ($albUrl) { break }
    Write-Host "  Waiting... ($attempt/$maxAttempts)" -ForegroundColor Yellow
    Start-Sleep -Seconds 15
    $attempt++
}

if ($albUrl) {
    .\scripts\setup-webhook.ps1 $BotToken "http://$albUrl/webhook"
    
    Write-Host "`n=== DEPLOYMENT COMPLETE ===" -ForegroundColor Green
    Write-Host "Webhook URL: http://$albUrl/webhook" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Implemented features:" -ForegroundColor Yellow
    Write-Host "  [x] HPA with CPU+Memory metrics" -ForegroundColor Green
    Write-Host "  [x] Pod Disruption Budget" -ForegroundColor Green
    Write-Host "  [x] Circuit breaker (5 failures, 30s recovery)" -ForegroundColor Green
    Write-Host "  [x] Timeouts (5 seconds)" -ForegroundColor Green
    Write-Host "  [x] Right-sized resources" -ForegroundColor Green
    Write-Host "  [x] Spot instances (70% cost savings)" -ForegroundColor Green
    Write-Host "  [x] Prometheus monitoring" -ForegroundColor Green
    Write-Host ""
    Write-Host "Monitoring commands:" -ForegroundColor Cyan
    Write-Host "  kubectl get hpa -n telegram -w" -ForegroundColor White
    Write-Host "  kubectl get pdb -n telegram" -ForegroundColor White
    Write-Host "  kubectl get pods -n telegram" -ForegroundColor White
    Write-Host ""
    Write-Host "Access Prometheus:" -ForegroundColor Cyan
    Write-Host "  kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090" -ForegroundColor White
    Write-Host "  Open: http://localhost:9090" -ForegroundColor White
    Write-Host ""
    Write-Host "Access Grafana:" -ForegroundColor Cyan
    Write-Host "  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80" -ForegroundColor White
    Write-Host "  Open: http://localhost:3000 (admin/prom-operator)" -ForegroundColor White
} else {
    Write-Host "Load balancer not ready. Check manually:" -ForegroundColor Yellow
    Write-Host "  kubectl get ingress telegram-ingress -n telegram -w" -ForegroundColor White
}
