
variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "node_group_name" {
  description = "EKS managed node group name."
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN for worker nodes."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for worker nodes."
  type        = list(string)
}

variable "instance_types" {
  description = "EC2 instance types for worker nodes."
  type        = list(string)

  default = [
    "t3.small"
  ]
}

variable "desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 3
}

variable "tags" {
  description = "Tags applied to node group resources."
  type        = map(string)
  default     = {}
}