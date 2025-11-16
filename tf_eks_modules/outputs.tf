# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.vpc.private_subnet_ids
}

# EKS Outputs
output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = module.eks.cluster_role_arn
}

output "eks_node_group_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = module.eks.node_group_role_arn
}

# Bastion Outputs
output "bastion_public_ip" {
  description = "Public IP of bastion host"
  value       = module.bastion.bastion_public_ip
}

output "bastion_instance_id" {
  description = "Instance ID of bastion for SSM"
  value       = module.bastion.bastion_instance_id
}

output "ssh_private_key_path" {
  description = "Path to SSH private key"
  value       = module.bastion.ssh_private_key_path
}

output "ssh_command" {
  description = "Command to SSH into bastion"
  value       = module.bastion.ssh_command
}

output "configure_kubectl_command" {
  description = "Command to run on bastion to configure kubectl"
  value       = module.bastion.configure_kubectl_command
}

# ECR Outputs
output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.ecr_repository_url
}

# Jenkins Outputs
output "jenkins_role_arn" {
  description = "ARN of IAM role for Jenkins"
  value       = module.jenkins.jenkins_role_arn
}

output "jenkins_url" {
  description = "Jenkins URL via Terraform-managed ALB"
  value       = module.jenkins.jenkins_url
}

output "jenkins_alb_dns" {
  description = "DNS name of Jenkins Application Load Balancer"
  value       = module.jenkins.jenkins_alb_dns
}

output "jenkins_agent_nlb_dns" {
  description = "DNS name of Jenkins Agent Network Load Balancer (internal)"
  value       = module.jenkins.jenkins_agent_nlb_dns
}

output "jenkins_web_target_group_arn" {
  description = "ARN of Jenkins Web UI target group"
  value       = module.jenkins.jenkins_web_target_group_arn
}

output "jenkins_target_group_agent_arn" {
  description = "ARN of Jenkins agent target group"
  value       = module.jenkins.jenkins_agent_target_group_arn
}

# Region Output
output "region" {
  description = "AWS region"
  value       = var.aws_region
}

# Argo CD Output
output "argocd_url" {
  description = "Argo CD URL (HTTP via ALB port 8080)"
  value       = "http://${module.jenkins.jenkins_alb_dns}:8080"
}

# Application Pod URL
output "app_url" {
  description = "Application URL (HTTP via ALB port 3000)"
  value       = "http://${module.jenkins.jenkins_alb_dns}:3000"
}

# output "cluster_endpoint" {
#   value = module.eks.eks-cluster-endpoint
# }

# output "cluster_ca" {
#   value = module.eks.eks-cluster-CA
# }

# output "rds_endpoint" {
#   value = module.rds.rds_endpoint
# }

# output "bastion_public_ip" {
#   value = module.jump_server.bastion_public_ip
# }

# output "rds_secret_arn" {
#   value = module.secret_manager.rds_secret_arn
# }
