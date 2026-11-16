# A thin wrapper over the community VPC module. Hand-rolling a VPC is a
# thousand lines of subnets, routes and gateways that nobody should maintain;
# what belongs here is the Flink-specific part, which is the subnet tagging
# that lets EKS place load balancers correctly.

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = var.name
  cidr = var.cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  # TaskManagers and MSK brokers sit in private subnets and reach ECR and S3
  # through the NAT gateway. single_nat_gateway is the cheap, non-HA choice:
  # fine for a dev cluster, not for one that must survive an AZ outage.
  enable_nat_gateway = true
  single_nat_gateway = var.single_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags  = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }

  tags = var.tags
}

# A gateway endpoint for S3 costs nothing and keeps checkpoint traffic off the
# NAT gateway. With a job checkpointing hundreds of GB an hour, NAT data
# processing charges alone can exceed the cost of the cluster.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids
  tags              = merge(var.tags, { Name = "${var.name}-s3" })
}
