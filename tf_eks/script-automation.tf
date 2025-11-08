# S3 + SSM automation to copy and run scripts on bastion after EKS is ready

# Random ID for unique bucket naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 bucket to store scripts
resource "aws_s3_bucket" "eks_scripts" {
  bucket = "${lower(var.cluster_name)}-eks-scripts-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "${var.cluster_name}-scripts"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "eks_scripts" {
  bucket = aws_s3_bucket.eks_scripts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "eks_scripts" {
  bucket = aws_s3_bucket.eks_scripts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload eks-helper.sh script to S3
resource "aws_s3_object" "eks_helper_script" {
  bucket = aws_s3_bucket.eks_scripts.id
  key    = "eks-helper.sh"
  source = "${path.module}/scripts/eks-helper.sh"
  etag   = filemd5("${path.module}/scripts/eks-helper.sh")

  tags = {
    Name = "EKS Helper Script"
  }
}

# Upload deploy-jenkins.sh script to S3
resource "aws_s3_object" "deploy_jenkins_script" {
  bucket = aws_s3_bucket.eks_scripts.id
  key    = "deploy-jenkins.sh"
  source = "${path.module}/scripts/deploy-jenkins.sh"
  etag   = filemd5("${path.module}/scripts/deploy-jenkins.sh")

  tags = {
    Name = "Deploy Jenkins Script"
  }
}

# IAM policy for bastion to access S3 scripts bucket
resource "aws_iam_policy" "bastion_s3_scripts" {
  name        = "${var.cluster_name}-bastion-s3-scripts"
  description = "Allow bastion to read scripts from S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.eks_scripts.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.eks_scripts.arn
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-bastion-s3-scripts"
  }
}

# Attach S3 policy to bastion IAM role
resource "aws_iam_role_policy_attachment" "bastion_s3_scripts" {
  policy_arn = aws_iam_policy.bastion_s3_scripts.arn
  role       = aws_iam_role.bastion.name
}

# SSM Document to download and execute scripts
resource "aws_ssm_document" "setup_eks_scripts" {
  name          = "${var.cluster_name}-setup-eks-scripts"
  document_type = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Download EKS scripts from S3 and set up the bastion host"
    parameters = {
      bucketName = {
        type        = "String"
        description = "S3 bucket containing the scripts"
        default     = aws_s3_bucket.eks_scripts.bucket
      }
      clusterName = {
        type        = "String"
        description = "Name of the EKS cluster"
        default     = var.cluster_name
      }
      region = {
        type        = "String"
        description = "AWS region"
        default     = var.aws_region
      }
    }
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "setupEKSEnvironment"
        inputs = {
          timeoutSeconds = "1800"
          runCommand = [
            "echo '=== Starting EKS Environment Setup ==='",
            "echo 'Bucket: {{ bucketName }}'",
            "echo 'Cluster: {{ clusterName }}'",
            "echo 'Region: {{ region }}'",
            "echo 'Timestamp: $(date)'",
            "",
            "# Create scripts directory",
            "mkdir -p /home/ec2-user/eks-scripts",
            "cd /home/ec2-user/eks-scripts",
            "",
            "# Download scripts from S3",
            "echo 'Downloading scripts from S3...'",
            "aws s3 cp s3://{{ bucketName }}/eks-helper.sh ./eks-helper.sh",
            "aws s3 cp s3://{{ bucketName }}/deploy-jenkins.sh ./deploy-jenkins.sh",
            "",
            "# Make scripts executable",
            "chmod +x *.sh",
            "chown -R ec2-user:ec2-user /home/ec2-user/eks-scripts",
            "",
            "# Configure kubectl",
            "echo 'Configuring kubectl...'",
            "runuser -l ec2-user -c 'aws eks update-kubeconfig --region {{ region }} --name {{ clusterName }}'",
            "",
            "# Wait for cluster to be ready",
            "echo 'Waiting for cluster to be ready...'",
            "max_attempts=30",
            "attempt=1",
            "while [ $attempt -le $max_attempts ]; do",
            "  if runuser -l ec2-user -c 'kubectl get nodes' >/dev/null 2>&1; then",
            "    echo 'Cluster is ready!'",
            "    break",
            "  fi",
            "  echo \"Attempt $attempt/$max_attempts: Cluster not ready, waiting 30 seconds...\"",
            "  sleep 30",
            "  ((attempt++))",
            "done",
            "",
            "if [ $attempt -gt $max_attempts ]; then",
            "  echo 'ERROR: Cluster failed to become ready'",
            "  exit 1",
            "fi",
            "",
            "# Show cluster status",
            "echo 'Cluster nodes:'",
            "runuser -l ec2-user -c 'kubectl get nodes'",
            "",
            "# Deploy Jenkins automatically",
            "echo 'Deploying Jenkins...'",
            "runuser -l ec2-user -c 'cd /home/ec2-user/eks-scripts && ./deploy-jenkins.sh'",
            "",
            "# Create completion marker",
            "echo \"$(date): EKS setup completed successfully\" > /home/ec2-user/eks-setup-complete.log",
            "chown ec2-user:ec2-user /home/ec2-user/eks-setup-complete.log",
            "",
            "echo '=== EKS Environment Setup Complete ==='",
            "echo 'Scripts available in: /home/ec2-user/eks-scripts'",
            "echo \"Use './eks-helper.sh help' for available commands\""
          ]
        }
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-setup-eks-scripts"
  }
}

# SSM Association to run the setup automatically after bastion and EKS are ready
resource "aws_ssm_association" "setup_eks_environment" {
  name             = aws_ssm_document.setup_eks_scripts.name
  association_name = "${var.cluster_name}-auto-setup-eks"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.bastion.id]
  }

  parameters = {
    bucketName  = aws_s3_bucket.eks_scripts.bucket
    clusterName = var.cluster_name
    region      = var.aws_region
  }

  # Run once after both bastion and EKS cluster are ready
  schedule_expression = "rate(30 days)"  # Prevents re-runs, but allows manual execution
  
  depends_on = [
    aws_instance.bastion,
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.eks_nodes,
    aws_s3_object.eks_helper_script,
    aws_s3_object.deploy_jenkins_script,
    aws_iam_role_policy_attachment.bastion_s3_scripts
  ]

  tags = {
    Name = "${var.cluster_name}-auto-setup-eks"
  }
}

# Output the SSM command to manually run the setup if needed
output "manual_setup_command" {
  description = "Command to manually run the EKS setup on bastion"
  value = "aws ssm send-command --instance-ids ${aws_instance.bastion.id} --document-name ${aws_ssm_document.setup_eks_scripts.name} --region ${var.aws_region}"
}

# Output S3 bucket information
output "scripts_s3_bucket" {
  description = "S3 bucket containing the EKS scripts"
  value       = aws_s3_bucket.eks_scripts.bucket
}