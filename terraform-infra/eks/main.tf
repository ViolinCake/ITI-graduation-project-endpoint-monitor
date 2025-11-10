resource "aws_iam_role" "demo-eks-cluster-role" {
  name = "demo-eks-cluster-role"

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
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })  

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eks-cluster-policy" {
  role       = aws_iam_role.demo-eks-cluster-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
} 




resource "aws_eks_cluster" "demo-eks-cluster" {
  name = var.cluster_name

  access_config {
    authentication_mode = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  role_arn = aws_iam_role.demo-eks-cluster-role.arn
  version  = var.eks_version

   vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = false

    subnet_ids = [
      var.public-subnet-1,
      var.public-subnet-2,
      var.private-subnet-1,
      var.private-subnet-2,

      # aws_subnet.public-subnet-1.id,
      # aws_subnet.public-subnet-2.id,
      # aws_subnet.private-subnet-1.id,
      # aws_subnet.private-subnet-2.id,
    ]
  }

  bootstrap_self_managed_addons = true
  tags = var.tags

  upgrade_policy {
    support_type = "STANDARD"
  }


  # Ensure that IAM Role permissions are created before and deleted
  # after EKS Cluster handling. Otherwise, EKS will not be able to
  # properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.eks-cluster-policy,
  ]
}

resource "aws_security_group_rule" "allow-basstionhost-sg" {
  security_group_id = aws_eks_cluster.demo-eks-cluster.vpc_config[0].cluster_security_group_id
  type = "ingress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  source_security_group_id = var.bastion-host-sg
  description = "allow all traffic from the bastion host security group"
}

# resource "aws_security_group_rule" "allow-codebuild-sg" {
#   security_group_id = aws_eks_cluster.demo-eks-cluster.vpc_config[0].cluster_security_group_id
#   type = "ingress"
#   from_port = 0
#   to_port = 0
#   protocol = "-1"
#   source_security_group_id = var.codebuild-sg
#   description = "allow all traffic from the code build security group"
# }






resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = aws_eks_cluster.demo-eks-cluster.name
  addon_name   = "aws-ebs-csi-driver"

  # Use the new arguments to resolve the deprecation warning
  resolve_conflicts_on_create = "OVERWRITE" 
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    var.ebs_csi_policy_attachment_id,
  ]
}