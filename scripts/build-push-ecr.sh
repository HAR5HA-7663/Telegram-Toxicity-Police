#!/bin/bash
# Build and push Docker images to ECR
# Usage: ./build-push-ecr.sh <ACCOUNT_ID> <REGION>

set -e

ACCOUNT_ID=$1
REGION=$2

if [ -z "$ACCOUNT_ID" ] || [ -z "$REGION" ]; then
  echo "Usage: ./build-push-ecr.sh <ACCOUNT_ID> <REGION>"
  exit 1
fi

echo "Creating ECR repositories..."
aws ecr create-repository --repository-name toxicity-svc --region $REGION || true
aws ecr create-repository --repository-name telegram-bot-svc --region $REGION || true

echo "Logging in to ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

echo "Building and pushing toxicity-svc..."
docker build -t toxicity-svc:latest services/toxicity-svc
docker tag toxicity-svc:latest $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/toxicity-svc:latest
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/toxicity-svc:latest

echo "Building and pushing telegram-bot-svc..."
docker build -t telegram-bot-svc:latest services/telegram-bot-svc
docker tag telegram-bot-svc:latest $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/telegram-bot-svc:latest
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/telegram-bot-svc:latest

echo "All images pushed successfully!"
