terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Required for IRSA: without the OIDC provider there is no way for a pod's
  # service account to become an IAM principal.
  enable_irsa = true

  # Since v20 of this module the creator gets NO access by default: without
  # this line the apply succeeds and the very next kubectl is Unauthorized.
  enable_cluster_creator_admin_permissions = true

  cluster_endpoint_public_access  = var.public_endpoint
  cluster_endpoint_private_access = true

  eks_managed_node_groups = {
    flink = {
      # Flink wants memory far more than cores: TaskManager heap, RocksDB
      # off-heap, and network buffers all come out of the same pod limit.
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
      capacity_type  = var.capacity_type

      # RocksDB writes continuously. gp2 throttles and shows up as checkpoint
      # duration creeping upward with no change in state size.
      block_device_mappings = {
        root = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = var.node_disk_gb
            volume_type = "gp3"
            iops        = 3000
            throughput  = 250
            encrypted   = true
          }
        }
      }

      labels = { workload = "flink" }
    }
  }

  tags = var.tags
}
