variable "name" {
  description = "Name prefix"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
}

variable "public_subnets" {
  description = "Public subnet CIDRs"
  type        = list(string)
}

variable "private_app_subnets" {
  description = "Private application subnet CIDRs"
  type        = list(string)
}

variable "private_db_subnets" {
  description = "Private database subnet CIDRs"
  type        = list(string)
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
