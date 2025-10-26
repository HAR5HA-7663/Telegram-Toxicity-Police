#!/bin/bash
# Update Kubernetes manifests with your ECR images
# Usage: ./update-k8s-images.sh <ACCOUNT_ID> <REGION>

set -e

ACCOUNT_ID=$1
REGION=$2

if [ -z "$ACCOUNT_ID" ] || [ -z "$REGION" ]; then
  echo "Usage: ./update-k8s-images.sh <ACCOUNT_ID> <REGION>"
  exit 1
fi

echo "Updating Kubernetes manifests with ECR image URIs..."

# Update toxicity-svc deployment
sed -i "s|<ACCOUNT_ID>|$ACCOUNT_ID|g" k8s/10-toxicity.yaml
sed -i "s|<REGION>|$REGION|g" k8s/10-toxicity.yaml

# Update telegram-bot-svc deployment
sed -i "s|<ACCOUNT_ID>|$ACCOUNT_ID|g" k8s/20-telegram-bot.yaml
sed -i "s|<REGION>|$REGION|g" k8s/20-telegram-bot.yaml

echo "Kubernetes manifests updated!"
echo "Remember to update k8s/01-config-secrets.yaml with your BOT_TOKEN and MOD_CHAT_ID"
