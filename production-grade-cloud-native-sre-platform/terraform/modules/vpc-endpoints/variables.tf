variable "name" {
  description = "Name prefix for VPC endpoint resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where endpoints will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for interface endpoints"
  type        = list(string)
}

variable "private_route_table_ids" {
  description = "Private route table IDs for gateway endpoints"
  type        = list(string)
}

variable "endpoint_security_group_id" {
  description = "Security group ID used by interface endpoints"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
