variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of public subnet IDs"
}

variable "bastion_instance_type" {
  type        = string
  description = "Instance type for bastion host"
}

variable "allowed_ssh_cidr" {
  type        = list(string)
  description = "CIDR blocks allowed to SSH to bastion"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "jenkins_role_arn" {
  type        = string
  description = "ARN of Jenkins IAM role"
}

variable "eks_cluster_security_group_id" {
  type        = string
  description = "Security group ID of the EKS cluster"
}
