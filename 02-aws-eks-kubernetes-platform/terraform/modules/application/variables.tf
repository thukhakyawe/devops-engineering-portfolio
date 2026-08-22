
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
  default     = "nginx:1.27-alpine"
}

variable "replicas" {
  description = "Number of application replicas."
  type        = number
  default     = 2
}

variable "container_port" {
  description = "Application container port."
  type        = number
  default     = 80
}