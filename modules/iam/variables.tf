variable "project" {
  description = "Project name — used as prefix for all resources"
  type        = string
}

variable "env" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "account_id" {
  description = "AWS account ID — used to ensure globally unique bucket names"
  type        = string
}

variable "eks_oidc_provider_url" {
  description = "OIDC provider URL of the EKS cluster — empty until Phase 3"
  type        = string
  default     = ""
}

variable "eks_namespace" {
  description = "Kubernetes namespace allowed to assume the EKS IAM role through IRSA"
  type        = string
  default     = "argo"
}

variable "eks_service_account_name" {
  description = "Kubernetes service account name allowed to assume the EKS IAM role through IRSA"
  type        = string
  default     = "workflow"
}

variable "raw_bucket_arn" {
  description = "ARN of the raw S3 bucket — used in Glue IAM policy"
  type        = string
}

variable "curated_bucket_arn" {
  description = "ARN of the curated S3 bucket — used in Glue IAM policy"
  type        = string
}

variable "athena_results_bucket_arn" {
  description = "ARN of the athena_results S3 bucket — used in Glue IAM policy"
  type        = string
}