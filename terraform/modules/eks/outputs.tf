output "cluster_name" { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }

output "oidc_provider_arn" {
  description = "Feed to the flink-irsa module."
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "Issuer with the https:// stripped, as IAM conditions want it."
  value       = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
}

output "node_security_group_id" {
  description = "MSK allows traffic from this."
  value       = module.eks.node_security_group_id
}
