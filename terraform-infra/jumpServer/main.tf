# --- 2. Bastion Host Security Group ---
# WARNING: This security group is set to allow ALL INBOUND and OUTBOUND traffic from ALL sources (0.0.0.0/0).
# For production use, you should restrict the inbound 'port 22' rule to only your specific IP range!
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-host-sg"
  description = "Security group for the EKS Bastion Host"
  vpc_id      = var.vpc-id # Replace with your VPC ID variable

  # Inbound Rule: Allow ALL traffic from ALL sources (0.0.0.0/0)
  ingress {
    description = "Allow all inbound traffic (WARNING: Restrict this in production!)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound Rule: Allow ALL traffic to ALL destinations (0.0.0.0/0)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-bastion-sg"
  }
}

# --- 3. Bastion Host EC2 Instance ---
resource "aws_instance" "bastion_host" {
  ami                         = "ami-0bdd88bd06d16ba03"
  instance_type               = "t3.micro"
  subnet_id                   = var.subnet-id # Replace with your Public Subnet 1 ID variable
  associate_public_ip_address = true
  key_name                    = "my-key" # IMPORTANT: Define your SSH Key Pair name
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  iam_instance_profile = var.iam-instance-profile

  # User Data Script to install kubectl and helm
  user_data = <<-EOF
              #!/bin/bash
              
              # Update the package manager
              sudo yum update -y
              
              # --- Install kubectl ---
              # Reference: https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html
              echo "Installing kubectl..."
              # Install the required dependencies
              sudo yum install -y curl
              
              # Download and install the latest stable version of kubectl
              curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
              echo "$(<kubectl.sha256) kubectl" | sha256sum --check
              sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
              kubectl version --client
              
              # --- Install Helm ---
              # Reference: https://helm.sh/docs/intro/install/
              echo "Installing Helm..."
              curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
              
              # --- Configure AWS CLI (optional, but helpful for EKS API access) ---
              echo "Configuring AWS CLI..."
              # Ensure the latest AWS CLI is available (it often is on AL2023)
              

              # NOTE: You will still need to manually run the 'aws eks update-kubeconfig' command
              # or a script to configure kubectl AFTER the instance is running and the EKS cluster is deployed.
              aws eks update-kubeconfig --name demo-eks-cluster

              echo "Bastion setup complete. You must SSH in and run 'aws eks update-kubeconfig --name <cluster-name> --region <region>' to configure kubectl."

              EOF

  tags = {
    Name = "EKS-Bastion-Host"
  }
}

# --- 4. Outputs ---
output "bastion_public_ip" {
  description = "The public IP address of the Bastion Host"
  value       = aws_instance.bastion_host.public_ip
}