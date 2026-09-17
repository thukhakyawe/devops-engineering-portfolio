module "iam" {
  source = "../../modules/iam"

  name = local.name_prefix

  tags = local.common_tags
}
