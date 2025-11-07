output "vpc-id" {
  value = aws_vpc.demo-eks-cluster-vpc.id
}


output "public-subnet-1-id" {
  value = aws_subnet.public-subnet-1.id
}
output "public-subnet-2-id" {
  value = aws_subnet.public-subnet-2.id
}
output "private-subnet-1-id" {
  value = aws_subnet.private-subnet-1.id
}
output "private-subnet-2-id" {
  value = aws_subnet.private-subnet-1.id
}
