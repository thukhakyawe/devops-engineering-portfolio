# Create the non-sensitive configuration as a ConfigMap:

resource "kubernetes_config_map" "application" {
  metadata {
    name      = "platform-api-config"
    namespace = var.namespace
  }

  data = {
    ENVIRONMENT   = var.environment
    DATABASE_HOST = var.database_host
    DATABASE_PORT = tostring(var.database_port)
  }
}
