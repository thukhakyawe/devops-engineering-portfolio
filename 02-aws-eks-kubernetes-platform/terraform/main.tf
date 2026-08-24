locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# Module networking

module "networking" {
  source = "./modules/networking"

  name = local.name_prefix

  vpc_cidr = var.vpc_cidr

  availability_zones = var.availability_zones

  public_subnet_cidrs = var.public_subnet_cidrs

  private_subnet_cidrs = var.private_subnet_cidrs

  tags = {
    Environment = var.environment
  }
}

# Module iam

module "iam" {
  source = "./modules/iam"

  name = local.name_prefix

  tags = {
    Environment = var.environment
  }
}

# Module EKS

module "eks" {
  source = "./modules/eks"

  name = local.name_prefix

  kubernetes_version = "1.33"

  subnet_ids = module.networking.private_subnet_ids

  cluster_role_arn = module.iam.eks_role_arn

  tags = {
    Environment = var.environment
  }
}

# Module node-group

module "node_group" {
  source = "./modules/node-group"

  cluster_name = module.eks.cluster_name

  node_group_name = "${local.name_prefix}-nodes"

  node_role_arn = module.iam.node_role_arn

  subnet_ids = module.networking.private_subnet_ids

  instance_types = [
    "t3.small"
  ]

  desired_size = 2
  min_size     = 2
  max_size     = 3

  tags = {
    Environment = var.environment
  }
}

# Module namespaces

module "namespaces" {
  source = "./modules/namespaces"

  namespaces = [
    "platform",
    "application",
    "monitoring"
  ]
}

# Module application-config
module "application_config" {
  source = "./modules/application-config"

  namespace     = "application"
  environment   = var.environment
  database_host = "postgres.application.svc.cluster.local"
  database_port = 5432
  aws_region    = var.aws_region
}

module "application" {
  source = "./modules/application"

  namespace = "application"

  name = "platform-api"

  image = "nginx:1.27-alpine"

  replicas = 2

  container_port = 80

  config_map_name = module.application_config.config_map_name
}

# Module aws_load_balancer_controller

module "aws_load_balancer_controller" {
  source = "./modules/aws-load-balancer-controller"

  name = module.eks.cluster_name

  tags = {
    Environment = var.environment
  }
}

# Module ingress
module "ingress" {
  source = "./modules/ingress"

  namespace = "application"

  name = "platform-api"

  service_name = module.application.service_name

  service_port = 80
}



# Module external_secrets

module "external_secrets" {
  source = "./modules/external-secrets"

  name = module.eks.cluster_name

  tags = {
    Environment = var.environment
  }
}

# Module karpenter
module "karpenter" {
  source = "./modules/karpenter"

  cluster_name = module.eks.cluster_name

  node_role_arn = module.iam.node_role_arn

  tags = {
    Environment = var.environment
  }
}
