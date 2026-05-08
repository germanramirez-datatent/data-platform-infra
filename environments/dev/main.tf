terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      project    = "data-platform"
      env        = "dev"
      managed-by = "terraform"
    }
  }
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

module "s3_data_lake" {
  source     = "../../modules/s3-data-lake"
  project    = "data-platform"
  env        = "dev"
  account_id = "811430801421"
}

module "argo" {
  source = "../../modules/argo"

  cluster_name           = module.eks.cluster_name
  cluster_endpoint       = module.eks.cluster_endpoint
  cluster_ca_certificate = module.eks.cluster_certificate_authority_data
  eso_role_arn           = module.iam.eso_role_arn
}

module "eks" {
  source              = "../../modules/eks"

  project             = "data-platform"
  env                 = "dev"

  node_instance_types = ["t3.small"]
}

module "iam" {
  source = "../../modules/iam"

  project    = "data-platform"
  env        = "dev"
  account_id = "811430801421"

  raw_bucket_arn            = module.s3_data_lake.raw_bucket_arn
  curated_bucket_arn        = module.s3_data_lake.curated_bucket_arn
  athena_results_bucket_arn = module.s3_data_lake.athena_results_bucket_arn
  assets_bucket_arn         = module.s3_data_lake.assets_bucket_arn

  eks_oidc_provider_url = module.eks.oidc_provider_url
}

module "glue" {
  source = "../../modules/glue"

  project = "data-platform"
  env     = "dev"

  glue_role_arn     = module.iam.glue_role_arn
  raw_bucket_id     = module.s3_data_lake.raw_bucket_id
  curated_bucket_id = module.s3_data_lake.curated_bucket_id
  assets_bucket_id  = module.s3_data_lake.assets_bucket_id
}

module "athena" {
  source = "../../modules/athena"

  project                  = "data-platform"
  env                      = "dev"
  athena_results_bucket_id = module.s3_data_lake.athena_results_bucket_id
}

module "ecr" {
  source  = "../../modules/ecr"
  project = "data-platform"

  image_names = [
    "simulation-api",
    "python-ingestor",
    "data-quality",
    "glue-trigger",
    "dbt-runner",
    "serving-api",
    "stream-consumer",
  ]
}

output "ecr_repository_urls" {
  description = "ECR repository URLs by image name"
  value       = module.ecr.repository_urls
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions OIDC role"
  value       = module.iam.github_actions_role_arn
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_oidc_provider_url" {
  description = "OIDC issuer URL for IRSA"
  value       = module.eks.oidc_provider_url
}
