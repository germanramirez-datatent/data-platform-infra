terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

module "s3_data_lake" {
  source  = "../../modules/s3-data-lake"
  project = "data-platform"
  env     = "dev"
  account_id = "811430801421"
}

module "iam" {
  source = "../../modules/iam"

  project    = "data-platform"
  env        = "dev"
  account_id = "811430801421"

  raw_bucket_arn            = module.s3_data_lake.raw_bucket_arn
  curated_bucket_arn        = module.s3_data_lake.curated_bucket_arn
  athena_results_bucket_arn = module.s3_data_lake.athena_results_bucket_arn

  # eks_oidc_provider_url vacío hasta Fase 3
}