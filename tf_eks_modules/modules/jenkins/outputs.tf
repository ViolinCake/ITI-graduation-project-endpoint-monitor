output "jenkins_role_arn" {
  description = "ARN of IAM role for Jenkins"
  value       = aws_iam_role.jenkins.arn
}

output "jenkins_url" {
  description = "Jenkins URL via Terraform-managed ALB"
  value       = "http://${aws_lb.jenkins.dns_name}"
}

output "argocd_url" {
  description = "Argo CD URL via Terraform-managed ALB"
  value       = "http://${aws_lb.jenkins.dns_name}:8080"
}

output "jenkins_alb_dns" {
  description = "DNS name of Shared Application Load Balancer (Jenkins & Argo CD)"
  value       = aws_lb.jenkins.dns_name
}

output "jenkins_agent_nlb_dns" {
  description = "DNS name of Jenkins Agent Network Load Balancer (internal)"
  value       = aws_lb.jenkins_agent.dns_name
}

output "jenkins_web_target_group_arn" {
  description = "ARN of Jenkins Web UI target group"
  value       = aws_lb_target_group.jenkins_web.arn
}

output "jenkins_agent_target_group_arn" {
  description = "ARN of Jenkins agent target group"
  value       = aws_lb_target_group.jenkins_agent.arn
}

output "argocd_target_group_arn" {
  description = "ARN of Argo CD target group"
  value       = aws_lb_target_group.argocd.arn
}
