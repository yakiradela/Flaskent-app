output "s3_bucket_name" {
  value = aws_s3_bucket.tf_state.id
}

output "iam_role_arn" {
  value = aws_iam_role.tf_role.arn
}
