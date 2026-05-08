data "aws_vpc" "default" {
  count = var.vpc_id == "" ? 1 : 0

  default = true
}

data "aws_subnets" "default" {
  count = length(var.subnet_ids) == 0 ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

locals {
  cluster_name = "${var.project}-${var.env}-eks"
  vpc_id       = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default[0].id
  subnet_ids   = length(var.subnet_ids) > 0 ? var.subnet_ids : sort(data.aws_subnets.default[0].ids)
}

module "this" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access
  cluster_enabled_log_types       = var.cluster_enabled_log_types

  enable_irsa                              = true
  enable_cluster_creator_admin_permissions = true
  cloudwatch_log_group_retention_in_days   = var.cloudwatch_log_group_retention_in_days

  vpc_id                   = local.vpc_id
  subnet_ids               = local.subnet_ids
  control_plane_subnet_ids = local.subnet_ids

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  eks_managed_node_groups = {
    default = {
      name                            = "default"
      use_name_prefix                 = false
      iam_role_name                   = "${local.cluster_name}-node"
      iam_role_use_name_prefix        = false
      launch_template_name            = "${local.cluster_name}-node"
      launch_template_use_name_prefix = false
      min_size                        = var.node_group_min_size
      max_size                        = var.node_group_max_size
      desired_size                    = var.node_group_desired_size
      instance_types                  = var.node_instance_types
      capacity_type                   = var.node_capacity_type
      disk_size                       = var.node_disk_size

      labels = {
        workload = "platform"
      }
    }
  }

  tags = merge(
    {
      Name = local.cluster_name
    },
    var.tags
  )
}
