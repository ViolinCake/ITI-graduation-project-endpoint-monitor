resource "aws_eks_fargate_profile" "eks_fg_profile" {
  cluster_name           = var.cluster_name
  fargate_profile_name   = var.eks_fargate_name
  pod_execution_role_arn = aws_iam_role.fargate_profile_role.arn
  selector {
    namespace = "kube-system"
  }
  selector {
    namespace = "default"
  }
  subnet_ids = aws_subnet.private_subnets[*].id
  depends_on = [aws_iam_role_policy_attachment.fargate_execution_policy, 
  aws_eks_cluster.eks_cluster,]
}