variable "region" {
  type = string
  default = "us-east-1"
  description = "AWS region"
}



variable "cluster_name" {
  type = string
  default = "demo-eks-cluster"
  description = "EKS cluster name"
}
variable "eks_version" {
  type = string
  default = "1.31"
  description = "EKS version"
}

variable "tags" {
type = map(string)
default = {
    terraform  = "true"
    kubernetes = "demo-eks-cluster"
}
description = "Tags to apply to all resources"
}

# variable "eks_version" {
#   type = string
#   default = "1.31"
#   description = "EKS version"
# }
