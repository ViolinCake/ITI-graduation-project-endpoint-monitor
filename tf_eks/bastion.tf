data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "bastion" {
  name        = "${var.cluster_name}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.cluster_vpc.id
  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-bastion-sg"
  }
}

resource "aws_iam_role" "bastion" {
  name = "${var.cluster_name}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-bastion-role"
  }
}
resource "aws_iam_role_policy" "bastion_eks" {
  name = "${var.cluster_name}-bastion-eks-policy"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi",
          "eks:ListAccessEntries",
          "eks:DescribeAccessEntry"
        ]
        Resource = "*"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.bastion.name
}
resource "aws_iam_instance_profile" "bastion" {
  name = "${var.cluster_name}-bastion-profile"
  role = aws_iam_role.bastion.name
}
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.bastion_instance_type
  key_name                    = aws_key_pair.bastion_key.key_name
  subnet_id                   = aws_subnet.public_subnets[0].id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.bastion.name

  #   # Configure kubectl with cluster credentials
  #   won't work here because the cluster might not be ready yet
  #   aws eks update-kubeconfig \
  #     --region ${var.aws_region} \
  #     --name ${var.cluster_name} \
  #     --kubeconfig /home/ec2-user/.kube/config

  # User data: Install tools and basic setup
  user_data = base64encode(<<-EOF
              #!/bin/bash
              set -e
              
              # Logging function
              log() {
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/eks-setup.log
              }
              
              log "=== Starting Bastion Host Setup ==="
              
              # Update system
              log "Updating system packages..."
              dnf update -y
              
              # Install kubectl
              log "Installing kubectl..."
              curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              chmod +x kubectl
              mv kubectl /usr/local/bin/
              
              # Install git
              log "Installing git..."
              dnf install -y git
              
              # Install helm
              log "Installing helm..."
              curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
              
              # Create .kube directory for ec2-user
              mkdir -p /home/ec2-user/.kube
              chown ec2-user:ec2-user /home/ec2-user/.kube
              
              # Create scripts directory
              mkdir -p /home/ec2-user/eks-scripts
              chown ec2-user:ec2-user /home/ec2-user/eks-scripts
              
              # Add helpful aliases and environment variables
              log "Setting up user environment..."
              cat >> /home/ec2-user/.bashrc <<'BASHRC'
              
              # Kubernetes aliases
              alias k='kubectl'
              alias kgp='kubectl get pods'
              alias kgs='kubectl get svc'
              alias kgn='kubectl get nodes'
              alias kgd='kubectl get deployments'
              alias kga='kubectl get all'
              
              # Set AWS default region
              export AWS_DEFAULT_REGION=${var.aws_region}
              
              # Kubectl bash completion
              source <(kubectl completion bash)
              complete -F __start_kubectl k
              BASHRC
              
              chown ec2-user:ec2-user /home/ec2-user/.bashrc
              
              log "=== Bastion Host Setup Complete ==="
              EOF
  )

  # Copy scripts to bastion after instance is created
  provisioner "file" {
    source      = "${path.module}/scripts/"
    destination = "/home/ec2-user/eks-scripts"
    
    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ec2-user"
      private_key = file(local_file.private_key.filename)
      timeout     = "2m"
    }
  }

  # Execute setup script after files are copied
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ec2-user/eks-scripts/*.sh",
      "chown -R ec2-user:ec2-user /home/ec2-user/eks-scripts",
      "/home/ec2-user/eks-scripts/auto-setup-eks.sh"
    ]
    
    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ec2-user"  
      private_key = file(local_file.private_key.filename)
      timeout     = "10m"
    }
  }

  tags = {
    Name = "${var.cluster_name}-bastion"
  }

  depends_on = [
    aws_nat_gateway.cluster_nat,
    aws_key_pair.bastion_key,
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.eks_nodes
  ]
}

resource "aws_security_group_rule" "bastion_to_eks" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  description              = "Allow bastion to access EKS API"
}
# Grant bastion IAM role access to EKS cluster (Modern approach)
resource "aws_eks_access_entry" "bastion" {
  cluster_name  = aws_eks_cluster.eks_cluster.name
  principal_arn = aws_iam_role.bastion.arn
  type          = "STANDARD"

  depends_on = [aws_eks_cluster.eks_cluster]
}

# Associate the bastion with cluster admin policy
resource "aws_eks_access_policy_association" "bastion_admin" {
  cluster_name  = aws_eks_cluster.eks_cluster.name
  principal_arn = aws_iam_role.bastion.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bastion]
}