#!/bin/bash

BASTION_IP="13.51.48.212"
KEY_PATH="./keys/ITI-GP-Cluster_bastion_key.pem"

echo "🔍 Checking bastion setup progress..."
echo "================================================"

# Check if we can connect
echo "📡 Testing SSH connection..."
if ssh -i $KEY_PATH -o ConnectTimeout=10 -o StrictHostKeyChecking=no ec2-user@$BASTION_IP "echo 'SSH connection successful'" 2>/dev/null; then
    echo "✅ SSH connection working"
else
    echo "❌ SSH connection failed - bastion may still be initializing"
    exit 1
fi

echo ""
echo "📋 Checking setup logs..."
ssh -i $KEY_PATH -o StrictHostKeyChecking=no ec2-user@$BASTION_IP "tail -20 /var/log/bastion-setup.log" 2>/dev/null || echo "Setup log not available yet"

echo ""
echo "🔧 Checking kubectl status..."
ssh -i $KEY_PATH -o StrictHostKeyChecking=no ec2-user@$BASTION_IP "kubectl version --client --short 2>/dev/null && echo '✅ kubectl installed'" || echo "❌ kubectl not ready"

echo ""
echo "⚙️  Checking helm status..."
ssh -i $KEY_PATH -o StrictHostKeyChecking=no ec2-user@$BASTION_IP "helm version --short 2>/dev/null && echo '✅ helm installed'" || echo "❌ helm not ready"

echo ""
echo "🚀 Checking Jenkins installation status..."
ssh -i $KEY_PATH -o StrictHostKeyChecking=no ec2-user@$BASTION_IP "kubectl get pods -n jenkins 2>/dev/null" || echo "❌ Jenkins not installed yet"

echo ""
echo "🌐 Checking for Jenkins URL..."
ssh -i $KEY_PATH -o StrictHostKeyChecking=no ec2-user@$BASTION_IP "cat /home/ec2-user/jenkins-url.txt 2>/dev/null && echo ':8080'" || echo "❌ Jenkins URL not ready yet"

echo ""
echo "🔑 Checking for Jenkins admin password..."
ssh -i $KEY_PATH -o StrictHostKeyChecking=no ec2-user@$BASTION_IP "test -f /home/ec2-user/jenkins-password.txt && echo '✅ Admin password saved' || echo '❌ Admin password not ready yet'"

echo ""
echo "================================================"
echo "💡 Tips:"
echo "   - Setup may take 5-10 minutes to complete"
echo "   - Re-run this script to check progress"
echo "   - Jenkins installation happens after kubectl setup"