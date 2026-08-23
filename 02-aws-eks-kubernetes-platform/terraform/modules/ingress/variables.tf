
variable "namespace" {
  description = "Kubernetes namespace containing the application."
  type        = string
}

variable "name" {
  description = "Ingress name."
  type        = string
}

variable "service_name" {
  description = "Kubernetes Service receiving traffic."
  type        = string
}

variable "service_port" {
  description = "Kubernetes Service port."
  type        = number
  default     = 80
}