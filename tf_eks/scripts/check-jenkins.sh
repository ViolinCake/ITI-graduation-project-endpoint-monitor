#!/bin/bash

# Jenkins Installation Check Script
# This script provides comprehensive checks for Jenkins installation status

echo "🔍 Jenkins Installation Status Check"
echo "====================================="
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 1. Check if kubectl is configured
echo "1️⃣  Checking kubectl configuration..."
if command_exists kubectl; then
    echo "✅ kubectl is installed"
    if kubectl cluster-info >/dev/null 2>&1; then
        echo "✅ kubectl is configured and can connect to cluster"
    else
        echo "❌ kubectl is installed but not configured or cluster unreachable"
        echo "   Run: aws eks update-kubeconfig --region eu-north-1 --name ITI-GP-Cluster"
    fi
else
    echo "❌ kubectl is not installed"
fi
echo ""

# 2. Check if Helm is installed
echo "2️⃣  Checking Helm installation..."
if command_exists helm; then
    echo "✅ Helm is installed ($(helm version --short))"
else
    echo "❌ Helm is not installed"
fi
echo ""

# 3. Check Jenkins namespace
echo "3️⃣  Checking Jenkins namespace..."
if kubectl get namespace jenkins >/dev/null 2>&1; then
    echo "✅ Jenkins namespace exists"
else
    echo "❌ Jenkins namespace does not exist"
fi
echo ""

# 4. Check Jenkins Helm installation
echo "4️⃣  Checking Jenkins Helm deployment..."
if helm list -n jenkins | grep -q jenkins; then
    echo "✅ Jenkins is installed via Helm"
    helm list -n jenkins
else
    echo "❌ Jenkins is not installed via Helm"
fi
echo ""

# 5. Check Jenkins pods
echo "5️⃣  Checking Jenkins pods..."
if kubectl get pods -n jenkins >/dev/null 2>&1; then
    echo "📦 Jenkins pods status:"
    kubectl get pods -n jenkins
else
    echo "❌ No Jenkins pods found"
fi
echo ""

# 6. Check Jenkins service
echo "6️⃣  Checking Jenkins service..."
if kubectl get svc jenkins -n jenkins >/dev/null 2>&1; then
    echo "🌐 Jenkins service status:"
    kubectl get svc jenkins -n jenkins
    
    # Get Jenkins URL
    JENKINS_URL=$(kubectl get svc jenkins -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -n "$JENKINS_URL" ]; then
        echo ""
        echo "🎉 Jenkins URL: http://$JENKINS_URL"
        echo "🔑 Username: admin"
        echo "🔑 Password: admin123"
    else
        echo "⏳ LoadBalancer is still being provisioned..."
    fi
else
    echo "❌ Jenkins service not found"
fi
echo ""

# 7. Check setup completion markers
echo "7️⃣  Checking setup completion markers..."
if [ -f /home/ec2-user/eks-setup-complete.log ]; then
    echo "✅ EKS setup completed:"
    cat /home/ec2-user/eks-setup-complete.log
else
    echo "❌ EKS setup completion marker not found"
fi

if [ -f /home/ec2-user/jenkins-deployment.log ]; then
    echo "✅ Jenkins deployment log:"
    cat /home/ec2-user/jenkins-deployment.log
else
    echo "❌ Jenkins deployment log not found"
fi
echo ""

# 8. Check setup logs
echo "8️⃣  Checking setup logs..."
if [ -f /var/log/eks-setup.log ]; then
    echo "📋 Recent EKS setup log entries:"
    tail -10 /var/log/eks-setup.log
else
    echo "❌ EKS setup log not found"
fi
echo ""

# 9. Check helper scripts
echo "9️⃣  Checking helper scripts..."
if [ -d /home/ec2-user/eks-scripts ]; then
    echo "✅ EKS scripts directory exists:"
    ls -la /home/ec2-user/eks-scripts/
    
    if [ -x /home/ec2-user/eks-scripts/eks-helper.sh ]; then
        echo ""
        echo "💡 You can use helper commands:"
        echo "   cd /home/ec2-user/eks-scripts"
        echo "   ./eks-helper.sh status    # Check cluster and Jenkins status"
        echo "   ./eks-helper.sh url       # Get Jenkins URL"
        echo "   ./eks-helper.sh help      # Show all available commands"
    fi
else
    echo "❌ EKS scripts directory not found"
fi
echo ""

echo "🔍 Jenkins Installation Check Complete!"
echo "======================================"