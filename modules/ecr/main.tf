locals {
  # Full repository name: project/image-name
  # e.g. data-platform/dbt-runner
  repositories = { for name in var.image_names : name => "${var.project}/${name}" }
}

# One ECR repository per image.
resource "aws_ecr_repository" "this" {
  for_each = local.repositories

  name                 = each.value
  image_tag_mutability = "MUTABLE" # allows overwriting :latest on every push

  image_scanning_configuration {
    scan_on_push = true # free basic scanning — catches known CVEs on push
  }

  tags = {
    image = each.key
  }
}

# Lifecycle policy: keep only the last N tagged images and remove untagged
# digests immediately. Prevents orphaned layers from accumulating when
# pushing :latest repeatedly.
resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images immediately"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the last ${var.max_tagged_images} tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["latest", "v"]
          countType     = "imageCountMoreThan"
          countNumber   = var.max_tagged_images
        }
        action = { type = "expire" }
      }
    ]
  })
}
