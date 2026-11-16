output "role_arn" {
  description = "Put this in the ServiceAccount annotation eks.amazonaws.com/role-arn."
  value       = aws_iam_role.flink.arn
}
