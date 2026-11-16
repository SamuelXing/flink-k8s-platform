# terraform

**Nothing here has been applied.** It validates and it is formatted; that is a
statement about syntax and types, not about whether an EKS cluster comes up.

## What you can check without an AWS account

```sh
make tf-fmt         # formatting
make tf-validate    # syntax, types, module wiring, all 6 directories
make tf-local-apply # really creates the bucket, against LocalStack
```

`tf-local-apply` needs `tflocal`:

```sh
pipx install terraform-local
```

Only the `checkpoints` module works this way. S3 is emulated properly by
LocalStack; `vpc`, `eks` and `msk` are not, and an apply against their mocks
would report success without creating anything real.

## What needs credentials

```sh
make tf-plan        # read-only, creates nothing, costs nothing
```

A plan is the first thing that would catch a wrong AMI type, an AZ that does
not offer the chosen instance, or a bucket name already taken.

## What this would cost

Rough us-west-2 monthly, if applied as written:

| | |
|---|---|
| EKS control plane | ~$73 |
| 3 × m7i.xlarge on demand | ~$440 |
| NAT gateway (1) | ~$33 + data |
| MSK 3 × kafka.m7g.large | ~$300 |
| S3 + requests | small, until it isn't |
| | **~$850/month before traffic** |

Two things dominate the surprises:

- **NAT data processing.** A job checkpointing to S3 through a NAT gateway is
  billed per GB. The `aws_vpc_endpoint` for S3 in the vpc module exists for
  exactly this and costs nothing.
- **Noncurrent S3 versions.** Flink overwrites the same keys every interval.
  The lifecycle rule in the `checkpoints` module is what stops a month of
  superseded versions accumulating.

## Before an apply

- `single_nat_gateway = true` is the cheap, non-HA default. An AZ outage takes
  out egress for every node.
- `cluster_endpoint_public_access = true` means the API server is reachable
  from the internet. Restrict it by CIDR.
- `pipeline.max-parallelism` in the Helm values is 720. It is the job's
  lifetime parallelism ceiling and cannot be changed without discarding every
  existing savepoint. Decide it now, not later.
- `num.partitions = 24` in the MSK config is the ceiling on Flink source
  parallelism. Raising it later means rebuilding topics, not restarting a job.
