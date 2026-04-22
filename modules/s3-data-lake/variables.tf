variable "project" {
  description = "Project name — used as prefix for all resources"
  type        = string
}

variable "env" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "account_id" {
  description = "AWS account ID — used to ensure globally unique bucket names"
  type        = string
}