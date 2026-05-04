locals {
  workgroup_name = "${var.project}-${var.env}-analytics"
}

# Athena workgroup used for analytics queries across the data platform.
resource "aws_athena_workgroup" "analytics" {
  name = local.workgroup_name

  description = "Athena workgroup for running analytics queries on the data platform."
  state       = "ENABLED"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${var.athena_results_bucket_id}/query-results/"
    }
  }
}
