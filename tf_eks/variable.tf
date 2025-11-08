variable "aws_region" {
  default     = "eu-north-1"
  type        = string
  description = "AWS region where resources will be created"
}
variable "aws_profile" {
  default     = "terraform"
  type        = string
  description = "AWS CLI profile to use for authentication"
}
variable "environment" {
  default     = "dev"
  type        = string
  description = "Environment name (dev, staging, prod)"
}
variable "tags" {
  default = {
    terraform  = "true"
    kubernetes = "eks-cluster"
  }
  type        = map(string)
  description = "Tags to apply to all terraform resources"
}
variable "cluster_name" {
  default     = "ITI-GP-Cluster"
  type        = string
  description = "Name of the EKS cluster"
}
variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.31"
}
variable "vpc_cidr" {
  default     = "10.0.0.0/16"
  type        = string
  description = "CIDR block for VPC"
}
variable "availability_zones" {
  type    = list(string)
  default = ["eu-north-1a", "eu-north-1b"]
}
variable "private_subnet_cidrs" {
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  description = "CIDR blocks for private subnets"
}
variable "public_subnet_cidrs" {
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
  description = "CIDR blocks for public subnets"
}
variable "node_instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type for EKS nodes"
}
variable "node_desired_size" {
  type        = number
  default     = 2
  description = "Desired number of worker nodes"
}
variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}
variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}
variable "bastion_instance_type" {
  description = "Instance type for bastion host"
  type        = string
  default     = "t3.micro"
}
variable "allowed_ssh_cidr" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "CIDR blocks allowed to SSH to bastion"
}

variable "eks_fargate_name" {
  type        = string
  default     = "eks_fargate_profile"
  description = "Name of the EKS Fargate profile"
}