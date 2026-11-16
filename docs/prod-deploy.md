# Deploying to AWS

**Nobody has run this.** Every step is written from the code in this repo and
each piece that can be exercised locally has been (see the README table), but
the sequence as a whole has never met a real AWS account. Expect to fix things.

Run from the repo root. `TF` is shorthand for the prod environment:

```sh
TF="terraform -chdir=terraform/envs/prod"
```

## 1. Infrastructure

```sh
$TF init
$TF plan  -var checkpoints_bucket_name=<globally-unique-name>
$TF apply -var checkpoints_bucket_name=<globally-unique-name>
eval "$($TF output -raw kubeconfig_command)"
```

Read `terraform/README.md` first: it lists what this costs and what to tighten.

## 2. Image

Tags are immutable in this repository, so every build needs a new one.

```sh
REPO=$($TF output -raw ecr_repository_url)
TAG=$(git rev-parse --short HEAD)
aws ecr get-login-password | docker login --username AWS --password-stdin "${REPO%%/*}"
docker build --platform linux/amd64 -t "$REPO:$TAG" app
docker push "$REPO:$TAG"
```

`--platform linux/amd64` matters when building on an Apple Silicon laptop for
`m7i` nodes.

## 3. cert-manager

The Flink operator's admission webhook needs it.

```sh
helm repo add jetstack https://charts.jetstack.io
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace --version v1.21.3 --set crds.enabled=true
```

## 4. Flink operator, and the service account jobs run as

The operator's chart creates the `flink` service account. The annotation is the
whole of IRSA from the workload's side, and the namespace and name must match
the role's trust policy (`flink_namespace`, `flink_service_account`).

```sh
helm repo add flink-operator https://archive.apache.org/dist/flink/flink-kubernetes-operator-1.16.1/
helm upgrade --install flink-kubernetes-operator flink-operator/flink-kubernetes-operator \
  --namespace flink --create-namespace --version 1.16.1 \
  --set "jobServiceAccount.annotations.eks\.amazonaws\.com/role-arn=$($TF output -raw flink_irsa_role_arn)"
```

## 5. Topics

Auto-creation is off on the MSK cluster. The image carries a small tool that
creates missing topics and refuses to alter existing ones.

```sh
BOOTSTRAP=$($TF output -raw msk_bootstrap_brokers)
kubectl -n flink run topics --rm -i --restart=Never \
  --image "$REPO:$TAG" --env KAFKA_IAM_AUTH=true \
  --overrides '{"spec":{"serviceAccountName":"flink"}}' --command -- \
  java -cp '/opt/flink/lib/*:/opt/flink/usrlib/*' dev.samuelxing.flinkjob.Topics \
  "$BOOTSTRAP" orders:24:3 revenue_1m:6:3
```

`orders:24:3` is 24 partitions, replication 3. The partition count is the
ceiling on the pipeline's source parallelism; choose it now.

## 6. Jobs

```sh
for job in generator pipeline; do
  helm upgrade --install "$job" charts/flink-job --namespace flink \
    -f charts/flink-job/values-prod.yaml \
    --set sqlFile="$job.sql" \
    --set image.repository="$REPO" --set image.tag="$TAG" \
    --set checkpoints.bucket="$($TF output -raw checkpoints_bucket)" \
    --set kafka.bootstrap="$BOOTSTRAP"
done
kubectl -n flink get flinkdeployment
```

In a real system the generator does not exist: `orders` is written by whatever
takes orders.

## What to check first when it does not work

These are the places most likely to be wrong, in order:

1. **IRSA and the S3 plugin.** `flink-s3-fs-presto` should pick up the web
   identity token through the default credential chain. If checkpoints fail
   with an access error, the pod has the token (`AWS_WEB_IDENTITY_TOKEN_FILE`
   is set) but the plugin is not using it.
2. **MSK IAM.** A timeout fetching topic metadata usually means the connection
   was made and then refused: check the `kafka-cluster:*` statements in the
   `flink-irsa` module against the cluster ARN.
3. **`kubectl` is Unauthorized.** The cluster creator is granted admin by
   `enable_cluster_creator_admin_permissions`; anyone else needs an access
   entry.
