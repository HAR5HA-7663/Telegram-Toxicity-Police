#!/bin/bash
# Create EKS cluster for Telegram moderator
# Usage: ./create-eks-cluster.sh <REGION>

set -e

REGION=$1

if [ -z "$REGION" ]; then
  echo "Usage: ./create-eks-cluster.sh <REGION>"
  exit 1
fi

echo "Creating EKS cluster 'tg-moderator' in region $REGION..."
eksctl create cluster \
  --name tg-moderator \
  --region $REGION \
  --nodes 2 \
  --node-type t3.large \
  --managed

echo "EKS cluster created successfully!"
echo "Run the following to configure kubectl:"
echo "  aws eks update-kubeconfig --region $REGION --name tg-moderator"
