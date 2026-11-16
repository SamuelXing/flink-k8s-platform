variable "bucket_name" {
  description = "Name of the checkpoint bucket. Must be globally unique on real AWS."
  type        = string
}

variable "job_prefix" {
  description = "Key prefix the Flink jobs write under. Matches checkpoints.prefix in the Helm values."
  type        = string
  default     = "jobs"
}

variable "checkpoint_retention_days" {
  description = "Days before objects under job_prefix/ expire. Covers checkpoints left by deleted jobs."
  type        = number
  default     = 30
}

variable "noncurrent_version_retention_days" {
  description = "Days a superseded object version is kept. Flink overwrites constantly, so this drives most of the cost."
  type        = number
  default     = 7
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete a non-empty bucket. True locally, false in prod."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to the bucket."
  type        = map(string)
  default     = {}
}
