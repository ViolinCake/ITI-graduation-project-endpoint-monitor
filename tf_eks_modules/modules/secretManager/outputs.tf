output "rds_secret_arn" {
  description = "ARN of the secret"
  value       = aws_secretsmanager_secret.rds_secret.arn
}


