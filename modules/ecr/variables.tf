variable "project" {
  description = "Project name — used as prefix for all repository names"
  type        = string
}

variable "image_names" {
  description = "List of image names to create repositories for (e.g. dbt-runner, python-ingestor)"
  type        = list(string)
}

variable "max_tagged_images" {
  description = "Maximum number of tagged images to retain per repository before expiring older ones"
  type        = number
  default     = 5
}
