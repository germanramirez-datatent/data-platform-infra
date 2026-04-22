variable "project" {
  description = "Project name — used as prefix for all resources"
  type        = string
}

variable "env" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "glue_role_arn" {
  description = "ARN of the IAM role assumed by Glue crawlers and jobs"
  type        = string
}

variable "raw_bucket_id" {
  description = "Name/ID of the raw S3 bucket — used as crawler target"
  type        = string
}

variable "curated_bucket_id" {
  description = "Name/ID of the curated S3 bucket — used as crawler target"
  type        = string
}