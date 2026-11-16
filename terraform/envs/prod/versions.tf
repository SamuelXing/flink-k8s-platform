terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state with locking. Left commented so `terraform init` works before
  # the bucket exists: uncomment once it does, then `terraform init -migrate-state`.
  #
  # backend "s3" {
  #   bucket       = "acme-terraform-state"
  #   key          = "flink-platform/prod.tfstate"
  #   region       = "us-west-2"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}
