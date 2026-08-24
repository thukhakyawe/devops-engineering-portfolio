resource "aws_secretsmanager_secret" "application" {
  name = "${var.environment}/platform-api/database"

  description = "Database credentials for the platform API."

  tags = {
    Environment = var.environment
    Application = "platform-api"
  }
}

resource "aws_secretsmanager_secret_version" "application" {
  secret_id = aws_secretsmanager_secret.application.id

  secret_string = jsonencode({
    username = var.database_username
    password = var.database_password
  })
}