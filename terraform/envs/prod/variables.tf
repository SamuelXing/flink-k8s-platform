variable "project" {
  type    = string
  default = "flink-platform"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "region" {
  type    = string
  default = "us-west-2"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.0.0/20", "10.20.16.0/20", "10.20.32.0/20"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.100.0/24", "10.20.101.0/24", "10.20.102.0/24"]
}

variable "single_nat_gateway" {
  type    = bool
  default = true
}

variable "kubernetes_version" {
  type    = string
  default = "1.31"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["m7i.xlarge"]
}

variable "node_desired_size" {
  type    = number
  default = 3
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 10
}

variable "checkpoints_bucket_name" {
  description = "Globally unique. Something like acme-flink-checkpoints-prod."
  type        = string
}

variable "job_prefix" {
  description = "Must match checkpoints.prefix in the Helm values."
  type        = string
  default     = "jobs"
}

variable "flink_namespace" {
  description = "Must match the namespace the chart installs into."
  type        = string
  default     = "flink"
}

variable "flink_service_account" {
  description = "Must match serviceAccount.name in the Helm values."
  type        = string
  default     = "flink"
}

variable "kafka_retention_hours" {
  type    = number
  default = 168
}
