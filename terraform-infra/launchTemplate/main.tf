# New resource to define the EC2 Launch Template with IMDSv2 enforcement
resource "aws_launch_template" "demo_node_launch_template" {
  name_prefix   = "demo-eks-node-lt"
  image_id      = data.aws_ami.eks_ami.id # Use EKS-Optimized AMI
  instance_type = "m7i-flex.large"
  key_name      = "my-key"
  
  # *** CRITICAL: ADD THIS USER DATA BLOCK ***
  user_data = local.base64_user_data

  # *** CRITICAL: IMDSv2 Configuration ***
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Enforces IMDSv2
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags          = var.tags
  }
}

# Data source to fetch the latest EKS Optimized AMI for your version/type
data "aws_ami" "eks_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.eks_version}-*"]
  }

  # Replace with your desired AMI type (e.g., AL2_x86_64, AL2023_x86_64, etc.)
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}