output "bootstrap_brokers_sasl_iam" {
  description = "Pass to the Helm chart as kafka.bootstrap."
  value       = aws_msk_cluster.this.bootstrap_brokers_sasl_iam
}

output "security_group_id" {
  value = aws_security_group.msk.id
}
