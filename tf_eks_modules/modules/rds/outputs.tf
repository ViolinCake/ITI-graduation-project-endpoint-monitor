output "rds_endpoint" {
  description = "RDS endpoint address"
  value       = aws_db_instance.mysql.address
}

output "rds_sg_id" {
  description = "RDS Security Group ID"
  value       = aws_security_group.rds_sg.id
}
output "db_name" {
  value = aws_db_instance.mysql.db_name
}

output "db_username" {
  value = aws_db_instance.mysql.username
}

output "db_password" {
  value = aws_db_instance.mysql.password
  sensitive = true
}

output "db_endpoint" {
  value = aws_db_instance.mysql.endpoint
}
