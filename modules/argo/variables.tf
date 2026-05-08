variable "cluster_name" {
  description = "Name of the EKS cluster — used to fetch the auth token"
  type        = string
}

variable "cluster_endpoint" {
  description = "Kubernetes API server endpoint — from the EKS module output"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate of the EKS cluster — from the EKS module output"
  type        = string
}

variable "argo_workflows_chart_version" {
  description = "Helm chart version for Argo Workflows"
  type        = string
  default     = "0.45.19"
}

variable "eso_chart_version" {
  description = "Helm chart version for External Secrets Operator"
  type        = string
  default     = "0.10.7"
}

variable "eso_role_arn" {
  description = "ARN of the IAM role for External Secrets Operator IRSA"
  type        = string
}