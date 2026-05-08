variable "project" {
  description = "Project name - used as prefix for the EKS cluster"
  type        = string
}

variable "env" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.33"
}

variable "vpc_id" {
  description = "Existing VPC ID to deploy into. When empty, the AWS default VPC is used."
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Existing subnet IDs for the control plane and node group. When empty, all subnets in the selected VPC are used."
  type        = list(string)
  default     = []
}

variable "cluster_endpoint_public_access" {
  description = "Whether the Kubernetes API server endpoint is publicly reachable"
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Whether the Kubernetes API server endpoint is privately reachable from within the VPC"
  type        = bool
  default     = true
}

variable "cluster_enabled_log_types" {
  description = "EKS control plane log types to enable in CloudWatch"
  type        = list(string)
  default = [
    "api",
    "audit",
    "authenticator",
  ]
}

variable "cloudwatch_log_group_retention_in_days" {
  description = "Retention for EKS control plane logs in CloudWatch"
  type        = number
  default     = 7
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_capacity_type" {
  description = "Capacity type for the managed node group (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be either ON_DEMAND or SPOT."
  }
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in the managed node group"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the managed node group"
  type        = number
  default     = 2
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in the managed node group"
  type        = number
  default     = 1
}

variable "node_disk_size" {
  description = "Root EBS volume size in GiB for managed nodes"
  type        = number
  default     = 50
}

variable "tags" {
  description = "Additional tags to apply to EKS resources"
  type        = map(string)
  default     = {}
}
