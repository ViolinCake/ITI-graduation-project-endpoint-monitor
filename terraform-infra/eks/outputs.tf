output "eks-cluster-CA" {
  value = aws_eks_cluster.demo-eks-cluster.certificate_authority.0.data
}
output "eks-cluster-endpoint" {
  value = aws_eks_cluster.demo-eks-cluster.endpoint
}