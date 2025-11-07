variable "eks_version" {
  type = string
  default = "1.31"
  description = "EKS version"
}
variable "cluster_name" {
  type = string
  default = "demo-eks-cluster"
  description = "EKS cluster name"
}
variable "tags" {
    type = map(string)
}
variable "public-subnet-1" {
  type = string
}
variable "public-subnet-2" {
  type = string
}
variable "private-subnet-1" {
  type = string
}
variable "private-subnet-2" {
  type = string
}
variable "bastion-host-sg" {
  type = string
}
variable "ebs_csi_policy_attachment_id" {
  description = "EBS CSI policy attachment ID from node group module"
  type        = string
}
variable "codebuild-sg" {
  type = string
}