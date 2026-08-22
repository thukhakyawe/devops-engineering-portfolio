Phase 2 — EKS IAM

Now we're going to learn an important AWS/EKS concept:

The EKS control plane and the EKS worker nodes require different IAM roles.

We'll create:

EKS Control Plane
       │
       ▼
aws_iam_role.eks
       │
       ├── AmazonEKSClusterPolicy
       └── AmazonEKSVPCResourceController
       
Worker Nodes
       │
       ▼
aws_iam_role.nodes
       │
       ├── AmazonEKSWorkerNodePolicy
       ├── AmazonEC2ContainerRegistryPullOnly
       └── AmazonEKS_CNI_Policy

We'll keep IAM in its own module, just as we did with Project 1.

1. Create the IAM module

From:

02-aws-eks-kubernetes-platform/

run:

mkdir -p terraform/modules/iam

Create:

terraform/modules/iam/
├── main.tf
├── variables.tf
└── outputs.tf

# variables.tf

variable "name" {
  description = "Name prefix for EKS IAM resources."
  type        = string
}

variable "tags" {
  description = "Tags applied to IAM resources."
  type        = map(string)
  default     = {}
}

# main.tf

data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}

resource "aws_iam_role" "eks" {
  name               = "${var.name}-eks-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-eks-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_vpc_controller" {
  role       = aws_iam_role.eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}


data "aws_iam_policy_document" "nodes_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}

resource "aws_iam_role" "nodes" {
  name               = "${var.name}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.nodes_assume_role.json

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-eks-node-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "nodes_worker" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "nodes_ecr" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "nodes_cni" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# outputs.tf

output "eks_role_arn" {
  description = "IAM role ARN used by the EKS control plane."
  value       = aws_iam_role.eks.arn
}

output "eks_role_name" {
  description = "IAM role name used by the EKS control plane."
  value       = aws_iam_role.eks.name
}

output "node_role_arn" {
  description = "IAM role ARN used by EKS worker nodes."
  value       = aws_iam_role.nodes.arn
}

output "node_role_name" {
  description = "IAM role name used by EKS worker nodes."
  value       = aws_iam_role.nodes.name
}

2. Connect IAM to the root module

Add this to:

terraform/main.tf

after the networking module:

module "iam" {
  source = "./modules/iam"

  name = local.name_prefix

  tags = {
    Environment = var.environment
  }
}

Then add these outputs to:

terraform/outputs.tf

output "eks_role_arn" {
  description = "IAM role ARN used by the EKS control plane."
  value       = module.iam.eks_role_arn
}

output "node_role_arn" {
  description = "IAM role ARN used by EKS worker nodes."
  value       = module.iam.node_role_arn
}


3. Format and validate

Run:

terraform -chdir=terraform fmt -recursive

Then:

terraform -chdir=terraform validate
terraform -chdir=terraform init

Then:

terraform -chdir=terraform plan

We are still not applying anything.

The plan should now contain the networking resources plus the IAM resources.