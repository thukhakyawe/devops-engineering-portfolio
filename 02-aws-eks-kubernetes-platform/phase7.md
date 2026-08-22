Phase 7 — Kubernetes Application

Now we start building an actual Kubernetes workload.

We'll create a small application with:

                    Kubernetes
                        │
                application namespace
                        │
              ┌─────────▼─────────┐
              │    Deployment     │
              │                   │
              │   ┌───────────┐   │
              │   │   Pod     │   │
              │   │           │   │
              │   │ Container │   │
              │   └───────────┘   │
              └─────────┬─────────┘
                        │
                        ▼
                    Service
                        │
                        ▼
                  Cluster network

We'll deliberately use good Kubernetes practices from the beginning:

Deployment
Multiple replicas
Resource requests
Resource limits
Liveness probe
Readiness probe
Environment variables
Service
Dedicated namespace

1. Create the application module
mkdir -p terraform/modules/application

Create:

terraform/modules/application/
├── main.tf
├── variables.tf
└── outputs.tf

# variables.tf

variable "namespace" {
  description = "Kubernetes namespace for the application."
  type        = string
  default     = "application"
}

variable "name" {
  description = "Application name."
  type        = string
  default     = "platform-api"
}

variable "image" {
  description = "Container image."
  type        = string
  default     = "nginx:1.27-alpine"
}

variable "replicas" {
  description = "Number of application replicas."
  type        = number
  default     = 2
}

variable "container_port" {
  description = "Application container port."
  type        = number
  default     = 80
}

# main.tf

resource "kubernetes_deployment" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace

    labels = {
      app = var.name
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = var.name
      }
    }

    template {
      metadata {
        labels = {
          app = var.name
        }
      }

      spec {
        container {
          name  = var.name
          image = var.image

          port {
            container_port = var.container_port
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }

            limits = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/"
              port = var.container_port
            }

            initial_delay_seconds = 5
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/"
              port = var.container_port
            }

            initial_delay_seconds = 10
            period_seconds        = 20
          }

          env {
            name  = "ENVIRONMENT"
            value = "dev"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  spec {
    selector = {
      app = var.name
    }

    port {
      port        = 80
      target_port = var.container_port
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}


# outputs.tf

output "deployment_name" {
  description = "Application Deployment name."
  value       = kubernetes_deployment.this.metadata[0].name
}

output "service_name" {
  description = "Application Service name."
  value       = kubernetes_service.this.metadata[0].name
}

output "namespace" {
  description = "Application namespace."
  value       = var.namespace
}

2. Connect the application module

Add this to terraform/main.tf:

module "application" {
  source = "./modules/application"

  namespace = "application"

  name = "platform-api"

  image = "nginx:1.27-alpine"

  replicas = 2

  container_port = 80
}

Then add to terraform/outputs.tf:

output "application_deployment" {
  description = "Application Deployment name."
  value       = module.application.deployment_name
}

output "application_service" {
  description = "Application Service name."
  value       = module.application.service_name
}

3. Format and validate

Run:

terraform -chdir=terraform fmt -recursive

Then:

terraform -chdir=terraform init

Then:

terraform -chdir=terraform validate

You should get:

Success! The configuration is valid.
Don't run terraform plan yet

This module contains:

kubernetes_deployment
kubernetes_service

which require a real Kubernetes API server.

Our EKS cluster hasn't been created because we're intentionally avoiding terraform apply.

So validation is the correct checkpoint here.

One architectural point

We're intentionally keeping the application module separate:

terraform/
├── modules/
│   ├── networking/
│   ├── iam/
│   ├── eks/
│   ├── node-group/
│   ├── namespaces/
│   └── application/

This is teaching you an important real-world distinction:

AWS infrastructure layer

networking
iam
eks
node-group

versus the

Kubernetes workload layer

namespaces
application

Later we'll add:

ingress
helm
monitoring
autoscaling
security

and eventually CI/CD + GitOps.