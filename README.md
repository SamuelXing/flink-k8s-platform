# flink-k8s-platform

One Flink SQL job, deployed two ways: a laptop, and AWS.

The point of the repo is the diff between those two. The query does not change,
the image does not change, and the Flink configuration changes by four lines.
Everything else that differs is infrastructure, kept where infrastructure
belongs.

```
                    ┌──────────────────────────────┐
  generator job ───▶│  orders topic  (6 partitions)│───▶ pipeline job ───▶ revenue_1m
  datagen → Kafka   └──────────────────────────────┘     TUMBLE 1 min
                                                          per category

  local   kind ·  Strimzi  ·  LocalStack (S3)  ·  Flink Kubernetes Operator
  prod    EKS  ·  MSK      ·  S3 + IRSA        ·  Flink Kubernetes Operator
```

## The diff that matters

`make diff-envs` renders the chart against both value files and diffs the
Flink configuration:

```diff
-    taskmanager.numberOfTaskSlots: "2"
+    taskmanager.numberOfTaskSlots: "4"
     state.backend.type: "rocksdb"
     state.backend.incremental: "true"
-    execution.checkpointing.interval: "30s"
+    execution.checkpointing.interval: "60s"
-    execution.checkpointing.dir: s3://flink-checkpoints/jobs/demo/checkpoints
+    execution.checkpointing.dir: s3://acme-flink-ckpt/jobs/demo/checkpoints
     execution.checkpointing.aligned-checkpoint-timeout: "30s"
     high-availability.type: kubernetes
-    s3.endpoint: "http://localstack...:4566"
-    s3.path.style.access: "true"
-    s3.access-key: "test"
-    s3.secret-key: "test"
     pipeline.max-parallelism: "720"
```

Two tuning numbers, a bucket name, and four lines that **disappear** in
production because IRSA replaces them. There are no static AWS credentials
anywhere in the production path.

## Layout

| Path | What it is |
|---|---|
| `app/` | A ~150-line SQL runner and its Dockerfile. The jar never changes. |
| `charts/flink-job/` | One Helm chart, installed twice. The SQL lives here, not in the image. |
| `local/` | kind cluster, Tiltfile, Strimzi and LocalStack manifests. |
| `terraform/modules/` | vpc, eks, checkpoints, flink-irsa, msk. |
| `terraform/envs/prod/` | Wires them together. |

The job's SQL is a mounted ConfigMap, so changing the pipeline is a config
change and a restart, not a rebuild and a push.

## Running it locally

```sh
brew install kind tilt         # the two things this needs that you may not have
make local-up                  # creates the kind cluster, then `tilt up`
```

Tilt brings the layers up in order: cert-manager, Strimzi, Kafka, LocalStack,
the checkpoint bucket, the Flink operator, then the two jobs. The Flink web UI
is forwarded to <http://localhost:8081>; checkpoint size, checkpoint history
and alignment duration are all on it.

```sh
make test          # unit tests for the SQL splitter
make lint          # helm lint, both value sets
make diff-envs     # the diff above
make local-down
```

## What is actually verified

Being precise about this, because "it deploys to AWS" is easy to claim:

| | Status |
|---|---|
| SQL splitter, including statement sets | ✅ 7 unit tests, `make test` |
| Helm chart renders, both environments | ✅ `helm lint`, `helm template` |
| Terraform syntax, types, module wiring | ✅ `terraform validate` on all 6, `fmt` clean |
| `checkpoints` module creates a real bucket | ✅ against LocalStack, `make tf-local-apply` |
| Local stack comes up end to end | ⬜ needs kind + tilt installed |
| `terraform plan` against real AWS | ⬜ needs credentials; read-only, creates nothing |
| **Ever applied to AWS** | ❌ **never** |

The AWS side is written to be read and reviewed. See
[`terraform/README.md`](terraform/README.md) for what it would cost and what to
check before an apply.

## Why LocalStack is used for S3 and nothing else

LocalStack emulates S3, IAM and STS properly, which lets the local Flink
configuration say `s3://` exactly as production does.

It does not emulate EKS, MSK or VPC in any useful way. VPC and EKS are mocked
API responses: `terraform apply` goes green without proving the network would
come up on real AWS. A green run that proves nothing is worse than no run, so
those stay at `validate`, and kind and Strimzi cover the local case instead.

## Notes

The pipeline is the same query as a UCSC Extension course lab, deliberately:
the interesting part here is not the SQL.

Versions are pinned throughout (Flink 1.20.0, operator 1.10.0, Strimzi 0.45.0,
EKS module ~> 20.31). Check for newer ones before using this for anything real.
