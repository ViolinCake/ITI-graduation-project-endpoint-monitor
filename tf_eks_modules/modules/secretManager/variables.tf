variable "project_name" {
  description = "Project name"
  type        = string
}

variable "db_username" {
  description = "RDS username"
  type        = string
}

variable "db_password" {
  description = "RDS password"
  type        = string
  sensitive   = true
}

variable "rds_endpoint" {
  description = "RDS endpoint"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}
