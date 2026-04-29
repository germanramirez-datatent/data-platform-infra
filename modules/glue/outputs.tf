output "raw_database_name" {
  description = "Name of the Glue Catalog database that stores raw datasets."
  value       = aws_glue_catalog_database.raw.name
}

output "curated_database_name" {
  description = "Name of the Glue Catalog database that stores curated datasets."
  value       = aws_glue_catalog_database.curated.name
}

output "transform_to_curated_job_name" {
  description = "Name of the Glue job that transforms raw data into curated datasets."
  value       = aws_glue_job.transform_to_curated.name
}

output "transform_to_curated_job_arn" {
  description = "ARN of the Glue job that transforms raw data into curated datasets."
  value       = aws_glue_job.transform_to_curated.arn
}
