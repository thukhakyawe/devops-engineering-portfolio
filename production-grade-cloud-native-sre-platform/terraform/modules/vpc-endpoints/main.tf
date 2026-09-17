resource "aws_vpc_endpoint" "s3" {
  vpc_id = var.vpc_id

  service_name = "com.amazonaws.ap-southeast-1.s3"

  vpc_endpoint_type = "Gateway"

  route_table_ids = var.private_route_table_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-s3-endpoint"
    }
  )
}


resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id = var.vpc_id

  service_name = "com.amazonaws.ap-southeast-1.ecr.api"

  vpc_endpoint_type = "Interface"

  subnet_ids = var.private_subnet_ids

  security_group_ids = [
    var.endpoint_security_group_id
  ]

  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-ecr-api-endpoint"
    }
  )
}


resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id = var.vpc_id

  service_name = "com.amazonaws.ap-southeast-1.ecr.dkr"

  vpc_endpoint_type = "Interface"

  subnet_ids = var.private_subnet_ids

  security_group_ids = [
    var.endpoint_security_group_id
  ]

  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-ecr-dkr-endpoint"
    }
  )
}


resource "aws_vpc_endpoint" "ssm" {
  vpc_id = var.vpc_id

  service_name = "com.amazonaws.ap-southeast-1.ssm"

  vpc_endpoint_type = "Interface"

  subnet_ids = var.private_subnet_ids

  security_group_ids = [
    var.endpoint_security_group_id
  ]

  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-ssm-endpoint"
    }
  )
}


resource "aws_vpc_endpoint" "ssm_messages" {
  vpc_id = var.vpc_id

  service_name = "com.amazonaws.ap-southeast-1.ssmmessages"

  vpc_endpoint_type = "Interface"

  subnet_ids = var.private_subnet_ids

  security_group_ids = [
    var.endpoint_security_group_id
  ]

  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-ssm-messages-endpoint"
    }
  )
}


resource "aws_vpc_endpoint" "ec2_messages" {
  vpc_id = var.vpc_id

  service_name = "com.amazonaws.ap-southeast-1.ec2messages"

  vpc_endpoint_type = "Interface"

  subnet_ids = var.private_subnet_ids

  security_group_ids = [
    var.endpoint_security_group_id
  ]

  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-ec2-messages-endpoint"
    }
  )
}
