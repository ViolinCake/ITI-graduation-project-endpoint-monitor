output "ebs_csi_policy_attachment_id" {
  value = aws_iam_role_policy_attachment.eks-demo-ng-EBS_CSI-policy.id
}
