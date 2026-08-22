variable "name" {
  description = "Name prefix for AWS Load Balancer Controller resources."
  type        = string
}

variable "tags" {
  description = "Tags applied to IAM resources."
  type        = map(string)
  default     = {}
}