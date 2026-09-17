module "security_groups" {
  source = "../../modules/security-groups"

  name   = local.name_prefix
  vpc_id = module.vpc.vpc_id
  tags   = local.common_tags
}
