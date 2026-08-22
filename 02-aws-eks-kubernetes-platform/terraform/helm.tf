
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