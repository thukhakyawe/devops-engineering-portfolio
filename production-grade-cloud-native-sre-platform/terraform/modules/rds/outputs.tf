output "db_instance_id" {
  description = "RDS DB instance identifier"
  value       = aws_db_instance.this.id
}

output "db_instance_arn" {
  description = "RDS DB instance ARN"
  value       = aws_db_instance.this.arn
}

output "db_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "RDS database port"
  value       = aws_db_instance.this.port
}

output "db_subnet_group_name" {
  description = "RDS DB subnet group name"
  value       = aws_db_subnet_group.this.name
}
