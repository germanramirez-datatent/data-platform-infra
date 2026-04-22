output "glue_role_arn" {
  description = "ARN of the Glue IAM role"
  value       = aws_iam_role.glue.arn
}

output "eks_workflow_role_arn" {
  description = "ARN of the IRSA role for EKS workflow pods — empty until Phase 3"
  value       = length(aws_iam_role.eks_workflow) > 0 ? aws_iam_role.eks_workflow[0].arn : ""
}