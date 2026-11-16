# The checkpoint bucket.
#
# This is the one module in this repo that can be applied without an AWS
# account, because LocalStack emulates S3 properly rather than mocking it.
# terraform/envs/local does exactly that: `make tf-local-apply`.
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

# Only SUPERSEDED versions are expired here. Nothing is ever deleted by age.
#
# An age rule looks like the obvious way to clean up, and it destroys running
# jobs: with incremental checkpoints the newest checkpoint still references SST
# files under shared/ that were uploaded weeks ago. Expire those by age and the
# job runs fine until the day it has to restore. The same rule would also eat
# savepoints, which exist precisely to be kept.
#
# Flink deletes its own obsolete checkpoint files; versioning turns each of
# those deletes into a noncurrent version, and this rule is what finally
# removes them. Leftovers from a deleted job are removed by deleting its prefix
# on purpose, not by a timer.
resource "aws_s3_bucket_lifecycle_configuration" "checkpoints" {
  bucket = aws_s3_bucket.checkpoints.id

  # Without this, versioning keeps every overwritten and deleted object forever.
  depends_on = [aws_s3_bucket_versioning.checkpoints]

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    # A delete marker with no versions left behind it is pure clutter.
    expiration {
      expired_object_delete_marker = true
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}
