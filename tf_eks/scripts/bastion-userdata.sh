#!/bin/bash
set -euo pipefail

# -------------------------
# Template variables (injected by Terraform)
# -------------------------
AWS_REGION="${aws_region}"
CLUSTER_NAME="${cluster_name}"
JENKINS_ROLE_ARN="${jenkins_role_arn}"
JENKINS_ADMIN_SECRET_NAME="${jenkins_admin_secret_name}"

LOG_FILE="/var/log/bastion-setup.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Bastion Setup" | tee -a "$LOG_FILE"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# -------------------------
# DEBUG: Check variable substitution
# -------------------------
log "DEBUG: Checking variable substitution..."
log "DEBUG: AWS_REGION=$AWS_REGION"
log "DEBUG: CLUSTER_NAME=$CLUSTER_NAME"
log "DEBUG: JENKINS_ROLE_ARN=$JENKINS_ROLE_ARN"
log "DEBUG: JENKINS_ADMIN_SECRET_NAME=$JENKINS_ADMIN_SECRET_NAME"

# Also check if the variable is being passed correctly from Terraform
log "DEBUG: Checking if jenkins_role_arn is available in environment..."
env | grep -i jenkins >> "$LOG_FILE" || log "DEBUG: No jenkins-related environment variables found"
# -------------------------
# System update & deps
# -------------------------
log "Updating system and installing prerequisites..."
dnf -y update || true
dnf install -y unzip curl tar git jq || true

# -------------------------
# Install AWS CLI v2
# -------------------------
log "Installing AWS CLI v2..."
if ! command -v aws >/dev/null 2>&1; then
  tmpdir=$(mktemp -d)
  pushd "$tmpdir"
  curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  ./aws/install --update
  popd
  rm -rf "$tmpdir"
fi
log "aws CLI version: $(aws --version 2>&1 | tr -d '\n')"

# -------------------------
# Install kubectl (stable)
# -------------------------
log "Installing kubectl..."
for i in 1 2 3; do
  stable=$(curl -L -s https://dl.k8s.io/release/stable.txt || echo "")
  if [ -n "$stable" ]; then
    curl -sSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/$${stable}/bin/linux/amd64/kubectl" && break
  fi
  log "Retrying kubectl download ($i)..."
  sleep 5
done
chmod +x /usr/local/bin/kubectl
log "kubectl installed at $(which kubectl) ($(kubectl version --client  2>/dev/null || echo 'version unknown'))"

# -------------------------
# Install Helm
# -------------------------
log "Installing Helm..."
if ! command -v helm >/dev/null 2>&1; then
  for i in 1 2 3; do
    curl -fsSL -o /tmp/helm.tar.gz "https://get.helm.sh/helm-v3.15.0-linux-amd64.tar.gz" && break || log "Retry helm download ($i)"; sleep 5
  done
  tar -xzf /tmp/helm.tar.gz -C /tmp
  mv /tmp/linux-amd64/helm /usr/local/bin/helm
  chmod +x /usr/local/bin/helm
  rm -rf /tmp/helm.tar.gz /tmp/linux-amd64
fi
log "helm installed at $(which helm) ($(helm version --short 2>/dev/null || echo 'version unknown'))"

# -------------------------
# Prepare ec2-user home & kube config location
# -------------------------
log "Preparing ec2-user home and kubeconfig..."
mkdir -p /home/ec2-user/.kube
chown -R ec2-user:ec2-user /home/ec2-user

# Ensure /usr/local/bin is in ec2-user PATH for non-login shells
echo 'export PATH=/usr/local/bin:$PATH' >> /home/ec2-user/.bash_profile
chown ec2-user:ec2-user /home/ec2-user/.bash_profile

# -------------------------
# Wait & configure kubeconfig (retry until EKS API available)
# -------------------------
max_attempts=30
attempt=1
while [ $attempt -le $max_attempts ]; do
  log "Attempt $attempt/$max_attempts: running aws eks update-kubeconfig..."
  if runuser -l ec2-user -c "aws eks update-kubeconfig --region '$${AWS_REGION}' --name '$${CLUSTER_NAME}'" >/var/log/kubectl-config.log 2>&1; then
    log "✅ kubeconfig updated"
    if runuser -l ec2-user -c "kubectl get nodes --no-headers" >/dev/null 2>&1; then
      log "✅ EKS cluster is reachable"
      runuser -l ec2-user -c "kubectl get nodes" | tee -a "$LOG_FILE"
      break
    else
      log "kubectl connected but no nodes returned yet"
    fi
  else
    log "aws eks update-kubeconfig failed; check /var/log/kubectl-config.log"
  fi

  if [ $attempt -eq $max_attempts ]; then
    log "❌ Failed to configure kubeconfig after $max_attempts attempts"
  else
    log "Waiting 30s before retry..."
    sleep 30
  fi
  attempt=$((attempt+1))
done

# If kubeconfig still not configured, exit early (script error)
if ! runuser -l ec2-user -c "kubectl version " >/dev/null 2>&1; then
  log "❌ kubectl is still not functional. Checking kubectl status..."
  runuser -l ec2-user -c "kubectl version" >>"$LOG_FILE" 2>&1 || true
  log "❌ Exiting userdata with failure."
  exit 1
else
  log "✅ kubectl is functional, proceeding to StorageClass creation"
fi

# -------------------------
# Create default StorageClass
# -------------------------
# Wait until kubectl is ready
max_attempts=30
attempt=1
while [ $attempt -le $max_attempts ]; do
  if runuser -l ec2-user -c "kubectl get nodes" >/dev/null 2>&1; then
    log "✅ kubectl ready, proceeding to StorageClass creation"
    break
  fi
  log "Waiting for EKS API... ($attempt/$max_attempts)"
  sleep 20
  ((attempt++))
done

# Create default StorageClass for EBS CSI Driver
log "Creating default StorageClass for EBS CSI Driver..."
cat <<'SC' > /tmp/gp2-sc.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp2
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  type: gp2
  fsType: ext4
SC

max_sc_attempts=10
sc_attempt=1
while [ $sc_attempt -le $max_sc_attempts ]; do
# Ensure old gp2 SC (in-tree) is removed if exists
if runuser -l ec2-user -c "kubectl get storageclass gp2" >/dev/null 2>&1; then
  log "Legacy gp2 StorageClass detected — deleting old version before creating CSI-based one..."
  runuser -l ec2-user -c "kubectl delete storageclass gp2" >>/var/log/sc-apply.log 2>&1 || true
fi

# Apply CSI-based gp2 SC
if runuser -l ec2-user -c "kubectl apply -f /tmp/gp2-sc.yaml" >>/var/log/sc-apply.log 2>&1; then
    log "✅ StorageClass created successfully"
    break
  else
    log "❌ Failed to apply StorageClass (attempt $sc_attempt). Retrying in 30s..."
    sleep 30
  fi
  ((sc_attempt++))
done

# -------------------------
# Add aliases & completions (for ec2-user interactive sessions)
# -------------------------
log "Adding useful aliases and completion to /home/ec2-user/.bashrc..."
cat >> /home/ec2-user/.bashrc <<'BASHRC'

# Kubernetes aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kgd='kubectl get deployments'
alias kga='kubectl get all'

# Helm aliases
alias h='helm'
alias hls='helm list'
alias hla='helm list --all-namespaces'

# AWS region
export AWS_DEFAULT_REGION=$${AWS_REGION}

# Enable kubectl and helm completion if available
if command -v kubectl >/dev/null 2>&1; then
  source <(kubectl completion bash) 2>/dev/null || true
  complete -F __start_kubectl k 2>/dev/null || true
fi
if command -v helm >/dev/null 2>&1; then
  source <(helm completion bash) 2>/dev/null || true
  complete -F __start_helm h 2>/dev/null || true
fi
BASHRC

chown ec2-user:ec2-user /home/ec2-user/.bashrc

# -------------------------
# Prepare Jenkins Helm values file
# -------------------------
log "Writing jenkins-values.yaml..."
cat > /home/ec2-user/jenkins-values.yaml <<JENKINS_VALUES
controller:
  image:
    registry: "docker.io"
    repository: "jenkins/jenkins"
    tag: "2.528.1-jdk17"
  resources:
    requests:
      cpu: "50m"
      memory: "256Mi"
    limits:
      cpu: "2000m"
      memory: "4096Mi"
  JCasC:
    defaultConfig: true
    configScripts:
      welcome-message: |
        jenkins:
          systemMessage: Welcome to Jenkins on EKS!
  installPlugins:
    - kubernetes
    - workflow-aggregator
    - git
    - blueocean
    - configuration-as-code
    - docker-workflow
    - kubernetes-credentials-provider
    - aws-credentials
    - pipeline-aws
    - amazon-ecr
  serviceType: NodePort
  nodePort: 30080
  admin:
    existingSecret: ""
    userKey: jenkins-admin-user
    passwordKey: jenkins-admin-password
  persistence:
    enabled: true
    size: "20Gi"
    storageClass: "gp2"

agent:
  enabled: true
  resources:
    requests:
      cpu: "512m"
      memory: "512Mi"
    limits:
      cpu: "1"
      memory: "1024Mi"

serviceAccount:
  create: true
  name: jenkins
  annotations:
    eks.amazonaws.com/role-arn: ${jenkins_role_arn}

rbac:
  create: true
  readSecrets: true

networkPolicy:
  enabled: false
JENKINS_VALUES

chown ec2-user:ec2-user /home/ec2-user/jenkins-values.yaml

# -------------------------
# Install Jenkins with Helm (retry loop)
# -------------------------
log "Starting Jenkins Helm install (upgrade --install)..."

max_jenkins_attempts=10
jenkins_attempt=1
while [ $jenkins_attempt -le $max_jenkins_attempts ]; do
  log "Jenkins install attempt $jenkins_attempt/$max_jenkins_attempts"

  if runuser -l ec2-user -c "kubectl get nodes" >/dev/null 2>&1; then
    # Add repo & update
    runuser -l ec2-user -c "helm repo add jenkins https://charts.jenkins.io" >>/var/log/helm-jenkins.log 2>&1 || true
    runuser -l ec2-user -c "helm repo update" >>/var/log/helm-jenkins.log 2>&1 || true

    runuser -l ec2-user -c "kubectl create namespace jenkins" >/dev/null 2>&1 || log "jenkins namespace exists or could not be created"

    # Idempotent install/upgrade
    if runuser -l ec2-user -c "helm upgrade --install jenkins jenkins/jenkins -n jenkins -f /home/ec2-user/jenkins-values.yaml --wait --timeout 600s" >>/var/log/helm-jenkins.log 2>&1; then
      log "✅ Helm release installed/upgraded"

      # Wait for Jenkins controller pod to be ready
      log "Waiting for Jenkins controller pod to be Ready (timeout 600s)..."
      if runuser -l ec2-user -c "kubectl wait --for=condition=Ready pod -l app.kubernetes.io/component=jenkins-controller -n jenkins --timeout=600s" >>"$LOG_FILE" 2>&1; then
        log "✅ Jenkins controller pod Ready"
      else
        log "⚠️ Jenkins controller pod did not become Ready within timeout"
      fi

      # Create NodePort for agent port (idempotent apply)
      log "Ensuring agent NodePort service exists..."
      runuser -l ec2-user -c "kubectl apply -n jenkins -f -" <<'EOF' >>/var/log/jenkins-deploy.log 2>&1
apiVersion: v1
kind: Service
metadata:
  name: jenkins-agent
  namespace: jenkins
spec:
  type: NodePort
  ports:
  - name: agent
    port: 50000
    targetPort: 50000
    nodePort: 30050
  selector:
    app.kubernetes.io/component: jenkins-controller
    app.kubernetes.io/instance: jenkins
EOF

      # Fetch admin password and store in Secrets Manager
      log "Fetching Jenkins admin password..."
      sleep 10
      ADMIN_PW=$(runuser -l ec2-user -c "kubectl get secret --namespace jenkins jenkins -o jsonpath='{.data.jenkins-admin-password}' 2>/dev/null || true" | base64 --decode 2>/dev/null || true)
      if [ -n "$ADMIN_PW" ]; then
        log "Storing Jenkins admin password into AWS Secrets Manager as '$${JENKINS_ADMIN_SECRET_NAME}'..."
        # Try create, if exists then put
        if aws secretsmanager create-secret --name "$${JENKINS_ADMIN_SECRET_NAME}" --secret-string "$ADMIN_PW" --region "$${AWS_REGION}" >/dev/null 2>&1; then
          log "✅ Secret created"
        else
          # If create fails (exists), update value
          if aws secretsmanager put-secret-value --secret-id "$${JENKINS_ADMIN_SECRET_NAME}" --secret-string "$ADMIN_PW" --region "$${AWS_REGION}" >/dev/null 2>&1; then
            log "✅ Secret updated"
          else
            log "⚠️ Failed to store secret in Secrets Manager; check IAM permissions"
          fi
        fi
        # Save password to file for convenience (owner ec2-user)
        echo "$ADMIN_PW" > /home/ec2-user/jenkins-password.txt
        chown ec2-user:ec2-user /home/ec2-user/jenkins-password.txt
        chmod 600 /home/ec2-user/jenkins-password.txt
        log "✅ Jenkins admin password saved to /home/ec2-user/jenkins-password.txt"
      else
        log "⚠️ Could not fetch admin password yet (secret not present). Will retry if attempts remain."
      fi

      log "✅ Jenkins installation process finished (attempt $jenkins_attempt)."
      break
    else
      log "❌ Helm install/upgrade failed (check /var/log/helm-jenkins.log)"
    fi
  else
    log "kubectl not ready; skipping helm install this attempt"
  fi

  if [ $jenkins_attempt -lt $max_jenkins_attempts ]; then
    log "Waiting 60s before next Jenkins attempt..."
    sleep 60
  else
    log "❌ Reached maximum Jenkins install attempts ($max_jenkins_attempts)."
  fi
  jenkins_attempt=$((jenkins_attempt+1))
done

log "Bastion Setup Complete"
