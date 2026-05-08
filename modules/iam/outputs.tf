output "glue_role_arn" {
  description = "ARN of the Glue IAM role"
  value       = aws_iam_role.glue.arn
}

output "eks_workflow_role_arn" {
  description = "ARN of the IRSA role for EKS workflow pods"
  value       = aws_iam_role.eks_workflow.arn
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role assumed by GitHub Actions via OIDC - use in workflow role-to-assume"
  value       = aws_iam_role.github_actions.arn
}

output "eso_role_arn" {
  description = "ARN of the IRSA role for External Secrets Operator"
  value       = length(aws_iam_role.eso) > 0 ? aws_iam_role.eso[0].arn : ""
}