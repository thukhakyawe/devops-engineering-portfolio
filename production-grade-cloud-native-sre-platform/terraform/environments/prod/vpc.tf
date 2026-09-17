module "vpc" {
  source = "../../modules/vpc"

  name = local.name_prefix

  vpc_cidr = "10.0.0.0/16"

  availability_zones = [
    "ap-southeast-1a",
    "ap-southeast-1b"
  ]

  public_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]

  private_app_subnets = [
    "10.0.11.0/24",
    "10.0.12.0/24"
  ]

  private_db_subnets = [
    "10.0.21.0/24",
    "10.0.22.0/24"
  ]

  tags = local.common_tags
}
