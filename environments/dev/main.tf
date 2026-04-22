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