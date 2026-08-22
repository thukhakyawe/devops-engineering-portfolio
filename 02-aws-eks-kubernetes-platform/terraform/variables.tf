
variable "aws_region" {
  description = "AWS region for the EKS platform."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Project name."
  type        = string
  default     = "eks-platform"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the EKS VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "Availability Zones used by the EKS platform."
  type        = list(string)

  default = [
    "ap-southeast-1a",
    "ap-southeast-1b"
  ]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets."
  type        = list(string)

  default = [
    "10.20.1.0/24",
    "10.20.2.0/24"
  ]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private EKS subnets."
  type        = list(string)

  default = [
    "10.20.11.0/24",
    "10.20.12.0/24"
  ]
}