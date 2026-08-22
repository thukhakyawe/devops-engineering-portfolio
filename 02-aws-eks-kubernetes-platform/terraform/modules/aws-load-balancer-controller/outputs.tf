output "role_arn" {
  description = "IAM role ARN used by the AWS Load Balancer Controller."
  value       = aws_iam_role.controller.arn
}

output "role_name" {
  description = "IAM role name used by the AWS Load Balancer Controller."
  value       = aws_iam_role.controller.name
}

output "policy_arn" {
  description = "IAM policy ARN used by the AWS Load Balancer Controller."
  value       = aws_iam_policy.controller.arn
}