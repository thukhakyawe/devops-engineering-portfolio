
variable "name" {
  description = "Name prefix for EKS IAM resources."
  type        = string
}

variable "tags" {
  description = "Tags applied to IAM resources."
  type        = map(string)
  default     = {}
}