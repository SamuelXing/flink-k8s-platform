# terraform

**Nothing here has been applied.** It validates and it is formatted; that is a
statement about syntax and types, not about whether an EKS cluster comes up.

## What you can check without an AWS account

```sh
make tf-fmt          # formatting
make tf-validate     # syntax, types, module wiring, all 8 directories
make tf-local-apply  # really creates the bucket, against LocalStack
make tf-local-destroy
```

`tf-local-apply` needs the local stack running under `tilt up`, which forwards
LocalStack to `localhost:4566`. It applies `envs/local`, which is the
`checkpoints` module and nothing else: bucket, versioning, encryption, public
access block and lifecycle rule.

Only that module works this way. S3 is emulated properly by LocalStack; `vpc`,
`eks` and `msk` are not, and an apply against their mocks would report success
without creating anything real. IAM is not enforced either, so this says
nothing about whether the policies in `flink-irsa` are right.

`envs/local` pins AWS provider 5.80.0, older than prod. Newer providers wait
for the lifecycle rule to read back with a field LocalStack 3.8 does not
return, and time out with the rule already applied.

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
| ECR, S3 + requests | small, until it isn't |
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
- Topic partition counts are chosen when the topics are created
  (`docs/prod-deploy.md`, step 5). They are the ceiling on Flink source
  parallelism, and raising one later moves every key to a different partition.
- The checkpoint bucket never deletes anything by age, only superseded
  versions. Leftovers from a job that no longer exists have to be removed by
  deleting its prefix.
