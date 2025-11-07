variable "cidr_block" {
 type = string
 default = "10.10.0.0/16" 
}
variable "cluster_name" {
  type = string
}
variable "az-b" {
  type = string
  default = "us-east-1b"
}
variable "az-c" {
  type = string
  default = "us-east-1c"
}
variable "tags" {
  type = map(string)
}