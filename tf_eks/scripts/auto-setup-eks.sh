#!/bin/bash

# Auto-setup EKS Environment Script
# This script runs automatically after the bastion is created and scripts are copied

set -e

CLUSTER_NAME="ITI-GP-Cluster"
REGION="eu-north-1"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/eks-auto-setup.log
}

log "=== Starting Automatic EKS Setup ==="

# Wait for EKS cluster to be ready and then auto-configure
log "Waiting for EKS cluster to be ready..."
max_attempts=60
attempt=1

while [ $attempt -le $max_attempts ]; do
    log "Attempt $attempt/$max_attempts: Checking if EKS cluster is ready..."
    
    # Try to configure kubectl
    if runuser -l ec2-user -c "aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME" 2>/var/log/kubectl-config.log; then
        log "kubectl configured successfully"
        
        # Test if we can connect to the cluster
        if runuser -l ec2-user -c "kubectl get nodes" >/var/log/kubectl-test.log 2>&1; then
            log "✅ EKS cluster is ready and accessible!"
            
            # Show cluster info
            log "Cluster nodes:"
            runuser -l ec2-user -c "kubectl get nodes" | tee -a /var/log/eks-auto-setup.log
            
            # Auto-deploy Jenkins
            log "🚀 Starting automatic Jenkins deployment..."
            if runuser -l ec2-user -c "cd /home/ec2-user/eks-scripts && ./deploy-jenkins.sh" >> /var/log/eks-auto-setup.log 2>&1; then
                log "✅ Jenkins deployed successfully!"
            else
                log "❌ Jenkins deployment failed. Check logs for details."
            fi
            
            # Create completion marker
            echo "$(date): EKS setup and Jenkins deployment completed successfully" > /home/ec2-user/eks-setup-complete.log
            chown ec2-user:ec2-user /home/ec2-user/eks-setup-complete.log
            
            log "=== EKS Environment Setup Complete ==="
            log "Scripts available in: /home/ec2-user/eks-scripts"
            log "Use './eks-helper.sh help' for available commands"
            break
        else
            log "kubectl configured but cluster not yet accessible..."
        fi
    else
        log "Failed to configure kubectl, cluster might not be ready yet..."
    fi
    
    if [ $attempt -eq $max_attempts ]; then
        log "❌ Failed to access EKS cluster after $max_attempts attempts"
        log "You can manually run: /home/ec2-user/eks-scripts/eks-helper.sh setup"
        echo "$(date): EKS setup failed - manual intervention required" > /home/ec2-user/eks-setup-failed.log
        chown ec2-user:ec2-user /home/ec2-user/eks-setup-failed.log
    else
        log "Waiting 30 seconds before next attempt..."
        sleep 30
    fi
    
    ((attempt++))
done

log "=== Auto EKS Setup Complete ==="