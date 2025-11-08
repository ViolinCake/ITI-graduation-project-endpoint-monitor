resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = var.cluster_name
  node_role_arn   = aws_iam_role.eks_nodes.arn
  node_group_name = "${var.cluster_name}-node-group"
  subnet_ids      = aws_subnet.private_subnets[*].id
  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }
  update_config {
    max_unavailable = 1
  }
  instance_types = [var.node_instance_type]
  capacity_type  = "ON_DEMAND"
  disk_size      = 20
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
    aws_eks_cluster.eks_cluster

  ]

  tags = {
    Name = "${var.cluster_name}-node-group"
  }
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}
#AWS automatically creates this same rule for EKS clusters.
# resource "aws_security_group_rule" "node_to_node" {
#   type                     = "ingress"
#   from_port                = 0
#   to_port                  = 65535
#   protocol                 = "-1"
#   source_security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
#   security_group_id        = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
#   description              = "Allow nodes to communicate with each other"
# }