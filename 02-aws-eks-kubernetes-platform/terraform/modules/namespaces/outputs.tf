
output "namespace_names" {
  description = "Names of the Kubernetes namespaces."
  value = [
    for namespace in kubernetes_namespace.this : namespace.metadata[0].name
  ]
}