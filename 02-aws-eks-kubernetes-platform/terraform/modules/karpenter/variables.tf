
variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN used by EKS worker nodes."
  type        = string
}

variable "tags" {
  description = "Tags applied to Karpenter resources."
  type        = map(string)
  default     = {}
}