# output "cluster_id" {
#   description = "EKS cluster ID"
#   value       = aws_eks_cluster.main.id
# }

# output "cluster_endpoint" {
#   description = "Endpoint for EKS control plane"
#   value       = aws_eks_cluster.main.endpoint
# }

# output "cluster_security_group_id" {
#   description = "Security group ID attached to the EKS cluster"
#   value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
# }

# output "cluster_name" {
#   description = "Kubernetes Cluster Name"
#   value       = aws_eks_cluster.main.name
# }

# output "region" {
#   description = "AWS region"
#   value       = var.aws_region
# }

# output "cluster_certificate_authority_data" {
#   description = "Base64 encoded certificate data required to communicate with the cluster"
#   value       = aws_eks_cluster.main.certificate_authority[0].data
#   sensitive   = true
# }
output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = aws_iam_role.eks_cluster_role.arn
}

output "eks_node_group_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = aws_iam_role.eks_nodes.arn
}
# Bastion outputs
output "bastion_public_ip" {
  description = "Public IP of bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_instance_id" {
  description = "Instance ID of bastion for SSM"
  value       = aws_instance.bastion.id
}

output "ssh_private_key_path" {
  description = "Path to SSH private key"
  value       = local_file.private_key.filename
}

output "ssh_command" {
  description = "Command to SSH into bastion"
  value       = "ssh -i ${local_file.private_key.filename} ec2-user@${aws_instance.bastion.public_ip}"
}

output "ssm_command" {
  description = "Command to connect via AWS Systems Manager"
  value       = "aws ssm start-session --target ${aws_instance.bastion.id} --region ${var.aws_region}"
}

output "configure_kubectl_command" {
  description = "Command to run on bastion to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}
output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.app.repository_url
}
output "jenkins_role_arn" {
  description = "ARN of IAM role for Jenkins"
  value       = aws_iam_role.jenkins.arn
}

# Jenkins URL will be available after manual deployment from bastion
# output "jenkins_url" {
#   description = "Jenkins URL"
#   value       = "Will be available after manual Jenkins deployment from bastion"
# }