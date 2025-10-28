# Install AWS Load Balancer Controller for EKS
# This is required for Ingress resources to create ALB

$ErrorActionPreference = "Stop"
$AWS_REGION = "us-east-2"
$CLUSTER_NAME = "tg-moderator"
$ACCOUNT_ID = "898919247265"

Write-Host "`n🚀 Installing AWS Load Balancer Controller" -ForegroundColor Green
Write-Host "Cluster: $CLUSTER_NAME ($AWS_REGION)`n" -ForegroundColor Cyan

# Step 1: Download IAM policy
Write-Host "📥 Step 1/5: Downloading IAM policy..." -ForegroundColor Yellow
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json" -OutFile "iam-policy.json"
Write-Host "   ✅ Policy downloaded`n" -ForegroundColor Green

# Step 2: Create IAM policy (may already exist)
Write-Host "📝 Step 2/5: Creating/verifying IAM policy..." -ForegroundColor Yellow
try {
    aws iam create-policy `
        --policy-name AWSLoadBalancerControllerIAMPolicy `
        --policy-document file://iam-policy.json `
        --profile har5ha 2>&1 | Out-Null
    Write-Host "   ✅ IAM policy created`n" -ForegroundColor Green
} catch {
    Write-Host "   ℹ️  IAM policy already exists (OK)`n" -ForegroundColor Cyan
}

# Step 3: Create IAM service account with eksctl
Write-Host "🔐 Step 3/5: Creating IAM service account..." -ForegroundColor Yellow
Write-Host "   (This may take 1-2 minutes)" -ForegroundColor Gray

eksctl create iamserviceaccount `
    --cluster=$CLUSTER_NAME `
    --namespace=kube-system `
    --name=aws-load-balancer-controller `
    --attach-policy-arn=arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy `
    --override-existing-serviceaccounts `
    --region=$AWS_REGION `
    --profile=har5ha `
    --approve

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ Service account created`n" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Service account may already exist, continuing...`n" -ForegroundColor Yellow
}

# Step 4: Add Helm repo
Write-Host "📦 Step 4/5: Setting up Helm repository..." -ForegroundColor Yellow
helm repo add eks https://aws.github.io/eks-charts 2>&1 | Out-Null
helm repo update 2>&1 | Out-Null
Write-Host "   ✅ Helm repo ready`n" -ForegroundColor Green

# Step 5: Install ALB controller
Write-Host "🎯 Step 5/5: Installing AWS Load Balancer Controller..." -ForegroundColor Yellow
Write-Host "   (This may take 1-2 minutes)" -ForegroundColor Gray

# Update kubeconfig first
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME --profile har5ha 2>&1 | Out-Null

# Check if already installed
$existing = helm list -n kube-system 2>$null | Select-String "aws-load-balancer-controller"
if ($existing) {
    Write-Host "`n   ℹ️  ALB Controller already installed, upgrading..." -ForegroundColor Cyan
    helm upgrade aws-load-balancer-controller eks/aws-load-balancer-controller `
        -n kube-system `
        --set clusterName=$CLUSTER_NAME `
        --set serviceAccount.create=false `
        --set serviceAccount.name=aws-load-balancer-controller
} else {
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller `
        -n kube-system `
        --set clusterName=$CLUSTER_NAME `
        --set serviceAccount.create=false `
        --set serviceAccount.name=aws-load-balancer-controller
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n   ✅ AWS Load Balancer Controller installed!`n" -ForegroundColor Green
    
    Write-Host "⏳ Waiting for controller pods to be ready (30s)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    
    Write-Host "`n📊 Controller Status:" -ForegroundColor Cyan
    kubectl get deployment -n kube-system aws-load-balancer-controller
    
    Write-Host "`n✅ Installation complete!" -ForegroundColor Green
    Write-Host "`nℹ️  The Load Balancer will be created automatically when you deploy the ingress." -ForegroundColor Cyan
    Write-Host "   Check status with: kubectl get ingress -n telegram`n" -ForegroundColor Gray
} else {
    Write-Host "`n❌ Installation failed. Check errors above.`n" -ForegroundColor Red
    exit 1
}

# Cleanup
Remove-Item -Path "iam-policy.json" -ErrorAction SilentlyContinue
