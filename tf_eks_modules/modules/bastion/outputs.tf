output "bastion_public_ip" {
  description = "Public IP of bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_instance_id" {
  description = "Instance ID of bastion for SSM"
  value       = aws_instance.bastion.id
}

output "ssh_private_key_path" {
  description = "Path to SSH private key"
  value       = local_file.private_key.filename
}

output "ssh_command" {
  description = "Command to SSH into bastion"
  value       = "ssh -i ${local_file.private_key.filename} ec2-user@${aws_instance.bastion.public_ip}"
}

output "configure_kubectl_command" {
  description = "Command to run on bastion to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}

output "bastion_role_arn" {
  description = "ARN of the bastion IAM role"
  value       = aws_iam_role.bastion.arn
}

output "bastion_security_group_id" {
  description = "Security group ID of the bastion"
  value       = aws_security_group.bastion.id
}
