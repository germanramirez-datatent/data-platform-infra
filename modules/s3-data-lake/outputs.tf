output "raw_bucket_arn" {
  description = "ARN of the raw bucket"
  value       = aws_s3_bucket.raw.arn
}

output "raw_bucket_id" {
  description = "Name/ID of the raw bucket"
  value       = aws_s3_bucket.raw.id
}

output "curated_bucket_arn" {
  description = "ARN of the curated bucket"
  value       = aws_s3_bucket.curated.arn
}

output "curated_bucket_id" {
  description = "Name/ID of the curated bucket"
  value       = aws_s3_bucket.curated.id
}

output "athena_results_bucket_arn" {
  description = "ARN of the athena results bucket"
  value       = aws_s3_bucket.athena_results.arn
}

output "athena_results_bucket_id" {
  description = "Name/ID of the athena_results bucket"
  value       = aws_s3_bucket.athena_results.id
}
