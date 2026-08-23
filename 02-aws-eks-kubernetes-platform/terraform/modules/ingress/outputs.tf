
output "ingress_name" {
  description = "Kubernetes Ingress name."
  value       = kubernetes_ingress_v1.this.metadata[0].name
}