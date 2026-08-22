Phase 4 — EKS Managed Node Group

Now we add the worker nodes.

The architecture becomes:

                  EKS Cluster
               Control Plane
                    │
          ┌─────────┴─────────┐
          │                   │
       AZ-A                 AZ-B
          │                   │
   Private Subnet       Private Subnet
          │                   │
      EC2 Node             EC2 Node
          │                   │
          └─────────┬─────────┘
                    │
              Managed Node Group

We'll use an EKS managed node group, rather than manually creating an Auto Scaling Group. This is the more appropriate EKS-native approach for this project.

We'll use:

Instance type: t3.small
Desired:       2
Minimum:       2
Maximum:       3

We are still not applying.

Create the node group module

mkdir -p terraform/modules/node-group

Create:

terraform/modules/node-group/
├── main.tf
├── variables.tf
└── outputs.tf

# variables.tf

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "node_group_name" {
  description = "EKS managed node group name."
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN for worker nodes."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for worker nodes."
  type        = list(string)
}

variable "instance_types" {
  description = "EC2 instance types for worker nodes."
  type        = list(string)

  default = [
    "t3.small"
  ]
}

variable "desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 3
}

variable "tags" {
  description = "Tags applied to node group resources."
  type        = map(string)
  default     = {}
}

# main.tf

resource "aws_eks_node_group" "this" {
  cluster_name    = var.cluster_name
  node_group_name = var.node_group_name
  node_role_arn   = var.node_role_arn

  subnet_ids = var.subnet_ids

  instance_types = var.instance_types

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  tags = merge(
    var.tags,
    {
      Name = var.node_group_name
    }
  )
}

# outputs.tf

output "node_group_name" {
  description = "EKS managed node group name."
  value       = aws_eks_node_group.this.node_group_name
}

output "node_group_arn" {
  description = "EKS managed node group ARN."
  value       = aws_eks_node_group.this.arn
}

output "status" {
  description = "EKS managed node group status."
  value       = aws_eks_node_group.this.status
}

Connect it to the root

Add to terraform/main.tf:

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

Add to terraform/outputs.tf:

output "node_group_name" {
  description = "EKS managed node group name."
  value       = module.node_group.node_group_name
}

output "node_group_status" {
  description = "EKS managed node group status."
  value       = module.node_group.status
}

Then:

terraform -chdir=terraform fmt -recursive
terraform -chdir=terraform init
terraform -chdir=terraform validate

Finally:

terraform -chdir=terraform plan

We're expecting the plan to increase from:

25 to add

to approximately:

26 to add
0 to change
0 to destroy

because the managed node group is one Terraform resource.