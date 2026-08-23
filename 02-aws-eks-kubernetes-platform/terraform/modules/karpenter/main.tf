
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role" "controller" {
  name               = "${var.cluster_name}-karpenter-controller"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-karpenter-controller"
    }
  )
}

# Now add the controller permissions:

data "aws_iam_policy_document" "controller" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateTags",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
      "ec2:RunInstances",
      "ec2:TerminateInstances"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      var.node_role_arn
    ]
  }
}

resource "aws_iam_policy" "controller" {
  name        = "${var.cluster_name}-karpenter-controller"
  description = "Permissions for Karpenter to provision EKS compute."

  policy = data.aws_iam_policy_document.controller.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "controller" {
  role       = aws_iam_role.controller.name
  policy_arn = aws_iam_policy.controller.arn
}

resource "aws_eks_pod_identity_association" "controller" {
  cluster_name    = var.cluster_name
  namespace       = "karpenter"
  service_account = "karpenter"
  role_arn        = aws_iam_role.controller.arn
}