variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block of the VPC"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of public subnet IDs"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs"
}

variable "eks_cluster_security_group_id" {
  type        = string
  description = "Security group ID of the EKS cluster"
}

variable "eks_node_group_autoscaling_group_name" {
  type        = string
  description = "Name of the EKS node group autoscaling group"
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the EKS OIDC provider for IRSA"
}

variable "oidc_provider_url" {
  type        = string
  description = "URL of the EKS OIDC provider for IRSA"
}
