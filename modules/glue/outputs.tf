output "raw_database_name" {
  description = "Name of the Glue Catalog database that stores raw datasets."
  value       = aws_glue_catalog_database.raw.name
}

output "curated_database_name" {
  description = "Name of the Glue Catalog database that stores curated datasets."
  value       = aws_glue_catalog_database.curated.name
}
