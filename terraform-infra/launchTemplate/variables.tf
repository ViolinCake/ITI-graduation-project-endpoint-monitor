variable "cluster_name" {
  type = string
}
variable "eks_version" {
  type = string
}
variable "tags" {
  type = map(string)
}

variable "cluster-CA" {
  type = string
}
variable "cluster-endpoint" {
  type = string
}