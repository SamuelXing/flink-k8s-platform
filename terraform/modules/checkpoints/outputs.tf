output "bucket_name" {
  description = "Pass to the Helm chart as checkpoints.bucket."
  value       = aws_s3_bucket.checkpoints.id
}

output "bucket_arn" {
  description = "Used by the flink-irsa module to scope the IAM policy."
  value       = aws_s3_bucket.checkpoints.arn
}
