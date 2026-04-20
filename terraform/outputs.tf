output "vpc_id" {
  description = "ID of the QuantumTrade VPC"
  value       = aws_vpc.main.id
}

output "app_server_id" {
  description = "EC2 instance ID of the application server"
  value       = module.app_server.instance_id
}

output "data_bucket_arn" {
  description = "ARN of the transaction data S3 bucket"
  value       = module.data_bucket.bucket_arn
}

output "db_instance_endpoint" {
  description = "RDS PostgreSQL connection endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "private_subnet_id" {
  description = "ID of the primary private subnet"
  value       = aws_subnet.private.id
}
