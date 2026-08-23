resource "kubernetes_pod_disruption_budget_v1" "this" {
  metadata {
    name      = "${var.name}-pdb"
    namespace = var.namespace
  }

  spec {
    min_available = 1

    selector {
      match_labels = {
        app = var.name
      }
    }
  }
}