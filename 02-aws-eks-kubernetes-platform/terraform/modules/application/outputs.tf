
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