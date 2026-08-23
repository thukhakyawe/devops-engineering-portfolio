Phase 13 — Kubernetes Autoscaling (HPA)

This phase teaches an important production Kubernetes concept: allowing the application to scale based on resource utilization instead of keeping a fixed replica count.

We'll keep everything in Terraform and still will not run terraform apply.

Phase 13A — Add HPA variables

Open:

terraform/modules/application/variables.tf

Add:

variable "min_replicas" {
  description = "Minimum number of application replicas."
  type        = number
  default     = 2
}

variable "max_replicas" {
  description = "Maximum number of application replicas."
  type        = number
  default     = 5
}

variable "target_cpu_utilization" {
  description = "Target average CPU utilization percentage."
  type        = number
  default     = 70
}

Phase 13B — Create the HPA

Create:

terraform/modules/application/hpa.tf

Add:

resource "kubernetes_horizontal_pod_autoscaler_v2" "this" {
  metadata {
    name      = "${var.name}-hpa"
    namespace = var.namespace
  }

  spec {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.this.metadata[0].name
    }

    metric {
      type = "Resource"

      resource {
        name = "cpu"

        target {
          type                = "Utilization"
          average_utilization = var.target_cpu_utilization
        }
      }
    }

    behavior {
      scale_up {
        stabilization_window_seconds = 0

        select_policy = "Max"

        policy {
          type           = "Percent"
          value          = 100
          period_seconds = 60
        }
      }

      scale_down {
        stabilization_window_seconds = 300

        select_policy = "Max"

        policy {
          type           = "Percent"
          value          = 50
          period_seconds = 60
        }
      }
    }
  }
}

This gives us:

                 HPA
                  │
          CPU utilization
                  │
        ┌─────────┴─────────┐
        │                   │
      < 70%               > 70%
        │                   │
   scale down          scale up
        │                   │
        ▼                   ▼
      2 Pods             up to 5 Pods

Phase 13C — Important relationship with resources

Your Deployment already has:

resources {
  requests = {
    cpu    = "100m"
    memory = "128Mi"
  }

  limits = {
    cpu    = "500m"
    memory = "512Mi"
  }
}

This is important because HPA CPU utilization is calculated relative to the container's CPU request.

With:

CPU request = 100m
HPA target  = 70%

approximately:

70% × 100m = 70m

average CPU usage per Pod is the target threshold.

This is one reason resource requests should not be omitted when using CPU-based HPA.

Phase 13D — Change the Deployment replica configuration

Your Deployment currently uses:

replicas = var.replicas

We need to avoid having Terraform continuously forcing a fixed replica count while Kubernetes HPA is dynamically changing it.

So change:

replicas = var.replicas

to:

replicas = var.min_replicas

However, there's an even better Terraform practice here: let the HPA own the replica count.

Add this to the Deployment resource:

lifecycle {
  ignore_changes = [
    spec[0].replicas
  ]
}

So near the top of the Deployment:

resource "kubernetes_deployment" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace

    labels = {
      app = var.name
    }
  }

  lifecycle {
    ignore_changes = [
      spec[0].replicas
    ]
  }

  spec {
    replicas = var.min_replicas

The idea is:

Terraform
   │
   │ manages Deployment configuration
   ▼
Kubernetes Deployment
   │
   │ replica count
   ▼
HPA owns runtime scaling

Terraform shouldn't fight the HPA.

Phase 13E — Update the module outputs

Add to:

terraform/modules/application/outputs.tf

output "hpa_name" {
  description = "Horizontal Pod Autoscaler name."
  value       = kubernetes_horizontal_pod_autoscaler_v2.this.metadata[0].name
}

Then add to the root:

terraform/outputs.tf

output "application_hpa_name" {
  description = "Application Horizontal Pod Autoscaler name."
  value       = module.application.hpa_name
}

Phase 13F — Validate

Run:

terraform -chdir=terraform fmt -recursive

Then:

terraform -chdir=terraform init

Then:

terraform -chdir=terraform validate

Expected:

Success! The configuration is valid.

What Phase 13 teaches

After this phase your architecture becomes:

                    AWS ALB
                       │
                       ▼
                    Ingress
                       │
                       ▼
                 ClusterIP Service
                       │
                       ▼
                 Kubernetes Pods
                  /    │    \
                 /     │     \
                ▼      ▼      ▼
              Pod    Pod    Pod
                 \     │     /
                  \    │    /
                     HPA
                      │
             CPU utilization
                      │
             ┌────────┴────────┐
             ▼                 ▼
          scale up          scale down
          max = 5           min = 2