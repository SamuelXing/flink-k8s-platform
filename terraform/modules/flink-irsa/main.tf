# IRSA: the Flink pods' path to S3 without any static credentials.
#
# How it works, end to end:
#   1. EKS publishes an OIDC issuer for the cluster
#   2. this IAM role trusts that issuer, but only for one namespace/SA pair
#   3. the Helm chart annotates the ServiceAccount with this role's ARN
#   4. the EKS pod identity webhook injects a projected web identity token
#   5. the AWS SDK inside Flink picks it up through the default credential chain
#
# That is why values-prod.yaml has no s3.access-key: there is nothing to put.

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    # Without this the role would be assumable by ANY service account in the
    # cluster. Scoping it to one namespace and one SA is the whole security
    # boundary.
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flink" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = var.tags
}

data "aws_iam_policy_document" "checkpoints" {
  # Listing is scoped to the job prefix, not the whole bucket.
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [var.checkpoints_bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.job_prefix}/*"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = ["${var.checkpoints_bucket_arn}/${var.job_prefix}/*"]
  }
}

resource "aws_iam_role_policy" "checkpoints" {
  name   = "${var.role_name}-checkpoints"
  role   = aws_iam_role.flink.id
  policy = data.aws_iam_policy_document.checkpoints.json
}
