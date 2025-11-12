terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  required_version = ">=1.2"
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  default_tags {
    tags = {
      Environment = var.environment
      project     = "eks-cluster"
      ManagedBy   = "Terraform"
    }
  }
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    command     = "aws"
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  cluster_name         = var.cluster_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  tags                 = var.tags
}

# EKS Module
module "eks" {
  source = "./modules/eks"

  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size

  depends_on = [module.vpc]
}

# ECR Module
module "ecr" {
  source = "./modules/ecr"

  cluster_name = var.cluster_name
}

# Jenkins Module
module "jenkins" {
  source = "./modules/jenkins"

  cluster_name                          = var.cluster_name
  vpc_id                                = module.vpc.vpc_id
  vpc_cidr                              = module.vpc.vpc_cidr
  public_subnet_ids                     = module.vpc.public_subnet_ids
  private_subnet_ids                    = module.vpc.private_subnet_ids
  eks_cluster_security_group_id         = module.eks.cluster_security_group_id
  eks_node_group_autoscaling_group_name = module.eks.node_group_autoscaling_group_name
  oidc_provider_arn                     = module.eks.oidc_provider_arn
  oidc_provider_url                     = module.eks.oidc_provider_url

  depends_on = [module.eks]
}

# Bastion Module
module "bastion" {
  source = "./modules/bastion"

  cluster_name                  = var.cluster_name
  vpc_id                        = module.vpc.vpc_id
  public_subnet_ids             = module.vpc.public_subnet_ids
  bastion_instance_type         = var.bastion_instance_type
  allowed_ssh_cidr              = var.allowed_ssh_cidr
  aws_region                    = var.aws_region
  jenkins_role_arn              = module.jenkins.jenkins_role_arn
  eks_cluster_security_group_id = module.eks.cluster_security_group_id

  depends_on = [module.eks, module.jenkins]
}
