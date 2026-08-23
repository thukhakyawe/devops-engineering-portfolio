output "config_map_name" {
  description = "Application ConfigMap name."
  value       = kubernetes_config_map.application.metadata[0].name
}