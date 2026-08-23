
provider "helm" {
  kubernetes = {
    host = module.eks.cluster_endpoint

    cluster_ca_certificate = base64decode(
      module.eks.cluster_certificate_authority_data
    )

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"

      command = "aws"

      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name,
        "--region",
        var.aws_region
      ]
    }
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
    }
  ]

  depends_on = [
    module.eks,
    module.karpenter
  ]
}
