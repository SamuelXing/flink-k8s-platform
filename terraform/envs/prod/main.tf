# The production stack, wired together.
#
# NOTHING HERE HAS BEEN APPLIED. It is written to be read and reviewed; see
# terraform/README.md for what can and cannot be verified without an AWS
# account, and for what this would cost if you did apply it.

locals {
  name = "${var.project}-${var.environment}"

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name               = local.name
  region             = var.region
  cidr               = var.vpc_cidr
  availability_zones = var.availability_zones

  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway

  tags = local.tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name       = local.name
  kubernetes_version = var.kubernetes_version

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size

  tags = local.tags
}

module "ecr" {
  source = "../../modules/ecr"

  name = "${var.project}/flink-sql-platform"
  tags = local.tags
}

module "checkpoints" {
  source = "../../modules/checkpoints"

  bucket_name = var.checkpoints_bucket_name

  # Production keeps its checkpoints: a mistyped destroy should fail, not
  # silently delete the only copy of every job's state.
  force_destroy = false

  tags = local.tags
}

module "flink_irsa" {
  source = "../../modules/flink-irsa"

  role_name            = "${local.name}-flink"
  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider_url    = module.eks.oidc_provider_url
  namespace            = var.flink_namespace
  service_account_name = var.flink_service_account

  checkpoints_bucket_arn = module.checkpoints.bucket_arn
  msk_cluster_arn        = module.msk.cluster_arn
  job_prefix             = var.job_prefix

  tags = local.tags
}

module "msk" {
  source = "../../modules/msk"

  cluster_name             = local.name
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnet_ids
  client_security_group_id = module.eks.node_security_group_id

  retention_hours = var.kafka_retention_hours

  tags = local.tags
}
