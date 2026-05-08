locals {
  glue_role_name       = "${var.project}-${var.env}-glue-role"
  glue_policy_name     = "${var.project}-${var.env}-glue-policy"
  eks_role_name        = "${var.project}-${var.env}-eks-workflow-role"
  eks_policy_name      = "${var.project}-${var.env}-eks-workflow-policy"
  eks_oidc_provider_id = replace(var.eks_oidc_provider_url, "https://", "")
  eks_service_account  = "system:serviceaccount:${var.eks_namespace}:${var.eks_service_account_name}"
  eso_role_name        = "${var.project}-${var.env}-eso-role"
  eso_policy_name      = "${var.project}-${var.env}-eso-policy"
  eso_service_account  = "system:serviceaccount:external-secrets:external-secrets"
  create_eks_iam_assets = var.eks_oidc_provider_url != "" ? 1 : 0
}

# Trust policy that allows AWS Glue to assume this IAM role.
data "aws_iam_policy_document" "assume_role" {
  statement {
    sid    = "AllowGlueToAssumeRole"
    effect = "Allow"

    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

# Permissions policy for accessing the data lake buckets.
data "aws_iam_policy_document" "glue_access" {
  statement {
    sid    = "AllowListBucket"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]

    resources = [
      var.raw_bucket_arn,
      var.curated_bucket_arn,
      var.assets_bucket_arn
    ]
  }

  statement {
    sid    = "AllowObjectReadWrite"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      "${var.raw_bucket_arn}/*",
      "${var.curated_bucket_arn}/*",
      "${var.assets_bucket_arn}/*"
    ]
  }

  statement {
    sid    = "AllowGlueLogging"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "cloudwatch:PutMetricData",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowGlueCatalogAccess"
    effect = "Allow"

    actions = [
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:UpdateDatabase",
      "glue:GetTable",
      "glue:GetTables",
      "glue:GetTableVersion",
      "glue:GetTableVersions",
      "glue:GetPartition",
      "glue:BatchGetPartition",
      "glue:GetPartitions",
      "glue:CreateTable",
      "glue:UpdateTable",
      "glue:DeleteTable",
      "glue:BatchDeleteTable",
      "glue:CreatePartition",
      "glue:BatchCreatePartition",
      "glue:UpdatePartition",
      "glue:DeletePartition",
      "glue:BatchDeletePartition",
      "glue:GetUserDefinedFunction",
      "glue:GetUserDefinedFunctions",
    ]

    resources = [
      "arn:aws:glue:eu-west-1:${var.account_id}:catalog",
      "arn:aws:glue:eu-west-1:${var.account_id}:database/data-platform_*",
      "arn:aws:glue:eu-west-1:${var.account_id}:table/data-platform_*/*",
      "arn:aws:glue:eu-west-1:${var.account_id}:userDefinedFunction/data-platform_*/*",
    ]
  }

  statement {
    sid    = "AllowGlueDefaultDatabaseRead"
    effect = "Allow"

    actions = [
      "glue:GetDatabase",
      "glue:GetTable",
      "glue:GetTables",
      "glue:GetUserDefinedFunction",
      "glue:GetUserDefinedFunctions",
    ]

    resources = [
      "arn:aws:glue:eu-west-1:${var.account_id}:catalog",
      "arn:aws:glue:eu-west-1:${var.account_id}:database/default",
      "arn:aws:glue:eu-west-1:${var.account_id}:table/default/*",
      "arn:aws:glue:eu-west-1:${var.account_id}:userDefinedFunction/default/*",
    ]
  }
}

# IAM role to be assumed by AWS Glue jobs or crawlers.
resource "aws_iam_role" "glue" {
  name               = local.glue_role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  description = "IAM role assumed by AWS Glue to access data lake resources."
}

# Customer-managed IAM policy for Glue data lake access.
resource "aws_iam_policy" "glue" {
  name        = local.glue_policy_name
  description = "Permissions for AWS Glue to read and write data lake buckets."
  policy      = data.aws_iam_policy_document.glue_access.json
}

# Attach the custom policy to the Glue IAM role.
resource "aws_iam_role_policy_attachment" "glue" {
  role       = aws_iam_role.glue.name
  policy_arn = aws_iam_policy.glue.arn
}

# Trust policy for EKS workloads using IAM Roles for Service Accounts (IRSA).
data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    sid    = "AllowEksServiceAccountToAssumeRole"
    effect = "Allow"

    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      identifiers = [
        "arn:aws:iam::${var.account_id}:oidc-provider/${local.eks_oidc_provider_id}"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_provider_id}:sub"
      values   = [local.eks_service_account]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_provider_id}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# Permissions policy for EKS workloads that need access to the data lake buckets.
data "aws_iam_policy_document" "eks_access" {
  statement {
    sid    = "AllowListBucket"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]

    resources = [
      var.raw_bucket_arn,
      var.curated_bucket_arn,
      var.athena_results_bucket_arn
    ]
  }

  statement {
    sid    = "AllowObjectReadWrite"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      "${var.raw_bucket_arn}/*",
      "${var.curated_bucket_arn}/*",
      "${var.athena_results_bucket_arn}/*"
    ]
  }

  statement {
    sid    = "AllowSSMParameterRead"
    effect = "Allow"

    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]

    resources = [
      "arn:aws:ssm:eu-west-1:${var.account_id}:parameter/data-platform/${var.env}/*"
    ]
  }

  statement {
    sid    = "AllowAthenaQuery"
    effect = "Allow"

    actions = [
      "athena:StartQueryExecution",
      "athena:GetQueryExecution",
      "athena:GetQueryResults",
      "athena:StopQueryExecution",
      "athena:GetWorkGroup",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowGlueCatalogRead"
    effect = "Allow"

    actions = [
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetTable",
      "glue:GetTables",
      "glue:GetTableVersion",
      "glue:GetTableVersions",
      "glue:GetPartition",
      "glue:GetPartitions",
      "glue:BatchGetPartition",
      "glue:CreateTable",
      "glue:UpdateTable",
      "glue:DeleteTable",
      "glue:BatchDeleteTable",
      "glue:CreatePartition",
      "glue:BatchCreatePartition",
      "glue:UpdatePartition",
      "glue:DeletePartition",
      "glue:BatchDeletePartition",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowGlueJobRun"
    effect = "Allow"

    actions = [
      "glue:StartJobRun",
      "glue:GetJobRun",
      "glue:GetJobRuns",
      "glue:StopJobRun",
    ]

    resources = [
      "arn:aws:glue:eu-west-1:${var.account_id}:job/${var.project}-${var.env}-*"
    ]
  }
}

# IAM role for EKS workloads that authenticate through IRSA.
resource "aws_iam_role" "eks_workflow" {
  name               = local.eks_role_name
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
  description        = "IAM role assumed by EKS workloads through IRSA."
}

# Customer-managed IAM policy for EKS workloads.
resource "aws_iam_policy" "eks_workflow" {
  name        = local.eks_policy_name
  description = "Permissions for EKS workloads to access data lake buckets."
  policy      = data.aws_iam_policy_document.eks_access.json
}

# Attach the custom policy to the EKS IAM role.
resource "aws_iam_role_policy_attachment" "eks_workflow" {
  role       = aws_iam_role.eks_workflow.name
  policy_arn = aws_iam_policy.eks_workflow.arn
}

data "aws_iam_policy_document" "eso_assume_role" {
  count = local.create_eks_iam_assets

  statement {
    sid     = "AllowESOAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${var.account_id}:oidc-provider/${local.eks_oidc_provider_id}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_provider_id}:sub"
      values   = [local.eso_service_account]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_provider_id}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "eso_access" {
  count = local.create_eks_iam_assets

  statement {
    sid    = "AllowSSMRead"
    effect = "Allow"

    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]

    resources = [
      "arn:aws:ssm:eu-west-1:${var.account_id}:parameter/data-platform/${var.env}/*"
    ]
  }
}

resource "aws_iam_role" "eso" {
  count              = local.create_eks_iam_assets
  name               = local.eso_role_name
  assume_role_policy = data.aws_iam_policy_document.eso_assume_role[0].json
  description        = "IAM role assumed by External Secrets Operator through IRSA."
}

resource "aws_iam_policy" "eso" {
  count       = local.create_eks_iam_assets
  name        = local.eso_policy_name
  description = "Permissions for ESO to read SSM parameters."
  policy      = data.aws_iam_policy_document.eso_access[0].json
}

resource "aws_iam_role_policy_attachment" "eso" {
  count      = local.create_eks_iam_assets
  role       = aws_iam_role.eso[0].name
  policy_arn = aws_iam_policy.eso[0].arn
}