resource "aws_security_group" "eks_nodes" {
  name        = "${var.name}-eks-nodes"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name                     = "${var.name}-eks-nodes"
      "karpenter.sh/discovery" = var.name
    }
  )
}