variable "project" {
  description = "Project name - used as prefix for all resources"
  type        = string
}

variable "env" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "account_id" {
  description = "AWS account ID - used to ensure globally unique bucket names"
  type        = string
}

variable "eks_oidc_provider_url" {
  description = "OIDC provider URL of the EKS cluster - empty until Phase 3"
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
  description = "ARN of the raw S3 bucket - used in Glue IAM policy"
  type        = string
}

variable "curated_bucket_arn" {
  description = "ARN of the curated S3 bucket - used in Glue IAM policy"
  type        = string
}

variable "athena_results_bucket_arn" {
  description = "ARN of the athena_results S3 bucket - used in Glue IAM policy"
  type        = string
}

variable "assets_bucket_arn" {
  description = "ARN of the assets S3 bucket - Glue needs read access to download scripts"
  type        = string
}


variable "tfstate_bucket_name" {
  description = "Name of the S3 bucket used for Terraform state - managed outside Terraform"
  type        = string
  default     = "data-platform-tfstate-811430801421"
}

variable "tfstate_lock_table_name" {
  description = "Name of the DynamoDB table used for Terraform state locking - managed outside Terraform"
  type        = string
  default     = "data-platform-tfstate-lock"
}

variable "github_owner" {
  description = "GitHub username or organization that owns the repositories"
  type        = string
  default     = "germanramirez-datatent"
}

variable "github_repos" {
  description = "List of GitHub repository names allowed to assume the GitHub Actions IAM role via OIDC"
  type        = list(string)
  default = [
    "data-platform-infra",
    "data-platform-workflows",
    "data-platform-images",
    "data-platform-dbt",
  ]
}

variable "github_allowed_environments" {
  description = "GitHub Environments allowed to assume the GitHub Actions IAM role via OIDC. Defaults to the Terraform env value when empty."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for environment in var.github_allowed_environments : length(trimspace(environment)) > 0])
    error_message = "github_allowed_environments cannot contain empty environment names."
  }
}
