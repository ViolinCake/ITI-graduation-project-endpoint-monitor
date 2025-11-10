terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.82.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = module.eks.eks-cluster-endpoint
  cluster_ca_certificate = base64decode(module.eks.eks-cluster-CA)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes= {
    host                   = module.eks.eks-cluster-endpoint
    cluster_ca_certificate = base64decode(module.eks.eks-cluster-CA)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
      command     = "aws"
    }
  }
}

# 🕸 Network Layer
module "network" {
  source        = "../network"
  cluster_name  = var.cluster_name
  tags          = var.tags
}

# 🧠 EKS Cluster
module "eks" {
  source = "../eks"
  tags = var.tags
  public-subnet-1 = module.network.public-subnet-1-id
  public-subnet-2 = module.network.public-subnet-2-id
  private-subnet-1 = module.network.private-subnet-1-id
  private-subnet-2 = module.network.private-subnet-2-id
  bastion-host-sg = module.jump_server.bastion-sg-id
  ebs_csi_policy_attachment_id = module.node_groupe.ebs_csi_policy_attachment_id
}

# 🚀 Launch Template
module "launch_template" {
  source             = "../launchTemplate"
  tags               = var.tags
  cluster_name       = var.cluster_name
  eks_version        = var.eks_version
  cluster-CA         = module.eks.eks-cluster-CA
  cluster-endpoint   = module.eks.eks-cluster-endpoint
}

# 🧩 Node Group
module "node_groupe" {
  source                 = "../nodeGroupe"
  tags                   = var.tags
  cluster_name           = var.cluster_name
  private-subnet-1       = module.network.private-subnet-1-id
  private-subnet-2       = module.network.private-subnet-2-id
  launch-template-name   = module.launch_template.launch-template-name
  launch-template-version= module.launch_template.launch-template-version
  launch-template-id     = module.launch_template.launch-template-id
  vpc-id = module.network.vpc-id
}

# 🧱 Instance Profile
module "instance_profile" {
  source        = "../instanceProfile"
  cluster_name  = var.cluster_name
  eks_dependency = module.eks
}

# 💻 Jump Server
module "jump_server" {
  source               = "../jumpServer"
  vpc-id               = module.network.vpc-id
  subnet-id            = module.network.public-subnet-1-id
  iam-instance-profile = module.instance_profile.instance-profile-name
  eks_dependency = module.eks
  # bastion_ip = module.jump_server.bastion_public_ip

}
# bastion_ip = module.jump_server.bastion_public_ip

# 🧭 Fargate
module "fargate" {
  source          = "../fargate"
  tags            = var.tags
  cluster_name    = var.cluster_name
  private-subnet-1= module.network.private-subnet-1-id
  private-subnet-2= module.network.private-subnet-2-id
  eks_dependency = module.eks
}

# 🗄️ RDS
module "rds" {
  source = "../rds"

  vpc_id            = module.network.vpc-id
  db_name           = "api_health_db"
  db_username       = var.db_username
  db_password       = var.db_password
  private_subnet_ids = [module.network.private-subnet-1-id, module.network.private-subnet-2-id]
  eks_node_sg_id    = module.node_groupe.eks_node_sg_id
  project_name      = var.project_name
}


# 🔐 Secrets Manager
module "secret_manager" {
  source       = "../secretManager"
  db_name      = module.rds.db_name
  project_name = var.project_name
  db_username  = module.rds.db_username
  db_password  = module.rds.db_password
  rds_endpoint = module.rds.db_endpoint
}
