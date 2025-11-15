
variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for RDS"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "eks_node_sg_id" {
  description = "Security group ID for EKS worker nodes"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}
