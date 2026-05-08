output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.this.cluster_name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = module.this.cluster_arn
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = module.this.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the EKS control plane"
  value       = module.this.cluster_version
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate data required to authenticate to the cluster"
  value       = module.this.cluster_certificate_authority_data
}

output "cluster_security_group_id" {
  description = "Security group attached to the EKS control plane"
  value       = module.this.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group attached to the managed worker nodes"
  value       = module.this.node_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider created for IRSA"
  value       = module.this.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "OIDC issuer URL used by IAM Roles for Service Accounts"
  value       = module.this.cluster_oidc_issuer_url
}

output "vpc_id" {
  description = "VPC ID used by the EKS cluster"
  value       = local.vpc_id
}

output "subnet_ids" {
  description = "Subnet IDs used by the EKS cluster and managed node group"
  value       = local.subnet_ids
}
