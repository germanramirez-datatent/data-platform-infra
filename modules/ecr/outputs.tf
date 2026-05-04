output "repository_urls" {
  description = "Map of image name to ECR repository URL (without tag)"
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

output "registry_id" {
  description = "AWS account ID of the ECR registry"
  value       = values(aws_ecr_repository.this)[0].registry_id
}
