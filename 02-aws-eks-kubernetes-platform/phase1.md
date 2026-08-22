Phase 1: EKS Networking Foundation

We'll start with the VPC and subnet layer. Don't create the EKS cluster yet.

Target architecture
AWS VPC: 10.20.0.0/16
│
├── Availability Zone A
│   ├── Public subnet  10.20.1.0/24
│   └── Private subnet 10.20.11.0/24
│
└── Availability Zone B
    ├── Public subnet  10.20.2.0/24
    └── Private subnet 10.20.12.0/24

For EKS, the worker nodes will eventually live in the private subnets.

We'll use:

Internet Gateway for public connectivity
NAT Gateway for private subnet outbound access
Route tables
Two AZs
Terraform module structure
No terraform apply
1. Create the networking module

From:

02-aws-eks-kubernetes-platform/

run:

mkdir -p terraform/modules/networking

Create:

terraform/
└── modules/
    └── networking/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf

2. variables.tf

Create:

variable "name" {
  description = "Name prefix for networking resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the EKS VPC."
  type        = string
}

variable "availability_zones" {
  description = "Availability Zones for the EKS cluster."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to networking resources."
  type        = map(string)
  default     = {}
}

3. main.tf

Use:

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-vpc"
    }
  )
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-igw"
    }
  )
}

resource "aws_subnet" "public" {
  for_each = zipmap(
    var.availability_zones,
    var.public_subnet_cidrs
  )

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name                     = "${var.name}-public-${each.key}"
      Tier                     = "public"
      "kubernetes.io/role/elb" = "1"
    }
  )
}

resource "aws_subnet" "private" {
  for_each = zipmap(
    var.availability_zones,
    var.private_subnet_cidrs
  )

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(
    var.tags,
    {
      Name                              = "${var.name}-private-${each.key}"
      Tier                              = "private"
      "kubernetes.io/role/internal-elb" = "1"
    }
  )
}

resource "aws_eip" "nat" {
  for_each = toset(var.availability_zones)

  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-nat-eip-${each.key}"
    }
  )
}

resource "aws_nat_gateway" "this" {
  for_each = toset(var.availability_zones)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  depends_on = [
    aws_internet_gateway.this
  ]

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-nat-${each.key}"
    }
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-public-rt"
    }
  )
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  for_each = toset(var.availability_zones)

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[each.key].id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-private-rt-${each.key}"
    }
  )
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id = each.value.id

  route_table_id = aws_route_table.private[
    each.key
  ].id
}

4. outputs.tf

output "vpc_id" {
  description = "ID of the EKS VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the EKS VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "availability_zones" {
  description = "Availability Zones used by the VPC."
  value       = var.availability_zones
}

5. Why the Kubernetes subnet tags matter

These two tags are intentional:

"kubernetes.io/role/elb" = "1"

and:

"kubernetes.io/role/internal-elb" = "1"

They tell AWS/Kubernetes which subnets are appropriate for load balancers.

We'll use them later when we deploy Kubernetes Services/Ingress.

6. Cost note

There is one important issue here given your decision not to apply:

NAT Gateway
+
Elastic IP

NAT Gateways incur AWS charges when actually created and used.

So Phase 1 can be fully validated without creating anything in AWS.

We will keep the architecture realistic, but we won't run:

terraform apply

7. Next step

After creating those three files, run from the Project 2 directory:

terraform fmt -recursive terraform/

Then:

terraform fmt -check -recursive terraform/

Don't run terraform init yet unless we've created the root Terraform files. The next part of Phase 1 will be creating:

terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
└── terraform.tfvars.example

which will connect this networking module to the root configuration.

---

Now we connect it to the root Terraform configuration.

Phase 1 — Root Terraform configuration

From:

02-aws-eks-kubernetes-platform/

your structure should now be:

02-aws-eks-kubernetes-platform/
├── terraform/
│   └── modules/
│       └── networking/
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
├── kubernetes/
├── docs/
├── scripts/
└── tests/

1. Create terraform/versions.tf

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "devops-engineering-portfolio"
      Component   = "eks-platform"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "thukhakyawe"
    }
  }
}

2. Create terraform/variables.tf

variable "aws_region" {
  description = "AWS region for the EKS platform."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Project name."
  type        = string
  default     = "eks-platform"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the EKS VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "Availability Zones used by the EKS platform."
  type        = list(string)

  default = [
    "ap-southeast-1a",
    "ap-southeast-1b"
  ]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets."
  type        = list(string)

  default = [
    "10.20.1.0/24",
    "10.20.2.0/24"
  ]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private EKS subnets."
  type        = list(string)

  default = [
    "10.20.11.0/24",
    "10.20.12.0/24"
  ]
}

3. Create terraform/main.tf


locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

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

4. Create terraform/outputs.tf

output "vpc_id" {
  description = "ID of the EKS VPC."
  value       = module.networking.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the EKS VPC."
  value       = module.networking.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private EKS subnets."
  value       = module.networking.private_subnet_ids
}

output "availability_zones" {
  description = "Availability Zones used by the EKS platform."
  value       = module.networking.availability_zones
}

5. Create terraform/terraform.tfvars.example

aws_region  = "ap-southeast-1"
project_name = "eks-platform"
environment  = "dev"

vpc_cidr = "10.20.0.0/16"

availability_zones = [
  "ap-southeast-1a",
  "ap-southeast-1b"
]

public_subnet_cidrs = [
  "10.20.1.0/24",
  "10.20.2.0/24"
]

private_subnet_cidrs = [
  "10.20.11.0/24",
  "10.20.12.0/24"
]

Don't create a real terraform.tfvars; the example file is enough for now.

6. Validate Phase 1

From:

02-aws-eks-kubernetes-platform/

run:

terraform -chdir=terraform fmt -recursive

Then:

terraform -chdir=terraform init -backend=false

Then:

terraform -chdir=terraform validate

Expected:

Success! The configuration is valid.

Finally:

terraform -chdir=terraform plan

Important

Because we are using:

-backend=false

and we're not applying, this is still a validation exercise. The plan should show the networking resources that would be created, but nothing will be created in AWS.

You should expect roughly:

aws_vpc
aws_internet_gateway
aws_subnet.public
aws_subnet.private
aws_eip.nat
aws_nat_gateway
aws_route_table.public
aws_route_table.private
aws_route_table_association.public
aws_route_table_association.private

After plan, check that there are no errors.

Also run:

find terraform \
  \( -name ".terraform" \
  -o -name "terraform.tfstate" \
  -o -name "terraform.tfstate.backup" \
  -o -name "tfplan" \
  \) -print