# Jenkins IAM Policy for ECR
resource "aws_iam_policy" "jenkins_ecr" {
  name        = "${var.cluster_name}-jenkins-ecr-policy"
  description = "Allow Jenkins to push/pull from ECR"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "secretsmanager:GetSecretValue",
          "sts:GetCallerIdentity"
        ],
        Resource = "*"
      }
    ]
  })
}

# Jenkins IAM Role (IRSA)
resource "aws_iam_role" "jenkins" {
  name       = "AWS_EKS_Cluster_Auto_Scaler_Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
      }
    ]
  })
  
  tags = {
    Name      = "${var.cluster_name}-jenkins-role"
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role_policy" "jenkins_ecr_push" {
  name = "${var.cluster_name}-jenkins-ecr-push"
  role = aws_iam_role.jenkins.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PushToECR"
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = "*"
      },
      {
        Sid    = "GetAuthorizationToken"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_ecr" {
  policy_arn = aws_iam_policy.jenkins_ecr.arn
  role       = aws_iam_role.jenkins.name
}

# Allow Jenkins to access EKS cluster (Admin)
resource "aws_eks_access_entry" "jenkins" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.jenkins.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "jenkins" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.jenkins.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.jenkins]
}

# Security Group for Jenkins ALB
resource "aws_security_group" "jenkins_alb" {
  name_prefix = "${var.cluster_name}-jenkins-alb-"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Argo CD HTTP from anywhere"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Node.js App HTTP from anywhere"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-jenkins-alb-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for Jenkins NodePort
resource "aws_security_group" "jenkins_nodeport" {
  name_prefix = "${var.cluster_name}-jenkins-nodeport-"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Jenkins Web UI NodePort from ALB"
    from_port       = 30080
    to_port         = 30080
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_alb.id]
  }

  ingress {
    description = "Jenkins Agent NodePort from VPC"
    from_port   = 30050
    to_port     = 30050
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description     = "Argo CD HTTP NodePort from ALB"
    from_port       = 30081
    to_port         = 30081
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_alb.id]
  }

  ingress {
    description     = "Argo CD HTTPS NodePort from ALB"
    from_port       = 30443
    to_port         = 30443
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_alb.id]
  }

  ingress {
    description     = "Node.js App NodePort from ALB"
    from_port       = 30300
    to_port         = 30300
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_alb.id]
  }

  tags = {
    Name = "${var.cluster_name}-jenkins-nodeport-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Application Load Balancer for Jenkins and Argo CD
resource "aws_lb" "jenkins" {
  name               = "${var.cluster_name}-apps-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.jenkins_alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.cluster_name}-apps-alb"
  }
}

# Target Group for Jenkins Web UI (NodePort)
resource "aws_lb_target_group" "jenkins_web" {
  name        = "${var.cluster_name}-jenkins-web"
  port        = 30080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200,403"
    path                = "/login"
    port                = "30080"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.cluster_name}-jenkins-web-tg"
  }
}

# Target Group for Argo CD (NodePort)
resource "aws_lb_target_group" "argocd" {
  name        = "${var.cluster_name}-argocd"
  port        = 30443
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200,307"
    path                = "/healthz"
    port                = "30443"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.cluster_name}-argocd-tg"
  }
}

# Target Group for Node.js API Health App (NodePort)
resource "aws_lb_target_group" "node_app" {
  name        = "${var.cluster_name}-node-app"
  port        = 30300
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/api/health"
    port                = "30300"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.cluster_name}-node-app-tg"
  }
}

# Network Load Balancer for Jenkins Agent
resource "aws_lb" "jenkins_agent" {
  name               = "${var.cluster_name}-jenkins-agent-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.cluster_name}-jenkins-agent-nlb"
  }
}

# Target Group for Jenkins Agent (NodePort)
resource "aws_lb_target_group" "jenkins_agent" {
  name        = "${var.cluster_name}-jenkins-agent"
  port        = 30050
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    port                = "30050"
    protocol            = "TCP"
    timeout             = 10
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.cluster_name}-jenkins-agent-tg"
  }
}

# Listener for Jenkins and Argo CD (HTTP with path-based routing)
resource "aws_lb_listener" "jenkins_web_http" {
  load_balancer_arn = aws_lb.jenkins.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins_web.arn
  }
}

# Listener for Argo CD on port 8080
resource "aws_lb_listener" "argocd_http" {
  load_balancer_arn = aws_lb.jenkins.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.argocd.arn
  }
}

# Listener for Node.js App on port 3000
resource "aws_lb_listener" "node_http" {
  load_balancer_arn = aws_lb.jenkins.arn
  port              = "3000"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.node_app.arn
  }
}

# Listener for Jenkins Agent (TCP)
resource "aws_lb_listener" "jenkins_agent" {
  load_balancer_arn = aws_lb.jenkins_agent.arn
  port              = "50000"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins_agent.arn
  }
}

# Data source to get the Auto Scaling Group created by EKS node group
data "aws_autoscaling_group" "eks_nodes" {
  name = var.eks_node_group_autoscaling_group_name
}

# Auto Scaling Group attachment for Jenkins Web UI target group
resource "aws_autoscaling_attachment" "jenkins_web" {
  autoscaling_group_name = data.aws_autoscaling_group.eks_nodes.name
  lb_target_group_arn    = aws_lb_target_group.jenkins_web.arn
}

# Auto Scaling Group attachment for Argo CD target group
resource "aws_autoscaling_attachment" "argocd" {
  autoscaling_group_name = data.aws_autoscaling_group.eks_nodes.name
  lb_target_group_arn    = aws_lb_target_group.argocd.arn
}

# Auto Scaling Group attachment for Node.js App target group
resource "aws_autoscaling_attachment" "node_app" {
  autoscaling_group_name = data.aws_autoscaling_group.eks_nodes.name
  lb_target_group_arn    = aws_lb_target_group.node_app.arn
}

# Auto Scaling Group attachment for Jenkins Agent target group
resource "aws_autoscaling_attachment" "jenkins_agent" {
  autoscaling_group_name = data.aws_autoscaling_group.eks_nodes.name
  lb_target_group_arn    = aws_lb_target_group.jenkins_agent.arn
}

# Security group rules for Jenkins NodePort access
resource "aws_security_group_rule" "jenkins_web_nodeport" {
  type                     = "ingress"
  from_port                = 30080
  to_port                  = 30080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.jenkins_alb.id
  security_group_id        = var.eks_cluster_security_group_id
  description              = "Allow ALB to access Jenkins Web UI NodePort"
}

resource "aws_security_group_rule" "jenkins_agent_nodeport" {
  type              = "ingress"
  from_port         = 30050
  to_port           = 30050
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = var.eks_cluster_security_group_id
  description       = "Allow internal NLB to access Jenkins Agent NodePort"
}

# Security group rules for Argo CD NodePort access
resource "aws_security_group_rule" "argocd_http_nodeport" {
  type                     = "ingress"
  from_port                = 30081
  to_port                  = 30081
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.jenkins_alb.id
  security_group_id        = var.eks_cluster_security_group_id
  description              = "Allow ALB to access Argo CD HTTP NodePort"
}

resource "aws_security_group_rule" "argocd_https_nodeport" {
  type                     = "ingress"
  from_port                = 30443
  to_port                  = 30443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.jenkins_alb.id
  security_group_id        = var.eks_cluster_security_group_id
  description              = "Allow ALB to access Argo CD HTTPS NodePort"
}

# Security group rule for Node.js App NodePort access
resource "aws_security_group_rule" "node_app_nodeport" {
  type                     = "ingress"
  from_port                = 30300
  to_port                  = 30300
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.jenkins_alb.id
  security_group_id        = var.eks_cluster_security_group_id
  description              = "Allow ALB to access Node.js App NodePort"
}

# Automatically update Kaniko YAML with Jenkins URL
resource "null_resource" "update_kaniko_yaml" {
  triggers = {
    jenkins_url = aws_lb.jenkins.dns_name
  }

  provisioner "local-exec" {
    command = "bash ${path.root}/../kaniko/update-jenkins-url.sh"
    #command = "bash ${path.root}/../jenkins/kaniko/update-jenkins-url.sh ${path.root}"
  }

  depends_on = [aws_lb.jenkins]
}
