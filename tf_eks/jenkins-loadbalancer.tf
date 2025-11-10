# Security Group for Jenkins Load Balancer
resource "aws_security_group" "jenkins_lb" {
  name_prefix = "${var.cluster_name}-jenkins-lb-"
  vpc_id      = aws_vpc.cluster_vpc.id

  ingress {
    description = "Jenkins Web UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins Agent"
    from_port   = 50000
    to_port     = 50000
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.cluster_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-jenkins-lb-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Network Load Balancer for Jenkins
resource "aws_lb" "jenkins" {
  name               = "${var.cluster_name}-jenkins-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = aws_subnet.public_subnets[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.cluster_name}-jenkins-nlb"
  }
}

# Target Group for Jenkins Web UI
resource "aws_lb_target_group" "jenkins_web" {
  name     = "${var.cluster_name}-jenkins-web"
  port     = 8080
  protocol = "TCP"
  vpc_id   = aws_vpc.cluster_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/login"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.cluster_name}-jenkins-web-tg"
  }
}

# Target Group for Jenkins Agent
resource "aws_lb_target_group" "jenkins_agent" {
  name     = "${var.cluster_name}-jenkins-agent"
  port     = 50000
  protocol = "TCP"
  vpc_id   = aws_vpc.cluster_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    port                = "traffic-port"
    protocol            = "TCP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.cluster_name}-jenkins-agent-tg"
  }
}

# Listener for Jenkins Web UI
resource "aws_lb_listener" "jenkins_web" {
  load_balancer_arn = aws_lb.jenkins.arn
  port              = "8080"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins_web.arn
  }
}

# Listener for Jenkins Agent
resource "aws_lb_listener" "jenkins_agent" {
  load_balancer_arn = aws_lb.jenkins.arn
  port              = "50000"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins_agent.arn
  }
}

# Note: Auto Scaling Group attachments will be added after EKS node group is created
# This can be done as a separate terraform apply or manually through AWS console
# The Load Balancer is created and ready, just need to attach EKS node group ASG to target groups
# 
# Manual commands after terraform apply:
# 1. Find ASG name: aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[?Tags[?Key=='eks:cluster-name' && Value=='ITI-GP-Cluster']].AutoScalingGroupName" --output text
# 2. Attach to web target group: aws elbv2 register-targets --target-group-arn <jenkins_web_target_group_arn> --targets Id=<instance-id>
# 3. Attach to agent target group: aws elbv2 register-targets --target-group-arn <jenkins_agent_target_group_arn> --targets Id=<instance-id>