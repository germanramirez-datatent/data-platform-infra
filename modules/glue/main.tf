locals {
  raw_database_name       = "${var.project}_${var.env}_raw"
  curated_database_name   = "${var.project}_${var.env}_curated"
  raw_crawler_name        = "${var.project}-${var.env}-raw-crawler"
  transform_job_name      = "${var.project}-${var.env}-transform-to-curated"
  transform_script_s3_uri = "s3://${var.assets_bucket_id}/glue/transform.py"
  transform_wheel_s3_uri  = "s3://${var.assets_bucket_id}/glue/glue_transformers-0.1.0-py3-none-any.whl"
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

# Reusable PySpark job that transforms raw JSON source data into curated Parquet.
resource "aws_glue_job" "transform_to_curated" {
  name        = local.transform_job_name
  role_arn    = var.glue_role_arn
  description = "Transforms raw JSON data into curated Parquet datasets."

  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 30

  command {
    name            = "glueetl"
    script_location = local.transform_script_s3_uri
    python_version  = "3"
  }

  default_arguments = {
    "--RAW_BUCKET"                       = var.raw_bucket_id
    "--CURATED_BUCKET"                   = var.curated_bucket_id
    "--WRITE_MODE"                       = "overwrite"
    "--extra-py-files"                   = local.transform_wheel_s3_uri
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"                   = "true"
    "--job-language"                     = "python"
    "--conf"                             = "spark.sql.sources.partitionOverwriteMode=dynamic"
  }

  execution_property {
    max_concurrent_runs = 4
  }
}
