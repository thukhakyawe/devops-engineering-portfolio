resource "aws_db_subnet_group" "this" {
  name = "${var.name}-db-subnet-group"

  subnet_ids = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-db-subnet-group"
    }
  )
}


resource "aws_db_instance" "this" {
  identifier = "${var.name}-mysql"

  engine         = "mysql"
  engine_version = var.engine_version

  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"

  storage_encrypted = true

  db_name  = var.db_name
  username = var.username

  manage_master_user_password = true

  port = 3306

  db_subnet_group_name = aws_db_subnet_group.this.name

  vpc_security_group_ids = var.security_group_ids

  multi_az = var.multi_az

  publicly_accessible = false

  backup_retention_period = var.backup_retention_period

  backup_window           = "18:00-19:00"
  maintenance_window      = "sun:19:00-sun:20:00"

  auto_minor_version_upgrade = true

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot

  copy_tags_to_snapshot = true

  enabled_cloudwatch_logs_exports = [
    "error",
    "general",
    "slowquery"
  ]

  performance_insights_enabled = false

  monitoring_interval = 60
  monitoring_role_arn = var.monitoring_role_arn

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-mysql"
    }
  )
}
