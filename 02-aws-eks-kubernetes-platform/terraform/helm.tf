data "aws_eks_cluster_auth" "helm" {
  name = module.eks.cluster_name

  depends_on = [
    module.eks
  ]
}

provider "helm" {
  kubernetes = {
    host = module.eks.cluster_endpoint

    cluster_ca_certificate = base64decode(
      module.eks.cluster_certificate_authority_data
    )

    token = data.aws_eks_cluster_auth.helm.token
  }
}

resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = "karpenter"
  create_namespace = true

  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.12.1"

  set = [
    {
      name  = "settings.clusterName"
      value = module.eks.cluster_name
    },
    {
      name  = "settings.interruptionQueue"
      value = "${module.eks.cluster_name}-karpenter"
    },
    {
      name  = "serviceAccount.name"
      value = "karpenter"
    },
    {
      name  = "settings.aws.region"
      value = var.aws_region
    }
  ]

  depends_on = [
    module.eks
  ]
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true

  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = "0.20.2"

  set = [
    {
      name  = "installCRDs"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "external-secrets"
    }
  ]

  depends_on = [
    module.eks,
    module.external_secrets
  ]
}