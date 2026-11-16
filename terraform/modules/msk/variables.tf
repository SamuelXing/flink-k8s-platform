variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnets, one per AZ. Broker count is derived from this."
  type        = list(string)
}

variable "client_security_group_id" {
  description = "The EKS node security group. Only it may reach the brokers."
  type        = string
}

variable "kafka_version" {
  type    = string
  default = "3.6.0"
}

variable "broker_instance_type" {
  type    = string
  default = "kafka.m7g.large"
}

variable "broker_storage_gb" {
  type    = number
  default = 500
}

variable "default_partitions" {
  description = "Ceiling on Flink source parallelism. Raising it later means rebuilding topics."
  type        = number
  default     = 24
}

variable "retention_hours" {
  description = "How far back a job can be replayed from. This is the real recovery window."
  type        = number
  default     = 168
}

variable "tags" {
  type    = map(string)
  default = {}
}
