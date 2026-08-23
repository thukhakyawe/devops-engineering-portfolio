output "vpc_id" {
  description = "ID of the EKS VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the EKS VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "availability_zones" {
  description = "Availability Zones used by the VPC."
  value       = var.availability_zones
}

output "eks_nodes_security_group_id" {
  description = "Security group ID for EKS worker nodes and Karpenter."
  value       = aws_security_group.eks_nodes.id
}