# 1. IAM Role (Identity)
resource "aws_iam_role" "bastion_eks_role" {
  name = "bastion-eks-admin-role"

  # Trust Policy: Allows EC2 service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Define minimal EKS Access Policy (to get cluster endpoint/details)
data "aws_iam_policy_document" "eks_read_access" {
  statement {
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
      "eks:DescribeClusterVersions", #<- needed for creating the IRSA
      "iam:GetOpenIDConnectProvider", # <- the following permissions needed for the OICD provider
      "iam:GetOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviders",
      "iam:CreateOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "eks:TagResource",
      "cloudformation:DescribeStacks",  #<- the following permissions are needed for the eksctl cloudformation
      "cloudformation:DescribeStackResources",
      "cloudformation:ListStacks",
      "cloudformation:ListStackResources",
      "cloudformation:GetTemplateSummary",
      "cloudformation:CreateStack"
    ]
    resources = [
      "*" # Scope this to your specific EKS cluster ARN for max least-privilege
    ]
  }
  statement {
    effect = "Allow"
    actions = [ 
      # Policy Management             
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:CreatePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:DeletePolicyVersion",
      
      # Role Management (used by eksctl when creating iamserviceaccount)
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:PutRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:TagRole",
      "iam:PassRole",
      "iam:GetRole"
     ]
     resources = [ "*" ]
  }
}


# Attach the Inline policy to the role
# You can Instead use an aws_iam_policy resource and then create the aws_iam_policy_attachement resource
# But this methode is called an inline policy where the policy itself is embed into the role , not a separate one
resource "aws_iam_role_policy" "bastion_eks_policy" {
  name   = "bastion-eks-read-policy"
  role   = aws_iam_role.bastion_eks_role.id
  policy = data.aws_iam_policy_document.eks_read_access.json
}


# 3. Encapsulate the role in an Instance Profile
# an Instance profile is used to grant an ec2 the IAM role
resource "aws_iam_instance_profile" "bastion_profile" {
  name = "bastion-eks-profile"
  role = aws_iam_role.bastion_eks_role.name
}

# You would then attach aws_iam_instance_profile.bastion_profile.id to your aws_instance resource.



resource "aws_eks_access_entry" "bastion_access" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.bastion_eks_role.arn
  type          = "STANDARD"
  depends_on = [ var.eks_dependency ]
}

resource "aws_eks_access_policy_association" "bastion_policy" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.bastion_eks_role.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
  depends_on = [ var.eks_dependency ]
}
