variable "project" {
  description = "Project name — used as prefix for all resources"
  type        = string
}

variable "env" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "athena_results_bucket_id" {
  description = "Name/ID of the S3 bucket used to store Athena query results"
  type        = string
}
