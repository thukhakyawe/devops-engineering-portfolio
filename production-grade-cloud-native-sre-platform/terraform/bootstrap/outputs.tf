output "terraform_state_bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "terraform_state_bucket_arn" {
  value = aws_s3_bucket.terraform_state.arn
}

output "terraform_state_kms_key_arn" {
  value = aws_kms_key.terraform_state.arn
}
