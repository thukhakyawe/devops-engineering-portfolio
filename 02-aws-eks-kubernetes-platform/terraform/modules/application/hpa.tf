
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