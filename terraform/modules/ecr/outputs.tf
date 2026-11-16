output "repository_url" {
  description = "Pass to the Helm chart as image.repository."
  value       = aws_ecr_repository.this.repository_url
}
