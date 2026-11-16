# The checkpoint bucket.
#
# This is the one module in this repo that can be applied locally against
# LocalStack, because S3 is emulated properly rather than mocked:
#
#     cd terraform/modules/checkpoints
#     tflocal init && tflocal apply -var bucket_name=flink-checkpoints
#
# vpc, eks and msk cannot. LocalStack answers their APIs with canned responses,
# so an apply goes green without proving anything would come up on real AWS.

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_s3_bucket" "checkpoints" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags
}

# Flink overwrites the same keys constantly. Versioning is what makes a bad
# deploy recoverable, and the lifecycle rule below is what stops it costing a
# fortune.
resource "aws_s3_bucket_versioning" "checkpoints" {
  bucket = aws_s3_bucket.checkpoints.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "checkpoints" {
  bucket = aws_s3_bucket.checkpoints.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "checkpoints" {
  bucket                  = aws_s3_bucket.checkpoints.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# A running job rewrites checkpoints every interval. Without expiry, a job that
# checkpoints 200 GB every minute leaves a petabyte behind in a week.
resource "aws_s3_bucket_lifecycle_configuration" "checkpoints" {
  bucket = aws_s3_bucket.checkpoints.id

  rule {
    id     = "expire-noncurrent-checkpoints"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  # Savepoints are the thing you restore from after a bad deploy, so they are
  # kept far longer than checkpoints and are never auto-deleted here.
  rule {
    id     = "expire-orphaned-checkpoints"
    status = "Enabled"

    filter {
      prefix = "${var.job_prefix}/"
    }

    expiration {
      days = var.checkpoint_retention_days
    }
  }
}
