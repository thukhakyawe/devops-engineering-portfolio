
output "eks_role_arn" {
  description = "IAM role ARN used by the EKS control plane."
  value       = aws_iam_role.eks.arn
}

output "eks_role_name" {
  description = "IAM role name used by the EKS control plane."
  value       = aws_iam_role.eks.name
}

output "node_role_arn" {
  description = "IAM role ARN used by EKS worker nodes."
  value       = aws_iam_role.nodes.arn
}

output "node_role_name" {
  description = "IAM role name used by EKS worker nodes."
  value       = aws_iam_role.nodes.name
}