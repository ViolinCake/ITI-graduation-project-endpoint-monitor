resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  vpc_config {
    endpoint_public_access  = false # Private only - access via bastion
    endpoint_private_access = true
    subnet_ids              = concat(aws_subnet.private_subnets[*].id, aws_subnet.public_subnets[*].id)
    # public_access_cidrs     = ["0.0.0.0/0"]

  }
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  access_config {
    bootstrap_cluster_creator_admin_permissions = true
    authentication_mode                         = "API"
  }
  bootstrap_self_managed_addons = true

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]

  version = var.cluster_version

  tags = {
    Name = var.cluster_name
  }

  upgrade_policy {
    support_type = "STANDARD"
  }
}

# OIDC Provider for EKS (Required for IAM roles for service accounts)
data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer

  tags = {
    Name = "${var.cluster_name}-eks-oidc"
  }
}

# IAM role for EBS CSI driver
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.cluster_name}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud": "sts.amazonaws.com"
          }
        }
      },
    ]
  })

  tags = {
    Name = "${var.cluster_name}-ebs-csi-driver-role"
  }
}

# Attach AWS managed policy for EBS CSI driver
resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

# Install EBS CSI driver addon
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.eks_cluster.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

  # Use the new arguments to resolve the deprecation warning
  resolve_conflicts_on_create = "OVERWRITE" 
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_iam_role_policy_attachment.ebs_csi_driver_policy,
    aws_eks_node_group.eks_nodes,
  ]
}
resource "aws_iam_openid_connect_provider" "oidc" {
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [ data.tls_certificate.eks.certificates[0].sha1_fingerprint ]
}
