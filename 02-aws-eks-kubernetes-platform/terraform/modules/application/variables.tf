
variable "namespace" {
  description = "Kubernetes namespace for the application."
  type        = string
  default     = "application"
}

variable "name" {
  description = "Application name."
  type        = string
  default     = "platform-api"
}

variable "image" {
  description = "Container image."
  type        = string
  default     = "nginxinc/nginx-unprivileged:1.27-alpine"
}

variable "replicas" {
  description = "Number of application replicas."
  type        = number
  default     = 2
}

variable "container_port" {
  description = "Application container port."
  type        = number
  default     = 8080
}

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

variable "config_map_name" {
  description = "Name of the ConfigMap containing application configuration."
  type        = string
}