module "rds" {
  source = "../../modules/rds"

  name = local.name_prefix

  subnet_ids = module.vpc.private_db_subnet_ids

  security_group_ids = [
    module.security_groups.db_security_group_id
  ]

  db_name  = "appdb"
  username = "appadmin"

  instance_class = "db.t4g.micro"

  engine_version = "8.0"

  allocated_storage     = 20
  max_allocated_storage = 100

  backup_retention_period = 7

  multi_az = false

  deletion_protection = false
  skip_final_snapshot = true

  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  tags = local.common_tags
}