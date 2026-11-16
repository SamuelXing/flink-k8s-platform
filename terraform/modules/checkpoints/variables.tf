variable "bucket_name" {
  description = "Name of the checkpoint bucket. Must be globally unique on real AWS."
  type        = string
}

variable "noncurrent_version_retention_days" {
  description = "Days a superseded or deleted object version is kept. This is the window in which a bad delete can be undone, and it drives most of the storage cost."
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
