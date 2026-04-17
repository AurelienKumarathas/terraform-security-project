output "bucket_id" {
  description = "ID (name) of the created S3 bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the created S3 bucket"
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "Bucket domain name for use in policies and CloudFront"
  value       = aws_s3_bucket.this.bucket_domain_name
}
