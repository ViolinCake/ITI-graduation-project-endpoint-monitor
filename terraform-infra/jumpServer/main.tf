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
  user_data = local.base64_user_data
  tags = {
    Name = "EKS-Bastion-Host"
  }
  depends_on = [ var.eks_dependency ]
}
