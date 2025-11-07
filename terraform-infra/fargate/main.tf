resource "aws_iam_role" "demo-eks-fargate-profile-role" {
  name = "demo-eks-fargate-profile-role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "eks-fargate-pods.amazonaws.com"
        }
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "fargate-execution-policy" {
  role       = aws_iam_role.demo-eks-fargate-profile-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

resource "aws_eks_fargate_profile" "demo-eks-fg-prof" {
  cluster_name           = var.cluster_name
  fargate_profile_name   = "demo-eks-fargate-profile-1"
  pod_execution_role_arn = aws_iam_role.demo-eks-fargate-profile-role.arn
  subnet_ids             = [var.private-subnet-1,var.private-subnet-2]

  selector {
    namespace = "default"
  }
  selector {
    namespace = "kube-system"
  }
  depends_on = [aws_iam_role_policy_attachment.fargate-execution-policy]
}
