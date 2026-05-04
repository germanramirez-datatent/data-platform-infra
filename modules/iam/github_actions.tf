locals {
  github_actions_role_name   = "${var.project}-github-actions-role"
  github_actions_policy_name = "${var.project}-github-actions-policy"
  tfstate_bucket_arn         = "arn:aws:s3:::${var.tfstate_bucket_name}"
  tfstate_lock_table_arn     = "arn:aws:dynamodb:eu-west-1:${var.account_id}:table/${var.tfstate_lock_table_name}"

  github_actions_environments = length(var.github_allowed_environments) > 0 ? var.github_allowed_environments : [var.env]

  # GitHub Actions OIDC subjects allowed to assume this role.
  github_actions_allowed_subjects = flatten([
    for repo in var.github_repos : [
      for environment in local.github_actions_environments :
      "repo:${var.github_owner}/${repo}:environment:${environment}"
    ]
  ])

  # Additional subjects for pull request workflows (no environment context).
  github_actions_pr_subjects = [
    "repo:${var.github_owner}/data-platform-dbt:pull_request",
    "repo:${var.github_owner}/data-platform-infra:pull_request",
  ]

  github_oidc_thumbprints = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

# Register GitHub Actions as an OIDC identity provider in this AWS account.
# One provider per account - shared by all repositories.
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = local.github_oidc_thumbprints

  tags = { purpose = "github-actions-oidc" }
}

# Trust policy: only allow tokens from our specific GitHub repos and environments.
# The sub claim format is: repo:<owner>/<repo>:environment:<environment>
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    sid     = "AllowGitHubActionsOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    # Restrict to repositories owned by github_owner and explicitly allowed GitHub Environments.
    # Also allows pull_request triggers from data-platform-dbt and data-platform-infra.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = concat(local.github_actions_allowed_subjects, local.github_actions_pr_subjects)
    }

    # Enforce audience - prevents token reuse across AWS accounts
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# Permissions policy - ECR push/pull + Terraform state + infrastructure management.
data "aws_iam_policy_document" "github_actions" {
  # --- ECR: login ---
  statement {
    sid       = "AllowECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # GetAuthorizationToken does not support resource-level permissions
  }

  # --- ECR: push and pull ---
  statement {
    sid    = "AllowECRPushPull"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]

    resources = ["arn:aws:ecr:eu-west-1:${var.account_id}:repository/${var.project}/*"]
  }

  # --- Terraform state backend ---
  statement {
    sid    = "AllowTerraformStateBucket"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]

    resources = [
      local.tfstate_bucket_arn,
      "${local.tfstate_bucket_arn}/*",
    ]
  }

  statement {
    sid    = "AllowTerraformStateLock"
    effect = "Allow"

    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable",
    ]

    resources = [local.tfstate_lock_table_arn]
  }

  # --- S3 data lake management ---
  statement {
    sid    = "AllowS3Management"
    effect = "Allow"

    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:DeleteBucketTagging",
      "s3:GetAccelerateConfiguration",
      "s3:GetBucketAcl",
      "s3:GetBucketCORS",
      "s3:GetBucketLocation",
      "s3:GetBucketLogging",
      "s3:GetBucketNotification",
      "s3:GetBucketObjectLockConfiguration",
      "s3:GetBucketOwnershipControls",
      "s3:GetBucketPolicy",
      "s3:GetBucketPolicyStatus",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketRequestPayment",
      "s3:GetBucketTagging",
      "s3:GetBucketVersioning",
      "s3:GetBucketWebsite",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
      "s3:PutBucketPolicy",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketTagging",
      "s3:PutBucketVersioning",
      "s3:PutEncryptionConfiguration",
      "s3:PutLifecycleConfiguration",
    ]

    resources = ["arn:aws:s3:::${var.project}-*"]
  }

  statement {
    sid       = "AllowS3ListBuckets"
    effect    = "Allow"
    actions   = ["s3:ListAllMyBuckets"]
    resources = ["*"]
  }

  # --- S3 object access for dbt (read source data + write Athena query results) ---
  statement {
    sid    = "AllowS3DataLakeObjects"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = ["arn:aws:s3:::${var.project}-*/*"]
  }

  # --- IAM management ---
  statement {
    sid    = "AllowIAMManagement"
    effect = "Allow"

    actions = [
      "iam:AttachRolePolicy",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:CreateRole",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:DeleteRole",
      "iam:DetachRolePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListPolicies",
      "iam:ListPolicyVersions",
      "iam:ListRolePolicies",
      "iam:ListRoles",
      "iam:PassRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviders",
      "iam:TagOpenIDConnectProvider",
    ]

    resources = ["*"]
  }

  # --- Glue management ---
  statement {
    sid    = "AllowGlueManagement"
    effect = "Allow"

    actions = [
      "glue:CreateDatabase",
      "glue:DeleteDatabase",
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:UpdateDatabase",
      "glue:GetTable",
      "glue:GetTables",
      "glue:GetTableVersions",
      "glue:CreateTable",
      "glue:UpdateTable",
      "glue:DeleteTable",
      "glue:GetPartition",
      "glue:GetPartitions",
      "glue:BatchGetPartition",
      "glue:CreatePartition",
      "glue:UpdatePartition",
      "glue:DeletePartition",
      "glue:BatchCreatePartition",
      "glue:BatchDeletePartition",
      "glue:GetTags",
      "glue:TagResource",
      "glue:UntagResource",
      "glue:CreateCrawler",
      "glue:DeleteCrawler",
      "glue:GetCrawler",
      "glue:GetCrawlers",
      "glue:UpdateCrawler",
      "glue:CreateJob",
      "glue:DeleteJob",
      "glue:GetJob",
      "glue:GetJobs",
      "glue:UpdateJob",
    ]

    resources = ["*"]
  }

  # --- Athena management ---
  statement {
    sid    = "AllowAthenaManagement"
    effect = "Allow"

    actions = [
      "athena:CreateWorkGroup",
      "athena:DeleteWorkGroup",
      "athena:GetWorkGroup",
      "athena:ListWorkGroups",
      "athena:UpdateWorkGroup",
      "athena:TagResource",
      "athena:UntagResource",
      "athena:ListTagsForResource",
    ]

    resources = ["*"]
  }

  # --- Athena query execution (required by dbt) ---
  statement {
    sid    = "AllowAthenaQueryExecution"
    effect = "Allow"

    actions = [
      "athena:StartQueryExecution",
      "athena:StopQueryExecution",
      "athena:GetQueryExecution",
      "athena:GetQueryResults",
      "athena:ListQueryExecutions",
      "athena:BatchGetQueryExecution",
    ]

    resources = ["*"]
  }

  # --- ECR repository management ---
  statement {
    sid    = "AllowECRManagement"
    effect = "Allow"

    actions = [
      "ecr:CreateRepository",
      "ecr:DeleteRepository",
      "ecr:DescribeRepositories",
      "ecr:GetLifecyclePolicy",
      "ecr:GetRepositoryPolicy",
      "ecr:ListTagsForResource",
      "ecr:PutLifecyclePolicy",
      "ecr:PutImageScanningConfiguration",
      "ecr:PutImageTagMutability",
      "ecr:SetRepositoryPolicy",
      "ecr:TagResource",
      "ecr:UntagResource",
    ]

    resources = ["*"]
  }

  # --- EKS management (Fase 3) ---
  statement {
    sid    = "AllowEKSManagement"
    effect = "Allow"

    actions = [
      "eks:CreateCluster",
      "eks:DeleteCluster",
      "eks:DescribeCluster",
      "eks:DescribeNodegroup",
      "eks:CreateNodegroup",
      "eks:DeleteNodegroup",
      "eks:ListClusters",
      "eks:ListNodegroups",
      "eks:TagResource",
      "eks:UntagResource",
      "eks:UpdateClusterConfig",
      "eks:UpdateNodegroupConfig",
      "eks:AssociateIdentityProviderConfig",
      "eks:DescribeIdentityProviderConfig",
      "eks:ListIdentityProviderConfigs",
      "eks:CreateAddon",
      "eks:DeleteAddon",
      "eks:DescribeAddon",
      "eks:ListAddons",
    ]

    resources = ["*"]
  }

  # --- EC2 (required by EKS node groups - Fase 3) ---
  statement {
    sid    = "AllowEC2ForEKS"
    effect = "Allow"

    actions = [
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeNatGateways",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:CreateLaunchTemplate",
      "ec2:DeleteLaunchTemplate",
      "ec2:CreateLaunchTemplateVersion",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:ModifyVpcAttribute",
      "ec2:CreateSubnet",
      "ec2:DeleteSubnet",
      "ec2:ModifySubnetAttribute",
      "ec2:CreateInternetGateway",
      "ec2:DeleteInternetGateway",
      "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway",
      "ec2:CreateRouteTable",
      "ec2:DeleteRouteTable",
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable",
      "ec2:AllocateAddress",
      "ec2:ReleaseAddress",
      "ec2:AssociateAddress",
      "ec2:DisassociateAddress",
      "ec2:CreateNatGateway",
      "ec2:DeleteNatGateway",
    ]

    resources = ["*"]
  }
}

# IAM role assumed by GitHub Actions via OIDC - no static credentials.
resource "aws_iam_role" "github_actions" {
  name               = local.github_actions_role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
  description        = "Role assumed by GitHub Actions via OIDC - no static credentials."

  tags = { purpose = "github-actions-oidc" }
}

# Least-privilege policy for CI/CD pipelines.
resource "aws_iam_policy" "github_actions" {
  name        = local.github_actions_policy_name
  description = "Least-privilege policy for GitHub Actions OIDC - ECR push/pull and Terraform management."
  policy      = data.aws_iam_policy_document.github_actions.json
}

# Attach the policy to the GitHub Actions role.
resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}
