resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name      = aws_eks_cluster.eks_cluster.name
  addon_name        = "eks-pod-identity-agent"
}
resource "aws_eks_pod_identity_association" "jenkins" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  namespace       = "jenkins"
  service_account = "jenkins"
  role_arn        = aws_iam_role.jenkins.arn

  tags = {
    Name = "${var.cluster_name}-jenkins-pod-identity"
  }

  depends_on = [aws_eks_cluster.eks_cluster]
}