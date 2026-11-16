SHELL := /bin/bash
.DEFAULT_GOAL := help

CHART    := charts/flink-job
TF_PROD  := terraform/envs/prod
KIND_CLUSTER := flink-platform

## ---- help ---------------------------------------------------------------
help: ## Show this help
	@grep -hE '^[a-zA-Z0-9_.-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk -F':.*?## ' '{printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

## ---- app ----------------------------------------------------------------
test: ## Run the SQL runner's unit tests
	cd app && mvn -B test

build: ## Build the job image
	docker build -t flink-sql-platform:dev app

## ---- local --------------------------------------------------------------
kind-up: ## Create the local kind cluster
	kind create cluster --config local/kind.yaml

kind-down: ## Delete the local kind cluster
	kind delete cluster --name $(KIND_CLUSTER)

local-up: kind-up ## Create the cluster and bring the whole stack up under Tilt
	cd local && tilt up

local-ci: ## Bring the stack up, wait until everything is ready, then exit
	cd local && tilt ci --timeout 30m

local-status: ## Job state, pods, and what is in the checkpoint bucket
	kubectl -n flink-platform get flinkdeployment
	kubectl -n flink-platform get pods
	kubectl -n flink-platform exec deploy/localstack -- awslocal s3 ls s3://flink-checkpoints/jobs/ --recursive | tail -15

local-down: ## Tear the Tilt stack down (leaves the cluster)
	cd local && tilt down

## ---- chart --------------------------------------------------------------
lint: ## helm lint both value sets
	helm lint $(CHART) -f $(CHART)/values-local.yaml
	helm lint $(CHART) -f $(CHART)/values-prod.yaml \
	  --set checkpoints.bucket=example --set image.repository=example \
	  --set image.tag=v1 --set kafka.bootstrap=b-1.example:9098

render-local: ## Render the chart as it would deploy locally
	helm template pipeline $(CHART) -f $(CHART)/values-local.yaml

diff-envs: ## Show exactly how local and prod Flink config differ
	@helm template demo $(CHART) -f $(CHART)/values-local.yaml 2>/dev/null \
	  | sed -n '/flinkConfiguration:/,/podTemplate:/p' | grep -vE '^\s*#|^\s*$$' > /tmp/.local.yaml
	@helm template demo $(CHART) -f $(CHART)/values-prod.yaml \
	  --set checkpoints.bucket=acme-ckpt --set image.repository=ecr/flink \
	  --set image.tag=sha-abc --set kafka.bootstrap=b-1.msk:9098 2>/dev/null \
	  | sed -n '/flinkConfiguration:/,/podTemplate:/p' | grep -vE '^\s*#|^\s*$$' > /tmp/.prod.yaml
	@diff -u /tmp/.local.yaml /tmp/.prod.yaml || true

## ---- terraform ----------------------------------------------------------
tf-fmt: ## Format all HCL
	terraform fmt -recursive terraform

tf-validate: ## Validate every module and the prod env
	@set -e; for d in terraform/modules/*/ terraform/envs/*/; do \
	  echo "--- $$d"; \
	  terraform -chdir=$$d init -backend=false -input=false >/dev/null; \
	  terraform -chdir=$$d validate; \
	done

tf-plan: ## Plan prod. Needs real AWS credentials; read-only, creates nothing.
	terraform -chdir=$(TF_PROD) init -input=false
	terraform -chdir=$(TF_PROD) plan

## The one module that can be applied for real without an AWS account.
## Needs the local stack up: Tilt forwards LocalStack to localhost:4566.
tf-local-apply: ## Apply the checkpoints module against LocalStack
	terraform -chdir=terraform/envs/local init -input=false
	terraform -chdir=terraform/envs/local apply -auto-approve -input=false

tf-local-destroy: ## Destroy what tf-local-apply created
	terraform -chdir=terraform/envs/local destroy -auto-approve -input=false

.PHONY: help test build kind-up kind-down local-up local-ci local-status local-down lint \
        render-local diff-envs tf-fmt tf-validate tf-plan tf-local-apply tf-local-destroy
