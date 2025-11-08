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