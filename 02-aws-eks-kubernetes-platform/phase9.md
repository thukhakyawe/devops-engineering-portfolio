Phase 9 — Kubernetes Ingress → AWS ALB

Now we're going to connect the application we created in Phase 7 to the AWS Load Balancer Controller.

The target architecture is:

                         Internet
                            │
                            ▼
                  ┌──────────────────┐
                  │       ALB        │
                  │  HTTP :80        │
                  └────────┬─────────┘
                           │
                           ▼
                AWS Load Balancer
                    Controller
                           │
                           ▼
                  Kubernetes Ingress
                           │
                           ▼
                    Service :80
                           │
                 ┌─────────┴─────────┐
                 ▼                   ▼
             Pod :80              Pod :80
          platform-api         platform-api

This is a major milestone because we're no longer just creating an EKS cluster—we're defining how an application is exposed through AWS.

9A — Create the Ingress module

Create:

mkdir -p terraform/modules/ingress

Files:

terraform/modules/ingress/
├── main.tf
├── variables.tf
└── outputs.tf

# variables.tf
variable "namespace" {
  description = "Kubernetes namespace containing the application."
  type        = string
}

variable "name" {
  description = "Ingress name."
  type        = string
}

variable "service_name" {
  description = "Kubernetes Service receiving traffic."
  type        = string
}

variable "service_port" {
  description = "Kubernetes Service port."
  type        = number
  default     = 80
}


# main.tf
resource "kubernetes_ingress_v1" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace

    annotations = {
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"

      "alb.ingress.kubernetes.io/target-type" = "ip"

      "alb.ingress.kubernetes.io/listen-ports" = jsonencode([
        {
          HTTP = 80
        }
      ])
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = var.service_name

              port {
                number = var.service_port
              }
            }
          }
        }
      }
    }
  }
}


# outputs.tf
output "ingress_name" {
  description = "Kubernetes Ingress name."
  value       = kubernetes_ingress_v1.this.metadata[0].name
}

9B — Connect the module

Add to:

terraform/main.tf

module "ingress" {
  source = "./modules/ingress"

  namespace = "application"

  name = "platform-api"

  service_name = module.application.service_name

  service_port = 80
}

Add to:

terraform/outputs.tf

output "application_ingress" {
  description = "Kubernetes Ingress name for the application."
  value       = module.ingress.ingress_name
}

9C — Format and validate

Run:

terraform -chdir=terraform fmt -recursive

Then:

terraform -chdir=terraform init

Then:

terraform -chdir=terraform validate

Expected:

Success! The configuration is valid.
Again: don't apply

The Ingress requires the Kubernetes API and AWS Load Balancer Controller to actually exist.

We're deliberately building the entire project without provisioning AWS resources.

What we're learning here

This phase introduces a core Kubernetes concept:

Kubernetes doesn't directly create the ALB.

Instead:

Ingress
   │
   ▼
AWS Load Balancer Controller
   │
   ▼
AWS APIs
   │
   ▼
Application Load Balancer

That's an important distinction to understand for real DevOps/platform work.

Current architecture

After Phase 9:

                    AWS
                     │
              ┌──────▼──────┐
              │     VPC     │
              └──────┬──────┘
                     │
              ┌──────▼──────┐
              │     EKS     │
              └──────┬──────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
      Node         Node       Controller
        │            │            │
        └────────────┼────────────┘
                     │
                Kubernetes
                     │
             ┌───────┴───────┐
             │               │
         Namespace       Namespace
        application       monitoring
             │
       ┌─────┴─────┐
       │           │
   Deployment   Service
       │           │
   ┌───┴───┐       │
   │       │       │
  Pod     Pod ◄────┘
       │
       ▼
    Ingress
       │
       ▼
      ALB

Current progress
01  Networking                         ✅
02  EKS IAM                            ✅
03  EKS Control Plane                  ✅
04  EKS Managed Node Group             ✅
05  Kubernetes Provider                ✅
06  Kubernetes Namespaces              ✅
07  Kubernetes Application             ✅
08A AWS LBC IAM Role + Pod Identity    ✅
08B AWS LBC IAM Policy                 ✅
08C Helm Provider                      ✅
08D Helm → EKS authentication          ✅
08E AWS Load Balancer Controller       ✅
09  Kubernetes Ingress → ALB           ✅