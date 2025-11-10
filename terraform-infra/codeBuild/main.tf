resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-eks-jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_basic" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"    # <- codebuild needs it to perform any builds 
}

resource "aws_iam_role_policy_attachment" "eks_access" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"         # <- to apply helm chart installations on eks cluster
}

resource "aws_iam_role_policy_attachment" "ec2_access" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"     # <- used if we need to build a docker image and push into a registry
}
resource "aws_iam_role_policy_attachment" "codebuild_admin_access" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildAdminAccess"
}




resource "aws_iam_role_policy" "codebuild_logging_explicit" {
  name = "codebuild-logging-explicit"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}







resource "aws_iam_role_policy" "codebuild_network_access" {
  name = "CodeBuildVpcNetworkAccess"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs"
        ],
        Resource = "*"
      }
    ]
  })
}


#######################################################################################################################
#######################################################################################################################
resource "aws_security_group" "codebuild_sg" {
  name        = "codebuild-sg"
  description = "Allow CodeBuild to access EKS private endpoint and internet if needed"
  vpc_id      = var.vpc-id

  # Allow outbound traffic (to pull images, talk to API, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  

  tags = var.tags
}

#######################################################################################################################
#######################################################################################################################


resource "aws_codebuild_source_credential" "github" {
  auth_type = "PERSONAL_ACCESS_TOKEN"
  server_type = "GITHUB"
  token = var.github_token  # Store this securely in TF Cloud or SSM
}
resource "aws_codebuild_project" "jenkins_installer" {
  name          = "jenkins-helm-installer"
  service_role  = aws_iam_role.codebuild_role.arn
  description   = "Installs Jenkins Helm chart on EKS"
  build_timeout = 20

  source {
    type      = "GITHUB"
    location  = "https://github.com/ViolinCake/temp.git"
    buildspec = "buildspec.yml"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"    # <- the compute specs needed to run the container, SMALL is for 3GB RAM and 2vCPU
    image                       = "aws/codebuild/standard:7.0"  # <- The build environment "the container itself", this one includes aws cli ,kubectl and other pre installed utils 
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true  # <- allows docker-in-docker, this is used if the project will try to build a docker image 
  }

  artifacts {
    type = "NO_ARTIFACTS"   # <- The output of the build, used if the build will generate a compiled file  
  }

  vpc_config {
    vpc_id             = var.vpc-id
    subnets = [ var.subnet-id ]
    security_group_ids = [aws_security_group.codebuild_sg.id]
  }
}
