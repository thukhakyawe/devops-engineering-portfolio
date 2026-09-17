resource "aws_security_group" "vpc_endpoints" {
  name        = "${local.name_prefix}-vpc-endpoints-sg"
  description = "Security group for AWS VPC interface endpoints"
  vpc_id      = module.vpc.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-vpc-endpoints-sg"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoints_https_from_app" {
  security_group_id = aws_security_group.vpc_endpoints.id

  referenced_security_group_id = module.security_groups.app_security_group_id

  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443

  description = "Allow HTTPS from application workloads"
}

resource "aws_vpc_security_group_egress_rule" "vpc_endpoints_all" {
  security_group_id = aws_security_group.vpc_endpoints.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  description = "Allow endpoint response traffic"
}
