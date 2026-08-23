
resource "aws_secretsmanager_secret" "application" {
  name = "${var.environment}/platform-api/database"

  description = "Database credentials for the platform API."

  tags = {
    Environment = var.environment
    Application = "platform-api"
  }
}