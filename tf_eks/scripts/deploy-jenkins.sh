#!/bin/bash

# Jenkins Deployment Script for Private EKS Cluster
# Run this script from the bastion host after connecting to EKS

set -e

echo "🚀 Deploying Jenkins to EKS cluster..."

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ kubectl not configured. Please run:"
    echo "aws eks update-kubeconfig --region eu-north-1 --name ITI-GP-Cluster"
    exit 1
fi

echo "✅ kubectl configured successfully"

# Create Jenkins namespace
echo "📁 Creating jenkins namespace..."
kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -

# Create service account for Jenkins
echo "👤 Creating Jenkins service account..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
  namespace: jenkins
EOF

# Create cluster role binding for Jenkins
echo "🔐 Creating Jenkins cluster role binding..."
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: jenkins
  namespace: jenkins
EOF

# Add Jenkins Helm repository
echo "📦 Adding Jenkins Helm repository..."
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Create Jenkins values file
echo "📝 Creating Jenkins Helm values..."
cat <<EOF > /tmp/jenkins-values.yaml
controller:
  serviceType: LoadBalancer
  adminUser: "admin"
  adminPassword: "admin123"  # Change this in production
  resources:
    requests:
      cpu: "500m"
      memory: "512Mi"
    limits:
      cpu: "2000m"
      memory: "2048Mi"
  serviceAccount:
    create: false
    name: jenkins
persistence:
  enabled: true
  size: "10Gi"
serviceAccount:
  create: false
  name: jenkins
EOF

# Install Jenkins using Helm
echo "🛠️ Installing Jenkins with Helm..."
helm upgrade --install jenkins jenkins/jenkins \
  --namespace jenkins \
  --values /tmp/jenkins-values.yaml \
  --wait

echo "✅ Jenkins deployment completed!"

# Get Jenkins URL
echo "🌐 Getting Jenkins URL..."
echo "Waiting for LoadBalancer to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=jenkins-controller -n jenkins --timeout=300s

JENKINS_URL=$(kubectl get svc jenkins -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
if [ -z "$JENKINS_URL" ]; then
    echo "⏳ LoadBalancer still provisioning. Get the URL later with:"
    echo "kubectl get svc jenkins -n jenkins"
else
    echo "🎉 Jenkins is available at: http://$JENKINS_URL"
fi

echo "🔑 Jenkins credentials:"
echo "Username: admin"
echo "Password: admin123"

# Clean up temporary files
rm -f /tmp/jenkins-values.yaml

echo "✅ Jenkins deployment script completed!"