output "controller_role_arn" {
  description = "IAM role ARN used by the Karpenter controller."
  value       = aws_iam_role.controller.arn
}