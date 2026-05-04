# Data Platform Infrastructure

Terraform and local bootstrap assets for the shopping center data platform. This repository provisions the AWS foundation for the lakehouse and provides a local k3d-based environment for Argo workflow development.

## What It Creates

The `dev` Terraform environment provisions:

- S3 buckets for `raw`, `curated`, `athena-results`, and `assets`.
- Server-side encryption on all platform buckets.
- Versioning for the raw and curated buckets.
- A raw bucket lifecycle rule that transitions objects to Glacier after 90 days.
- Glue Catalog databases for raw and curated datasets.
- A Glue crawler for raw data discovery.
- A reusable AWS Glue 4.0 job that transforms raw JSON into curated Parquet.
- IAM roles and policies for Glue, with optional IRSA assets for EKS workflows.
- An Athena workgroup for analytics queries.
- ECR repositories for platform container images.

## Repository Layout

```text
.
|-- environments
|   `-- dev
|       |-- backend.tf
|       |-- main.tf
|       `-- variables.tf
|-- modules
|   |-- argo
|   |-- athena
|   |-- ecr
|   |-- glue
|   |-- iam
|   `-- s3-data-lake
`-- scripts
    `-- init-local.sh
```

## AWS Environment

The current `dev` environment is configured for:

- Region: `eu-west-1`
- Project: `data-platform`
- Environment: `dev`
- Terraform backend bucket: `data-platform-tfstate-`
- Terraform lock table: `data-platform-tfstate-lock`

Terraform resource names include the project, environment, and AWS account ID where required, for example:

- `data-platform-dev-raw-`
- `data-platform-dev-curated-`
- `data-platform-dev-athena-results-`
- `data-platform-dev-assets-`
- `data-platform-dev-transform-to-curated`
- `data-platform-dev-analytics`

## Prerequisites

- Terraform `>= 1.7`
- AWS CLI credentials for the target account
- An existing Terraform state bucket and DynamoDB lock table
- Docker Desktop, k3d, kubectl, Helm, and MinIO Client (`mc`) for local bootstrap

## Deploying Infrastructure

From the `dev` environment:

```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

The Glue transform job expects these assets to be uploaded to the assets bucket:

- `s3://<assets-bucket>/glue/transform.py`
- `s3://<assets-bucket>/glue/glue_transformers-0.1.0-py3-none-any.whl`

Those files are produced from the `data-platform-images/glue-transform` code.

## Local Development Environment

The bootstrap script creates a local k3d cluster and installs the workflow runtime used by the sibling repositories.

```bash
bash scripts/init-local.sh
```

The script:

- Creates or reuses a k3d cluster named `data-platform`.
- Installs Argo Workflows in the `argo` namespace.
- Applies workflow RBAC, MinIO, and the simulation API Kubernetes resources.
- Creates a `minio-credentials` secret for local storage.
- Imports local Docker images into the k3d cluster when they exist.
- Creates MinIO buckets named `raw`, `curated`, and `athena-results`.
- Applies the daily traffic CronWorkflow.

After bootstrap, use port-forwarding to access local UIs:

```bash
kubectl -n argo port-forward deployment/argo-workflows-server 2746:2746
kubectl -n argo port-forward deployment/minio 9000:9000
kubectl -n argo port-forward deployment/minio 9001:9001
```

Available local UIs:

- Argo UI: `http://localhost:2746`
- MinIO UI: `http://localhost:9001`

Default local MinIO credentials are `minioadmin` / `minioadmin`.

## Related Repositories

- `data-platform-images`: containerized Python services, ingestion jobs, validation jobs, Glue trigger, and Glue transform package.
- `data-platform-workflows`: Argo workflows and Kubernetes manifests that run the platform pipelines.
- `data-platform-dbt`: Athena-backed dbt analytics models over the curated Glue tables.

## Operational Notes

- ECR repositories are mutable and scan images on push.
- ECR lifecycle policy removes untagged images quickly and keeps only the latest tagged images according to `max_tagged_images`.
- The Glue job writes curated tables with dynamic partition overwrite enabled.
- The optional EKS IRSA role is only created when `eks_oidc_provider_url` is provided.
