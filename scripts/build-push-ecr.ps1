# Build and push Docker images to ECR (PowerShell)
# Usage: .\build-push-ecr.ps1 <ACCOUNT_ID> <REGION> [-Profile <AWS_PROFILE>]

param(
    [Parameter(Mandatory=$true)]
    [string]$AccountId,
    [Parameter(Mandatory=$true)]
    [string]$Region,
    [Parameter(Mandatory=$false)]
    [string]$Profile = "default"
)

$ErrorActionPreference = "Stop"

Write-Host "Using AWS Profile: $Profile" -ForegroundColor Cyan

Write-Host "Creating ECR repositories..."
aws ecr create-repository --repository-name toxicity-svc --region $Region --profile $Profile 2>$null
aws ecr create-repository --repository-name telegram-bot-svc --region $Region --profile $Profile 2>$null

Write-Host "Logging in to ECR..."
aws ecr get-login-password --region $Region --profile $Profile | docker login --username AWS --password-stdin "$AccountId.dkr.ecr.$Region.amazonaws.com"

Write-Host "Building and pushing toxicity-svc..."
docker build -t toxicity-svc:latest services/toxicity-svc
docker tag toxicity-svc:latest "$AccountId.dkr.ecr.$Region.amazonaws.com/toxicity-svc:latest"
docker push "$AccountId.dkr.ecr.$Region.amazonaws.com/toxicity-svc:latest"

Write-Host "Building and pushing telegram-bot-svc..."
docker build -t telegram-bot-svc:latest services/telegram-bot-svc
docker tag telegram-bot-svc:latest "$AccountId.dkr.ecr.$Region.amazonaws.com/telegram-bot-svc:latest"
docker push "$AccountId.dkr.ecr.$Region.amazonaws.com/telegram-bot-svc:latest"

Write-Host "All images pushed successfully!" -ForegroundColor Green
