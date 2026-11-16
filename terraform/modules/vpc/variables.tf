variable "name" { type = string }
variable "region" { type = string }

variable "cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "Three AZs. MSK and a production Flink cluster both want three."
}

variable "private_subnet_cidrs" { type = list(string) }
variable "public_subnet_cidrs" { type = list(string) }

variable "single_nat_gateway" {
  type        = bool
  description = "One NAT for all AZs. Cheaper, but an AZ outage takes out egress."
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
