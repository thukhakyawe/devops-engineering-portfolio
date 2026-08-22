
output "vpc_id" {
  description = "ID of the EKS VPC."
  value       = module.networking.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the EKS VPC."
  value       = module.networking.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private EKS subnets."
  value       = module.networking.private_subnet_ids
}

output "availability_zones" {
  description = "Availability Zones used by the EKS platform."
  value       = module.networking.availability_zones
}

output "eks_role_arn" {
  description = "IAM role ARN used by the EKS control plane."
  value       = module.iam.eks_role_arn
}

output "node_role_arn" {
  description = "IAM role ARN used by EKS worker nodes."
  value       = module.iam.node_role_arn
}


output "eks_cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN."
  value       = module.eks.cluster_arn
}

output "eks_cluster_endpoint" {
  description = "EKS Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_version" {
  description = "Kubernetes version."
  value       = module.eks.cluster_version
}


output "node_group_name" {
  description = "EKS managed node group name."
  value       = module.node_group.node_group_name
}

output "node_group_status" {
  description = "EKS managed node group status."
  value       = module.node_group.status
}

output "kubernetes_namespaces" {
  description = "Kubernetes namespaces managed by Terraform."
  value       = module.namespaces.namespace_names
}

output "application_deployment" {
  description = "Application Deployment name."
  value       = module.application.deployment_name
}

output "application_service" {
  description = "Application Service name."
  value       = module.application.service_name
}

