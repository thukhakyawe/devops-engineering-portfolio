resource "kubernetes_manifest" "database_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"

    metadata = {
      name      = "platform-api-database"
      namespace = var.namespace
    }

    spec = {
      refreshInterval = "1h"

      secretStoreRef = {
        name = "aws-secretsmanager"
        kind = "ClusterSecretStore"
      }

      target = {
        name           = "platform-api-database"
        creationPolicy = "Owner"
      }

      data = [
        {
          secretKey = "username"

          remoteRef = {
            key      = "${var.environment}/platform-api/database"
            property = "username"
          }
        },
        {
          secretKey = "password"

          remoteRef = {
            key      = "${var.environment}/platform-api/database"
            property = "password"
          }
        }
      ]
    }
  }
}