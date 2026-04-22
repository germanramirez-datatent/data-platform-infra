locals {
  raw_database_name     = "${var.project}_${var.env}_raw"
  curated_database_name = "${var.project}_${var.env}_curated"
  raw_crawler_name      = "${var.project}-${var.env}-raw-crawler"
}

# Glue Catalog database for raw ingestion data.
resource "aws_glue_catalog_database" "raw" {
  name        = local.raw_database_name
  description = "Glue Catalog database for raw data ingested from source systems."
}

# Glue Catalog database for curated analytics-ready data.
resource "aws_glue_catalog_database" "curated" {
  name        = local.curated_database_name
  description = "Glue Catalog database for curated data prepared for analytics workloads."
}

# Crawler that scans the raw S3 bucket and updates the raw Glue database.
resource "aws_glue_crawler" "raw" {
  name          = local.raw_crawler_name
  role          = var.glue_role_arn
  database_name = aws_glue_catalog_database.raw.name
  description   = "Crawls the raw S3 bucket and registers datasets in the raw Glue Catalog database."

  s3_target {
    path = "s3://${var.raw_bucket_id}/"
  }

  # Run daily at 03:00 UTC, after the ingestion workflow scheduled at 02:00 UTC.
  schedule = "cron(0 3 * * ? *)"
}

