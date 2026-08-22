Project 2 — AWS EKS + Kubernetes Platform

The goal is not simply to "create an EKS cluster." We will build a small but professional EKS platform, using Terraform to provision AWS infrastructure and Kubernetes manifests to operate workloads.

What you will learn
Terraform
   │
   ├── VPC / networking
   ├── IAM
   ├── EKS control plane
   ├── EKS managed node groups
   └── Security
          │
          ▼
       AWS EKS
          │
          ├── Kubernetes namespaces
          ├── Deployments
          ├── Services
          ├── ConfigMaps
          ├── Secrets
          ├── RBAC
          └── Ingress



Step 1 — Create Project 2

Inside:

devops-engineering-portfolio/

create:

02-aws-eks-kubernetes-platform/

Run:

cd "/mnt/d/My Carrier/Carrier/GitHub Projects/devops-engineering-portfolio"


mkdir -p 02-aws-eks-kubernetes-platform

Then create the initial structure:

cd 02-aws-eks-kubernetes-platform


mkdir -p \
  terraform \
  kubernetes/namespaces \
  kubernetes/workloads \
  kubernetes/services \
  kubernetes/config \
  kubernetes/rbac \
  docs \
  scripts \
  tests

Our structure will eventually look like:

02-aws-eks-kubernetes-platform/
│
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   ├── terraform.tfvars.example
│   │
│   └── modules/
│       ├── networking/
│       ├── eks/
│       └── iam/
│
├── kubernetes/
│   ├── namespaces/
│   ├── workloads/
│   ├── services/
│   ├── config/
│   └── rbac/
│
├── docs/
│   ├── architecture.md
│   ├── deployment.md
│   ├── kubernetes.md
│   └── security.md
│
├── scripts/
│
├── tests/
│
├── .gitignore
└── README.md

Step 2 — Important design decision

We are not going to copy Project 1's entire Terraform platform and simply add EKS.

Project 2 should teach you how to design Kubernetes infrastructure separately.

The architecture will be approximately:

                         Internet
                            │
                            ▼
                     AWS Load Balancer
                            │
                            ▼
                    ┌───────────────┐
                    │     EKS       │
                    │ Control Plane │
                    └───────┬───────┘
                            │
                 ┌──────────┴──────────┐
                 │                     │
             Node Group A          Node Group B
             AZ-a                  AZ-b
                 │                     │
                 └──────────┬──────────┘
                            │
                       Kubernetes
                        Workloads

AWS networking:

                    VPC
                     │
        ┌────────────┼────────────┐
        │            │            │
      AZ-a         AZ-b        AZ-c
        │            │            │
     public       public       public
     private      private      private
        │            │            │
        └──────── EKS ────────────┘

We'll initially use two Availability Zones to keep the project understandable and avoid unnecessary cost.

Step 3 — Cost-conscious approach

This is important given what we learned during Project 1.

We will design and validate everything without requiring:

terraform apply

Our workflow will be:

Write Terraform
      ↓
terraform fmt
      ↓
terraform init
      ↓
terraform validate
      ↓
terraform plan
      ↓
security scanning
      ↓
GitHub Actions
      ↓
Kubernetes manifest validation

No AWS resources need to be created just to demonstrate that you understand the architecture.

If later you want a real EKS deployment, we'll explicitly identify the expected AWS costs before applying.

Step 4 — Terraform architecture

Project 2's Terraform will eventually have:

terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── terraform.tfvars.example
│
└── modules/
    ├── networking/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── eks/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    └── iam/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf

The root module will compose them:

root
 │
 ├── networking
 │
 ├── iam
 │
 └── eks

This is deliberately similar to the module pattern you learned in Project 1.

Step 5 — Kubernetes architecture

We'll then introduce Kubernetes itself:

kubernetes/
│
├── namespaces/
│   └── platform.yaml
│
├── workloads/
│   └── app-deployment.yaml
│
├── services/
│   └── app-service.yaml
│
├── config/
│   ├── app-config.yaml
│   └── app-secret.example.yaml
│
└── rbac/
    └── app-service-account.yaml

You'll learn the relationship:

Deployment
    │
    ▼
   Pods
    │
    ▼
 Service
    │
    ▼
Load Balancer / Ingress
Step 6 — First hands-on task

For now, don't write the Terraform yet.

From:

devops-engineering-portfolio/02-aws-eks-kubernetes-platform/

run:

pwd

then:

find . -maxdepth 3 -type d | sort

We should see:

.
./docs
./kubernetes
./kubernetes/config
./kubernetes/namespaces
./kubernetes/rbac
./kubernetes/services
./kubernetes/workloads
./scripts
./terraform
./tests

Once that is correct, we'll build Phase 1: EKS Terraform foundation.

And this time we'll do it systematically:

Phase 1 → Networking

Phase 2 → IAM

Phase 3 → EKS control plane

Phase 4 → Managed node groups

Phase 5 → Kubernetes configuration

Phase 6 → Application deployment

Phase 7 → Load balancing / Ingress

Phase 8 → Security

Phase 9 → Validation + CI

Phase 10 → Documentation

No terraform apply required.