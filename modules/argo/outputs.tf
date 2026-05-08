output "argo_workflows_namespace" {
  description = "Kubernetes namespace where Argo Workflows is installed"
  value       = kubernetes_namespace.argo.metadata[0].name
}

output "eso_namespace" {
  description = "Kubernetes namespace where External Secrets Operator is installed"
  value       = kubernetes_namespace.external_secrets.metadata[0].name
}
