output "db_instance_id" {
  description = "ID of the RDS instance"
  value       = aws_db_instance.this.id
}

output "db_instance_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.this.arn
}

output "db_endpoint" {
  description = "Connection endpoint for the RDS instance — treat as sensitive; reveals internal hostname"
  value       = aws_db_instance.this.endpoint
  sensitive   = true
}

output "db_port" {
  description = "Port the RDS instance is listening on"
  value       = aws_db_instance.this.port
  sensitive   = true
}
