variable "cluster_name" { type = string }

variable "kubernetes_version" {
  type    = string
  default = "1.31"
}

variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }

variable "public_endpoint" {
  type        = bool
  description = "Expose the API server publicly. Convenient; restrict by CIDR before anything real."
  default     = true
}

variable "node_instance_types" {
  type    = list(string)
  default = ["m7i.xlarge"]
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 10
}

variable "node_desired_size" {
  type    = number
  default = 3
}

variable "node_disk_gb" {
  description = "Root volume per node. RocksDB working state lives here, not just the OS."
  type        = number
  default     = 200
}

variable "capacity_type" {
  type        = string
  description = "ON_DEMAND or SPOT. Spot is tempting, but every reclaim is a job restart plus a state download."
  default     = "ON_DEMAND"
}

variable "tags" {
  type    = map(string)
  default = {}
}
