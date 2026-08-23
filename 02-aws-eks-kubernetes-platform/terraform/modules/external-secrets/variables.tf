variable "name" {
  description = "Name prefix for External Secrets resources."
  type        = string
}

variable "tags" {
  description = "Tags applied to IAM resources."
  type        = map(string)
  default     = {}
}