module "eks" {
  source = "./eks"
  tags = var.tags
  public-subnet-1 = module.network.public-subnet-1-id
  public-subnet-2 = module.network.public-subnet-2-id
  private-subnet-1 = module.network.private-subnet-1-id
  private-subnet-2 = module.network.private-subnet-2-id
  bastion-host-sg = module.jump_server.bastion-sg-id
  ebs_csi_policy_attachment_id = module.node_groupe.ebs_csi_policy_attachment_id
}
module "launch_template" {
  source = "./launchTemplate"
  tags = var.tags
  cluster_name = var.cluster_name
  eks_version = var.eks_version
  cluster-CA = module.eks.eks-cluster-CA
  cluster-endpoint = module.eks.eks-cluster-endpoint
}
module "node_groupe" {
  source = "./nodeGroupe"
  tags = var.tags
  cluster_name = var.cluster_name
  private-subnet-1 = module.network.private-subnet-1-id
  private-subnet-2 = module.network.private-subnet-2-id
  launch-template-name = module.launch_template.launch-template-name
  launch-template-version = module.launch_template.launch-template-version
  launch-template-id = module.launch_template.launch-template-id
}
module "network" {
  source = "./network"
  cluster_name = var.cluster_name
  tags = var.tags
}
module "instance_profile" {
  source = "./instanceProfile"
  cluster_name = var.cluster_name
}
module "jump_server" {
  source = "./jumpServer"
  vpc-id = module.network.vpc-id
  subnet-id = module.network.public-subnet-1-id
  iam-instance-profile = module.instance_profile.instance-profile-name
}
module "fargate" {
  source = "./fargate"
  tags = var.tags
  cluster_name = var.cluster_name
  private-subnet-1 = module.network.private-subnet-1-id
  private-subnet-2 = module.network.private-subnet-2-id
}