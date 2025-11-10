resource "aws_iam_role" "demo-eks-ng-role" {
  name = "demo-eks-nodegroup-role"

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
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = var.tags
}


resource "aws_iam_role_policy_attachment" "eks-demo-ng-WorkerNode-policy" {
  role       = aws_iam_role.demo-eks-ng-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy" # To register kublets for every node on the controlplane
}
resource "aws_iam_role_policy_attachment" "eks-demo-ng-AmazonEKS_CNI-policy" {
  role       = aws_iam_role.demo-eks-ng-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy" # CNI plugin that runs as a daemonset on every node
}
resource "aws_iam_role_policy_attachment" "eks-demo-ng-ContainerRegistryReadOnly-policy" {
  role       = aws_iam_role.demo-eks-ng-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly" #to pull images from AWS ECR
}
resource "aws_iam_role_policy_attachment" "eks-demo-ng-EBS_CSI-policy" {
  role       = aws_iam_role.demo-eks-ng-role.name
  # The correct, verified AWS Managed Policy ARN
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy" 
}





resource "aws_eks_node_group" "eks-demo-node-group" {
  cluster_name    = var.cluster_name
  node_role_arn   = aws_iam_role.demo-eks-ng-role.arn
  node_group_name = "demo-eks-node-group"
  subnet_ids      = [var.private-subnet-1, var.private-subnet-2]
  
  # REMOVED: instance_types = [ "m7i-flex.large" ]
  # REMOVED: remote_access { ec2_ssh_key = "my-key" }
  # The instance_type and key_name are now managed by the Launch Template (aws_launch_template.demo_node_launch_template)

  # *** CRITICAL: Launch Template Reference ***
  launch_template {
    name    = var.launch-template-name
    version = var.launch-template-version
  }

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }
  
  update_config {
    max_unavailable = 1
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.eks-demo-ng-AmazonEKS_CNI-policy,
    aws_iam_role_policy_attachment.eks-demo-ng-ContainerRegistryReadOnly-policy,
    aws_iam_role_policy_attachment.eks-demo-ng-WorkerNode-policy,
    # Add dependency on the Launch Template
    var.launch-template-id, 
  ]

}
resource "aws_security_group" "eks_nodes_sg" {
  vpc_id = var.vpc-id
  name   = "${var.cluster_name}-nodes-sg"
  tags   = var.tags
}

