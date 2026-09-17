output "vpc_id" {
  description = "Project VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Project public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "Project private application subnet IDs"
  value       = module.vpc.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "Project private database subnet IDs"
  value       = module.vpc.private_db_subnet_ids
}

output "nat_gateway_id" {
  description = "Project NAT Gateway ID"
  value       = module.vpc.nat_gateway_id
}

output "ec2_role_name" {
  description = "EC2 IAM role name"
  value       = module.iam.ec2_role_name
}

output "ec2_role_arn" {
  description = "EC2 IAM role ARN"
  value       = module.iam.ec2_role_arn
}

output "alb_security_group_id" {
  value = module.security_groups.alb_security_group_id
}

output "app_security_group_id" {
  value = module.security_groups.app_security_group_id
}

output "db_security_group_id" {
  value = module.security_groups.db_security_group_id
}

output "private_app_route_table_id" {
  value = module.vpc.private_app_route_table_id
}