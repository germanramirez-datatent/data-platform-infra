terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

locals {
  argo_namespace = "argo"
  eso_namespace  = "external-secrets"
}

# ---------------------------------------------------------------------------
# Namespace: argo
# ---------------------------------------------------------------------------
resource "kubernetes_namespace" "argo" {
  metadata {
    name = local.argo_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ---------------------------------------------------------------------------
# Argo Workflows — installed via Helm
# ---------------------------------------------------------------------------
resource "helm_release" "argo_workflows" {
  name       = "argo-workflows"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-workflows"
  version    = var.argo_workflows_chart_version
  namespace  = kubernetes_namespace.argo.metadata[0].name

  values = [file("${path.module}/values.yaml")]

  set {
    name  = "server.serviceType"
    value = "ClusterIP"
  }

  depends_on = [kubernetes_namespace.argo]
}

# ---------------------------------------------------------------------------
# Namespace: external-secrets
# ---------------------------------------------------------------------------
resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = local.eso_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ---------------------------------------------------------------------------
# External Secrets Operator — installed via Helm
# ---------------------------------------------------------------------------
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.eso_chart_version
  namespace  = kubernetes_namespace.external_secrets.metadata[0].name

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.eso_role_arn
  }

  depends_on = [kubernetes_namespace.external_secrets]
}
