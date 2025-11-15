resource "aws_secretsmanager_secret" "rds_secret" {
  name = "${var.project_name}/rds-credentials"

  tags = {
    Project = var.project_name
  }
}

resource "aws_secretsmanager_secret_version" "rds_secret_version" {
  secret_id     = aws_secretsmanager_secret.rds_secret.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = var.rds_endpoint
    port     = 3306
    dbname   = var.db_name
  })
}
