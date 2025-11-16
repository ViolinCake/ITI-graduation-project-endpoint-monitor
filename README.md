# ITI Graduation Project: Endpoint Monitor with Full GitOps Pipeline on AWS

## Project Overview  

A production-ready **Endpoint Monitoring System** deployed using a complete GitOps pipeline on AWS. This project demonstrates modern DevOps practices including Infrastructure as Code (IaC), continuous integration/deployment, container orchestration, and secure secrets management.

The system monitors web endpoints (URLs, APIs) for availability and performance, recording their status with a comprehensive monitoring dashboard.

### Key Features

#### Application Features

- Real-time endpoint health monitoring
- Performance metrics collection
- Dark UI dashboard for status visualization
- Historical data tracking and analysis
- Redis caching for optimized performance
- MySQL persistence for monitoring history

#### DevOps & Infrastructure Features

- Automated AWS infrastructure provisioning with Terraform
- Kubernetes orchestration on Amazon EKS
- CI/CD pipeline with Jenkins
- GitOps deployment with ArgoCD
- Automated image updates with Argo Image Updater
- Secure secrets management with External Secrets Operator

---

### Component Architecture

| Component | Technology | Purpose |
| --- | --- | --- |
| **Application** | Node.js + Express | Backend API server for endpoint monitoring |
| **Frontend** | HTML/CSS/JavaScript | Dark theme dashboard for visualization |
| **Database** | AWS RDS (MySQL) | Stores monitoring history and configurations |
| **Cache** | Redis on Kubernetes | Accelerates API responses |
| **Container Platform** | AWS EKS | Kubernetes orchestration |
| **CI Pipeline** | Jenkins on EKS | Build, test, and package automation with Kaniko |
| **CD Pipeline** | Argo CD | GitOps-based deployment |
| **Auto-sync** | Argo Image Updater | Automatic image updates from ECR |
| **Infrastructure** | Terraform | IaC for AWS resources |
| **Secrets** | External Secrets Operator + AWS Secrets Manager | Secure credential management |
| **Registry** | AWS ECR | Container image storage |
| **Load Balancer** | AWS ALB | Multi-port routing (80, 3000, 8080) |

---

## Setup Instructions

### Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured (`aws configure`)
- Terraform >= 1.5.0
- kubectl >= 1.27.0
- Docker installed
- Git
- Node.js >= 16.x (for local development)

### Complete Setup Guide

#### Step 1: Clone the Repository

```bash
git clone https://github.com/ahmed22362/ITI-graduation-project-endpoint-monitor
cd ITI-graduation-project-endpoint-monitor
```

#### Step 2: Infrastructure Provisioning with Terraform

```bash
# Navigate to terraform directory
cd tf_eks_modules

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply infrastructure
terraform apply -auto-approve

# Save the EKS cluster details
aws eks update-kubeconfig --region eu-north-1 --name ITI-GP-Cluster
```

This creates:

- VPC with public/private subnets across 3 AZs
- EKS cluster (ITI-GP-Cluster) with managed node groups
- RDS MySQL instance
- AWS Secrets Manager for credentials
- ECR repository
- Jenkins on EKS with ALB (port 3000)
- Argo CD with ALB (port 8080)
- Node.js app with ALB (port 80)
- Bastion host for secure access
- External Secrets Operator with IRSA
- Argo Image Updater for GitOps automation
- IAM roles and policies
- Security groups and network ACLs

#### Step 3: Access Infrastructure Components

```bash
# Get Terraform outputs
cd tf_eks_modules
terraform output

# Access Jenkins (port 3000)
# URL from output: jenkins_url
open $(terraform output -raw jenkins_url)

# Access Argo CD (port 8080)
# URL from output: argocd_url
open $(terraform output -raw argocd_url)

# Access Node.js Application (port 80)
# URL: http://<alb-dns-name>
open "http://$(terraform output -raw jenkins_alb_dns)"

# SSH to Bastion Host
ssh -i ./keys/ITI-GP-Cluster_bastion_key.pem ec2-user@$(terraform output -raw bastion_public_ip)
```

#### Step 4: Deploy the Application via GitOps

```bash
# Application is automatically deployed through the GitOps pipeline:
# 1. Jenkins builds and pushes Docker image to ECR on code push
# 2. Argo Image Updater detects new image
# 3. Argo CD syncs the updated manifest to EKS

# Apply application manifests (if manual deployment needed)
kubectl apply -k app-manifests/

# Check deployment status
kubectl get pods -A
kubectl get svc -A

# View application logs
kubectl logs -f deployment/node-app -n default
kubectl logs -f deployment/mysql -n default
kubectl logs -f deployment/redis -n default
```

### Local Development Setup

For development and testing locally:

```bash
# Start MySQL and Redis with Docker Compose
cd node_app
docker-compose up -d

# Install Node.js dependencies
npm install

# Set environment variables
export DB_HOST=localhost
export DB_USER=root
export DB_PASSWORD=password
export REDIS_HOST=localhost
export REDIS_PORT=6379

# Run the application
npm start

# Run tests
npm test

# Access at http://localhost:3000
```

---

## Accessing Deployed Services

After successful Terraform deployment, access your services using the ALB DNS:

```bash
# Get ALB DNS name
cd tf_eks_modules
ALB_DNS=$(terraform output -raw jenkins_alb_dns)

# Service URLs:
# Node.js Application:  http://<ALB_DNS>         (Port 80)
# Jenkins:              http://<ALB_DNS>:3000    (Port 3000)
# Argo CD:              http://<ALB_DNS>:8080    (Port 8080)
```

**Example:**

```
http://ITI-GP-Cluster-apps-alb-1230796949.eu-north-1.elb.amazonaws.com       # Node App
http://ITI-GP-Cluster-apps-alb-1230796949.eu-north-1.elb.amazonaws.com:3000  # Jenkins
http://ITI-GP-Cluster-apps-alb-1230796949.eu-north-1.elb.amazonaws.com:8080  # Argo CD
```

---

## CI/CD Flow Explanation

### Complete GitOps Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          CI/CD Pipeline Flow                                 │
└─────────────────────────────────────────────────────────────────────────────┘

Developer → GitHub → Jenkins → ECR → ArgoCD → EKS Cluster
    │         │         │        │       │         │
    │         │         │        │       │         └─► Application Running
    │         │         │        │       │
    │         │         │        │       └─► Argo Image Updater
    │         │         │        │           (Auto-sync new images)
    │         │         │        │
    │         │         │        └─► Docker Registry (ECR)
    │         │         │            Push tagged images
    │         │         │
    │         │         └─► Build Pipeline
    │         │             1. Checkout code
    │         │             2. Run tests
    │         │             3. Build Docker image
    │         │             4. Security scanning
    │         │             5. Push to ECR
    │         │             6. Update manifests
    │         │
    │         └─► Webhook triggers Jenkins
    │
    └─► Git push/merge to main branch
```

## Project Structure

```
ITI-graduation-project-endpoint-monitor/
│
├── README.md
├── github_token
│
├── node_app/                          # Node.js Application
│   ├── app.js
│   ├── package.json
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── init.sql
│   ├── config/                        # Database & Redis config
│   ├── middleware/                    # Error handling & validation
│   ├── models/                        # Data models
│   ├── routes/                        # API routes
│   ├── services/                      # Business logic
│   ├── views/                         # HTML pages
│   ├── public/                        # Static assets (CSS, JS, images)
│   └── tests/                         # Jest test suite
│
├── tf_eks_modules/                    # Terraform Infrastructure
│   ├── main.tf
│   ├── outputs.tf
│   ├── variable.tf
│   ├── terraform.tfvars
│   ├── modules/
│   │   ├── vpc/                       # VPC, subnets, NAT, IGW
│   │   ├── eks/                       # EKS cluster & node groups
│   │   ├── rds/                       # MySQL RDS instance
│   │   ├── ecr/                       # Container registry
│   │   ├── jenkins/                   # Jenkins + ALB
│   │   ├── bastion/                   # Bastion host for SSH access
│   │   ├── secretManager/             # AWS Secrets Manager
│   │   ├── external-secrets/          # External Secrets Operator
│   │   └── image_updater/             # Argo Image Updater
│   ├── scripts/                       # Helper scripts
│   └── keys/                          # SSH keys (gitignored)
│
├── app-manifests/                     # Kubernetes Manifests
│   ├── kustomization.yaml
│   ├── mysql/                         # MySQL deployment
│   ├── redis/                         # Redis deployment
│   └── node-app/                      # Node.js app deployment
│
└── jenkins/                           # CI/CD Configuration
    ├── Jenkinsfile                    # Pipeline definition
    └── kaniko/                        # Kaniko build configuration
        ├── index.yaml                 # Pod template
        └── update-jenkins-url.sh      # Auto-update script
```

## Solved Issues

### **1. CI/CD Infinite Loop Between Jenkins and Argo Image Updater**

**Cause:** Jenkins builds triggered by Argo Image Updater commits, creating new images, which trigger Argo updates in an endless cycle.  
**Solution:** Added commit detection stage in Jenkinsfile to skip builds from argocd-image-updater commits with pattern matching.

### **2. AWS Secrets Manager - Secret Scheduled for Deletion**

**Cause:** Attempting to recreate a secret that was previously deleted and is in the recovery window.  
**Solution:** Restored the secret using `aws secretsmanager restore-secret` or used force-delete to remove permanently.

### **3. Redis Cache TypeError in Node Application**

**Cause:** Cache object not properly exported from redis.js configuration file.  
**Solution:** Added proper cache object export with get/set/del/clear methods.

### **4. Port Conflict - Jenkins and Node App**

**Cause:** Both services initially configured on same ALB listener port causing conflicts.  
**Solution:** Swapped ports via Terraform - Jenkins on 3000, Node app on 80, Argo CD on 8080. Updated all references including Kaniko pod template.

### **5. Jenkins Agent Connection Failures**

**Cause:** Kaniko pod template had outdated Jenkins URL without port number.  
**Solution:** Created automated update script (`update-jenkins-url.sh`) to sync Jenkins URL in pod template with Terraform output.

---
