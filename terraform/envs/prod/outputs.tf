# Everything the deploy needs. docs/prod-deploy.md uses each of these.

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "checkpoints_bucket" {
  value = module.checkpoints.bucket_name
}

output "flink_irsa_role_arn" {
  value = module.flink_irsa.role_arn
}

output "msk_bootstrap_brokers" {
  value = module.msk.bootstrap_brokers_sasl_iam
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}
