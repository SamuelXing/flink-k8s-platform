# Everything the Helm chart needs. After an apply:
#
#   helm upgrade --install pipeline charts/flink-job \
#     -f charts/flink-job/values-prod.yaml \
#     --set checkpoints.bucket=$(terraform output -raw checkpoints_bucket) \
#     --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$(terraform output -raw flink_irsa_role_arn) \
#     --set kafka.bootstrap=$(terraform output -raw msk_bootstrap_brokers)

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
