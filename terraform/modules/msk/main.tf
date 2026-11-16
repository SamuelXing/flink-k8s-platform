# MSK, written out rather than wrapped: it is small, and the parts that matter
# for Flink (partition count ceiling, IAM auth, retention) should be visible.
#
# Local uses Strimzi instead. That divergence is deliberate: running Kafka
# yourself on EKS and buying MSK are genuinely different operational choices,
# and pretending otherwise would hide the one that costs money.

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

resource "aws_security_group" "msk" {
  name        = "${var.cluster_name}-msk"
  description = "MSK brokers, reachable only from the EKS nodes."
  vpc_id      = var.vpc_id

  ingress {
    description     = "Kafka TLS from EKS nodes"
    from_port       = 9094
    to_port         = 9094
    protocol        = "tcp"
    security_groups = [var.client_security_group_id]
  }

  ingress {
    description     = "Kafka IAM-authenticated from EKS nodes"
    from_port       = 9098
    to_port         = 9098
    protocol        = "tcp"
    security_groups = [var.client_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_msk_cluster" "this" {
  cluster_name  = var.cluster_name
  kafka_version = var.kafka_version

  # One broker per AZ. This is also the floor for replication factor 3, which
  # the Flink sink's transactional writes depend on.
  number_of_broker_nodes = length(var.subnet_ids)

  broker_node_group_info {
    instance_type   = var.broker_instance_type
    client_subnets  = var.subnet_ids
    security_groups = [aws_security_group.msk.id]

    storage_info {
      ebs_storage_info {
        volume_size = var.broker_storage_gb
      }
    }
  }

  client_authentication {
    sasl {
      iam = true
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.this.arn
    revision = aws_msk_configuration.this.latest_revision
  }

  tags = var.tags
}

resource "aws_msk_configuration" "this" {
  name           = "${var.cluster_name}-config"
  kafka_versions = [var.kafka_version]

  # num.partitions is the single most consequential line here. A Flink source's
  # parallelism can never exceed the partition count, and raising it later
  # means rebuilding the topic, not restarting a job.
  server_properties = <<-PROPERTIES
    auto.create.topics.enable = false
    default.replication.factor = ${length(var.subnet_ids)}
    min.insync.replicas = 2
    num.partitions = ${var.default_partitions}
    log.retention.hours = ${var.retention_hours}
  PROPERTIES
}
