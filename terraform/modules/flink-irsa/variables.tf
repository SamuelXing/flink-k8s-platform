variable "role_name" {
  type        = string
  description = "Name of the IAM role the Flink service account assumes."
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the cluster's IAM OIDC provider (from the eks module)."
}

variable "oidc_provider_url" {
  type        = string
  description = "OIDC issuer host and path, with no https:// prefix."
}

variable "namespace" {
  type        = string
  description = "Namespace the Flink service account lives in."
  default     = "flink"
}

variable "service_account_name" {
  type        = string
  description = "Must match serviceAccount.name in the Helm values."
  default     = "flink"
}

variable "checkpoints_bucket_arn" {
  type        = string
  description = "ARN of the checkpoint bucket."
}

variable "msk_cluster_arn" {
  type        = string
  description = "ARN of the MSK cluster the jobs read and write."
}

variable "job_prefix" {
  type        = string
  description = "Key prefix the role is allowed to touch."
  default     = "jobs"
}

variable "tags" {
  type    = map(string)
  default = {}
}
