output "bootstrap_brokers_sasl_iam" {
  description = "Pass to the Helm chart as kafka.bootstrap."
  value       = aws_msk_cluster.this.bootstrap_brokers_sasl_iam
}

output "cluster_arn" {
  description = "Used by the flink-irsa module to scope kafka-cluster permissions."
  value       = aws_msk_cluster.this.arn
}

output "security_group_id" {
  value = aws_security_group.msk.id
}
