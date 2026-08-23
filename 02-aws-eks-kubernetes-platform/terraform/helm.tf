
data "aws_eks_cluster" "helm" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "helm" {
  name = module.eks.cluster_name
}

provider "helm" {
  kubernetes = {
    host = data.aws_eks_cluster.helm.endpoint
    cluster_ca_certificate = base64decode(
      data.aws_eks_cluster.helm.certificate_authority[0].data
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
    }
  ]

  depends_on = [
    module.eks,
    module.karpenter
  ]
}
