Phase 5 — Kubernetes Access

Now we move from AWS infrastructure into the Kubernetes layer.

This is an important transition because we'll establish the relationship:

Terraform
   │
   ├── AWS VPC
   ├── EKS Control Plane
   └── EKS Nodes
          │
          ▼
     Kubernetes API
          │
          ▼
      kubectl

We'll configure Terraform so it can obtain the EKS cluster connection information:

EKS endpoint
Cluster CA certificate
AWS authentication
Kubernetes provider

1. Add the Kubernetes provider

Modify:

terraform/versions.tf

Change the required_providers section to:

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
  }
}

Keep your existing AWS provider configuration.

2. Create Kubernetes provider configuration

Create:

terraform/kubernetes.tf

with:

data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(
    data.aws_eks_cluster.this.certificate_authority[0].data
  )

  token = data.aws_eks_cluster_auth.this.token
}

Important

We're not creating Kubernetes resources yet.

This phase is establishing the provider configuration that we'll use in later phases.

3. One important limitation

There is a subtle issue with our current workflow.

Your Terraform state is currently empty because we're deliberately not running terraform apply.

Therefore:

data "aws_eks_cluster" "this"

cannot actually query an EKS cluster that doesn't exist yet.

So don't expect terraform plan to successfully evaluate the Kubernetes provider against a real cluster at this point.

This is intentional.

We're building the project incrementally while avoiding AWS costs.

For now, we'll validate the Terraform configuration structurally.

Run:

terraform -chdir=terraform fmt -recursive

Then:

terraform -chdir=terraform init

Then:

terraform -chdir=terraform validate

If validate succeeds, that's the important result for this phase.

Phase 5 goal

We're establishing this eventual workflow:

AWS
│
├── VPC
│
├── EKS Control Plane
│       │
│       └── Kubernetes API
│
└── Managed Node Group
        │
        ├── Node AZ-A
        └── Node AZ-B


Terraform
    │
    ▼
Kubernetes Provider
    │
    ▼
Kubernetes API
    │
    ▼
Deployments / Services / ConfigMaps / Ingress

Later we'll use the Kubernetes provider to create actual Kubernetes objects.