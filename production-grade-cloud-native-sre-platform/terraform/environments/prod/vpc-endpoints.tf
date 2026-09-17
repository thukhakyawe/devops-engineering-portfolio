module "vpc_endpoints" {
  source = "../../modules/vpc-endpoints"

  name = local.name_prefix

  vpc_id = module.vpc.vpc_id

  private_subnet_ids = module.vpc.private_app_subnet_ids

  private_route_table_ids = [
    module.vpc.private_app_route_table_id
  ]

  endpoint_security_group_id = aws_security_group.vpc_endpoints.id

  tags = local.common_tags
}
