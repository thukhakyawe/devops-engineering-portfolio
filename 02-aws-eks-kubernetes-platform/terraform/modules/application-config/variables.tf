
variable "namespace" {
  description = "Kubernetes namespace for application configuration."
  type        = string
}

variable "environment" {
  description = "Application environment."
  type        = string
}

variable "database_host" {
  description = "Database hostname."
  type        = string
}

variable "database_port" {
  description = "Database port."
  type        = number
  default     = 5432
}

variable "aws_region" {
  description = "AWS region used by Secrets Manager."
  type        = string
}