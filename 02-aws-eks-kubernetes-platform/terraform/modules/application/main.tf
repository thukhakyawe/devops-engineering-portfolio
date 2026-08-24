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

    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_unavailable = "25%"
        max_surge       = "25%"
      }
    }

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
        security_context {
          run_as_non_root = true

          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name  = var.name
          image = var.image

          security_context {
            allow_privilege_escalation = false
            privileged                 = false
            read_only_root_filesystem  = true

            capabilities {
              drop = ["ALL"]
            }
          }

          port {
            container_port = var.container_port
          }

          env_from {
            config_map_ref {
              name = var.config_map_name
            }
          }

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

          startup_probe {
            http_get {
              path = "/"
              port = var.container_port
            }

            failure_threshold = 30
            period_seconds    = 5
          }

          readiness_probe {
            http_get {
              path = "/"
              port = var.container_port
            }

            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 2
            failure_threshold     = 3
            success_threshold     = 1
          }

          liveness_probe {
            http_get {
              path = "/"
              port = var.container_port
            }

            initial_delay_seconds = 15
            period_seconds        = 20
            timeout_seconds       = 2
            failure_threshold     = 3
            success_threshold     = 1
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