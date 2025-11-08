#!/bin/bash

# EKS Management Helper Script
# Run this script from the bastion host

set -e

CLUSTER_NAME="ITI-GP-Cluster"
REGION="eu-north-1"

function show_help() {
    echo "EKS Management Helper Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  setup           - Configure kubectl for EKS cluster"
    echo "  jenkins         - Deploy Jenkins to the cluster"
    echo "  status          - Show cluster and Jenkins status"
    echo "  url             - Get Jenkins URL"
    echo "  pods            - List all pods"
    echo "  services        - List all services"
    echo "  nodes           - Show cluster nodes"
    echo "  logs            - Show Jenkins logs"
    echo "  uninstall       - Remove Jenkins from cluster"
    echo "  help            - Show this help message"
    echo ""
}

function setup_kubectl() {
    echo "🔧 Configuring kubectl for EKS cluster..."
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
    echo "✅ kubectl configured successfully"
    kubectl cluster-info
}

function deploy_jenkins() {
    echo "🚀 Deploying Jenkins..."
    ./deploy-jenkins.sh
}

function show_status() {
    echo "📊 Cluster Status:"
    kubectl get nodes
    echo ""
    echo "📊 Jenkins Status:"
    kubectl get all -n jenkins 2>/dev/null || echo "Jenkins not deployed yet"
}

function get_jenkins_url() {
    echo "🌐 Getting Jenkins URL..."
    JENKINS_URL=$(kubectl get svc jenkins -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -z "$JENKINS_URL" ]; then
        echo "❌ Jenkins service not found or LoadBalancer not ready"
        echo "Check status with: kubectl get svc jenkins -n jenkins"
    else
        echo "🎉 Jenkins URL: http://$JENKINS_URL"
        echo "🔑 Username: admin"
        echo "🔑 Password: admin123"
    fi
}

function list_pods() {
    echo "📦 All Pods:"
    kubectl get pods --all-namespaces
}

function list_services() {
    echo "🌐 All Services:"
    kubectl get services --all-namespaces
}

function show_nodes() {
    echo "🖥️ Cluster Nodes:"
    kubectl get nodes -o wide
}

function show_logs() {
    echo "📋 Jenkins Controller Logs:"
    kubectl logs -n jenkins -l app.kubernetes.io/component=jenkins-controller --tail=50
}

function uninstall_jenkins() {
    echo "🗑️ Uninstalling Jenkins..."
    read -p "Are you sure you want to remove Jenkins? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        helm uninstall jenkins -n jenkins
        kubectl delete namespace jenkins
        echo "✅ Jenkins removed successfully"
    else
        echo "❌ Operation cancelled"
    fi
}

# Main script logic
case "${1:-help}" in
    setup)
        setup_kubectl
        ;;
    jenkins)
        deploy_jenkins
        ;;
    status)
        show_status
        ;;
    url)
        get_jenkins_url
        ;;
    pods)
        list_pods
        ;;
    services)
        list_services
        ;;
    nodes)
        show_nodes
        ;;
    logs)
        show_logs
        ;;
    uninstall)
        uninstall_jenkins
        ;;
    help|*)
        show_help
        ;;
esac