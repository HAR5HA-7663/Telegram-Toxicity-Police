#!/bin/bash
# Grant IAM user access to EKS cluster
# Run this via GitHub Actions or from a machine with cluster admin access

set -e

AWS_REGION="us-east-2"
CLUSTER_NAME="tg-moderator"
IAM_USER_ARN="arn:aws:iam::898919247265:user/HAR5HA"

echo "🔐 Granting kubectl access to IAM user: $IAM_USER_ARN"

# Update kubeconfig
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Check if eksctl is available (preferred method for EKS 1.32+)
if command -v eksctl &> /dev/null; then
    echo "Using eksctl to grant access..."
    
    # Create access entry for the user (EKS 1.32+ method)
    eksctl create accessentry \
        --cluster $CLUSTER_NAME \
        --region $AWS_REGION \
        --principal-arn $IAM_USER_ARN \
        --type STANDARD \
        --username HAR5HA || echo "Access entry may already exist"
    
    # Associate cluster admin policy
    eksctl associate accesspolicy \
        --cluster $CLUSTER_NAME \
        --region $AWS_REGION \
        --principal-arn $IAM_USER_ARN \
        --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
        --access-scope type=cluster || echo "Policy may already be associated"
    
    echo "✅ Access granted via EKS Access Entries"
else
    echo "❌ eksctl not found. Using AWS CLI method..."
    
    # Alternative: Use AWS CLI to create access entry
    aws eks create-access-entry \
        --cluster-name $CLUSTER_NAME \
        --region $AWS_REGION \
        --principal-arn $IAM_USER_ARN \
        --type STANDARD \
        --username HAR5HA 2>/dev/null || echo "Access entry may already exist"
    
    # Associate admin policy
    aws eks associate-access-policy \
        --cluster-name $CLUSTER_NAME \
        --region $AWS_REGION \
        --principal-arn $IAM_USER_ARN \
        --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
        --access-scope type=cluster 2>/dev/null || echo "Policy may already be associated"
    
    echo "✅ Access granted via AWS CLI"
fi

echo ""
echo "🎉 Done! You can now use kubectl locally:"
echo "   kubectl get nodes"
echo "   kubectl get pods -n telegram"
