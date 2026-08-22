Phase 3 — EKS Control Plane

Now we're getting to the core of Project 2:

                    AWS
                     │
              ┌──────▼──────┐
              │     EKS     │
              │  Control    │
              │   Plane     │
              └──────┬──────┘
                     │
          ┌──────────┴──────────┐
          │                     │
      Private AZ-A          Private AZ-B
          │                     │
      Worker nodes         Worker nodes

We will create the EKS cluster itself, but not the worker nodes yet.

Create the EKS module

From the project root:

mkdir -p terraform/modules/eks

Create:

terraform/modules/eks/
├── main.tf
├── variables.tf
└── outputs.tf

# variables.tf

variable "name" {
  description = "EKS cluster name."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.33"
}

variable "subnet_ids" {
  description = "Private subnet IDs for the EKS control plane."
  type        = list(string)
}

variable "cluster_role_arn" {
  description = "IAM role ARN for the EKS control plane."
  type        = string
}

variable "tags" {
  description = "Tags applied to EKS resources."
  type        = map(string)
  default     = {}
}

# main.tf

resource "aws_eks_cluster" "this" {
  name     = var.name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids = var.subnet_ids
  }

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}

# outputs.tf

output "cluster_id" {
  description = "EKS cluster ID."
  value       = aws_eks_cluster.this.id
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "EKS Kubernetes API endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_version" {
  description = "Kubernetes version."
  value       = aws_eks_cluster.this.version
}

Connect it to the root module

Add to terraform/main.tf:

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

Then add to terraform/outputs.tf:

output "eks_cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN."
  value       = module.eks.cluster_arn
}

output "eks_cluster_endpoint" {
  description = "EKS Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_version" {
  description = "Kubernetes version."
  value       = module.eks.cluster_version
}

Validate

Run:

terraform -chdir=terraform fmt -recursive
terraform -chdir=terraform init
terraform -chdir=terraform validate

Then:

terraform -chdir=terraform plan

Again, do not apply.

Your plan should now increase from:

24 to add

to approximately:

25 to add
0 to change
0 to destroy

because the EKS cluster itself is one additional resource.