# The checkpoints module, applied for real against LocalStack.
#
#     make tf-local-apply
#
# This is the only part of the Terraform that can be exercised without an AWS
# account. It proves the bucket, versioning, encryption, public access block
# and lifecycle rules are accepted by an S3 API, which `terraform validate`
# cannot. It proves nothing about IAM: LocalStack does not enforce it.

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Pinned on purpose, and older than prod's. From 5.86 the provider waits
      # for a lifecycle configuration to read back identically, including a
      # field LocalStack 3.8 never returns, so the apply times out after 3
      # minutes with the rule already in place. 3.8 is the last LocalStack
      # that starts without an account token. The module itself is the same.
      version = "5.80.0"
    }
  }
}

variable "endpoint" {
  description = "LocalStack edge endpoint. Tilt forwards it to localhost:4566."
  type        = string
  default     = "http://localhost:4566"
}

variable "bucket_name" {
  type    = string
  default = "tf-checkpoints-local"
}

provider "aws" {
  region     = "us-east-1"
  access_key = "test"
  secret_key = "test"

  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3 = var.endpoint
  }
}

module "checkpoints" {
  source = "../../modules/checkpoints"

  bucket_name   = var.bucket_name
  force_destroy = true
}

output "bucket_name" {
  value = module.checkpoints.bucket_name
}
