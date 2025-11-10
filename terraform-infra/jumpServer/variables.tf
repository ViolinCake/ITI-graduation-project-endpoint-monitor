variable "vpc-id" {
  type = string
}
variable "subnet-id" {
  type = string
}
variable "iam-instance-profile" {
  type = string
}
variable "eks_dependency" {
  type = any
}